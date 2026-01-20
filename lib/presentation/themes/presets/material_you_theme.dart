/// Material You Theme Preset
///
/// Material Design 3 风格主题 - Google 最新设计语言
/// Reference: docs/UI设计提示词合集/第五套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/material_you_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/material_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/pill_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/soft_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/none_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/material_motion.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Material You (MD3) theme configuration.
///
/// Combines:
/// - MaterialYouPalette (#6750A4, #FFFBFE)
/// - MaterialTypography (Roboto)
/// - PillShapes (fully rounded buttons)
/// - SoftShadow (elevation shadows)
/// - NoneEffect (clean, no special effects)
/// - MaterialMotion (MD3 motion curves)
///
/// This theme supports both light and dark modes.
class MaterialYouTheme {
  const MaterialYouTheme._();

  static const _composer = ThemeComposer(
    color: MaterialYouPalette(),
    typography: MaterialTypography(),
    shape: PillShapes(),
    shadow: SoftShadow(),
    effect: NoneEffect(),
    motion: MaterialMotion(),
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
  static String get displayName => 'Material You';

  /// Theme description.
  static String get description =>
      'Material Design 3 - Google 最新设计语言，圆润的形状与和谐的色彩';
}
