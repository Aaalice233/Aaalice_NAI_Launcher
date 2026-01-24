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
        primaryContainer: Color(0xFFE8E4DC), // Light warm gray for contrast
        onPrimaryContainer: Color(0xFF1A1A1A), // Dark gray for text/icons
        secondary: _accent,
        onSecondary: Colors.white,
        tertiary: Color(0xFF8B4513), // Rust brown
        surface: _surface,
        onSurface: _secondary,
        onSurfaceVariant: Color(0xFF6B5B4F), // Warm brown-gray
        surfaceContainerHighest: _background,
        outline: Color(0xFFD4CFC0), // Old paper border
        error: _accent,
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: _secondary,
        primaryContainer: Color(0xFF5C4A3D), // Dark warm brown for contrast
        onPrimaryContainer: Color(0xFFFFF5EE), // Light cream for text/icons
        secondary: _accent,
        onSecondary: Colors.white,
        tertiary: Color(0xFFD2691E),
        surface: Color(0xFF1A1A1A),
        onSurface: _primary,
        onSurfaceVariant: Color(0xFFD4CFC0), // Old paper tint
        outline: Color(0xFF525252), // Neutral-600
        error: _accent,
      );

  @override
  bool get supportsDarkMode => true;
}
