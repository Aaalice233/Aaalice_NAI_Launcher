/// Bold Retro Palette - 复古现代主义配色
///
/// Colors from: docs/UI设计提示词合集/第一套UI.txt
/// Primary: #BC2C2C (复古红)
/// Secondary: #5DA4C9 (复古蓝)
/// Tertiary: #FCD758 (复古黄)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Bold Retro color palette - warm, nostalgic colors.
class RetroPalette extends BaseColorModule {
  const RetroPalette();

  static const Color _primary = Color(0xFFBC2C2C);
  static const Color _secondary = Color(0xFF5DA4C9);
  static const Color _tertiary = Color(0xFFFCD758);
  static const Color _surface = Color(0xFFFFFDF5);
  static const Color _background = Color(0xFFF5F0E6);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: _tertiary,
        onTertiary: Colors.black,
        surface: _surface,
        onSurface: Color(0xFF1A1A1A),
        onSurfaceVariant: Color(0xFF78716C), // Warm gray (Stone-500)
        surfaceContainerHighest: _background,
        outline: Color(0xFFD6D3D1), // Stone-300
        error: Color(0xFFBA1A1A),
      );

  @override
  ColorScheme get darkScheme => lightScheme; // Retro is light-only

  @override
  bool get supportsDarkMode => false;
}
