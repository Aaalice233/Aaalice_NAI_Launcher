/// Color Module - Base Implementation
///
/// Provides the base class and utilities for color palette modules.
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';

export 'palettes/retro_palette.dart';
export 'palettes/grunge_palette.dart';
export 'palettes/fluid_palette.dart';
export 'palettes/material_you_palette.dart';
export 'palettes/flat_palette.dart';
export 'palettes/hand_drawn_palette.dart';
export 'palettes/editorial_palette.dart';
export 'palettes/zen_palette.dart';

/// Base implementation of [ColorSchemeModule] with common utilities.
abstract class BaseColorModule implements ColorSchemeModule {
  const BaseColorModule();

  /// Creates a light ColorScheme from primary and secondary colors.
  static ColorScheme createLightScheme({
    required Color primary,
    required Color secondary,
    Color? tertiary,
    Color? surface,
    Color? background,
    Color? error,
  }) {
    return ColorScheme.light(
      primary: primary,
      onPrimary: _contrastColor(primary),
      secondary: secondary,
      onSecondary: _contrastColor(secondary),
      tertiary: tertiary,
      surface: surface ?? Colors.white,
      onSurface: Colors.black87,
      error: error ?? const Color(0xFFB3261E),
    );
  }

  /// Creates a dark ColorScheme from primary and secondary colors.
  static ColorScheme createDarkScheme({
    required Color primary,
    required Color secondary,
    Color? tertiary,
    Color? surface,
    Color? background,
    Color? error,
  }) {
    return ColorScheme.dark(
      primary: primary,
      onPrimary: _contrastColor(primary),
      secondary: secondary,
      onSecondary: _contrastColor(secondary),
      tertiary: tertiary,
      surface: surface ?? const Color(0xFF1C1B1F),
      onSurface: Colors.white,
      error: error ?? const Color(0xFFF2B8B5),
    );
  }

  /// Returns black or white depending on the luminance of the color.
  static Color _contrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
