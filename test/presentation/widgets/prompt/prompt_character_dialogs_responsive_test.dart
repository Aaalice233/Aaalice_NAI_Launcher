import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/prompt/prompt_regex_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/prompt_regex_rules_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/add_to_library_dialog.dart';
import 'package:nai_launcher/presentation/widgets/prompt/regex_rules_dialog.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_help_dialog.dart';

void main() {
  testWidgets(
    'prompt and character panels stay reachable at 320x568, 3x and IME',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            promptRegexRulesProvider.overrideWith(_EmptyRegexRules.new),
            tagLibraryPageCategoriesProvider.overrideWith((ref) => const []),
            shortcutsByContextProvider.overrideWith(
              (ref) => const {
                ShortcutContext.global: [
                  ShortcutBinding(
                    id: 'responsive-test',
                    actionKey: 'responsive_test_action',
                    defaultShortcut: 'Ctrl+Shift+Alt+G',
                  ),
                ],
              },
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(3),
                viewInsets: const EdgeInsets.only(bottom: 220),
              ),
              child: child!,
            ),
            home: const _PanelTestHost(),
          ),
        ),
      );

      for (final label in ['Shortcuts', 'Library', 'Regex']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(
          find
                  .byKey(const ValueKey('adaptive-bottom-sheet'))
                  .evaluate()
                  .isNotEmpty ||
              find
                  .byKey(const ValueKey('adaptive-bottom-sheet'))
                  .evaluate()
                  .isNotEmpty,
          isTrue,
          reason: label,
        );
        expect(tester.takeException(), isNull, reason: label);

        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();
      }
    },
  );
}

class _PanelTestHost extends StatelessWidget {
  const _PanelTestHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(
            onPressed: () => ShortcutHelpDialog.show(context),
            child: const Text('Shortcuts'),
          ),
          FilledButton(
            onPressed: () => AddToLibraryDialog.show(
              context,
              name: 'Alice',
              content: '1girl, portrait',
            ),
            child: const Text('Library'),
          ),
          FilledButton(
            onPressed: () => RegexRulesDialog.show(context),
            child: const Text('Regex'),
          ),
        ],
      ),
    );
  }
}

class _EmptyRegexRules extends PromptRegexRules {
  @override
  List<PromptRegexRule> build() => const [];
}
