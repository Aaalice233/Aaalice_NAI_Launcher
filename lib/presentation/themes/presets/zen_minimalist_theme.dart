/// Zen Minimalist Theme Preset
///
/// 禅意极简风格主题 - 完美复刻自设计稿
/// Reference: docs/UI设计提示词合集/默认主题.txt
///
/// Design Tokens:
/// - Background: #050505 (极深黑)
/// - Surface: #0e0e0f
/// - Surface Elevated: #151517
/// - Text Main: #fcfcfc (接近纯白)
/// - Primary: #60a5fa (柔和蓝)
/// - Border: rgba(255,255,255,0.06)
/// - Animation: 1.2s cubic-bezier(0.2, 0.8, 0.2, 1)
/// - Card Radius: 32px
/// - Button Shape: StadiumBorder (pill)
/// - Shadow: 0 4px 24px -1px rgba(0,0,0,0.2)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/zen_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/zen_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/soft_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/none_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';
import 'package:nai_launcher/presentation/themes/modules/divider/soft_divider_module.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Zen Minimalist theme configuration.
///
/// Combines:
/// - ZenPalette (#050505 bg, #0e0e0f surface, #fcfcfc text, #60a5fa primary)
/// - ZenTypography (Plus Jakarta Sans)
/// - StandardShapes (32px radius, StadiumBorder buttons)
/// - SoftShadow (24px blur, premium feel)
/// - NoneEffect (clean, distraction-free)
/// - ZenMotion (1.2s slow, meditative animations)
///
/// This theme supports both light and dark modes.
class ZenMinimalistTheme {
  const ZenMinimalistTheme._();

  static const _composer = ThemeComposer(
    color: ZenPalette(),
    typography: ZenTypography(),
    shape: StandardShapes(),
    shadow: SoftShadow(),
    effect: NoneEffect(),
    motion: ZenMotion(),
    divider: SoftDividerModule.zenWhite,
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
  static String get displayName => 'Zen Minimalist';

  /// Theme description.
  static String get description => '禅意极简风格 - 柔和蓝色调、大量留白、平静冥想的设计哲学';
}
