import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_help_dialog.dart';

void main() {
  testWidgets('320px、3x 字号、IME 与 SafeArea 下可搜索滚动并正确返回', (tester) async {
    await _pumpHost(
      tester,
      size: const Size(320, 900),
      textScaler: const TextScaler.linear(3),
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      viewInsets: const EdgeInsets.only(bottom: 320),
    );

    await tester.tap(find.byKey(const ValueKey('open-shortcut-help')));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(surface, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('shortcut-help-scroll')), findsOneWidget);
    expect(tester.getTopLeft(surface).dy, greaterThanOrEqualTo(24));
    expect(tester.getBottomRight(surface).dy, lessThanOrEqualTo(580));

    expect(find.textContaining('Ctrl'), findsOneWidget);

    final search = find.byKey(const ValueKey('shortcut-help-search'));
    await tester.tap(search);
    await tester.enterText(search, 'not-found');
    await tester.pump();

    expect(find.text('未找到匹配的快捷键'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  for (final scenario in [
    (
      name: 'Medium',
      size: const Size(700, 800),
      surfaceKey: const ValueKey('adaptive-bottom-sheet'),
    ),
    (
      name: 'Expanded',
      size: const Size(1000, 800),
      surfaceKey: const ValueKey('adaptive-centered-form'),
    ),
  ]) {
    testWidgets('${scenario.name} 使用共享有界面板', (tester) async {
      await _pumpHost(tester, size: scenario.size);

      await tester.tap(find.byKey(const ValueKey('open-shortcut-help')));
      await tester.pumpAndSettle();

      final surface = find.byKey(scenario.surfaceKey);
      expect(surface, findsOneWidget);
      expect(tester.getSize(surface).width, lessThan(scenario.size.width));
      expect(find.text('快捷键帮助'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('shortcut-help-search')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
        searchShortcutsProvider('not-found').overrideWith((ref) => const []),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            textScaler: textScaler,
            padding: padding,
            viewPadding: padding,
            viewInsets: viewInsets,
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const ValueKey('open-shortcut-help'),
                onPressed: () => ShortcutHelpDialog.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
