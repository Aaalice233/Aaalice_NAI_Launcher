/// Retro Wave Palette - 复古未来霓虹风配色
///
/// Colors from: CassetteFuturismStyle
/// Primary: #FF7043 (焦橙色)
/// Secondary: #26A69A (复古青)
/// Tertiary: #FFD54F (芥末黄)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Retro Wave color palette - warm retro-futurism theme.
class RetroWavePalette extends BaseColorModule {
  const RetroWavePalette();

  static const Color _primary = Color(0xFFFF7043);
  static const Color _secondary = Color(0xFF26A69A);
  static const Color _tertiary = Color(0xFFFFD54F);
  static const Color _surface = Color(0xFF373737);
  static const Color _card = Color(0xFF424242);

  @override
  ColorScheme get lightScheme => darkScheme; // Dark-only theme

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF5C3A30), // Dark orange for contrast
        onPrimaryContainer: Color(0xFFFFCCBC), // Light orange for text/icons
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: _tertiary,
        onTertiary: Color(0xFF1A1A1A),
        surface: _surface,
        onSurface: Color(0xFFEEEEEE),
        onSurfaceVariant: Color(0xFFBDBDBD), // Warm light gray
        surfaceContainerHighest: _card,
        outline: Color(0xFF6B6B6B), // Warm border gray
        error: Color(0xFFEF5350),
      );

  @override
  bool get supportsDarkMode => true;
}
