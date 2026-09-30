import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input_dialog.dart';

import '../../../helpers/reachability_expectations.dart';

const _landscapePadding = FakeViewPadding(left: 32, right: 48);

final _viewports = <({Size size, double keyboard, FakeViewPadding padding})>[
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0])
    (size: Size(width, 900), keyboard: 0, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 0, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 160, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 160, padding: _landscapePadding),
  (size: const Size(568, 320), keyboard: 120, padding: FakeViewPadding.zero),
  (size: const Size(360, 740), keyboard: 300, padding: FakeViewPadding.zero),
];

Finder _button(String label) => find.ancestor(
  of: find.text(label, skipOffstage: false),
  matching: find.byWidgetPredicate(
    (widget) => widget is ButtonStyleButton,
    skipOffstage: false,
  ),
);

Future<void> _openInputDialog(
  WidgetTester tester, {
  required ({Size size, double keyboard, FakeViewPadding padding}) viewport,
  required String locale,
  required double textScale,
}) async {
  tester.view.physicalSize = viewport.size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = viewport.padding;
  tester.view.viewInsets = FakeViewPadding(bottom: viewport.keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => ThemedInputDialog.show(
                context: context,
                title: locale == 'zh'
                    ? '重命名所选类别'
                    : 'Rename the selected category',
                hintText: locale == 'zh' ? '输入新名称' : 'Enter a new name',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['zh', 'en']) {
    for (final textScale in [1.0, 3.0]) {
      testWidgets(
        '输入对话框在各宽度、短横屏、安全区与键盘下不溢出，$locale ${textScale}x 时标题、输入与操作都可达',
        (tester) async {
          for (final viewport in _viewports) {
            await _openInputDialog(
              tester,
              viewport: viewport,
              locale: locale,
              textScale: textScale,
            );
            final reason =
                '${viewport.size} keyboard=${viewport.keyboard} '
                'padding=${viewport.padding.left} $locale ${textScale}x';
            expect(tester.takeException(), isNull, reason: reason);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(ThemedInputDialog)),
            )!;
            for (final (label, target) in [
              (
                '关闭',
                find.ancestor(
                  of: find.byIcon(Icons.close, skipOffstage: false),
                  matching: find.byType(IconButton, skipOffstage: false),
                ),
              ),
              ('输入框', find.byType(TextField, skipOffstage: false)),
              ('取消', _button(l10n.common_cancel)),
              ('确认', _button(l10n.common_confirm)),
            ]) {
              await revealOnScreen(tester, target);
              expectReachable(tester, target, reason: '$reason $label');
            }
            expect(tester.takeException(), isNull, reason: reason);
          }
        },
      );
    }
  }

  testWidgets('input, validation error and IME stay in the safe viewport', (
    tester,
  ) async {
    final view = tester.view;
    view.devicePixelRatio = 3;
    view.physicalSize = const Size(960, 1704);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            padding: EdgeInsets.fromLTRB(12, 24, 12, 16),
            viewInsets: EdgeInsets.only(bottom: 240),
            textScaler: TextScaler.linear(3),
          ),
          child: Scaffold(
            body: ThemedInputDialog(
              title: 'A long localized title that wraps',
              labelText: 'A long field label',
              hintText: 'A long field hint',
              multiline: true,
              validator: (value) => value == 'bad'
                  ? 'A long validation error that must remain readable and scrollable'
                  : null,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.pump();

    expect(find.textContaining('long validation error'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField).evaluate().single.widget, isA<TextField>());

    view.physicalSize = const Size(4800, 2700);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(1600, 900),
            textScaler: TextScaler.linear(3),
          ),
          child: Scaffold(
            body: ThemedInputDialog(title: 'Large text input', multiline: true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
