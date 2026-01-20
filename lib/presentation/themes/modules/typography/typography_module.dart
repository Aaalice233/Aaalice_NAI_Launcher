/// Typography Module - Base Implementation
///
/// Provides the base class and utilities for typography modules.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';

export 'presets/retro_typography.dart';
export 'presets/grunge_typography.dart';
export 'presets/fluid_typography.dart';
export 'presets/material_typography.dart';
export 'presets/flat_typography.dart';
export 'presets/hand_drawn_typography.dart';
export 'presets/editorial_typography.dart';
export 'presets/zen_typography.dart';

/// Base implementation of [TypographyModule] with common utilities.
abstract class BaseTypographyModule implements TypographyModule {
  const BaseTypographyModule();

  /// Creates a complete TextTheme using Google Fonts.
  static TextTheme createTextTheme({
    required String displayFamily,
    required String bodyFamily,
  }) {
    final displayStyle = GoogleFonts.getFont(displayFamily);
    final bodyStyle = GoogleFonts.getFont(bodyFamily);

    return TextTheme(
      // Display styles
      displayLarge: displayStyle.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: displayStyle.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: displayStyle.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w400,
      ),
      // Headline styles
      headlineLarge: displayStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: displayStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: displayStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      // Title styles
      titleLarge: displayStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: bodyStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      // Body styles
      bodyLarge: bodyStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: bodyStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      // Label styles
      labelLarge: bodyStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: bodyStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: bodyStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
