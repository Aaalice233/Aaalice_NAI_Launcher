import 'package:flutter/material.dart';

import 'core/layered_surface_style.dart';

/// Inactive controls remain transparent; only an active function introduces
/// a restrained tint so the toolbar does not become a row of colored blocks.
class PromptControlColors {
  PromptControlColors(
    ThemeData theme,
    Color color, {
    bool active = false,
    bool hovered = false,
  }) {
    background = (active ? color : theme.colorScheme.onSurface).withValues(
      alpha: (active ? 0.08 : 0.0) + (hovered ? 0.04 : 0),
    );
    final paintedSurface = Color.alphaBlend(
      background,
      sectionSurfaceColor(theme.colorScheme),
    );
    accent = _legible(
      active ? color : theme.colorScheme.onSurfaceVariant,
      paintedSurface,
    );
    foreground = _legible(
      active ? accent : theme.colorScheme.onSurface,
      paintedSurface,
    );
  }

  late final Color background;
  late final Color foreground;
  late final Color accent;

  static double _contrast(Color a, Color b) {
    final first = a.computeLuminance();
    final second = b.computeLuminance();
    return (first > second ? first + 0.05 : second + 0.05) /
        (first > second ? second + 0.05 : first + 0.05);
  }

  static Color _legible(Color foreground, Color background) {
    foreground = Color.alphaBlend(foreground, background);
    if (_contrast(foreground, background) >= 4.5) return foreground;
    final target =
        _contrast(Colors.white, background) >
            _contrast(Colors.black, background)
        ? Colors.white
        : Colors.black;
    // Find the smallest tonal correction against the actual painted surface,
    // including customized palettes and intermediate theme-transition colors.
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 16; i++) {
      final middle = (low + high) / 2;
      if (_contrast(Color.lerp(foreground, target, middle)!, background) <
          4.5) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return Color.lerp(foreground, target, high)!;
  }
}
