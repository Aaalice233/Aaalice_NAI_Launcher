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
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/hard_offset_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/none_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';
import 'package:nai_launcher/presentation/themes/modules/divider/thick_divider.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Brutalist theme configuration.
class BrutalistTheme {
  const BrutalistTheme._();

  static const _composer = ThemeComposer(
    color: BrutalistPalette(),
    typography: FlatTypography(),
    shape: SharpShapes(),
    shadow: HardOffsetShadow(),
    effect: NoneEffect(),
    motion: SnappyMotion(),
    divider: ThickDividerModule.brutalist,
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static AppThemeExtension get lightExtension =>
      _composer.buildExtension(Brightness.light);
  static AppThemeExtension get darkExtension =>
      _composer.buildExtension(Brightness.dark);
  static bool get supportsDarkMode => false;
  static String get displayName => 'Brutalist';
  static String get description => '复古 LCD 显示器风格，浅色硬朗设计';
}
