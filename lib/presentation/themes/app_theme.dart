import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// 主题类型枚举
enum AppThemeType {
  invokeStyle,       // InvokeAI 风格 (默认)
  discordStyle,      // Discord 风格
  linearStyle,       // Linear 风格
  cassetteFuturism,  // 复古未来主义
  motorolaBeeper,    // 寻呼机风格
}

extension AppThemeTypeExtension on AppThemeType {
  String get displayName {
    switch (this) {
      case AppThemeType.invokeStyle:
        return 'Invoke Style';
      case AppThemeType.discordStyle:
        return 'Discord Style';
      case AppThemeType.linearStyle:
        return 'Linear Style';
      case AppThemeType.cassetteFuturism:
        return 'Cassette Futurism';
      case AppThemeType.motorolaBeeper:
        return 'Motorola Beeper';
    }
  }

  String get description {
    switch (this) {
      case AppThemeType.invokeStyle:
        return '专业深色生产力工具风格';
      case AppThemeType.discordStyle:
        return '熟悉的社交应用风格';
      case AppThemeType.linearStyle:
        return '极简现代 SaaS 风格';
      case AppThemeType.cassetteFuturism:
        return '复古科幻高对比度风格';
      case AppThemeType.motorolaBeeper:
        return '怀旧液晶屏风格';
    }
  }
}

/// 应用主题管理器
class AppTheme {
  AppTheme._();

  /// 获取指定类型的主题
  static ThemeData getTheme(AppThemeType type, Brightness brightness) {
    switch (type) {
      case AppThemeType.invokeStyle:
        return _invokeStyleTheme(brightness);
      case AppThemeType.discordStyle:
        return _discordStyleTheme(brightness);
      case AppThemeType.linearStyle:
        return _linearStyleTheme(brightness);
      case AppThemeType.cassetteFuturism:
        return _cassetteFuturismTheme(brightness);
      case AppThemeType.motorolaBeeper:
        return _motorolaBeeperTheme(brightness);
    }
  }

  // ==================== Invoke Style ====================
  // 专业深色生产力工具风格，参考 InvokeAI
  static ThemeData _invokeStyleTheme(Brightness brightness) {
    const primaryColor = Color(0xFF9B8AFF);
    const secondaryColor = Color(0xFF6366F1);
    const backgroundColor = Color(0xFF1A1A2E);
    const surfaceColor = Color(0xFF252542);
    const cardColor = Color(0xFF2D2D4A);

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
    );
  }

  // ==================== Discord Style ====================
  // 熟悉的社交应用风格
  static ThemeData _discordStyleTheme(Brightness brightness) {
    const blurple = Color(0xFF5865F2);
    const green = Color(0xFF57F287);
    const backgroundColor = Color(0xFF313338);
    const surfaceColor = Color(0xFF2B2D31);
    const cardColor = Color(0xFF383A40);

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
    );
  }

  // ==================== Linear Style ====================
  // 极简现代 SaaS 风格
  static ThemeData _linearStyleTheme(Brightness brightness) {
    const primaryColor = Color(0xFF5E6AD2);
    const backgroundColor = Color(0xFF0D0D0D);
    const surfaceColor = Color(0xFF1A1A1A);
    const cardColor = Color(0xFF222222);

    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFF3D4090),
        secondary: Color(0xFF8B5CF6),
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
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: const Color(0xFF333333),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: Color(0xFF8B5CF6),
        surface: surfaceColor,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFE5E5E5),
        onError: Colors.white,
      ),
    );
  }

  // ==================== Cassette Futurism ====================
  // 复古科幻高对比度风格
  static ThemeData _cassetteFuturismTheme(Brightness brightness) {
    const primaryColor = Color(0xFFFF6B35);
    const secondaryColor = Color(0xFFE63946);
    const backgroundColor = Color(0xFF0A0A0A);
    const surfaceColor = Color(0xFF1A1A1A);
    const cardColor = Color(0xFF242424);

    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFFB34A25),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF9E2A33),
        tertiary: Color(0xFFFFD166),
        tertiaryContainer: Color(0xFFB39447),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 20,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 25,
        inputDecoratorRadius: 0.0,
        inputDecoratorBorderWidth: 2.0,
        cardRadius: 0.0,
        elevatedButtonRadius: 0.0,
        outlinedButtonRadius: 0.0,
        textButtonRadius: 0.0,
        dialogRadius: 0.0,
        bottomSheetRadius: 0.0,
        chipRadius: 0.0,
      ),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: primaryColor.withOpacity(0.3),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Color(0xFFFF0000),
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: Color(0xFFFFFFFF),
        onError: Colors.white,
      ),
    );
  }

  // ==================== Motorola Beeper ====================
  // 怀旧液晶屏风格
  static ThemeData _motorolaBeeperTheme(Brightness brightness) {
    const primaryColor = Color(0xFF00FF41);  // 经典绿色液晶
    const secondaryColor = Color(0xFF39FF14);
    const backgroundColor = Color(0xFF0D1B0D);
    const surfaceColor = Color(0xFF142214);
    const cardColor = Color(0xFF1A2E1A);

    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFF00802A),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF248F24),
        tertiary: Color(0xFF88FF88),
        tertiaryContainer: Color(0xFF4D994D),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 10,
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 15,
        inputDecoratorRadius: 2.0,
        inputDecoratorBorderWidth: 1.0,
        cardRadius: 2.0,
        elevatedButtonRadius: 2.0,
        outlinedButtonRadius: 2.0,
        textButtonRadius: 2.0,
        dialogRadius: 4.0,
        bottomSheetRadius: 4.0,
        chipRadius: 2.0,
      ),
      useMaterial3: true,
      fontFamily: 'monospace',  // 等宽字体
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: primaryColor.withOpacity(0.2),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Color(0xFFFF4444),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: primaryColor,
        onError: Colors.white,
      ),
    );
  }
}
