import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const _actionInset = 4.0;

/// Keeps editor actions inside the visible portion of a tall, scrolling field.
class PromptViewportActions extends StatelessWidget {
  const PromptViewportActions({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Subscribe to position replacements as well as pixel changes. The field
    // can sit inside both horizontal and vertical scrollable ancestors.
    Scrollable.maybeOf(context, axis: Axis.vertical);
    Scrollable.maybeOf(context, axis: Axis.horizontal);
    final positions = <ScrollPosition>[];
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        positions.add((element.state as ScrollableState).position);
      }
      return true;
    });
    final media = MediaQuery.of(Scaffold.maybeOf(context)?.context ?? context);
    return Flow(
      delegate: _ViewportActionsLayout(
        context,
        positions,
        Rect.fromLTRB(
          media.padding.left,
          media.padding.top,
          media.size.width - media.padding.right,
          media.size.height -
              math.max(media.padding.bottom, media.viewInsets.bottom),
        ),
        Directionality.of(context),
      ),
      children: [child],
    );
  }
}

class _ViewportActionsLayout extends FlowDelegate {
  _ViewportActionsLayout(
    this.context,
    this.positions,
    this.screenBounds,
    this.direction,
  ) : super(repaint: Listenable.merge(positions));

  final BuildContext context;
  final List<ScrollPosition> positions;
  final Rect screenBounds;
  final TextDirection direction;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      constraints.deflate(const EdgeInsets.all(_actionInset)).loosen();

  @override
  void paintChildren(FlowPaintingContext painting) {
    final box = context.findRenderObject()! as RenderBox;
    final fromScreen = Matrix4.inverted(box.getTransformTo(null));
    var visible = (Offset.zero & painting.size).intersect(
      MatrixUtils.transformRect(fromScreen, screenBounds),
    );
    // Ancestor viewport clipping can be tighter than the application window.
    // Resolve it during paint so scrolling never rebuilds the prompt editor.
    RenderObject? ancestor = box.parent;
    while (ancestor != null) {
      if (ancestor is RenderAbstractViewport && ancestor is RenderBox) {
        visible = visible.intersect(
          MatrixUtils.transformRect(
            Matrix4.inverted(box.getTransformTo(ancestor)),
            Offset.zero & (ancestor as RenderBox).size,
          ),
        );
      }
      ancestor = ancestor.parent;
    }
    final childSize = painting.getChildSize(0)!;
    if (visible.isEmpty) return;
    final x = direction == TextDirection.rtl
        ? visible.left + _actionInset
        : visible.right - childSize.width - _actionInset;
    final y = visible.bottom - childSize.height - _actionInset;
    painting.paintChild(
      0,
      transform: Matrix4.translationValues(
        math.max(visible.left, x),
        math.max(visible.top, y),
        0,
      ),
    );
  }

  @override
  bool shouldRepaint(_ViewportActionsLayout oldDelegate) =>
      context != oldDelegate.context ||
      screenBounds != oldDelegate.screenBounds ||
      direction != oldDelegate.direction ||
      !listEquals(positions, oldDelegate.positions);
}
