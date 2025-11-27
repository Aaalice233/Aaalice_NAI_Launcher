import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_extension.dart';

/// 主题类型枚举
enum AppThemeType {
  defaultStyle,     // 默认风格 (Linear 灵感，设为默认)
  invokeStyle,      // Invoke 风格 (专业 AI 工具)
  discordStyle,     // Discord 风格 (社交应用)
  cyberpunkStyle,   // 赛博朋克风格 (霓虹科幻)
  retroTerminal,    // 复古终端风格 (80年代终端)
  pureLight,        // 纯净白风格 (极简浅色)
}

extension AppThemeTypeExtension on AppThemeType {
  String get displayName {
    switch (this) {
      case AppThemeType.defaultStyle:
        return '默认';
      case AppThemeType.invokeStyle:
        return 'Invoke';
      case AppThemeType.discordStyle:
        return 'Discord';
      case AppThemeType.cyberpunkStyle:
        return '赛博朋克';
      case AppThemeType.retroTerminal:
        return '复古终端';
      case AppThemeType.pureLight:
        return '纯净白';
    }
  }

  String get description {
    switch (this) {
      case AppThemeType.defaultStyle:
        return '现代极简深色，灵感源自 Linear';
      case AppThemeType.invokeStyle:
        return '专业 AI 工具风格';
      case AppThemeType.discordStyle:
        return '熟悉的社交应用风格';
      case AppThemeType.cyberpunkStyle:
        return '霓虹科幻高对比度风格';
      case AppThemeType.retroTerminal:
        return '80年代终端怀旧风格';
      case AppThemeType.pureLight:
        return '清爽极简浅色主题';
    }
  }
}

/// 应用主题管理器
class AppTheme {
  AppTheme._();

  /// 获取指定类型的主题
  static ThemeData getTheme(AppThemeType type, Brightness brightness) {
    switch (type) {
      case AppThemeType.defaultStyle:
        return _defaultStyleTheme(brightness);
      case AppThemeType.invokeStyle:
        return _invokeStyleTheme(brightness);
      case AppThemeType.discordStyle:
        return _discordStyleTheme(brightness);
      case AppThemeType.cyberpunkStyle:
        return _cyberpunkStyleTheme(brightness);
      case AppThemeType.retroTerminal:
        return _retroTerminalTheme(brightness);
      case AppThemeType.pureLight:
        return _pureLightTheme(brightness);
    }
  }

  // ==================== Default Style ====================
  // 现代极简深色风格，灵感源自 Linear 官网
  static ThemeData _defaultStyleTheme(Brightness brightness) {
    const primaryColor = Color(0xFF5E6AD2);
    const secondaryColor = Color(0xFF8B5CF6);
    const backgroundColor = Color(0xFF08090a);
    const surfaceColor = Color(0xFF111111);
    const cardColor = Color(0xFF1A1A1A);

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
      fontFamily: GoogleFonts.inter().fontFamily,
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
          containerDecoration: BoxDecoration(
            color: surfaceColor.withOpacity(0.6),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
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
      extensions: [
        const AppThemeExtension(
          navBarStyle: AppNavBarStyle.material,
        ),
      ],
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
      fontFamily: GoogleFonts.notoSans().fontFamily, // 使用类似字体
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
          containerDecoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  // ==================== Cyberpunk Style ====================
  // 霓虹科幻风格，灵感源自赛博朋克 2077 / Blade Runner
  static ThemeData _cyberpunkStyleTheme(Brightness brightness) {
    const primaryColor = Color(0xFFFF2D95);  // 霓虹粉
    const secondaryColor = Color(0xFF00F0FF);  // 青色
    const backgroundColor = Color(0xFF0A0A0A);
    const surfaceColor = Color(0xFF1A1A1A);
    const cardColor = Color(0xFF1A1A1A);

    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: Color(0xFF99195A),
        secondary: secondaryColor,
        secondaryContainer: Color(0xFF007A82),
        tertiary: Color(0xFFFFE500),
        tertiaryContainer: Color(0xFF997A00),
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
      fontFamily: GoogleFonts.orbitron().fontFamily,
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
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Color(0xFFFFFFFF),
        onError: Colors.white,
      ),
      extensions: [
        const AppThemeExtension(
          navBarStyle: AppNavBarStyle.material,
          enableCrtEffect: true,
          enableGlowEffect: true,
          enableNeonGlow: true,
          glowColor: primaryColor,
          borderWidth: 2.0,
          borderColor: primaryColor,
          containerDecoration: BoxDecoration(
            color: cardColor,
          ),
        ),
      ],
    );
  }

  // ==================== Retro Terminal ====================
  // 80年代终端风格，灵感源自 Matrix / 老式终端
  static ThemeData _retroTerminalTheme(Brightness brightness) {
    const primaryColor = Color(0xFF00FF41);  // 磷光绿
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
      fontFamily: GoogleFonts.vt323().fontFamily,
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
      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.retroBottom,
          usePixelFont: true,
          enableDotMatrix: true,
          enableCrtEffect: true,
          glowColor: primaryColor,
          borderWidth: 1.0,
          borderColor: primaryColor.withOpacity(0.5),
          containerDecoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: primaryColor.withOpacity(0.5), width: 1),
          ),
        ),
      ],
    );
  }

  // ==================== Pure Light ====================
  // 极简浅色风格，灵感源自 Apple / Notion
  static ThemeData _pureLightTheme(Brightness brightness) {
    const primaryColor = Color(0xFF0066FF);
    const secondaryColor = Color(0xFF00C853);
    const backgroundColor = Color(0xFFFFFFFF);
    const surfaceColor = Color(0xFFF5F5F5);
    const cardColor = Color(0xFFFFFFFF);

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
