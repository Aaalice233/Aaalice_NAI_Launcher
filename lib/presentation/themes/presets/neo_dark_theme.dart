/// Neo Dark Theme Preset
///
/// Linear 风格现代极简深色主题 - 重写自 LinearStyle
/// Inspired by: Linear.app
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/neo_dark_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/sharp_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';

/// Neo Dark theme configuration.
class NeoDarkTheme {
  const NeoDarkTheme._();

  static const _composer = ThemeComposer(
    color: NeoDarkPalette(),
    typography: MaterialTypography(),
    shape: SharpShapes(),
    motion: SnappyMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static bool get supportsDarkMode => true;
  static String get displayName => 'Neo Dark';
  static String get description => 'Linear 风格极简深色主题，干净利落';
}
