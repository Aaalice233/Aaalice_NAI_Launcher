/// Pro AI Palette - InvokeAI 风格专业 AI 工具配色
///
/// Colors from: InvokeStyle (InvokeAI inspired)
/// Primary: #9B8AFF (淡紫)
/// Secondary: #6366F1 (Indigo)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Pro AI color palette - professional AI tool theme.
class ProAiPalette extends BaseColorModule {
  const ProAiPalette();

  static const Color _primary = Color(0xFF9B8AFF);
  static const Color _secondary = Color(0xFF6366F1);
  static const Color _surface = Color(0xFF252542);
  static const Color _card = Color(0xFF2D2D4A);

  @override
  ColorScheme get lightScheme => darkScheme; // Dark-only theme

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: Color(0xFF22D3EE),
        onTertiary: Color(0xFF1A1A1A),
        surface: _surface,
        onSurface: Colors.white,
        surfaceContainerHighest: _card,
        error: Color(0xFFEF4444),
      );

  @override
  bool get supportsDarkMode => true;
}
