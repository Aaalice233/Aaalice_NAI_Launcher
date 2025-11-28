import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../theme_extension.dart';

/// Motorola Fix Beeper 风格 - 复古传呼机/LCD 电子风格
class MotorolaBeeperStyle {
  MotorolaBeeperStyle._();

  static const primaryColor = Color(0xFF212121); // 近乎黑色的文字色
  static const secondaryColor = Color(0xFF455A64); // 深灰蓝
  static const backgroundColor = Color(0xFF8FA38F); // 典型 LCD 背景色
  static const surfaceColor = Color(0xFF809680); // 稍深一点
  static const cardColor = Color(0xFF809680);

  static ThemeData createTheme(Brightness brightness, String? fontFamily) {
    return FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFF000000),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF263238),
        tertiary: Color(0xFF37474F),
        tertiaryContainer: Color(0xFF102027),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 0,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 0,
        inputDecoratorRadius: 2.0,
        inputDecoratorBorderWidth: 2.0,
        cardRadius: 4.0,
        elevatedButtonRadius: 2.0,
        outlinedButtonRadius: 2.0,
        textButtonRadius: 2.0,
        dialogRadius: 4.0,
        bottomSheetRadius: 4.0,
        chipRadius: 0.0,
      ),
      useMaterial3: true,
      fontFamily: fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: primaryColor.withOpacity(0.5),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Color(0xFFB71C1C),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: primaryColor,
        onError: Colors.white,
      ),
      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.retroBottom,
          interactionStyle: AppInteractionStyle.digital,
          usePixelFont: true,
          enableDotMatrix: true,
          enableCrtEffect: false,
          borderWidth: 2.0,
          borderColor: primaryColor,
          accentBarColor: primaryColor,
          containerDecoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
