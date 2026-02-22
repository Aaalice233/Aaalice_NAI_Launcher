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
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/soft_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/glassmorphism_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';
import 'package:nai_launcher/presentation/themes/modules/divider/none_divider.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Fluid Saturated theme configuration.
///
/// Combines:
/// - FluidPalette (#FDE047, #0A0A0A)
/// - FluidTypography (Inter)
/// - FluidShapes (100px+ rounded corners)
/// - SoftShadow (subtle elevation)
/// - GlassmorphismEffect (frosted glass effect)
/// - ZenMotion (smooth, fluid animations)
///
/// This theme supports both light and dark modes.
class FluidSaturatedTheme {
  const FluidSaturatedTheme._();

  static const _composer = ThemeComposer(
    color: FluidPalette(),
    typography: FluidTypography(),
    shape: FluidShapes(),
    shadow: SoftShadow(),
    effect: GlassmorphismEffect(),
    motion: ZenMotion(),
    divider: NoneDividerModule(),
  );

  /// The light theme.
  static ThemeData get light => _composer.buildTheme(Brightness.light);

  /// The dark theme.
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);

  /// The theme extension for light mode.
  static AppThemeExtension get lightExtension =>
      _composer.buildExtension(Brightness.light);

  /// The theme extension for dark mode.
  static AppThemeExtension get darkExtension =>
      _composer.buildExtension(Brightness.dark);

  /// Whether this theme supports dark mode.
  static bool get supportsDarkMode => true;

  /// Theme display name.
  static String get displayName => 'Fluid Saturated';

  /// Theme description.
  static String get description => '流体饱和风格 - 极大圆角、饱和色彩与毛玻璃效果的未来感设计';
}
