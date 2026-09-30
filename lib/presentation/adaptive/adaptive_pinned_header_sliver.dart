import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Pins [child] to the leading edge of the viewport only while every header up
/// to and including it still leaves [minContentExtent] for the content below;
/// otherwise it scrolls away with the content.
///
/// The choice is made from measured extents during layout, so switching modes
/// on rotation, text scaling or the soft keyboard keeps the same elements and
/// scroll offset. Place these headers before the scrolling content.
class AdaptivePinnedHeaderSliver extends StatelessWidget {
  const AdaptivePinnedHeaderSliver({
    super.key,
    required this.child,
    this.minContentExtent = defaultMinContentExtent,
  });

  static const double defaultMinContentExtent = 240;

  final Widget child;
  final double minContentExtent;

  @override
  Widget build(BuildContext context) => _AdaptivePinnedHeader(
    minContentExtent: minContentExtent,
    child: Semantics(container: true, explicitChildNodes: true, child: child),
  );
}

class _AdaptivePinnedHeader extends SingleChildRenderObjectWidget {
  const _AdaptivePinnedHeader({
    required this.minContentExtent,
    required super.child,
  });

  final double minContentExtent;

  @override
  RenderAdaptivePinnedHeaderSliver createRenderObject(BuildContext context) =>
      RenderAdaptivePinnedHeaderSliver(minContentExtent: minContentExtent);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderAdaptivePinnedHeaderSliver renderObject,
  ) {
    renderObject.minContentExtent = minContentExtent;
  }
}

class RenderAdaptivePinnedHeaderSliver extends RenderSliverSingleBoxAdapter {
  RenderAdaptivePinnedHeaderSliver({required double minContentExtent})
    : _minContentExtent = minContentExtent;

  double get minContentExtent => _minContentExtent;
  double _minContentExtent;
  set minContentExtent(double value) {
    if (value == _minContentExtent) return;
    _minContentExtent = value;
    markNeedsLayout();
  }

  bool get isPinned => _isPinned;
  bool _isPinned = false;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      _isPinned = false;
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final childExtent = switch (constraints.axis) {
      Axis.vertical => child.size.height,
      Axis.horizontal => child.size.width,
    };
    // Not overlap: it stays 0 until scrolling starts and would flip the choice.
    _isPinned =
        constraints.precedingScrollExtent + childExtent + minContentExtent <=
        constraints.viewportMainAxisExtent;
    geometry = _isPinned
        ? _pinnedGeometry(childExtent)
        : _scrollingGeometry(childExtent);
    final childParentData = child.parentData! as SliverPhysicalParentData;
    if (_isPinned) {
      childParentData.paintOffset = Offset.zero;
    } else {
      setChildParentData(child, constraints, geometry!);
    }
  }

  SliverGeometry _pinnedGeometry(double childExtent) {
    return SliverGeometry(
      scrollExtent: childExtent,
      paintOrigin: constraints.overlap,
      paintExtent: math.min(
        childExtent,
        constraints.remainingPaintExtent - constraints.overlap,
      ),
      layoutExtent: clampDouble(
        childExtent - constraints.scrollOffset,
        0,
        constraints.remainingPaintExtent,
      ),
      maxPaintExtent: childExtent,
      maxScrollObstructionExtent: childExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: childExtent),
      hasVisualOverflow: true,
    );
  }

  SliverGeometry _scrollingGeometry(double childExtent) {
    final paintExtent = calculatePaintOffset(
      constraints,
      from: 0,
      to: childExtent,
    );
    return SliverGeometry(
      scrollExtent: childExtent,
      paintExtent: paintExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: childExtent),
      maxPaintExtent: childExtent,
      hitTestExtent: paintExtent,
      hasVisualOverflow:
          childExtent > constraints.remainingPaintExtent ||
          constraints.scrollOffset > 0,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) =>
      _isPinned ? 0 : super.childMainAxisPosition(child);

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final child = this.child;
    if (!_isPinned || child == null || descendant == null) {
      super.showOnScreen(
        descendant: descendant,
        rect: rect,
        duration: duration,
        curve: curve,
      );
      return;
    }
    // A focused field's scroll padding can reach past the header edge, which
    // the viewport reads as unpinned and answers by scrolling the list away.
    final local = MatrixUtils.transformRect(
      descendant.getTransformTo(child),
      rect ?? descendant.paintBounds,
    );
    super.showOnScreen(
      descendant: child,
      rect: Rect.fromLTRB(
        clampDouble(local.left, 0, child.size.width),
        clampDouble(local.top, 0, child.size.height),
        clampDouble(local.right, 0, child.size.width),
        clampDouble(local.bottom, 0, child.size.height),
      ),
      duration: duration,
      curve: curve,
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final child = this.child;
    if (!_isPinned || child == null || geometry == null) return;
    final childExtent = switch (constraints.axis) {
      Axis.vertical => child.size.height,
      Axis.horizontal => child.size.width,
    };
    if (geometry!.layoutExtent < childExtent) {
      config.addTagForChildren(RenderViewport.excludeFromScrolling);
    }
  }
}
