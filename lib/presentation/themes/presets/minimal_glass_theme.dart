/// Minimal Layered Theme Preset
///
/// 金黄与深青的现代优雅风格 - 重写自 HerdingStyle
/// Inspired by: herdi.ng
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/minimal_glass_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';

/// Minimal layered theme configuration.
///
/// Combines:
/// - MinimalGlassPalette (#D4A843, #1095C1)
/// - MaterialTypography (Roboto)
/// - StandardShapes (12-16px radius)
/// - ZenMotion (smooth transitions)
class MinimalGlassTheme {
  const MinimalGlassTheme._();

  static const _composer = ThemeComposer(
    color: MinimalGlassPalette(),
    typography: MaterialTypography(),
    shape: StandardShapes(),
    motion: ZenMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static bool get supportsDarkMode => true;
  static String get displayName => 'Minimal Layered';
  static String get description => '金黄与深青的现代层叠风格';
}
