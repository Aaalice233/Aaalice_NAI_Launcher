/// Flat Design Theme Preset
///
/// 扁平设计风格主题 - 锐利转角与简约色块
/// Reference: docs/UI设计提示词合集/第六套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/flat_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/flat_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/sharp_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';

/// Flat Design theme configuration.
///
/// Combines:
/// - FlatPalette (#3B82F6, #FFFFFF)
/// - FlatTypography (Outfit)
/// - SharpShapes (6-8px radius)
/// - SnappyMotion (fast, responsive)
///
/// This theme supports both light and dark modes.
class FlatDesignTheme {
  const FlatDesignTheme._();

  static const _composer = ThemeComposer(
    color: FlatPalette(),
    typography: FlatTypography(),
    shape: SharpShapes(),
    motion: SnappyMotion(),
  );

  /// The light theme.
  static ThemeData get light => _composer.buildTheme(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);

  /// Whether this theme supports dark mode.
  static bool get supportsDarkMode => true;

  /// Theme display name.
  static String get displayName => 'Flat Design';

  /// Theme description.
  static String get description => '扁平设计风格 - 锐利转角与纯色块的简约美学';
}
