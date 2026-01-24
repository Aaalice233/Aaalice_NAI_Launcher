/// Flat Design Palette - 扁平设计配色
///
/// Colors from: docs/UI设计提示词合集/第六套UI.txt
/// Primary: #3B82F6 (蓝)
/// Background: #FFFFFF (纯白)
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/color/color_module.dart';

/// Flat Design color palette - clean, minimal colors.
class FlatPalette extends BaseColorModule {
  const FlatPalette();

  static const Color _primary = Color(0xFF3B82F6);
  static const Color _secondary = Color(0xFF10B981);
  static const Color _tertiary = Color(0xFFF59E0B);
  static const Color _error = Color(0xFFEF4444);
  static const Color _surface = Colors.white;

  @override
  ColorScheme get lightScheme => const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDCE7FF), // Light blue for contrast
        onPrimaryContainer: Color(0xFF0C3170), // Dark blue for text/icons
        secondary: _secondary,
        onSecondary: Colors.white,
        tertiary: _tertiary,
        onTertiary: Colors.black,
        surface: _surface,
        onSurface: Color(0xFF1F2937),
        surfaceContainerHighest: Color(0xFFF3F4F6),
        outline: Color(0xFFD1D5DB),
        error: _error,
      );

  @override
  ColorScheme get darkScheme => const ColorScheme.dark(
        primary: Color(0xFF60A5FA),
        onPrimary: Color(0xFF1E3A8A),
        primaryContainer: Color(0xFF1A3A6E), // Dark blue for contrast
        onPrimaryContainer: Color(0xFFDCE7FF), // Light blue for text/icons
        secondary: Color(0xFF34D399),
        onSecondary: Color(0xFF064E3B),
        tertiary: Color(0xFFFBBF24),
        surface: Color(0xFF111827),
        onSurface: Color(0xFFF9FAFB),
        surfaceContainerHighest: Color(0xFF1F2937),
        outline: Color(0xFF4B5563),
        error: Color(0xFFF87171),
      );

  @override
  bool get supportsDarkMode => true;
}
