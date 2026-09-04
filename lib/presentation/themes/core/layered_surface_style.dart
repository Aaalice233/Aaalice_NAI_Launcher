import 'package:flutter/material.dart';

/// Returns a section surface that remains distinct even when an older palette
/// maps Material 3 container roles back to the canvas color.
Color sectionSurfaceColor(ColorScheme colorScheme) {
  final base = colorScheme.surfaceContainerLow;
  if (base != colorScheme.surface) return base;
  return Color.alphaBlend(
    colorScheme.onSurface.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.045 : 0.025,
    ),
    base,
  );
}

/// Returns the stronger tonal surface used for controls nested in a section.
Color controlSurfaceColor(ColorScheme colorScheme) {
  final base = colorScheme.surfaceContainer;
  if (base != colorScheme.surface && base != colorScheme.surfaceContainerLow) {
    return base;
  }
  return Color.alphaBlend(
    colorScheme.onSurface.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.075 : 0.045,
    ),
    colorScheme.surface,
  );
}

/// Returns the overlay surface used by hover previews and other transient
/// quick-look cards. It remains distinct when a theme collapses Material
/// container roles back to the page canvas.
Color overlaySurfaceColor(ColorScheme colorScheme) {
  final base = colorScheme.surfaceContainerHigh;
  if (base != colorScheme.surface) return base;
  return Color.alphaBlend(
    colorScheme.onSurface.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.11 : 0.07,
    ),
    colorScheme.surface,
  );
}
