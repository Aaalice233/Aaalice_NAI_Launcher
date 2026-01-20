/// Neo Dark Palette - Linear 风格现代极简深色配色
///
/// Colors from: LinearStyle (Linear.app inspired)
/// Primary: #5E6AD2 (Indigo)
/// Secondary: #8B5CF6 (Violet)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Neo Dark color palette - modern minimalist dark theme.
class NeoDarkPalette extends BaseColorModule {
  const NeoDarkPalette();

  static const Color _primary = Color(0xFF5E6AD2);
  static const Color _secondary = Color(0xFF8B5CF6);
  static const Color _surface = Color(0xFF111111);
  static const Color _card = Color(0xFF1A1A1A);

  @override
  ColorScheme get lightScheme => darkScheme; // Dark-only theme

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: Color(0xFFF472B6),
        onTertiary: Colors.white,
        surface: _surface,
        onSurface: Color(0xFFEDEDEF),
        surfaceContainerHighest: _card,
        error: Color(0xFFEF4444),
      );

  @override
  bool get supportsDarkMode => true;
}
