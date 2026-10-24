import 'package:flutter/material.dart';

import 'core/layered_surface_style.dart';
import 'core/legible_color.dart';

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
    accent = legibleForeground(
      active ? color : theme.colorScheme.onSurfaceVariant,
      paintedSurface,
    );
    foreground = legibleForeground(
      active ? accent : theme.colorScheme.onSurface,
      paintedSurface,
    );
  }

  late final Color background;
  late final Color foreground;
  late final Color accent;
}
