/// System Palette - 跟随系统主题的自适应配色
///
/// Colors from: SystemStyle
/// Dark: #6366F1 (Indigo)
/// Light: #007AFF (iOS Blue)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// System color palette - adapts to system light/dark mode.
class SystemPalette extends BaseColorModule {
  const SystemPalette();

  // Dark mode colors
  static const Color _darkPrimary = Color(0xFF6366F1);
  static const Color _darkSecondary = Color(0xFF8B5CF6);
  static const Color _darkSurface = Color(0xFF12121A);
  static const Color _darkCard = Color(0xFF1A1A24);

  // Light mode colors
  static const Color _lightPrimary = Color(0xFF007AFF);
  static const Color _lightSecondary = Color(0xFF34C759);
  static const Color _lightSurface = Color(0xFFF5F5F7);
  static const Color _lightCard = Color(0xFFFFFFFF);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: _lightPrimary,
        onPrimary: Colors.white,
        secondary: _lightSecondary,
        onSecondary: Colors.white,
        tertiary: Color(0xFFFF9500),
        onTertiary: Colors.white,
        surface: _lightSurface,
        onSurface: Color(0xFF1D1D1F),
        surfaceContainerHighest: _lightCard,
        error: Color(0xFFFF3B30),
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _darkPrimary,
        onPrimary: Colors.white,
        secondary: _darkSecondary,
        onSecondary: Colors.white,
        tertiary: Color(0xFF22D3EE),
        onTertiary: Color(0xFF1A1A1A),
        surface: _darkSurface,
        onSurface: Color(0xFFA2AFB9),
        surfaceContainerHighest: _darkCard,
        error: Color(0xFFEF4444),
      );

  @override
  bool get supportsDarkMode => true;
}
