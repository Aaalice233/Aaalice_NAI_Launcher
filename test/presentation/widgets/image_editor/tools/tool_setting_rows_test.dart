import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/tools/tool_setting_rows.dart';

import '../../../../helpers/text_layout_expectations.dart';

void main() {
  const latinLabels = ['Size', 'Opacity', 'Hardness'];

  testWidgets('1x 标签放得下时保持 60px 标签列与 50px 数值列', (tester) async {
    const labels = ['大小', '不透明度', '硬度'];
    final controller = TextEditingController(text: '20');
    addTearDown(controller.dispose);
    await _pumpRows(
      tester,
      width: 280,
      rows: _sliderRows(labels, controller: controller),
    );

    for (final (index, label) in labels.indexed) {
      final labelRect = tester.getRect(find.text(label));
      final sliderRect = tester.getRect(find.byType(Slider).at(index));
      expect(sliderRect.left - labelRect.left, 60, reason: label);
      expect(
        sliderRect.center.dy,
        closeTo(labelRect.center.dy, 0.5),
        reason: label,
      );
    }
    expect(tester.getSize(find.text('100%')).width, 50);
    expect(tester.takeException(), isNull);
  });

  testWidgets('标签列按实测最宽标签对齐', (tester) async {
    await _pumpRows(tester, width: 600, rows: _sliderRows(latinLabels));

    final widest = tester
        .renderObject<RenderParagraph>(find.text('Hardness'))
        .getMaxIntrinsicWidth(double.infinity);
    expect(widest, greaterThan(60), reason: '测试字体下该标签应超出 1x 列宽');
    final sliderLefts = {
      for (var i = 0; i < latinLabels.length; i++)
        tester.getTopLeft(find.byType(Slider).at(i)).dx,
    };
    expect(sliderLefts, hasLength(1));
    expect(
      sliderLefts.single - tester.getTopLeft(find.text('Size')).dx,
      greaterThanOrEqualTo(widest),
    );
    for (final label in latinLabels) {
      expectSingleLineUntruncated(tester, find.text(label), reason: label);
    }
  });

  testWidgets('控件放不下时整组改为标签独占一行', (tester) async {
    await _pumpRows(
      tester,
      width: 320,
      textScale: 3,
      rows: _sliderRows(latinLabels),
    );

    for (final (index, label) in latinLabels.indexed) {
      expect(
        tester.getBottomLeft(find.text(label)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(Slider).at(index)).dy),
        reason: label,
      );
      expectSingleLineUntruncated(tester, find.text(label), reason: label);
    }
  });

  testWidgets('无尾随数值的行把剩余宽度全部交给控件', (tester) async {
    const controlKey = Key('control');
    await _pumpRows(
      tester,
      width: 280,
      rows: const [
        ToolSettingRow(
          label: '取样',
          control: SizedBox(key: controlKey, height: 40),
        ),
      ],
    );

    expect(tester.getSize(find.byKey(controlKey)).width, 280 - 24 - 60);
  });

  testWidgets('数值框提交时按滑块范围钳制', (tester) async {
    final controller = TextEditingController(text: '20');
    addTearDown(controller.dispose);
    final changes = <double>[];
    await _pumpRows(
      tester,
      width: 280,
      rows: [
        ToolSettingRow.slider(
          label: 'Size',
          value: 20,
          min: 1,
          max: 500,
          controller: controller,
          onChanged: changes.add,
        ),
      ],
    );

    for (final (input, expected) in const [
      ('900', 500.0),
      ('0', 1.0),
      ('42', 42.0),
      ('abc', 42.0),
    ]) {
      await tester.enterText(find.byType(EditableText), input);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(changes.last, expected, reason: input);
    }
    expect(changes, hasLength(3));
  });

  for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in const [1.0, 3.0]) {
      testWidgets('$width 宽 ${scale}x 文字下标签、数值与控件完整可达', (tester) async {
        final controller = TextEditingController(text: '20');
        addTearDown(controller.dispose);
        await _pumpRows(
          tester,
          width: width,
          textScale: scale,
          rows: _sliderRows(latinLabels, controller: controller),
        );
        final scenario = '$width x$scale';
        expect(tester.takeException(), isNull, reason: scenario);

        for (final text in [...latinLabels, '100%', '80%']) {
          expectSingleLineUntruncated(
            tester,
            find.text(text),
            reason: '$text $scenario',
          );
        }
        expect(
          tester.getSize(find.text('100%')).width,
          50 * scale,
          reason: '数值列随文字缩放 $scenario',
        );
        final fieldScroll = find.descendant(
          of: find.byType(EditableText),
          matching: find.byType(Scrollable),
        );
        expect(
          tester.state<ScrollableState>(fieldScroll).position.maxScrollExtent,
          0,
          reason: '数值框完整显示内容 $scenario',
        );

        final sliders = find.byType(Slider);
        for (final control in [
          find.byType(EditableText),
          for (var i = 0; i < latinLabels.length; i++) sliders.at(i),
        ]) {
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          expect(control.hitTestable(), findsOneWidget, reason: scenario);
        }
        for (var i = 0; i < latinLabels.length; i++) {
          expect(
            tester.getSize(sliders.at(i)).width,
            greaterThanOrEqualTo(120),
            reason: scenario,
          );
        }
      });
    }
  }
}

Future<void> _pumpRows(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  required List<ToolSettingRow> rows,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(child: ToolSettingRows(rows: rows)),
      ),
    ),
  );
}

List<ToolSettingRow> _sliderRows(
  List<String> labels, {
  TextEditingController? controller,
}) => [
  ToolSettingRow.slider(
    label: labels[0],
    value: 20,
    min: 1,
    max: 500,
    controller: controller,
    onChanged: (_) {},
  ),
  ToolSettingRow.slider(
    label: labels[1],
    value: 100,
    min: 0,
    max: 100,
    suffix: '%',
    onChanged: (_) {},
  ),
  ToolSettingRow.slider(
    label: labels[2],
    value: 80,
    min: 0,
    max: 100,
    suffix: '%',
    onChanged: (_) {},
  ),
];
