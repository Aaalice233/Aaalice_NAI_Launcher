/// Midnight Editorial Theme Preset
///
/// 午夜编辑风格主题 - 深黑背景、珊瑚色点缀、杂志排版
/// Reference: docs/UI设计提示词合集/第八套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/editorial_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/editorial_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/presets/soft_shadow.dart';
import 'package:nai_launcher/presentation/themes/modules/effect/presets/none_effect.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/zen_motion.dart';
import 'package:nai_launcher/presentation/themes/modules/divider/none_divider.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Midnight Editorial theme configuration.
///
/// Combines:
/// - EditorialPalette (#050505, #FF6B50)
/// - EditorialTypography (Satoshi/Inter)
/// - StandardShapes (12-16px radius)
/// - SoftShadow (subtle elevation)
/// - NoneEffect (clean design)
/// - ZenMotion (smooth, elegant)
///
/// This theme supports both light and dark modes.
class MidnightEditorialTheme {
  const MidnightEditorialTheme._();

  static const _composer = ThemeComposer(
    color: EditorialPalette(),
    typography: EditorialTypography(),
    shape: StandardShapes(),
    shadow: SoftShadow(),
    effect: NoneEffect(),
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
  static String get displayName => 'Midnight Editorial';

  /// Theme description.
  static String get description =>
      '午夜编辑风格 - 深黑背景配珊瑚色点缀，杂志般的优雅排版';
}
