/// System Theme Preset
///
/// 跟随系统主题 - 重写自 SystemStyle
/// Adapts to system light/dark mode
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/system_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';

/// System theme configuration.
class SystemTheme {
  const SystemTheme._();

  static const _composer = ThemeComposer(
    color: SystemPalette(),
    typography: MaterialTypography(),
    shape: StandardShapes(),
    motion: ZenMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static bool get supportsDarkMode => true;
  static String get displayName => 'System';
  static String get description => '跟随系统亮度自动切换深浅模式';
}
