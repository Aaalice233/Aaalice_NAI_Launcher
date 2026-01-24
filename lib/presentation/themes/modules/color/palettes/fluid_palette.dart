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
        primaryContainer: Color(0xFFFFF8DC), // Light yellow for contrast
        onPrimaryContainer: Color(0xFF5C4A00), // Dark yellow for text/icons
        secondary: Color(0xFF0891B2),
        onSecondary: Colors.white,
        tertiary: Color(0xFFDB2777),
        surface: Colors.white,
        onSurface: Colors.black87,
        onSurfaceVariant: Color(0xFF6B7280), // Gray-500
        outline: Color(0xFFD1D5DB), // Gray-300
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.black,
        primaryContainer: Color(0xFF5C4A00), // Dark yellow for contrast
        onPrimaryContainer: Color(0xFFFFF8DC), // Light yellow for text/icons
        secondary: _secondary,
        onSecondary: Colors.black,
        tertiary: _tertiary,
        surface: _surface,
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFFA1A1AA), // Zinc-400
        surfaceContainerHighest: _background,
        outline: Color(0xFF525252), // Neutral-600
      );

  @override
  bool get supportsDarkMode => true;
}
