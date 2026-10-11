import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/labeled_control_rows.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';

import 'text_layout_expectations.dart';

/// 标签行布局需要覆盖的窗口宽度与文字倍数
const labeledRowWidths = [320.0, 600.0, 840.0, 1180.0, 1600.0];
const labeledRowTextScales = [1.0, 3.0];

/// 标签行里的文本（标签、说明或只读读数）
Finder labeledRowText(String text) => find.descendant(
  of: find.byType(LabeledControlRows),
  matching: find.text(text),
);

/// 以 [label] 朗读的标签行滑块
Finder labeledRowSlider(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is NamedSlider && widget.label == label,
  ),
  matching: find.byType(Slider),
);

/// 逐行断言标签行在当前尺寸下完整可用
///
/// 标签完整可见，[labelsSingleLine] 时整行放得下的标签还不许换行；读数单行；数值框不滚动内容；
/// 以上内容都不越出所在标签行组；滑块轨道不短于 [minSliderWidth]，滚动到可见后能被命中。
/// 行位于惰性列表中时传入 [lazyScrollable]，先滚到该行再断言。
Future<void> expectLabeledSliderRows(
  WidgetTester tester, {
  required Iterable<String> labels,
  required bool labelsSingleLine,
  Iterable<String> readouts = const [],
  double minSliderWidth = 120,
  Finder? lazyScrollable,
  required String reason,
}) async {
  for (final label in labels) {
    final text = labeledRowText(label);
    if (lazyScrollable != null) {
      await tester.scrollUntilVisible(
        text,
        300,
        scrollable: lazyScrollable,
        maxScrolls: 100,
      );
      await tester.pump();
    }
    expect(text, findsOneWidget, reason: '$label $reason');
    if (labelsSingleLine && _fitsRowWidth(tester, text)) {
      expectSingleLineUntruncated(tester, text, reason: '$label $reason');
    }
    expectFullyVisible(tester, text, reason: '$label $reason');
    _expectInsideRows(tester, text, reason: '$label $reason');

    final slider = labeledRowSlider(label);
    expect(slider, findsOneWidget, reason: '$label $reason');
    _expectInsideRows(tester, slider, reason: '$label $reason');
    expect(
      tester.getSize(slider).width,
      greaterThanOrEqualTo(minSliderWidth),
      reason: '$label 滑块轨道 $reason',
    );
    await tester.ensureVisible(slider);
    await tester.pump();
    expect(slider.hitTestable(), findsOneWidget, reason: '$label $reason');
  }

  for (final readout in readouts) {
    final texts = labeledRowText(readout);
    expect(texts, findsWidgets, reason: '$readout $reason');
    for (var i = 0; i < texts.evaluate().length; i++) {
      expectSingleLineUntruncated(
        tester,
        texts.at(i),
        reason: '$readout $reason',
      );
      _expectInsideRows(tester, texts.at(i), reason: '$readout $reason');
    }
  }

  final fields = find.descendant(
    of: find.byType(LabeledControlRows),
    matching: find.byType(EditableText),
  );
  for (var i = 0; i < fields.evaluate().length; i++) {
    final field = fields.at(i);
    final scroll = find.descendant(
      of: field,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scroll).position.maxScrollExtent,
      0,
      reason: '数值框完整显示内容 #$i $reason',
    );
    _expectInsideRows(tester, field, reason: '数值框 #$i $reason');
    await tester.ensureVisible(field);
    await tester.pump();
    expect(field.hitTestable(), findsOneWidget, reason: '数值框 #$i $reason');
  }
}

// 标签比整行还宽时（如 320 宽 3x 下的七字日文标签）只能换行
bool _fitsRowWidth(WidgetTester tester, Finder text) {
  final rows = find
      .ancestor(of: text, matching: find.byType(LabeledControlRows))
      .first;
  final rowWidth =
      tester.getSize(rows).width -
      tester.widget<LabeledControlRows>(rows).rowPadding.horizontal;
  return tester
          .renderObject<RenderParagraph>(text)
          .getMaxIntrinsicWidth(double.infinity) <=
      rowWidth;
}

void _expectInsideRows(WidgetTester tester, Finder part, {String? reason}) {
  final rows = tester.getRect(
    find.ancestor(of: part, matching: find.byType(LabeledControlRows)).first,
  );
  final rect = tester.getRect(part);
  expect(rect.left, greaterThanOrEqualTo(rows.left - 0.5), reason: reason);
  expect(rect.right, lessThanOrEqualTo(rows.right + 0.5), reason: reason);
}
