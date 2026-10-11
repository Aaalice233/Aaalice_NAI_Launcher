import 'dart:math' as math;
import 'dart:ui';

enum FloatingPanelEdge {
  left,
  top,
  right,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  bool get movesLeft => this == left || this == topLeft || this == bottomLeft;
  bool get movesRight =>
      this == right || this == topRight || this == bottomRight;
  bool get movesTop => this == top || this == topLeft || this == topRight;
  bool get movesBottom =>
      this == bottom || this == bottomLeft || this == bottomRight;
}

/// Keeps an in-app floating panel inside its workspace and above its minimum
/// size. Stored rectangles are preferences; every caller renders the clamped
/// result so a smaller window never overwrites the saved geometry.
abstract final class FloatingPanelGeometry {
  static const Size minimumSize = Size(320, 360);
  static const Size defaultSize = Size(420, 600);
  static const double defaultMargin = 16;

  static Rect defaultRect(Size bounds) {
    final size = _clampSize(defaultSize, bounds);
    final left = bounds.width - size.width - defaultMargin;
    final top = bounds.height - size.height - defaultMargin;
    return clamp(Rect.fromLTWH(left, top, size.width, size.height), bounds);
  }

  static Rect clamp(Rect preferred, Size bounds) {
    final size = _clampSize(preferred.size, bounds);
    final left = preferred.left
        .clamp(0.0, math.max(0.0, bounds.width - size.width))
        .toDouble();
    final top = preferred.top
        .clamp(0.0, math.max(0.0, bounds.height - size.height))
        .toDouble();
    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  static Rect move(Rect rect, Offset delta, Size bounds) =>
      clamp(clamp(rect, bounds).shift(delta), bounds);

  static Rect resize(
    Rect rect,
    FloatingPanelEdge edge,
    Offset delta,
    Size bounds,
  ) {
    final current = clamp(rect, bounds);
    final minimum = _minimumFor(bounds);
    var left = current.left;
    var top = current.top;
    var right = current.right;
    var bottom = current.bottom;
    if (edge.movesLeft) {
      left = (left + delta.dx).clamp(0.0, right - minimum.width);
    }
    if (edge.movesRight) {
      right = (right + delta.dx).clamp(left + minimum.width, bounds.width);
    }
    if (edge.movesTop) {
      top = (top + delta.dy).clamp(0.0, bottom - minimum.height);
    }
    if (edge.movesBottom) {
      bottom = (bottom + delta.dy).clamp(top + minimum.height, bounds.height);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static bool isUsable(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.width.isFinite &&
      rect.height.isFinite &&
      rect.width > 0 &&
      rect.height > 0;

  static Size _minimumFor(Size bounds) => Size(
    math.min(minimumSize.width, math.max(0.0, bounds.width)),
    math.min(minimumSize.height, math.max(0.0, bounds.height)),
  );

  static Size _clampSize(Size size, Size bounds) {
    final minimum = _minimumFor(bounds);
    return Size(
      size.width.clamp(minimum.width, math.max(minimum.width, bounds.width)),
      size.height.clamp(
        minimum.height,
        math.max(minimum.height, bounds.height),
      ),
    );
  }
}
