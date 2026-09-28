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
    primaryContainer: const Color(0xFFE8E4DC), // Light warm gray for contrast
    onPrimaryContainer: const Color(0xFF2D2D2D), // Dark gray for text/icons
    secondary: _secondary,
    onSecondary: const Color(0xFF4D0000),
    tertiary: _tertiary,
    onTertiary: const Color(0xFF00134D),
    surface: _surface,
    onSurface: _primary,
    surfaceContainerHighest: _background,
    outline: const Color(0xFF2D2D2D).withValues(alpha: 0.3),
    error: _secondary,
    onError: const Color(0xFF4D0000),
  );

  @override
  ColorScheme get darkScheme => lightScheme; // Light mode only

  @override
  bool get supportsDarkMode => false;
}
