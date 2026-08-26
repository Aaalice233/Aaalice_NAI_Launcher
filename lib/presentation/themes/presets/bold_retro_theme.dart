/// Bold Retro Theme Preset
///
/// 复古现代主义风格主题 - 温暖怀旧的配色与现代排版结合
/// Reference: docs/UI设计提示词合集/第一套UI.txt
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/retro_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/retro_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/standard_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/snappy_motion.dart';

/// Bold Retro theme configuration.
///
/// Combines:
/// - RetroPalette (#BC2C2C, #5DA4C9, #FCD758)
/// - RetroTypography (Montserrat/Poppins + Open Sans)
/// - StandardShapes (12-16px radius)
/// - SnappyMotion (fast, responsive)
///
/// Note: This theme only supports light mode.
class BoldRetroTheme {
  const BoldRetroTheme._();

  static const _composer = ThemeComposer(
    color: RetroPalette(),
    typography: RetroTypography(),
    shape: StandardShapes(),
    motion: SnappyMotion(),
  );

  /// The light theme.
  static ThemeData get light => _composer.buildTheme(Brightness.light);

  /// The dark theme (falls back to light as this theme doesn't support dark mode).
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);

  /// Whether this theme supports dark mode.
  static bool get supportsDarkMode => false;

  /// Theme display name.
  static String get displayName => 'Bold Retro';

  /// Theme description.
  static String get description => '复古现代主义风格 - 温暖的红黄蓝配色，怀旧而不失现代感';
}
