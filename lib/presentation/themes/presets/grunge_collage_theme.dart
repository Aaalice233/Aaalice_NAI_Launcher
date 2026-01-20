/// Grunge Collage Theme Preset
///
/// 复古拼贴风格主题 - 颗粒感、做旧效果、高对比度
/// Reference: docs/UI设计提示词合集/第二套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/grunge_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/grunge_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/hard_offset_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/texture_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/jitter_motion.dart';
import 'package:nai_launcher/presentation/themes/modules/divider/thick_divider.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Grunge Collage theme configuration.
///
/// Combines:
/// - GrungePalette (#F0EAD6, #1A1A1A, #DC143C)
/// - GrungeTypography (Impact/Oswald + Courier New)
/// - StandardShapes (12-16px radius)
/// - HardOffsetShadow (4px 4px 0)
/// - TextureEffect (grunge texture overlay)
/// - JitterMotion (rough, organic movement)
///
/// This theme supports both light and dark modes.
class GrungeCollageTheme {
  const GrungeCollageTheme._();

  static const _composer = ThemeComposer(
    color: GrungePalette(),
    typography: GrungeTypography(),
    shape: StandardShapes(),
    shadow: HardOffsetShadow(),
    effect: TextureEffect(),
    motion: JitterMotion(),
    divider: ThickDividerModule.grunge,
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
  static String get displayName => 'Grunge Collage';

  /// Theme description.
  static String get description =>
      '复古拼贴风格 - 做旧纹理、硬阴影、高对比度的朋克美学';
}
