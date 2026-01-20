/// Minimal Glass Palette - 金黄与深青的现代优雅配色
///
/// Colors from: HerdingStyle (herdi.ng inspired)
/// Primary: #D4A843 (金黄色)
/// Secondary: #1095C1 (青蓝色)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Minimal Glass color palette - elegant dark theme with gold and cyan.
class MinimalGlassPalette extends BaseColorModule {
  const MinimalGlassPalette();

  static const Color _primary = Color(0xFFD4A843);
  static const Color _secondary = Color(0xFF1095C1);
  static const Color _surface = Color(0xFF141E26);
  static const Color _card = Color(0xFF18232C);

  @override
  ColorScheme get lightScheme => darkScheme; // Dark-only theme

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Color(0xFF1A1A1A),
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: Color(0xFFE1E6EB),
        onTertiary: Color(0xFF1A1A1A),
        surface: _surface,
        onSurface: Color(0xFFA2AFB9),
        surfaceContainerHighest: _card,
        error: Color(0xFFC62828),
      );

  @override
  bool get supportsDarkMode => true;
}
