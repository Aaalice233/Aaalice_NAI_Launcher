import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../theme_extension.dart';

/// 纯净白风格 - 极简浅色主题
/// 灵感来源: Apple / Notion
class PureLightStyle {
  PureLightStyle._();

  static const primaryColor = Color(0xFF0066FF);
  static const secondaryColor = Color(0xFF00C853);
  static const backgroundColor = Color(0xFFFFFFFF);
  static const surfaceColor = Color(0xFFF5F5F5);
  static const cardColor = Color(0xFFFFFFFF);

  static ThemeData createTheme(Brightness brightness, String? fontFamily) {
    return FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFFD1E4FF),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFFB9F6CA),
        tertiary: Color(0xFFFF6D00),
        tertiaryContainer: Color(0xFFFFE0B2),
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 5,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        inputDecoratorRadius: 10.0,
        inputDecoratorBorderWidth: 1.0,
        cardRadius: 12.0,
        cardElevation: 2.0,
        elevatedButtonRadius: 10.0,
        outlinedButtonRadius: 10.0,
        textButtonRadius: 10.0,
        dialogRadius: 16.0,
        bottomSheetRadius: 16.0,
        chipRadius: 8.0,
      ),
      useMaterial3: true,
      fontFamily: fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: const Color(0xFFE0E0E0),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Color(0xFFD32F2F),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A1A1A),
        onError: Colors.white,
      ),
      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.material,
          isLightTheme: true,
          shadowIntensity: 0.5,
          accentBarColor: primaryColor,
          containerDecoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

