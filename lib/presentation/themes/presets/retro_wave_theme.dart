/// Retro Wave Theme Preset
///
/// 复古未来霓虹风格 - 重写自 CassetteFuturismStyle
/// Inspired by: Cassette Futurism / Retro-futurism
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/retro_wave_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';

/// Retro Wave theme configuration.
class RetroWaveTheme {
  const RetroWaveTheme._();

  static const _composer = ThemeComposer(
    color: RetroWavePalette(),
    typography: MaterialTypography(),
    shape: StandardShapes(),
    motion: SnappyMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static bool get supportsDarkMode => true;
  static String get displayName => 'Retro Wave';
  static String get description => '复古未来主义风格，温暖的橙青黄配色';
}
