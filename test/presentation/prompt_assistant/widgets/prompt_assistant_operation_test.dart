import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/generation_effort.dart';
import 'package:nai_launcher/core/services/prompt_token_counter_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_history_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/prompt_token_counter_provider.dart';
import 'package:nai_launcher/presentation/providers/reverse_prompt_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_editor.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_picker_dialog.dart';

import '../../../helpers/controlled_prompt_assistant_service.dart';
import '../../../helpers/memory_local_storage.dart';

class _Service extends Fake implements PromptAssistantService {
  // An explicit cleanup future belongs to this test's async zone, unlike
  // Dart's shared completed cancellation future for controllers without cleanup.
  final stream = StreamController<StreamingChunk>(onCancel: () async {});
  int calls = 0;
  int cancels = 0;

  @override
  Stream<StreamingChunk> optimizePrompt(
    String input, {
    required String sessionId,
  }) {
    calls++;
    return stream.stream;
  }

  @override
  Future<void> cancelCurrentTask({String? sessionId}) async {
    cancels++;
    // Cancellation can race with the final response from the transport.
    if (!stream.isClosed) {
      stream.add(const StreamingChunk(delta: 'late result'));
      await stream.close();
    }
  }
}

void main() {
  for (final outcome in ['success', 'cancel', 'error', 'unmount']) {
    testWidgets('processing collapses and handles $outcome', (tester) async {
      final source = TextEditingController(text: 'original');
      final service = _Service();
      addTearDown(source.dispose);
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => MemoryLocalStorage(),
          ),
          promptAssistantServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Align(
                child: PromptAssistantOverlay(
                  sessionId: 'operation',
                  controller: source,
                  placement: PromptAssistantPlacement.inline,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final notifier = container.read(promptAssistantStateProvider.notifier);
      notifier.setExpanded('operation', true);
      await tester.pump();
      await tester.tap(
        find.byIcon(Icons.auto_fix_high),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      expect(service.calls, 1);
      expect(find.byIcon(Icons.auto_fix_high), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('prompt_assistant_stop'))),
      );
      await tester.pump();
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final finished = Completer<void>();
      final subscription = container.listen(
        promptAssistantStateProvider,
        (_, states) {
          if (states['operation']?.processing == false &&
              !finished.isCompleted) {
            finished.complete();
          }
        },
        fireImmediately: false,
      );
      addTearDown(subscription.close);
      switch (outcome) {
        case 'success':
          service.stream.add(const StreamingChunk(delta: 'updated'));
          await service.stream.close();
        case 'cancel':
          await mouse.down(
            tester.getCenter(
              find.byKey(const ValueKey('prompt_assistant_stop')),
            ),
          );
          await mouse.up();
          await service.stream.done;
        case 'error':
          service.stream.addError(StateError('test failure'));
          await service.stream.close();
        case 'unmount':
          await tester.pumpWidget(const SizedBox.shrink());
      }
      await finished.future;
      await tester.pumpAndSettle();
      if (outcome == 'cancel') {
        expect(
          service.cancels,
          1,
          reason: 'stop button must dispatch cancellation',
        );
      }
      expect(notifier.getState('operation').processing, false);
      expect(notifier.getState('operation').action, isNull);
      expect(source.text, outcome == 'success' ? 'updated' : 'original');
      expect(
        service.cancels,
        outcome == 'cancel' || outcome == 'unmount' ? 1 : 0,
      );
      if (outcome == 'error') {
        expect(notifier.getState('operation').error, contains('test failure'));
      }
      if (outcome == 'success') {
        expect(find.text('Prompt assistant finished'), findsOneWidget);
        expect(notifier.getState('operation').expanded, true);
      } else {
        expect(find.text('Prompt assistant finished'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final isCharacter in [false, true]) {
    final editorName = isCharacter ? '角色' : '主提示词';
    testWidgets('$editorName负向页切到固定 UC 后丢弃在途回复', (tester) async {
      final service = ControlledPromptAssistantService();
      addTearDown(service.dispose);
      final storage = _RecordingPromptStorage()
        ..values[StorageKeys.defaultModel] = ImageModels.animeDiffusionV5Full
        ..values[StorageKeys.lastNegativePrompt] = _negativePrompt
        ..values[StorageKeys.enableAutocomplete] = false;
      final characters = _RecordingCharacterNotifier();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          promptAssistantServiceProvider.overrideWithValue(service),
          characterPromptNotifierProvider.overrideWith(() => characters),
          for (final target in PromptTokenCountTarget.values)
            promptTokenUsageProvider(target).overrideWith(
              (ref) async => const PromptTokenUsage(usedTokens: 0, limit: 512),
            ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: isCharacter
                  ? const SingleChildScrollView(
                      child: CharacterPromptEditor(character: _character),
                    )
                  : const PromptInputWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        isCharacter
            ? find.text('Undesired Content')
            : find.byKey(const ValueKey('generation_prompt_negative_mode')),
      );
      await tester.pumpAndSettle();

      final sessionId = isCharacter
          ? PromptHistorySessionIds.characterNegative(_character.id)
          : PromptHistorySessionIds.generationNegative;
      final assistant = find.byType(PromptAssistantOverlay);
      final assistantState = tester.state(assistant);
      final controller = tester
          .widget<PromptAssistantOverlay>(assistant)
          .controller;
      expect(controller.text, _negativePrompt);
      final toolbar = find.byKey(
        ValueKey('prompt_assistant_toolbar_$sessionId'),
      );
      await tester.tap(
        find.descendant(
          of: toolbar,
          matching: find.byIcon(Icons.auto_awesome_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: toolbar, matching: find.byIcon(Icons.translate)),
      );
      await tester.pump();
      expect(service.requests, [sessionId]);
      expect(service.stream.hasListener, isTrue);

      container
          .read(generationParamsNotifierProvider.notifier)
          .updateEffort(GenerationEffort.medium);
      await tester.pump();
      expect(tester.state(assistant), same(assistantState));
      expect(tester.widget<PromptAssistantOverlay>(assistant).enabled, isFalse);
      expect(toolbar, findsNothing);

      service.respond('late result');
      await tester.pump();
      expect(controller.text, _negativePrompt);
      expect(storage.negativeWrites, isEmpty);
      expect(characters.updates, isEmpty);
      expect(service.cancellations, [sessionId]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'replacement always asks even with a saved reverse-prompt character',
    (tester) async {
      final source = TextEditingController(text: 'original');
      addTearDown(source.dispose);
      final service = _Service();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => MemoryLocalStorage(),
          ),
          promptAssistantServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(reversePromptCharacterProvider.notifier)
          .setReplacementCharacter(
            CharacterPrompt.create(
              name: 'Saved character',
              prompt: 'saved tags',
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                child: PromptAssistantOverlay(
                  sessionId: 'role',
                  controller: source,
                  placement: PromptAssistantPlacement.inline,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container
          .read(promptAssistantStateProvider.notifier)
          .setExpanded('role', true);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.manage_accounts_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(TagLibraryPickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(TagLibraryPickerDialog))).pop();
      await tester.pumpAndSettle();
      expect(
        container.read(promptAssistantStateProvider)['role']?.processing,
        false,
      );
      expect(source.text, 'original');
      expect(service.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(service.stream.close());
    },
  );
}

const _negativePrompt = 'blurry';
const _character = CharacterPrompt(
  id: 'alice',
  name: 'Alice',
  negativePrompt: _negativePrompt,
);

class _RecordingPromptStorage extends MemoryLocalStorage {
  final negativeWrites = <String>[];

  @override
  Future<void> setLastNegativePrompt(String negativePrompt) {
    negativeWrites.add(negativePrompt);
    return super.setLastNegativePrompt(negativePrompt);
  }
}

class _RecordingCharacterNotifier extends CharacterPromptNotifier {
  final updates = <CharacterPrompt>[];

  @override
  CharacterPromptConfig build() =>
      const CharacterPromptConfig(characters: [_character]);

  @override
  void updateCharacter(CharacterPrompt character) => updates.add(character);
}
