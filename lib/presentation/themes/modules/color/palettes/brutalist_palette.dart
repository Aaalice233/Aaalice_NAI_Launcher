/// Brutalist Palette - Motorola Beeper 复古 LCD 风格配色
///
/// Colors from: MotorolaBeeperStyle
/// Primary: #212121 (深灰黑)
/// Background: #8FA38F (LCD 绿)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Brutalist color palette - retro LCD / beeper theme.
class BrutalistPalette extends BaseColorModule {
  const BrutalistPalette();

  static const Color _primary = Color(0xFF212121);
  static const Color _secondary = Color(0xFF455A64);
  static const Color _surface = Color(0xFF809680);
  static const Color _card = Color(0xFF809680);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF9AA99A), // Light LCD green for contrast
        onPrimaryContainer: Color(0xFF0F1F0F), // Dark green for text/icons
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: Color(0xFF37474F),
        onTertiary: Colors.white,
        surface: _surface,
        onSurface: _primary,
        onSurfaceVariant: Color(0xFF455A64), // Blue-gray 700
        surfaceContainerHighest: _card,
        outline: Color(0xFF607060), // LCD border green
        error: Color(0xFFB71C1C),
      );

  @override
  ColorScheme get darkScheme => lightScheme; // Light-only theme

  @override
  bool get supportsDarkMode => false;
}
