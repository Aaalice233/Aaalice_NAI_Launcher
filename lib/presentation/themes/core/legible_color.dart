import 'package:flutter/material.dart';

/// WCAG AA contrast ratio required for normal-size text.
const double minimumTextContrast = 4.5;

/// WCAG relative-luminance contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (first > second ? first + 0.05 : second + 0.05) /
      (first > second ? second + 0.05 : first + 0.05);
}

/// Returns [foreground] as painted on [background], moved toward black or
/// white by the smallest amount that reaches [minContrast].
///
/// [background] must be the opaque color actually painted behind the text,
/// for example `Color.alphaBlend(tint, surface)`.
Color legibleForeground(
  Color foreground,
  Color background, {
  double minContrast = minimumTextContrast,
}) {
  foreground = Color.alphaBlend(foreground, background);
  if (contrastRatio(foreground, background) >= minContrast) return foreground;
  final target =
      contrastRatio(Colors.white, background) >
          contrastRatio(Colors.black, background)
      ? Colors.white
      : Colors.black;
  // Find the smallest tonal correction against the actual painted surface,
  // including customized palettes and intermediate theme-transition colors.
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 16; i++) {
    final middle = (low + high) / 2;
    if (contrastRatio(Color.lerp(foreground, target, middle)!, background) <
        minContrast) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return Color.lerp(foreground, target, high)!;
}
