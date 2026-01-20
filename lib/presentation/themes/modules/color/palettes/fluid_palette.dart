/// Fluid Saturated Palette - 流体饱和配色
///
/// Colors from: docs/UI设计提示词合集/第三套UI.txt
/// Primary: #FDE047 (亮黄)
/// Background: #0A0A0A (纯黑)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Fluid Saturated color palette - high contrast, bold colors.
class FluidPalette extends BaseColorModule {
  const FluidPalette();

  static const Color _primary = Color(0xFFFDE047);
  static const Color _secondary = Color(0xFF22D3EE);
  static const Color _tertiary = Color(0xFFF472B6);
  static const Color _background = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF1A1A1A);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: Color(0xFFEAB308), // Darker yellow for light mode
        onPrimary: Colors.black,
        secondary: Color(0xFF0891B2),
        onSecondary: Colors.white,
        tertiary: Color(0xFFDB2777),
        surface: Colors.white,
        onSurface: Colors.black87,
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.black,
        secondary: _secondary,
        onSecondary: Colors.black,
        tertiary: _tertiary,
        surface: _surface,
        onSurface: Colors.white,
        surfaceContainerHighest: _background,
      );

  @override
  bool get supportsDarkMode => true;
}
