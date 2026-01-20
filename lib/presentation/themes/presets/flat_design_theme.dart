/// Flat Design Theme Preset
///
/// 扁平设计风格主题 - 零阴影、锐利边角、简约色块
/// Reference: docs/UI设计提示词合集/第六套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/flat_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/flat_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/sharp_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/none_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/none_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Flat Design theme configuration.
///
/// Combines:
/// - FlatPalette (#3B82F6, #FFFFFF)
/// - FlatTypography (Outfit)
/// - SharpShapes (6-8px radius)
/// - NoneShadow (zero shadows)
/// - NoneEffect (no special effects)
/// - SnappyMotion (fast, responsive)
///
/// This theme supports both light and dark modes.
class FlatDesignTheme {
  const FlatDesignTheme._();

  static const _composer = ThemeComposer(
    color: FlatPalette(),
    typography: FlatTypography(),
    shape: SharpShapes(),
    shadow: NoneShadow(),
    effect: NoneEffect(),
    motion: SnappyMotion(),
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
  static String get displayName => 'Flat Design';

  /// Theme description.
  static String get description =>
      '扁平设计风格 - 零阴影、锐角边框、纯色块的极简美学';
}
