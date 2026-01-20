import 'package:flutter/material.dart';
import '../../presentation/themes/theme_extension.dart';

/// BuildContext extension for convenient theme access
///
/// Usage:
/// ```dart
/// final appTheme = context.appTheme;
/// final blurStrength = appTheme.blurStrength;
/// ```
extension ThemeContextExtension on BuildContext {
  /// Access the current [AppThemeExtension] from the theme.
  ///
  /// Returns a non-nullable [AppThemeExtension]. If the extension is not
  /// registered in the current theme, returns a default instance.
  AppThemeExtension get appTheme {
    return Theme.of(this).extension<AppThemeExtension>() ??
        const AppThemeExtension();
  }

  /// Access the current [AppThemeExtension] or null if not available.
  AppThemeExtension? get appThemeOrNull {
    return Theme.of(this).extension<AppThemeExtension>();
  }

  /// Check if the current theme is a light theme.
  bool get isLightTheme {
    return appTheme.isLightTheme;
  }

  /// Check if the current theme is a dark theme.
  bool get isDarkTheme {
    return !appTheme.isLightTheme;
  }

  /// Get the current blur strength (for glassmorphism effects).
  double get themeBlurStrength {
    return appTheme.blurStrength;
  }

  /// Get the current interaction style.
  AppInteractionStyle get themeInteractionStyle {
    return appTheme.interactionStyle;
  }

  /// Get the current navigation bar style.
  AppNavBarStyle get themeNavBarStyle {
    return appTheme.navBarStyle;
  }

  /// Check if pixel font is enabled.
  bool get usePixelFont {
    return appTheme.usePixelFont;
  }

  /// Check if CRT effect is enabled.
  bool get enableCrtEffect {
    return appTheme.enableCrtEffect;
  }

  /// Check if neon glow effect is enabled.
  bool get enableNeonGlow {
    return appTheme.enableNeonGlow;
  }

  /// Get the glow color for neon effects.
  Color? get themeGlowColor {
    return appTheme.glowColor;
  }

  /// Get the container decoration from the theme.
  BoxDecoration? get containerDecoration {
    return appTheme.containerDecoration;
  }
}
