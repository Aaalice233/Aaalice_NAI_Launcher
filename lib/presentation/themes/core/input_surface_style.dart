import 'package:flutter/material.dart';

/// Returns the shared fill used by editable text surfaces.
///
/// The application currently renders in dark mode, so editable controls use a
/// restrained deep surface instead of lifting toward [ColorScheme.onSurface].
/// The result stays visibly editable without becoming a pale block inside the
/// workspace.
Color inputSurfaceFillColor(ColorScheme colorScheme, {bool prominent = false}) {
  if (colorScheme.brightness == Brightness.dark) {
    return Color.alphaBlend(
      Colors.black.withValues(alpha: prominent ? 0.18 : 0.28),
      colorScheme.surfaceContainerHighest,
    );
  }

  final opacity = prominent ? 0.11 : 0.07;
  return Color.alphaBlend(
    colorScheme.onSurface.withValues(alpha: opacity),
    colorScheme.surface,
  );
}

/// Paints a focus or error glow entirely inside an editable surface.
///
/// Clipping the glow to the control bounds prevents focus from changing the
/// measured size or drawing another frame around the outside of the field.
void paintInputInnerGlow(
  Canvas canvas,
  Rect rect, {
  required BorderRadius borderRadius,
  required Color color,
  TextDirection? textDirection,
}) {
  if (rect.isEmpty || color.a == 0) return;

  final outer = borderRadius.resolve(textDirection).toRRect(rect);
  final glowRect = outer.deflate(1.15);
  final coreRect = outer.deflate(0.55);

  canvas.save();
  canvas.clipRRect(outer);
  canvas.drawRRect(
    glowRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = color.withValues(alpha: color.a * 0.42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
  );
  canvas.drawRRect(
    coreRect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85
      ..color = color.withValues(alpha: color.a * 0.78),
  );
  canvas.restore();
}

/// An [InputBorder] whose dimensions are always zero and whose state feedback
/// is painted inward.
///
/// Keeping every state on this border type lets Flutter interpolate focus and
/// error colors without adding padding or changing the field geometry.
class InputInnerGlowBorder extends InputBorder {
  InputInnerGlowBorder({
    required Color color,
    required this.borderRadius,
  }) : super(borderSide: BorderSide(color: color, width: 1));

  final BorderRadius borderRadius;

  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  InputInnerGlowBorder copyWith({BorderSide? borderSide}) {
    return InputInnerGlowBorder(
      color: (borderSide ?? this.borderSide).color,
      borderRadius: borderRadius,
    );
  }

  @override
  InputInnerGlowBorder scale(double t) {
    return InputInnerGlowBorder(
      color: borderSide.color.withValues(alpha: borderSide.color.a * t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(
        borderRadius.resolve(textDirection).toRRect(rect).deflate(2.0),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(borderRadius.resolve(textDirection).toRRect(rect));
  }

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawRRect(
      borderRadius.resolve(textDirection).toRRect(rect),
      paint,
    );
  }

  @override
  bool get preferPaintInterior => true;

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is InputInnerGlowBorder) {
      return InputInnerGlowBorder(
        color: Color.lerp(a.borderSide.color, borderSide.color, t)!,
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is InputInnerGlowBorder) {
      return InputInnerGlowBorder(
        color: Color.lerp(borderSide.color, b.borderSide.color, t)!,
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    paintInputInnerGlow(
      canvas,
      rect,
      borderRadius: borderRadius,
      color: borderSide.color,
      textDirection: textDirection,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InputInnerGlowBorder &&
            other.borderSide == borderSide &&
            other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(borderSide, borderRadius);
}

InputBorder inputSurfaceBorder(
  ColorScheme colorScheme,
  BorderRadius borderRadius, {
  bool focused = false,
  bool error = false,
  bool enabled = true,
}) {
  final color = error
      ? colorScheme.error.withValues(alpha: focused ? 0.92 : 0.68)
      : focused
      ? colorScheme.primary.withValues(alpha: 0.82)
      : Colors.transparent;

  return InputInnerGlowBorder(color: color, borderRadius: borderRadius);
}
