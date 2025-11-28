import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../theme_extension.dart';

/// Invoke 风格 - 专业 AI 工具风格
/// 灵感来源: InvokeAI
class InvokeStyle {
  InvokeStyle._();

  static const primaryColor = Color(0xFF9B8AFF);
  static const secondaryColor = Color(0xFF6366F1);
  static const backgroundColor = Color(0xFF1A1A2E);
  static const surfaceColor = Color(0xFF252542);
  static const cardColor = Color(0xFF2D2D4A);

  static ThemeData createTheme(Brightness brightness, String? fontFamily) {
    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFF3D3A65),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF3730A3),
        tertiary: Color(0xFF22D3EE),
        tertiaryContainer: Color(0xFF164E63),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 15,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        inputDecoratorRadius: 8.0,
        cardRadius: 12.0,
        elevatedButtonRadius: 8.0,
        outlinedButtonRadius: 8.0,
        textButtonRadius: 8.0,
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
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      extensions: [
        const AppThemeExtension(
          navBarStyle: AppNavBarStyle.material,
          accentBarColor: primaryColor,
        ),
      ],
    );
  }
}

