/// Hand-Drawn Palette - 手绘风格配色
///
/// Colors from: docs/UI设计提示词合集/第七套UI.txt
/// Primary: #FDFBF7 (暖白)
/// Text: #2D2D2D (深灰)
/// Accent: #FF4D4D (红)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Hand-Drawn color palette - warm, paper-like colors.
/// Note: This theme only supports light mode.
class HandDrawnPalette extends BaseColorModule {
  const HandDrawnPalette();

  static const Color _primary = Color(0xFF2D2D2D);
  static const Color _secondary = Color(0xFFFF4D4D);
  static const Color _tertiary = Color(0xFF4D79FF);
  static const Color _surface = Color(0xFFFDFBF7);
  static const Color _background = Color(0xFFF5F3EF);

  @override
  ColorScheme get lightScheme => ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: _tertiary,
        onTertiary: Colors.white,
        surface: _surface,
        onSurface: _primary,
        surfaceContainerHighest: _background,
        outline: const Color(0xFF2D2D2D).withOpacity(0.3),
        error: _secondary,
      );

  @override
  ColorScheme get darkScheme => lightScheme; // Light mode only

  @override
  bool get supportsDarkMode => false;
}
