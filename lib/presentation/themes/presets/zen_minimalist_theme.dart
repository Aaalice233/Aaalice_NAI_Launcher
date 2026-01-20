/// Zen Minimalist Theme Preset
///
/// 禅意极简风格主题 - 柔和色彩、大量留白、平静氛围
/// Reference: docs/UI设计提示词合集/第九套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/zen_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/zen_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/soft_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/none_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Zen Minimalist theme configuration.
///
/// Combines:
/// - ZenPalette (#050505, #60A5FA)
/// - ZenTypography (Plus Jakarta Sans)
/// - StandardShapes (12-16px radius)
/// - SoftShadow (subtle, barely visible)
/// - NoneEffect (clean, distraction-free)
/// - ZenMotion (slow, meditative)
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
  static String get description =>
      '禅意极简风格 - 柔和蓝色调、大量留白、平静冥想的设计哲学';
}
