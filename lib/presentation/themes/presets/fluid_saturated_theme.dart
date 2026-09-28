/// Fluid Saturated Theme Preset
///
/// 流体饱和风格主题 - 极大圆角、饱和色彩、毛玻璃效果
/// Reference: docs/UI设计提示词合集/第三套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/fluid_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/fluid_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/fluid_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';

/// Fluid Saturated theme configuration.
///
/// Combines:
/// - FluidPalette (#FDE047, #0A0A0A)
/// - FluidTypography (Inter)
/// - FluidShapes (100px+ rounded corners)
/// - ZenMotion (smooth, fluid animations)
///
/// This theme supports both light and dark modes.
class FluidSaturatedTheme {
  const FluidSaturatedTheme._();

  static const _composer = ThemeComposer(
    color: FluidPalette(),
    typography: FluidTypography(),
    shape: FluidShapes(),
    motion: ZenMotion(),
  );

  /// The light theme.
  static ThemeData get light => _composer.buildTheme(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);

  /// Whether this theme supports dark mode.
  static bool get supportsDarkMode => true;

  /// Theme display name.
  static String get displayName => 'Fluid Saturated';

  /// Theme description.
  static String get description => '流体饱和风格 - 大圆角、饱和色彩与渐进色面的未来感设计';
}
