/// Apple Light Palette - Apple/Notion 风格极简浅色配色
///
/// Colors from: PureLightStyle
/// Primary: #0066FF (iOS 蓝)
/// Secondary: #00C853 (iOS 绿)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Apple Light color palette - clean minimalist light theme.
class AppleLightPalette extends BaseColorModule {
  const AppleLightPalette();

  static const Color _primary = Color(0xFF0066FF);
  static const Color _secondary = Color(0xFF00C853);
  static const Color _surface = Color(0xFFF5F5F5);
  static const Color _card = Color(0xFFFFFFFF);

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: Color(0xFFFF6D00),
        onTertiary: Colors.white,
        surface: _surface,
        onSurface: Color(0xFF1A1A1A),
        surfaceContainerHighest: _card,
        error: Color(0xFFD32F2F),
      );

  @override
  ColorScheme get darkScheme => lightScheme; // Light-only theme

  @override
  bool get supportsDarkMode => false;
}
