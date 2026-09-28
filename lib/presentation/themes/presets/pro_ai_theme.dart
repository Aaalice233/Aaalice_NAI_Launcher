/// Pro AI Theme Preset
///
/// 专业 AI 工具风格 - 重写自 InvokeStyle
/// Inspired by: InvokeAI
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/pro_ai_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';

/// Pro AI theme configuration.
class ProAiTheme {
  const ProAiTheme._();

  static const _composer = ThemeComposer(
    color: ProAiPalette(),
    typography: MaterialTypography(),
    shape: StandardShapes(),
    motion: SnappyMotion(),
  );

  static ThemeData get light => _composer.buildTheme(Brightness.light);
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);
  static bool get supportsDarkMode => true;
  static String get displayName => 'Pro AI';
  static String get description => '专业 AI 工具风格，淡紫配色';
}
