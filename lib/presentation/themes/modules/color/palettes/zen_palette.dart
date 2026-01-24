/// Zen Minimalist Palette - 禅意极简配色
///
/// Design Reference: docs/UI设计提示词合集/默认主题.txt
/// CSS Variables:
/// - --primary: #60a5fa
/// - --background: #050505
/// - --surface: #0e0e0f
/// - --surface-elevated: #151517
/// - --text-main: #fcfcfc
/// - --text-muted: #94a3b8
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Zen Minimalist color palette - calm, understated.
class ZenPalette extends BaseColorModule {
  const ZenPalette();

  // Design spec colors
  static const Color _primary = Color(0xFF60A5FA); // --primary
  static const Color _secondary = Color(0xFF94A3B8); // --text-muted
  static const Color _tertiary = Color(0xFFA78BFA);
  static const Color _background = Color(0xFF050505); // --background
  static const Color _surface = Color(0xFF0E0E0F); // --surface
  static const Color _surfaceElevated = Color(0xFF151517); // --surface-elevated
  static const Color _onSurface = Color(0xFFFCFCFC); // --text-main

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: Color(0xFF3B82F6),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDCE7FF), // Light blue for contrast
        onPrimaryContainer: Color(0xFF0C3170), // Dark blue for text/icons
        secondary: Color(0xFF64748B),
        onSecondary: Colors.white,
        tertiary: Color(0xFF8B5CF6),
        surface: Color(0xFFFAFAFA),
        onSurface: Color(0xFF27272A),
        surfaceContainerHighest: Color(0xFFF4F4F5),
        outline: Color(0xFFE4E4E7),
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.black,
        primaryContainer: Color(0xFF1A3A6E), // Dark blue for contrast
        onPrimaryContainer: Color(0xFFDCE7FF), // Light blue for text/icons
        secondary: _secondary,
        onSecondary: Colors.black,
        tertiary: _tertiary,
        surface: _surface,
        onSurface: _onSurface,
        onSurfaceVariant: Color(0xFF9CA3AF), // Gray-400 for better contrast
        surfaceContainerHighest: _surfaceElevated,
        surfaceContainerLowest:
            _background, // Use background for lowest container
        outline: Color(0xFF52525B), // Zinc-600 for better visibility
      );

  @override
  bool get supportsDarkMode => true;
}
