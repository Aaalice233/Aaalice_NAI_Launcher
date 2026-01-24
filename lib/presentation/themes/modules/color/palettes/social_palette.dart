/// Social Palette - Discord 风格社交应用配色
///
/// Colors from: DiscordStyle
/// Primary: #5865F2 (Blurple)
/// Secondary: #57F287 (Green)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Social color palette - familiar social app theme.
class SocialPalette extends BaseColorModule {
  const SocialPalette();

  static const Color _primary = Color(0xFF5865F2);
  static const Color _secondary = Color(0xFF57F287);
  static const Color _surface = Color(0xFF2B2D31);
  static const Color _card = Color(0xFF383A40);

  @override
  ColorScheme get lightScheme => darkScheme; // Dark-only theme

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF2C2D5F), // Dark blurple for contrast
        onPrimaryContainer: Color(0xFFD3D6FF), // Light blurple for text/icons
        secondary: _secondary,
        onSecondary: Colors.black,
        tertiary: Color(0xFFFEE75C),
        onTertiary: Colors.black,
        surface: _surface,
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFFB5BAC1), // Discord light gray
        surfaceContainerHighest: _card,
        outline: Color(0xFF5C5E66), // Discord border gray
        error: Color(0xFFED4245),
      );

  @override
  bool get supportsDarkMode => true;
}
