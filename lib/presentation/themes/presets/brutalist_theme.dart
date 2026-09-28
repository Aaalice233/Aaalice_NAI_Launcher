/// Brutalist Theme Preset
///
/// 复古 LCD / Beeper 风格 - 重写自 MotorolaBeeperStyle
/// Inspired by: Motorola pagers, retro LCD displays
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/brutalist_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/flat_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/sharp_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';

/// Brutalist theme configuration.
class BrutalistTheme {
  const BrutalistTheme._();

  static const _composer = ThemeComposer(
    color: BrutalistPalette(),
    typography: FlatTypography(),
    shape: SharpShapes(),
    motion: SnappyMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static bool get supportsDarkMode => false;
  static String get displayName => 'Brutalist';
  static String get description => '复古 LCD 显示器风格，浅色硬朗设计';
}
