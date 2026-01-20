/// Zen Minimalist Palette - 禅意极简配色
///
/// Colors from: docs/UI设计提示词合集/第九套UI.txt
/// Background: #050505 (深黑)
/// Primary: #60A5FA (柔和蓝)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Zen Minimalist color palette - calm, understated.
class ZenPalette extends BaseColorModule {
  const ZenPalette();

  static const Color _primary = Color(0xFF60A5FA);
  static const Color _secondary = Color(0xFF94A3B8);
  static const Color _tertiary = Color(0xFFA78BFA);
  static const Color _background = Color(0xFF050505);
  static const Color _surface = Color(0xFF0F0F0F);
  static const Color _onSurface = Color(0xFFD4D4D8);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: Color(0xFF3B82F6),
        onPrimary: Colors.white,
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
        secondary: _secondary,
        onSecondary: Colors.black,
        tertiary: _tertiary,
        surface: _surface,
        onSurface: _onSurface,
        surfaceContainerHighest: _background,
        outline: Color(0xFF27272A),
      );

  @override
  bool get supportsDarkMode => true;
}
