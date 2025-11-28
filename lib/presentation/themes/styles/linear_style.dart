import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../theme_extension.dart';

/// Linear 风格 - 现代极简深色
/// 灵感来源: Linear 官网
class LinearStyle {
  LinearStyle._();

  static const primaryColor = Color(0xFF5E6AD2);
  static const secondaryColor = Color(0xFF8B5CF6);
  static const backgroundColor = Color(0xFF08090a);
  static const surfaceColor = Color(0xFF111111);
  static const cardColor = Color(0xFF1A1A1A);

  static ThemeData createTheme(Brightness brightness, String? fontFamily) {
    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFF3D4090),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF5B3A9E),
        tertiary: Color(0xFFF472B6),
        tertiaryContainer: Color(0xFF9D4A76),
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 5,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        inputDecoratorRadius: 6.0,
        inputDecoratorBorderWidth: 1.0,
        cardRadius: 8.0,
        cardElevation: 0.0,
        elevatedButtonRadius: 6.0,
        outlinedButtonRadius: 6.0,
        textButtonRadius: 6.0,
        dialogRadius: 12.0,
        bottomSheetRadius: 12.0,
        chipRadius: 6.0,
      ),
      useMaterial3: true,
      fontFamily: fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: const Color(0xFF333333),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFEDEDEF),
        onError: Colors.white,
      ),
      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.defaultCompact,
          blurStrength: 10.0,
          borderWidth: 1.0,
          borderColor: Colors.white.withOpacity(0.1),
          shadowIntensity: 0.3,
          accentBarColor: primaryColor,
          containerDecoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.6),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

