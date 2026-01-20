/// Apple Light Theme Preset
///
/// 极简浅色主题 - 重写自 PureLightStyle
/// Inspired by: Apple / Notion
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/apple_light_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/pill_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/soft_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/none_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Apple Light theme configuration.
class AppleLightTheme {
  const AppleLightTheme._();

  static const _composer = ThemeComposer(
    color: AppleLightPalette(),
    typography: MaterialTypography(),
    shape: PillShapes(),
    shadow: SoftShadow(),
    effect: NoneEffect(),
    motion: ZenMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static AppThemeExtension get lightExtension =>
      _composer.buildExtension(Brightness.light);
  static AppThemeExtension get darkExtension =>
      _composer.buildExtension(Brightness.dark);
  static bool get supportsDarkMode => false;
  static String get displayName => 'Apple Light';
  static String get description => '极简浅色主题，iOS 蓝配色';
}
