import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/shortcut_settings_panel.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_display_names.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_help_dialog.dart';

const _locales = [Locale('zh'), Locale('en'), Locale('ja')];

const _sharedBindings = <String, ShortcutBinding>{
  'generate_image': ShortcutBinding(
    id: 'generate_image',
    actionKey: 'shortcut_action_generate_image',
    defaultShortcut: 'ctrl+enter',
  ),
  'vibe_import': ShortcutBinding(
    id: 'vibe_import',
    actionKey: 'shortcut_action_vibe_import',
    defaultShortcut: 'ctrl+i',
  ),
};

class _SharedShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async =>
      const ShortcutConfig(bindings: _sharedBindings);
}

void main() {
  group('文案解析', () {
    for (final locale in _locales) {
      test('${locale.languageCode} 下默认绑定的动作与分类都有译文', () {
        final l10n = lookupAppLocalizations(locale);
        final config = ShortcutConfig.createDefault();

        expect(config.bindings, isNotEmpty);
        for (final binding in config.bindings.values) {
          expect(
            shortcutActionDisplayName(l10n, binding.actionKey),
            isNotEmpty,
            reason: binding.actionKey,
          );
        }

        final untranslated =
            config.bindings.values
                .map((binding) => binding.actionKey)
                .where(
                  (actionKey) =>
                      shortcutActionDisplayName(l10n, actionKey) ==
                      shortcutActionFallbackName(actionKey),
                )
                .toList()
              ..sort();

        expect(
          untranslated,
          isEmpty,
          reason: '默认绑定必须收录进 shortcutActionDisplayName，不能退回裸键名：$untranslated',
        );

        for (final shortcutContext in ShortcutContext.values) {
          expect(
            shortcutContextDisplayName(l10n, shortcutContext),
            isNotEmpty,
            reason: '$shortcutContext',
          );
        }
      });
    }

    test('未收录的 actionKey 退回裸键名', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));

      expect(
        shortcutActionDisplayName(l10n, 'shortcut_action_not_translated'),
        'not_translated',
      );
    });
  });

  group('设置面板与帮助弹窗文案一致', () {
    for (final locale in _locales) {
      testWidgets('${locale.languageCode} 下两个入口显示同一组文案', (tester) async {
        tester.view.physicalSize = const Size(900, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final l10n = lookupAppLocalizations(locale);
        final expectedActions = _sharedBindings.values
            .map(
              (binding) => shortcutActionDisplayName(l10n, binding.actionKey),
            )
            .toList();
        final expectedContext = shortcutContextDisplayName(
          l10n,
          ShortcutContext.global,
        );

        await _pump(tester, locale, const ShortcutHelpDialog());
        for (final action in expectedActions) {
          expect(find.text(action), findsOneWidget, reason: '帮助弹窗 $action');
        }
        expect(find.text(expectedContext), findsWidgets);
        expect(tester.takeException(), isNull);

        await _pump(tester, locale, const ShortcutSettingsPanel());
        await tester.tap(find.text(expectedContext).first);
        await tester.pumpAndSettle();
        for (final action in expectedActions) {
          expect(find.text(action), findsOneWidget, reason: '设置面板 $action');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _pump(WidgetTester tester, Locale locale, Widget panel) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _SharedShortcutConfigNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: panel),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
