/// Grunge Collage Palette - Grunge拼贴配色
///
/// Colors from: docs/UI设计提示词合集/第二套UI.txt
/// Primary: #F0EAD6 (旧纸色)
/// Secondary: #1A1A1A (黑色)
/// Accent: #DC143C (猩红)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Grunge Collage color palette - distressed, punk aesthetic.
class GrungePalette extends BaseColorModule {
  const GrungePalette();

  static const Color _primary = Color(0xFFF0EAD6);
  static const Color _secondary = Color(0xFF1A1A1A);
  static const Color _accent = Color(0xFFDC143C);
  static const Color _surface = Color(0xFFF5F5F0);
  static const Color _background = Color(0xFFE8E4D4);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: _secondary, // Invert: dark primary on light bg
        onPrimary: Colors.white,
        secondary: _accent,
        onSecondary: Colors.white,
        tertiary: Color(0xFF8B4513), // Rust brown
        surface: _surface,
        onSurface: _secondary,
        surfaceContainerHighest: _background,
        error: _accent,
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: _secondary,
        secondary: _accent,
        onSecondary: Colors.white,
        tertiary: Color(0xFFD2691E),
        surface: Color(0xFF1A1A1A),
        onSurface: _primary,
        error: _accent,
      );

  @override
  bool get supportsDarkMode => true;
}
