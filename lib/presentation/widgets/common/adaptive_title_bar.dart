import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 操作组单行放得下就与标题同排靠右，否则整组换到下一行占满整宽；按测量而非按比例分宽，免得按钮被挤成多行。
class AdaptiveTitleBar extends MultiChildRenderObjectWidget {
  AdaptiveTitleBar({
    super.key,
    required Widget title,
    required Widget actions,
    required Widget trailing,
    this.minTitleWidth = 120,
    this.minRowHeight = 48,
    this.gap = 8,
    this.runSpacing = 4,
  }) : super(children: [title, actions, trailing]);

  final double minTitleWidth;
  final double minRowHeight;
  final double gap;
  final double runSpacing;

  @override
  RenderAdaptiveTitleBar createRenderObject(BuildContext context) =>
      RenderAdaptiveTitleBar(
        minTitleWidth: minTitleWidth,
        minRowHeight: minRowHeight,
        gap: gap,
        runSpacing: runSpacing,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAdaptiveTitleBar renderObject,
  ) {
    renderObject
      ..minTitleWidth = minTitleWidth
      ..minRowHeight = minRowHeight
      ..gap = gap
      ..runSpacing = runSpacing
      ..textDirection = Directionality.of(context);
  }
}

class _TitleBarParentData extends ContainerBoxParentData<RenderBox> {}

class RenderAdaptiveTitleBar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TitleBarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TitleBarParentData> {
  RenderAdaptiveTitleBar({
    required double minTitleWidth,
    required double minRowHeight,
    required double gap,
    required double runSpacing,
    required TextDirection textDirection,
  }) : _minTitleWidth = minTitleWidth,
       _minRowHeight = minRowHeight,
       _gap = gap,
       _runSpacing = runSpacing,
       _textDirection = textDirection;

  double _minTitleWidth;
  set minTitleWidth(double value) {
    if (value == _minTitleWidth) return;
    _minTitleWidth = value;
    markNeedsLayout();
  }

  double _minRowHeight;
  set minRowHeight(double value) {
    if (value == _minRowHeight) return;
    _minRowHeight = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _title => firstChild!;
  RenderBox get _actions => childAfter(_title)!;
  RenderBox get _trailing => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TitleBarParentData) {
      child.parentData = _TitleBarParentData();
    }
  }

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    assert(constraints.hasBoundedWidth);
    final width = constraints.maxWidth;
    Size measure(RenderBox child, BoxConstraints childConstraints) {
      if (dry) return child.getDryLayout(childConstraints);
      child.layout(childConstraints, parentUsesSize: true);
      return child.size;
    }

    final trailing = measure(_trailing, BoxConstraints(maxWidth: width));
    final rowWidth = math.max(0.0, width - trailing.width);
    final natural = measure(_actions, const BoxConstraints());
    final inline = natural.width + _gap + _minTitleWidth <= rowWidth;

    if (inline) {
      final actions = measure(
        _actions,
        BoxConstraints(maxWidth: natural.width),
      );
      final title = measure(
        _title,
        BoxConstraints(maxWidth: rowWidth - actions.width - _gap),
      );
      final height = [
        _minRowHeight,
        title.height,
        actions.height,
        trailing.height,
      ].reduce(math.max);
      if (!dry) {
        _place(_title, 0, (height - title.height) / 2, width);
        _place(
          _actions,
          rowWidth - actions.width,
          (height - actions.height) / 2,
          width,
        );
        _place(
          _trailing,
          width - trailing.width,
          (height - trailing.height) / 2,
          width,
        );
      }
      return constraints.constrain(Size(width, height));
    }

    final title = measure(_title, BoxConstraints(maxWidth: rowWidth));
    final firstRow = [
      _minRowHeight,
      title.height,
      trailing.height,
    ].reduce(math.max);
    final actions = measure(_actions, BoxConstraints(maxWidth: width));
    if (!dry) {
      _place(_title, 0, (firstRow - title.height) / 2, width);
      _place(
        _trailing,
        width - trailing.width,
        (firstRow - trailing.height) / 2,
        width,
      );
      _place(_actions, width - actions.width, firstRow + _runSpacing, width);
    }
    return constraints.constrain(
      Size(width, firstRow + _runSpacing + actions.height),
    );
  }

  void _place(RenderBox child, double x, double y, double width) {
    final mirrored = _textDirection == TextDirection.rtl
        ? width - x - child.size.width
        : x;
    (child.parentData! as _TitleBarParentData).offset = Offset(mirrored, y);
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _title.getMinIntrinsicWidth(height) +
        _trailing.getMaxIntrinsicWidth(height),
    _actions.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _title.getMaxIntrinsicWidth(height) +
      _gap +
      _actions.getMaxIntrinsicWidth(height) +
      _trailing.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
