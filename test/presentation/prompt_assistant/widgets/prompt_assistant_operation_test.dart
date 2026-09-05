import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/providers/reverse_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_picker_dialog.dart';

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
      final stopListening = notifier.addListener((states) {
        if (states['operation']?.processing == false && !finished.isCompleted) {
          finished.complete();
        }
      }, fireImmediately: false);
      addTearDown(stopListening);
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
