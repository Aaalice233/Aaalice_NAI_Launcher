/// Material You (MD3) Palette - Material Design 3 配色
///
/// Colors from: docs/UI设计提示词合集/第五套UI.txt
/// Primary: #6750A4 (MD3 紫)
/// Background: #FFFBFE (MD3 白)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Material You color palette - Google's Material Design 3.
class MaterialYouPalette extends BaseColorModule {
  const MaterialYouPalette();

  static const Color _primary = Color(0xFF6750A4);
  static const Color _secondary = Color(0xFF625B71);
  static const Color _tertiary = Color(0xFF7D5260);
  static const Color _surface = Color(0xFFFFFBFE);
  static const Color _surfaceDark = Color(0xFF1C1B1F);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFEADDFF),
        onPrimaryContainer: Color(0xFF21005D),
        secondary: _secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE8DEF8),
        onSecondaryContainer: Color(0xFF1D192B),
        tertiary: _tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFFFD8E4),
        onTertiaryContainer: Color(0xFF31111D),
        surface: _surface,
        onSurface: Color(0xFF1C1B1F),
        surfaceContainerHighest: Color(0xFFE6E0E9),
        outline: Color(0xFF79747E),
        error: Color(0xFFB3261E),
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: Color(0xFFD0BCFF),
        onPrimary: Color(0xFF381E72),
        primaryContainer: Color(0xFF4F378B),
        onPrimaryContainer: Color(0xFFEADDFF),
        secondary: Color(0xFFCCC2DC),
        onSecondary: Color(0xFF332D41),
        secondaryContainer: Color(0xFF4A4458),
        onSecondaryContainer: Color(0xFFE8DEF8),
        tertiary: Color(0xFFEFB8C8),
        onTertiary: Color(0xFF492532),
        tertiaryContainer: Color(0xFF633B48),
        onTertiaryContainer: Color(0xFFFFD8E4),
        surface: _surfaceDark,
        onSurface: Color(0xFFE6E1E5),
        surfaceContainerHighest: Color(0xFF49454F),
        outline: Color(0xFF938F99),
        error: Color(0xFFF2B8B5),
      );

  @override
  bool get supportsDarkMode => true;
}
