import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../theme_extension.dart';

/// Discord 风格 - 熟悉的社交应用风格
class DiscordStyle {
  DiscordStyle._();

  static const blurple = Color(0xFF5865F2);
  static const green = Color(0xFF57F287);
  static const backgroundColor = Color(0xFF313338);
  static const surfaceColor = Color(0xFF2B2D31);
  static const cardColor = Color(0xFF383A40);

  static ThemeData createTheme(Brightness brightness, String? fontFamily) {
    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: blurple,
        primaryContainer: Color(0xFF3C45A5),
        secondary: green,
        secondaryContainer: Color(0xFF2D7D46),
        tertiary: Color(0xFFFEE75C),
        tertiaryContainer: Color(0xFFAD9E3C),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 10,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 15,
        inputDecoratorRadius: 4.0,
        cardRadius: 8.0,
        elevatedButtonRadius: 4.0,
        outlinedButtonRadius: 4.0,
        textButtonRadius: 4.0,
        dialogRadius: 8.0,
        bottomSheetRadius: 12.0,
        chipRadius: 16.0,
      ),
      useMaterial3: true,
      fontFamily: fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      colorScheme: const ColorScheme.dark(
        primary: blurple,
        secondary: green,
        surface: surfaceColor,
        error: Color(0xFFED4245),
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.discordSide,
          accentBarColor: blurple,
          containerDecoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

