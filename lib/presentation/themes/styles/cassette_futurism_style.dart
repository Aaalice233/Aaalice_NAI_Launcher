import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../theme_extension.dart';

/// 未来磁带主义风格 - 温暖、模拟数字混合的复古未来风格
class CassetteFuturismStyle {
  CassetteFuturismStyle._();

  static const primaryColor = Color(0xFFFF7043);    // 焦橙色
  static const secondaryColor = Color(0xFF26A69A);  // 复古青
  static const backgroundColor = Color(0xFF2C2C2C); // 暖深灰
  static const surfaceColor = Color(0xFF373737);    // 稍亮的灰
  static const cardColor = Color(0xFF424242);
  static const tertiaryColor = Color(0xFFFFD54F);   // 芥末黄

  static ThemeData createTheme(Brightness brightness, String? fontFamily) {
    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFFD84315),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF00695C),
        tertiary: tertiaryColor,
        tertiaryContainer: Color(0xFFFF8F00),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 0,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 0,
        inputDecoratorRadius: 16.0,
        inputDecoratorBorderWidth: 2.0,
        cardRadius: 16.0,
        elevatedButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        textButtonRadius: 12.0,
        dialogRadius: 20.0,
        bottomSheetRadius: 24.0,
        chipRadius: 8.0,
      ),
      useMaterial3: true,
      fontFamily: fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: Colors.black.withOpacity(0.2),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Color(0xFFEF5350),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFEEEEEE),
        onError: Colors.white,
      ),
      extensions: [
        const AppThemeExtension(
          navBarStyle: AppNavBarStyle.material,
          interactionStyle: AppInteractionStyle.physical,
          enableCrtEffect: false,
          enableGlowEffect: false,
          enableNeonGlow: false,
          borderWidth: 2.0,
          borderColor: Color(0xFF505050),
          accentBarColor: primaryColor,
          containerDecoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFF505050), width: 2)),
          ),
        ),
      ],
    );
  }
}

