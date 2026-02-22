/// WobblyShapeBorder - Hand-drawn irregular border
///
/// Creates a ShapeBorder with slightly wobbly/irregular edges
/// to simulate a hand-drawn effect.
///
/// Reference: docs/UI设计提示词合集/第七套UI.txt:55-61
/// CSS: border-radius: 255px 15px 225px 15px / 15px 225px 15px 255px
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A [ShapeBorder] that creates irregular, hand-drawn looking edges.
///
/// The wobbliness can be controlled via [wobbleFactor] (0.0 = no wobble,
/// 1.0 = maximum wobble).
///
/// Use [seed] to generate consistent shapes across rebuilds.
class WobblyShapeBorder extends ShapeBorder {
  /// How much the border wobbles (0.0 - 1.0).
  final double wobbleFactor;

  /// Random seed for consistent wobble generation.
  final int seed;

  /// Border color.
  final Color borderColor;

  /// Border width.
  final double borderWidth;

  /// Base corner radius before wobble is applied.
  final double baseRadius;

  const WobblyShapeBorder({
    this.wobbleFactor = 0.3,
    this.seed = 42,
    this.borderColor = const Color(0xFF2D2D2D),
    this.borderWidth = 2.0,
    this.baseRadius = 12.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderWidth);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _createWobblyPath(rect.deflate(borderWidth));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _createWobblyPath(rect);
  }

  /// Creates a path with wobbly edges.
  Path _createWobblyPath(Rect rect) {
    final random = math.Random(seed);
    final path = Path();

    // Number of points per edge
    const pointsPerEdge = 8;

    // Calculate wobble amount based on rect size
    final wobbleAmount =
        math.min(rect.width, rect.height) * 0.02 * wobbleFactor;

    // Generate wobbled corners (asymmetric like hand-drawn)
    final topLeftRadius = baseRadius + _wobble(random, wobbleAmount * 2);
    final topRightRadius = baseRadius + _wobble(random, wobbleAmount * 2);
    final bottomRightRadius = baseRadius + _wobble(random, wobbleAmount * 2);
    final bottomLeftRadius = baseRadius + _wobble(random, wobbleAmount * 2);

    // Start at top-left corner (after radius)
    path.moveTo(
      rect.left + topLeftRadius,
      rect.top + _wobble(random, wobbleAmount),
    );

    // Top edge (left to right)
    for (int i = 1; i < pointsPerEdge; i++) {
      final t = i / pointsPerEdge;
      final x = rect.left +
          topLeftRadius +
          (rect.width - topLeftRadius - topRightRadius) * t;
      final y = rect.top + _wobble(random, wobbleAmount);
      path.lineTo(x, y);
    }

    // Top-right corner
    path.quadraticBezierTo(
      rect.right - topRightRadius / 2 + _wobble(random, wobbleAmount),
      rect.top + _wobble(random, wobbleAmount),
      rect.right + _wobble(random, wobbleAmount),
      rect.top + topRightRadius + _wobble(random, wobbleAmount),
    );

    // Right edge (top to bottom)
    for (int i = 1; i < pointsPerEdge; i++) {
      final t = i / pointsPerEdge;
      final x = rect.right + _wobble(random, wobbleAmount);
      final y = rect.top +
          topRightRadius +
          (rect.height - topRightRadius - bottomRightRadius) * t;
      path.lineTo(x, y);
    }

    // Bottom-right corner
    path.quadraticBezierTo(
      rect.right + _wobble(random, wobbleAmount),
      rect.bottom - bottomRightRadius / 2 + _wobble(random, wobbleAmount),
      rect.right - bottomRightRadius + _wobble(random, wobbleAmount),
      rect.bottom + _wobble(random, wobbleAmount),
    );

    // Bottom edge (right to left)
    for (int i = 1; i < pointsPerEdge; i++) {
      final t = i / pointsPerEdge;
      final x = rect.right -
          bottomRightRadius -
          (rect.width - bottomRightRadius - bottomLeftRadius) * t;
      final y = rect.bottom + _wobble(random, wobbleAmount);
      path.lineTo(x, y);
    }

    // Bottom-left corner
    path.quadraticBezierTo(
      rect.left + bottomLeftRadius / 2 + _wobble(random, wobbleAmount),
      rect.bottom + _wobble(random, wobbleAmount),
      rect.left + _wobble(random, wobbleAmount),
      rect.bottom - bottomLeftRadius + _wobble(random, wobbleAmount),
    );

    // Left edge (bottom to top)
    for (int i = 1; i < pointsPerEdge; i++) {
      final t = i / pointsPerEdge;
      final x = rect.left + _wobble(random, wobbleAmount);
      final y = rect.bottom -
          bottomLeftRadius -
          (rect.height - bottomLeftRadius - topLeftRadius) * t;
      path.lineTo(x, y);
    }

    // Top-left corner (back to start)
    path.quadraticBezierTo(
      rect.left + _wobble(random, wobbleAmount),
      rect.top + topLeftRadius / 2 + _wobble(random, wobbleAmount),
      rect.left + topLeftRadius + _wobble(random, wobbleAmount),
      rect.top + _wobble(random, wobbleAmount),
    );

    path.close();
    return path;
  }

  /// Generate a random wobble value.
  double _wobble(math.Random random, double maxWobble) {
    return (random.nextDouble() - 0.5) * 2 * maxWobble;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (borderWidth <= 0) return;

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) {
    return WobblyShapeBorder(
      wobbleFactor: wobbleFactor * t,
      seed: seed,
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      baseRadius: baseRadius * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is WobblyShapeBorder) {
      return WobblyShapeBorder(
        wobbleFactor: a.wobbleFactor + (wobbleFactor - a.wobbleFactor) * t,
        seed: seed,
        borderColor: Color.lerp(a.borderColor, borderColor, t)!,
        borderWidth: a.borderWidth + (borderWidth - a.borderWidth) * t,
        baseRadius: a.baseRadius + (baseRadius - a.baseRadius) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is WobblyShapeBorder) {
      return WobblyShapeBorder(
        wobbleFactor: wobbleFactor + (b.wobbleFactor - wobbleFactor) * t,
        seed: seed,
        borderColor: Color.lerp(borderColor, b.borderColor, t)!,
        borderWidth: borderWidth + (b.borderWidth - borderWidth) * t,
        baseRadius: baseRadius + (b.baseRadius - baseRadius) * t,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WobblyShapeBorder &&
        other.wobbleFactor == wobbleFactor &&
        other.seed == seed &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.baseRadius == baseRadius;
  }

  @override
  int get hashCode => Object.hash(
        wobbleFactor,
        seed,
        borderColor,
        borderWidth,
        baseRadius,
      );
}
