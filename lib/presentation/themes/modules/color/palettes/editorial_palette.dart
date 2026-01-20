/// Midnight Editorial Palette - 午夜编辑配色
///
/// Colors from: docs/UI设计提示词合集/第八套UI.txt
/// Background: #050505 (深黑)
/// Accent: #FF6B50 (珊瑚色)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Midnight Editorial color palette - dark, sophisticated.
class EditorialPalette extends BaseColorModule {
  const EditorialPalette();

  static const Color _primary = Color(0xFFFF6B50);
  static const Color _secondary = Color(0xFF60A5FA);
  static const Color _tertiary = Color(0xFFFBBF24);
  static const Color _background = Color(0xFF050505);
  static const Color _surface = Color(0xFF0A0A0A);
  static const Color _onSurface = Color(0xFFE5E5E5);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: Color(0xFFDC4A30),
        onPrimary: Colors.white,
        secondary: Color(0xFF2563EB),
        onSecondary: Colors.white,
        tertiary: Color(0xFFD97706),
        surface: Color(0xFFFAFAFA),
        onSurface: Color(0xFF171717),
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.black,
        secondary: _secondary,
        onSecondary: Colors.black,
        tertiary: _tertiary,
        surface: _surface,
        onSurface: _onSurface,
        surfaceContainerHighest: _background,
        outline: Color(0xFF262626),
      );

  @override
  bool get supportsDarkMode => true;
}
