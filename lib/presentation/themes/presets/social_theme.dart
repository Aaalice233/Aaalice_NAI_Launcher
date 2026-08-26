/// Social Theme Preset
///
/// 熟悉的社交应用风格 - 重写自 DiscordStyle
/// Inspired by: Discord
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/social_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';

/// Social theme configuration.
class SocialTheme {
  const SocialTheme._();

  static const _composer = ThemeComposer(
    color: SocialPalette(),
    typography: MaterialTypography(),
    shape: StandardShapes(),
    motion: SnappyMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static bool get supportsDarkMode => true;
  static String get displayName => 'Social';
  static String get description => '社交应用风格，Blurple 配色';
}
