/// Hand-Drawn Theme Preset
///
/// 手绘风格主题 - 轻微非对称轮廓与手写排版。
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_composer.dart';
import 'package:nai_launcher/presentation/themes/modules/color/palettes/hand_drawn_palette.dart';
import 'package:nai_launcher/presentation/themes/modules/typography/presets/hand_drawn_typography.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/presets/wobbly_shapes.dart';
import 'package:nai_launcher/presentation/themes/modules/motion/presets/jitter_motion.dart';

/// Hand-Drawn theme configuration.
///
/// Combines:
/// - HandDrawnPalette (#FDFBF7, #2D2D2D, #FF4D4D)
/// - HandDrawnTypography (Kalam + Patrick Hand)
/// - WobblyShapes (轻微非对称轮廓)
/// - JitterMotion (playful, bouncy movement)
///
/// Note: This theme only supports light mode.
class HandDrawnTheme {
  const HandDrawnTheme._();

  static const _composer = ThemeComposer(
    color: HandDrawnPalette(),
    typography: HandDrawnTypography(),
    shape: WobblyShapes(),
    motion: JitterMotion(),
  );

  /// The light theme.
  static ThemeData get light => _composer.buildTheme(Brightness.light);

  /// The dark theme (falls back to light as this theme doesn't support dark mode).
  static ThemeData get dark => _composer.buildTheme(Brightness.dark);

  /// Whether this theme supports dark mode.
  static bool get supportsDarkMode => false;

  /// Theme display name.
  static String get displayName => 'Hand-Drawn';

  /// Theme description.
  static String get description => '手绘风格 - 非对称轮廓与可爱手写字体的温馨设计';
}
