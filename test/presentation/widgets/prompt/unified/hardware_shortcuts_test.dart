import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';

void main() {
  testWidgets('tag mode search, replace, clear and undo use the same source', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'cat, dog, dog');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: UnifiedPromptInput(
                controller: controller,
                sessionId: 'tag_mode_search',
                enableAssistant: false,
                expands: true,
                config: const UnifiedPromptConfig(
                  enableAutocomplete: false,
                  enableSyntaxHighlight: false,
                  enableTagMode: true,
                  showClearButton: true,
                  clearNeedsConfirm: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('prompt_input_search_field')),
      'dog',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
          .where((w) => w.selected)
          .single
          .tag
          .span
          .label,
      'dog',
    );
    await tester.enterText(
      find.byKey(const ValueKey('prompt_input_replace_field')),
      'bird',
    );
    await tester.tap(find.byKey(const ValueKey('prompt_input_replace_all')));
    await tester.pumpAndSettle();
    expect(controller.text, 'cat, bird, bird');
    expect(find.byType(TagEditorCapsule), findsNWidgets(3));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(UnifiedPromptInput)),
    )!;
    await tester.tap(find.byTooltip(l10n.prompt_searchClose));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-clear-button')));
    await tester.pumpAndSettle();
    expect(controller.text, '');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.text, 'cat, bird, bird');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('physical keyboard shortcuts work on a touch-first platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final controller = TextEditingController(text: 'blue eyes');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 240,
              child: UnifiedPromptInput(
                controller: controller,
                sessionId: 'physical_keyboard_shortcuts',
                enableAssistant: false,
                fitContent: true,
                config: const UnifiedPromptConfig(
                  enableAutocomplete: false,
                  enableSyntaxHighlight: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;

    expect(find.byKey(const ValueKey('prompt_input_search_field')), findsOne);
    await tester.pump(const Duration(milliseconds: 250));
  });
}
