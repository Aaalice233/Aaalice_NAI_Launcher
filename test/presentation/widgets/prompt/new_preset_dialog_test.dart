import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/new_preset_dialog.dart';

import '../../../helpers/reachability_expectations.dart';
import '../../../helpers/viewport_scenarios.dart';

Finder _ancestorOfText(String text, bool Function(Widget) matches) =>
    find.ancestor(
      of: find.text(text, skipOffstage: false),
      matching: find.byWidgetPredicate(matches, skipOffstage: false),
    );

void main() {
  for (final locale in ['zh', 'en']) {
    for (final textScale in [1.0, 3.0]) {
      testWidgets(
        '新建预设在各宽度、短横屏、安全区与键盘下不溢出，$locale ${textScale}x 时标题、字段、选项与操作都可达',
        (tester) async {
          for (final viewport in formViewports) {
            applyViewport(tester, viewport);
            await _pumpLauncher(
              tester,
              textScale: textScale,
              locale: Locale(locale),
            );
            await tester.tap(find.text('打开'));
            await tester.pumpAndSettle();
            final reason =
                '${describeViewport(viewport)} $locale ${textScale}x';
            expect(tester.takeException(), isNull, reason: reason);
            final l10n = AppLocalizations.of(
              tester.element(find.byType(NewPresetDialog)),
            )!;
            bool isInk(Widget widget) => widget is InkWell;
            for (final (label, target) in [
              (
                '关闭',
                find.ancestor(
                  of: find.byIcon(Icons.close, skipOffstage: false),
                  matching: find.byType(IconButton, skipOffstage: false),
                ),
              ),
              ('名称', find.byType(TextField, skipOffstage: false)),
              (
                '基于默认预设',
                _ancestorOfText(l10n.newPresetDialog_template, isInk).first,
              ),
              (
                '完全空白',
                _ancestorOfText(l10n.newPresetDialog_blank, isInk).first,
              ),
              ('取消', buttonLabeled(l10n.common_cancel)),
              ('创建', buttonLabeled(l10n.common_create)),
            ]) {
              await scrollUntilBuilt(
                tester,
                target,
                find.byKey(
                  const ValueKey('new-preset-dialog-scroll'),
                  skipOffstage: false,
                ),
              );
              await revealOnScreen(tester, target);
              expectReachable(tester, target, reason: '$reason $label');
            }
            expect(tester.takeException(), isNull, reason: reason);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }

  testWidgets('320 宽紧凑窗格以全屏长表单呈现', (tester) async {
    applyViewport(tester, plainViewport(const Size(320, 640)));

    await _pumpLauncher(tester);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('new-preset-dialog-frame')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('new-preset-dialog-scroll')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Medium 与 Expanded 窗格紧凑有界且操作区贴底', (tester) async {
    applyViewport(tester, plainViewport(const Size(700, 900)));
    await _pumpLauncher(tester);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    _expectBoundedDialog(tester, surfaceKey: 'adaptive-centered-form');
    expect(
      find.byKey(const ValueKey('adaptive-panel-header-divider')),
      findsNothing,
    );
    final nameField = find.descendant(
      of: find.byType(NewPresetDialog),
      matching: find.byType(ThemedInput),
    );
    expect(nameField, findsOneWidget, reason: '名称框复用共享输入色面，不另画整圈描边');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: nameField, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
      reason: '打开后名称框获得焦点',
    );
    final headerSurface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('adaptive-panel-header-surface')),
    );
    final headerContext = tester.element(
      find.byKey(const ValueKey('adaptive-panel-header-surface')),
    );
    expect(
      headerSurface.color,
      sectionSurfaceColor(Theme.of(headerContext).colorScheme),
    );

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    applyViewport(tester, plainViewport(const Size(1200, 900)));
    await tester.pump();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    _expectBoundedDialog(tester, surfaceKey: 'adaptive-centered-form');
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择创建方式后返回完整结果，系统返回则取消', (tester) async {
    applyViewport(tester, plainViewport(const Size(360, 700)));

    NewPresetResult? result;
    var completed = false;
    await _pumpLauncher(
      tester,
      onResult: (value) {
        result = value;
        completed = true;
      },
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '移动端预设');
    await tester.drag(
      find.byKey(const ValueKey('new-preset-dialog-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完全空白'));
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result?.name, '移动端预设');
    expect(result?.mode, PresetCreationMode.blank);

    completed = false;
    result = null;
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text('创建新预设'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _expectBoundedDialog(WidgetTester tester, {required String surfaceKey}) {
  final surfaceRect = tester.getRect(find.byKey(ValueKey(surfaceKey)));
  final frameRect = tester.getRect(
    find.byKey(const ValueKey('new-preset-dialog-frame')),
  );
  final createRect = tester.getRect(find.text('创建'));

  if (surfaceKey == 'adaptive-centered-form') {
    expect(frameRect.width, 420);
    expect(frameRect.height, lessThanOrEqualTo(460));
  } else {
    expect(frameRect.width, surfaceRect.width);
    expect(frameRect.height, lessThan(surfaceRect.height));
    expect(frameRect.bottom, closeTo(surfaceRect.bottom, 0.01));
  }
  expect(frameRect.left, greaterThanOrEqualTo(surfaceRect.left));
  expect(frameRect.right, lessThanOrEqualTo(surfaceRect.right));
  expect(frameRect.top, greaterThanOrEqualTo(surfaceRect.top));
  expect(frameRect.bottom, lessThanOrEqualTo(surfaceRect.bottom));
  expect(createRect.right, lessThanOrEqualTo(frameRect.right - 16));
  expect(createRect.bottom, lessThanOrEqualTo(frameRect.bottom - 16));
  expect(createRect.bottom, greaterThan(frameRect.bottom - 64));
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  double textScale = 1,
  Locale locale = const Locale('zh'),
  ValueChanged<NewPresetResult?>? onResult,
}) async {
  await tester.pumpWidget(
    localizedTestApp(
      locale: locale,
      textScale: textScale,
      home: panelLauncher('打开', (context) async {
        final result = await NewPresetDialog.show(context);
        onResult?.call(result);
      }),
    ),
  );
}
