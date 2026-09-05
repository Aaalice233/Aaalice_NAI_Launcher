import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_editor.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_history_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_overlay.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_card.dart';

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> values = {StorageKeys.enableAutocomplete: false};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = values[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();
}

void main() {
  List<Override> buildOverrides() => [
    localStorageServiceProvider.overrideWith((ref) => _MemoryStorage()),
    characterPromptNotifierProvider.overrideWith(
      _TestCharacterPromptNotifier.new,
    ),
  ];

  const character = CharacterPrompt(
    id: 'char-1',
    name: 'Alice',
    prompt: 'girl, silver hair, maid dress',
  );

  Widget buildTestApp({CharacterPrompt target = character}) {
    return ProviderScope(
      overrides: buildOverrides(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: InlineCharacterCard(character: target, index: 0, total: 1),
            ),
          ),
        ),
      ),
    );
  }

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets(
      'character resize accumulates rapid events and tracks reversal $kind',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(),
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: CharacterPromptEditor(character: character)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final area = find.byKey(
          const ValueKey('character-prompt-editor-area-positive'),
        );
        final handle = find.byKey(
          const ValueKey('character-prompt-resize-handle-positive'),
        );
        final initialHeight = tester.getSize(area).height;
        final start = tester.getCenter(handle);
        final gesture = await tester.startGesture(start, kind: kind);
        await gesture.moveTo(start + const Offset(0, 30));
        await gesture.moveTo(start + const Offset(0, 50));
        await gesture.moveTo(start + const Offset(0, 90));
        await tester.pump();
        expect(tester.getSize(area).height, closeTo(initialHeight + 90, .01));
        await gesture.moveTo(start + const Offset(0, 120));
        await tester.pump();
        expect(tester.getSize(area).height, closeTo(initialHeight + 120, .01));
        await gesture.moveTo(start + const Offset(0, 60));
        await tester.pump();
        expect(tester.getSize(area).height, closeTo(initialHeight + 60, .01));
        await gesture.up();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        // Flush the existing delayed focus-loss toolbar dismissal.
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'character control mounting and per-field mode $width/$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildOverrides(),
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 600),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      child: CharacterPromptEditor(character: character),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final toggle = find.byKey(const ValueKey('tag-mode-button'));
          final area = find.byKey(
            const ValueKey('character-prompt-editor-area-positive'),
          );
          expect(
            tester.getRect(toggle).bottom,
            lessThanOrEqualTo(tester.getRect(area).top),
          );
          final assistant = find.byType(PromptAssistantOverlay);
          expect(
            tester.widget<PromptAssistantOverlay>(assistant).tapRegionGroupId,
            CharacterPromptEditor.tapRegionGroupId(character.id),
          );
          expect(
            tester.getRect(assistant).bottom,
            lessThanOrEqualTo(tester.getRect(area).bottom),
          );
          expect(
            tester.getRect(assistant).right,
            lessThanOrEqualTo(tester.getRect(area).right),
          );
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.byType(TagEditorView), findsOneWidget);
          final l10n = AppLocalizations.of(tester.element(toggle))!;
          await tester.tap(find.text(l10n.prompt_negativePrompt));
          await tester.pumpAndSettle();
          expect(find.byType(TagEditorView), findsNothing);
          await tester.tap(find.text(l10n.prompt_positivePrompt));
          await tester.pumpAndSettle();
          expect(find.byType(TagEditorView), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  group('InlineCharacterCard', () {
    testWidgets('未选中时显示名字与提示词只读预览', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byKey(const Key('character-gender-female')), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('girl, silver hair, maid dress'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('点击预览区选中角色进入编辑态', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return const SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: InlineCharacterCard(
                        character: character,
                        index: 0,
                        total: 1,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('girl, silver hair, maid dress'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(capturedRef.read(selectedCharacterIdProvider), equals('char-1'));
      expect(find.byType(TextField), findsWidgets);
      expect(
        tester
            .widget<PromptAssistantOverlay>(find.byType(PromptAssistantOverlay))
            .sessionId,
        PromptHistorySessionIds.characterPrompt(character.id),
      );
    });

    testWidgets('子对话框内点击不会退出角色编辑态', (tester) async {
      late WidgetRef capturedRef;
      late BuildContext pageContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  pageContext = context;
                  return Consumer(
                    builder: (context, ref, child) {
                      capturedRef = ref;
                      return const SizedBox(
                        width: 400,
                        child: SingleChildScrollView(
                          child: InlineCharacterCard(
                            character: character,
                            index: 0,
                            total: 1,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('girl, silver hair, maid dress'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(capturedRef.read(selectedCharacterIdProvider), 'char-1');

      final dialog = showDialog<void>(
        context: pageContext,
        builder: (context) => AlertDialog(
          content: const Text('Custom assistant request'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Execute'),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Execute'));
      await tester.pump(const Duration(milliseconds: 300));
      await dialog;

      expect(capturedRef.read(selectedCharacterIdProvider), 'char-1');
      expect(find.byType(TextField), findsWidgets);
      await tester.pump(const Duration(seconds: 3));
      expect(capturedRef.read(selectedCharacterIdProvider), 'char-1');
    });

    testWidgets('禁用角色保持弱化显示', (tester) async {
      await tester.pumpWidget(
        buildTestApp(target: character.copyWith(enabled: false)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacity.opacity, 0.48);
    });

    testWidgets('窄屏三点菜单保留全部操作且不 overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('character-actions-menu')));
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(InlineCharacterCard)),
      )!;
      expect(find.text(l10n.characterEditor_moveUp), findsOneWidget);
      expect(find.text(l10n.characterEditor_moveDown), findsOneWidget);
      expect(find.text(l10n.tagLibrary_addToLibrary), findsOneWidget);
      expect(find.text(l10n.common_delete), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('添加到词库时保留角色独立负面提示词', (tester) async {
      const target = CharacterPrompt(
        id: 'char-negative',
        name: 'Alice',
        prompt: 'girl, blue eyes',
        negativePrompt: 'red hair, glasses',
      );
      await tester.pumpWidget(buildTestApp(target: target));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('character-actions-menu')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(InlineCharacterCard)),
      )!;
      await tester.tap(find.text(l10n.tagLibrary_addToLibrary));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('girl, blue eyes, negative(red hair, glasses)'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
