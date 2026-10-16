import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input_dialog.dart';

import '../../../helpers/reachability_expectations.dart';
import '../../../helpers/viewport_scenarios.dart';

Future<void> _openInputDialog(
  WidgetTester tester, {
  required ViewportScenario viewport,
  required String locale,
  required double textScale,
  String? title,
  String? labelText,
  bool multiline = false,
  String? Function(String)? validator,
}) async {
  applyViewport(tester, viewport);
  await tester.pumpWidget(
    localizedTestApp(
      locale: Locale(locale),
      textScale: textScale,
      home: panelLauncher(
        'open',
        (context) => ThemedInputDialog.show(
          context: context,
          title:
              title ??
              (locale == 'zh' ? '重命名所选类别' : 'Rename the selected category'),
          labelText: labelText,
          hintText: locale == 'zh' ? '输入新名称' : 'Enter a new name',
          multiline: multiline,
          validator: validator,
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
          for (final viewport in formViewports) {
            await _openInputDialog(
              tester,
              viewport: viewport,
              locale: locale,
              textScale: textScale,
            );
            final reason =
                '${describeViewport(viewport)} $locale ${textScale}x';
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
              ('取消', buttonLabeled(l10n.common_cancel)),
              ('确认', buttonLabeled(l10n.common_confirm)),
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

  testWidgets('长标题、多行输入与校验错误在 3x 文字、键盘与安全区下都可滚动看到', (tester) async {
    for (final viewport in [
      (
        size: const Size(320, 568),
        keyboard: 240.0,
        padding: const FakeViewPadding(
          left: 12,
          top: 24,
          right: 12,
          bottom: 16,
        ),
      ),
      (
        size: const Size(1600, 900),
        keyboard: 0.0,
        padding: FakeViewPadding.zero,
      ),
    ]) {
      await _openInputDialog(
        tester,
        viewport: viewport,
        locale: 'en',
        textScale: 3,
        title: 'A long localized title that wraps',
        labelText: 'A long field label',
        multiline: true,
        validator: (value) => value == 'bad'
            ? 'A long validation error that must remain readable and scrollable'
            : null,
      );
      await tester.enterText(find.byType(TextField), 'bad');
      await tester.pump();

      final error = find.textContaining('long validation error');
      expect(error, findsOneWidget, reason: '${viewport.size}');
      await revealOnScreen(tester, error);
      expect(
        visibleViewRect(tester).contains(tester.getRect(error).center),
        isTrue,
        reason: '${viewport.size}',
      );
      expect(tester.takeException(), isNull, reason: '${viewport.size}');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });
}
