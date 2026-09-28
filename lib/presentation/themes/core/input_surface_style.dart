import 'package:flutter/material.dart';

/// Returns the shared fill used by editable text surfaces.
///
/// Derive input depth from the canvas, not the raised container ladder. A dark
/// overlay on a raised container can still leave fields brighter than the page.
/// Black changes luminance without introducing the theme's foreground hue.
Color inputSurfaceFillColor(ColorScheme colorScheme, {bool prominent = false}) {
  if (colorScheme.brightness == Brightness.dark) {
    return Color.alphaBlend(
      Colors.black.withValues(alpha: prominent ? 0.18 : 0.28),
      colorScheme.surface,
    );
  }

  final opacity = prominent ? 0.025 : 0.04;
  return Color.alphaBlend(
    Colors.black.withValues(alpha: opacity),
    colorScheme.surface,
  );
}

/// Builds the shared outline for Material text inputs.
///
/// Focus is communicated by a crisp theme-colored outline. No blur, shadow, or
/// inward glow is used, so the field remains easy to locate without brightening
/// the editable content area.
InputBorder inputSurfaceBorder(
  ColorScheme colorScheme,
  BorderRadius borderRadius, {
  bool focused = false,
  bool error = false,
  bool enabled = true,
}) {
  final color = !enabled
      ? colorScheme.outlineVariant.withValues(alpha: 0.18)
      : error
      ? colorScheme.error.withValues(alpha: focused ? 0.9 : 0.62)
      : focused
      ? colorScheme.primary.withValues(alpha: 0.68)
      : colorScheme.outlineVariant.withValues(alpha: 0.32);
  // Keep geometry constant across states; only color intensity changes.
  const width = 1.0;

  return OutlineInputBorder(
    borderRadius: borderRadius,
    borderSide: BorderSide(color: color, width: width),
  );
}
