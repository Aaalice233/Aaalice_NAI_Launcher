import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/editable_double_field.dart';
import 'package:nai_launcher/presentation/widgets/common/labeled_control_rows.dart';
import 'package:nai_launcher/presentation/widgets/common/labeled_slider_rows.dart';

import '../../../helpers/labeled_rows_expectations.dart';

const _labelSets = {
  'ja': (readouts: ['不透明度', 'サイズ', 'ぼかしの強さ'], inputs: ['参照強度', '情報抽出量']),
  // 测试字体下拉丁字母约为真实宽度两倍，用来施加换行压力
  'en': (
    readouts: ['Opacity', 'Pixel size', 'Blur strength'],
    inputs: ['Reference strength', 'Information extracted'],
  ),
};

String _percent(double value) => '${(value * 100).round()}%';

void main() {
  testWidgets('标签列按最宽标签定宽，同组滑块左缘对齐', (tester) async {
    final labels = _labelSets['ja']!.readouts;
    await _pump(tester, width: 1180, child: _readoutRows(labels));

    final widest = labels
        .map(
          (label) => tester
              .renderObject<RenderParagraph>(labeledRowText(label))
              .getMaxIntrinsicWidth(double.infinity),
        )
        .reduce((a, b) => a > b ? a : b);
    final sliderLefts = {
      for (final label in labels) tester.getTopLeft(labeledRowSlider(label)).dx,
    };
    expect(sliderLefts, hasLength(1));
    expect(
      sliderLefts.single - tester.getTopLeft(labeledRowText(labels[0])).dx,
      moreOrLessEquals(widest.ceilToDouble()),
    );
    for (final label in labels) {
      expect(
        tester.getCenter(labeledRowText(label)).dy,
        moreOrLessEquals(tester.getCenter(labeledRowSlider(label)).dy),
        reason: '行内布局时标签与滑块同一行 $label',
      );
    }
  });

  testWidgets('读数列按区间两端定宽，拖到任何值滑块轨道长度都不变', (tester) async {
    Future<double> sliderWidthAt(double value) async {
      await _pump(
        tester,
        width: 600,
        child: LabeledSliderRows(
          sliders: [
            LabeledSlider(
              label: 'Weight',
              value: value,
              min: 1,
              max: 100,
              valueText: (weight) => '${weight.round()}',
              onChanged: (_) {},
            ),
          ],
        ),
      );
      return tester.getSize(labeledRowSlider('Weight')).width;
    }

    final atMin = await sliderWidthAt(1);
    expect(await sliderWidthAt(55), atMin);
    expect(await sliderWidthAt(100), atMin);
  });

  testWidgets('控件放不下时整组改为标签独占一行，读数仍与滑块同行', (tester) async {
    final labels = _labelSets['en']!.readouts;
    await _pump(tester, width: 360, textScale: 3, child: _readoutRows(labels));

    for (final label in labels) {
      final slider = tester.getRect(labeledRowSlider(label));
      expect(
        tester.getBottomLeft(labeledRowText(label)).dy,
        lessThanOrEqualTo(slider.top),
        reason: label,
      );
      expect(slider.width, greaterThanOrEqualTo(120), reason: label);
    }
    final sliderLefts = {
      for (final label in labels) tester.getTopLeft(labeledRowSlider(label)).dx,
    };
    expect(sliderLefts, hasLength(1));
    expect(
      tester.getCenter(labeledRowText('35%')).dy,
      moreOrLessEquals(tester.getCenter(labeledRowSlider(labels[0])).dy),
    );
  });

  testWidgets('尾随列也放不下时另起一行并贴尾对齐', (tester) async {
    const controlKey = Key('control');
    const trailingKey = Key('trailing');
    await _pump(
      tester,
      width: 320,
      child: const LabeledControlRows(
        trailingWidth: 240,
        rows: [
          LabeledControlRow(
            label: 'Size',
            control: SizedBox(key: controlKey, height: 40),
            trailing: SizedBox(key: trailingKey, height: 40),
          ),
        ],
      ),
    );

    final control = tester.getRect(find.byKey(controlKey));
    final trailing = tester.getRect(find.byKey(trailingKey));
    expect(control.width, 320 - 32);
    expect(trailing.top, greaterThanOrEqualTo(control.bottom));
    expect(trailing.width, 240);
    expect(trailing.right, control.right);
    expect(tester.takeException(), isNull);
  });

  testWidgets('列间距计入行内布局，说明行与最小标签宽参与标签列定宽', (tester) async {
    const controlKey = Key('control');
    const trailingKey = Key('trailing');
    Future<Rect> controlRect({double minLabelWidth = 0}) async {
      await _pump(
        tester,
        width: 600,
        child: LabeledControlRows(
          trailingWidth: 50,
          columnGap: 8,
          minLabelWidth: minLabelWidth,
          rows: const [
            LabeledControlRow(
              label: 'Count',
              description: 'Up to 30 times',
              control: SizedBox(key: controlKey, height: 40),
              trailing: SizedBox(key: trailingKey, height: 40),
            ),
          ],
        ),
      );
      return tester.getRect(find.byKey(controlKey));
    }

    final control = await controlRect();
    final descriptionWidth = tester
        .renderObject<RenderParagraph>(labeledRowText('Up to 30 times'))
        .getMaxIntrinsicWidth(double.infinity)
        .ceilToDouble();
    expect(control.left - 16, descriptionWidth + 8);
    expect(tester.getRect(find.byKey(trailingKey)).left - control.right, 8);

    final widened = await controlRect(minLabelWidth: 300);
    expect(widened.left - 16, 300 + 8);
  });

  testWidgets('滑块与读数框以行标签朗读，读数与界面一致', (tester) async {
    await _pump(
      tester,
      width: 600,
      child: Column(
        children: [
          _readoutRows(const ['Opacity']),
          _inputRows(const ['Strength']),
        ],
      ),
    );

    final opacity = _sliderNode('Opacity');
    expect(opacity.value, '35%');
    expect(labeledRowText('35%'), findsOneWidget);

    final strength = _sliderNode('Strength');
    expect(strength.value, EditableDoubleField.format(0.6));
    final field = find.semantics.byPredicate(
      (node) => node.flagsCollection.isTextField && node.label == 'Strength',
    );
    expect(field, findsOne);
    expect(field.evaluate().single.value, strength.value);
  });

  testWidgets('数值框按输入区间钳制，未设区间时不受滑块范围限制', (tester) async {
    final bounded = <double>[];
    final unbounded = <double>[];
    await _pump(
      tester,
      width: 600,
      child: LabeledSliderRows(
        sliders: [
          LabeledSlider.editable(
            label: 'Bounded',
            value: 0.5,
            inputKey: const Key('bounded'),
            inputMin: 0,
            inputMax: 1,
            onChanged: bounded.add,
          ),
          LabeledSlider.editable(
            label: 'Unbounded',
            value: 0.5,
            inputKey: const Key('unbounded'),
            onChanged: unbounded.add,
          ),
        ],
      ),
    );

    for (final (key, sink) in [
      ('bounded', bounded),
      ('unbounded', unbounded),
    ]) {
      await tester.enterText(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
        '1.5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(sink, isNotEmpty, reason: key);
    }
    expect(bounded.last, 1);
    expect(unbounded.last, 1.5);
  });

  testWidgets('onChanged 为空时滑块与数值框一并禁用', (tester) async {
    await _pump(
      tester,
      width: 600,
      child: LabeledSliderRows(
        sliders: [
          LabeledSlider.editable(
            label: 'Strength',
            value: 0.5,
            onChanged: null,
          ),
          const LabeledSlider(
            label: 'Opacity',
            value: 0.5,
            valueText: _percent,
            onChanged: null,
          ),
        ],
      ),
    );

    for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
      expect(slider.onChanged, isNull);
    }
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  for (final MapEntry(key: locale, value: labels) in _labelSets.entries) {
    for (final width in labeledRowWidths) {
      for (final scale in labeledRowTextScales) {
        final scenario = '$locale ${width.toInt()} ${scale}x';
        testWidgets('$scenario 下标签完整、滑块对齐且全部控件可达', (tester) async {
          await _pump(
            tester,
            width: width,
            textScale: scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _readoutRows(labels.readouts),
                const SizedBox(height: 16),
                _inputRows(labels.inputs),
              ],
            ),
          );
          expect(tester.takeException(), isNull, reason: scenario);

          await expectLabeledSliderRows(
            tester,
            labels: [...labels.readouts, ...labels.inputs],
            labelsSingleLine: locale != 'en',
            readouts: const ['35%', '100%', '0%'],
            reason: scenario,
          );
          for (final group in [labels.readouts, labels.inputs]) {
            final lefts = {
              for (final label in group)
                tester.getTopLeft(labeledRowSlider(label)).dx,
            };
            expect(lefts, hasLength(1), reason: '同组滑块左缘对齐 $scenario');
          }
          expect(tester.takeException(), isNull, reason: scenario);
        });
      }
    }
  }
}

Widget _readoutRows(List<String> labels) => LabeledSliderRows(
  sliders: [
    for (final (index, label) in labels.indexed)
      LabeledSlider(
        label: label,
        value: const [0.35, 1.0, 0.0][index % 3],
        valueText: _percent,
        onChanged: (_) {},
      ),
  ],
);

Widget _inputRows(List<String> labels) => LabeledSliderRows(
  sliders: [
    for (final label in labels)
      LabeledSlider.editable(
        label: label,
        value: 0.6,
        divisions: 20,
        onChanged: (_) {},
      ),
  ],
);

SemanticsNode _sliderNode(String label) {
  final slider = find.semantics.byPredicate(
    (node) => node.flagsCollection.isSlider && node.label == label,
  );
  expect(slider, findsOne, reason: label);
  return slider.evaluate().single;
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}
