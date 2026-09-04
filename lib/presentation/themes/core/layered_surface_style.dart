import 'package:flutter/material.dart';

ColorScheme _materialDefaultScheme(Brightness brightness) {
  return brightness == Brightness.dark
      ? const ColorScheme.dark()
      : const ColorScheme.light();
}

bool _needsSurfaceFallback(
  ColorScheme colorScheme,
  Color actual,
  Color materialDefault,
) {
  return actual == colorScheme.surface || actual == materialDefault;
}

Color _fallbackSurfaceLayer(
  ColorScheme colorScheme,
  double amount, {
  bool lower = false,
}) {
  final target = lower
      ? colorScheme.brightness == Brightness.dark
            ? Colors.black
            : Colors.white
      : colorScheme.brightness == Brightness.dark
      ? Colors.white
      : Colors.black;
  return Color.lerp(colorScheme.surface, target, amount)!;
}

/// Returns a section surface that remains distinct even when an older palette
/// maps Material 3 container roles back to the canvas color.
Color sectionSurfaceColor(ColorScheme colorScheme) {
  final base = colorScheme.surfaceContainerLow;
  final defaults = _materialDefaultScheme(colorScheme.brightness);
  if (!_needsSurfaceFallback(colorScheme, base, defaults.surfaceContainerLow)) {
    return base;
  }
  return _fallbackSurfaceLayer(
    colorScheme,
    colorScheme.brightness == Brightness.dark ? 0.055 : 0.025,
  );
}

/// Returns the stronger tonal surface used for controls nested in a section.
Color controlSurfaceColor(ColorScheme colorScheme) {
  final base = colorScheme.surfaceContainer;
  final defaults = _materialDefaultScheme(colorScheme.brightness);
  if (!_needsSurfaceFallback(colorScheme, base, defaults.surfaceContainer) &&
      base != colorScheme.surfaceContainerLow) {
    return base;
  }
  return _fallbackSurfaceLayer(
    colorScheme,
    colorScheme.brightness == Brightness.dark ? 0.085 : 0.045,
  );
}

/// Returns the overlay surface used by hover previews and other transient
/// quick-look cards. It remains distinct when a theme collapses Material
/// container roles back to the page canvas.
Color overlaySurfaceColor(ColorScheme colorScheme) {
  final base = colorScheme.surfaceContainerHigh;
  final defaults = _materialDefaultScheme(colorScheme.brightness);
  if (!_needsSurfaceFallback(
    colorScheme,
    base,
    defaults.surfaceContainerHigh,
  )) {
    return base;
  }
  return _fallbackSurfaceLayer(
    colorScheme,
    colorScheme.brightness == Brightness.dark ? 0.12 : 0.07,
  );
}

/// Completes palettes that predate Material 3's container surface roles.
/// Explicitly authored roles remain untouched; roles left at Material defaults
/// or collapsed onto the page surface receive a neutral luminance step.
ColorScheme resolveLayeredSurfaceColors(ColorScheme colorScheme) {
  final defaults = _materialDefaultScheme(colorScheme.brightness);
  return colorScheme.copyWith(
    surfaceContainerLowest:
        _needsSurfaceFallback(
          colorScheme,
          colorScheme.surfaceContainerLowest,
          defaults.surfaceContainerLowest,
        )
        ? _fallbackSurfaceLayer(colorScheme, 0.08, lower: true)
        : colorScheme.surfaceContainerLowest,
    surfaceContainerLow: sectionSurfaceColor(colorScheme),
    surfaceContainer: controlSurfaceColor(colorScheme),
    surfaceContainerHigh: overlaySurfaceColor(colorScheme),
    surfaceContainerHighest:
        _needsSurfaceFallback(
          colorScheme,
          colorScheme.surfaceContainerHighest,
          defaults.surfaceContainerHighest,
        )
        ? _fallbackSurfaceLayer(
            colorScheme,
            colorScheme.brightness == Brightness.dark ? 0.15 : 0.09,
          )
        : colorScheme.surfaceContainerHighest,
  );
}
