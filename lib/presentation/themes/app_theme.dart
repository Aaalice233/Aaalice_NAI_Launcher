import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_extension.dart';

/// 风格类型枚举
enum AppStyle {
  naiStyle,         // NAI 风格 (NovelAI 官网风格) - 默认
  linearStyle,      // Linear 风格 (现代极简深色)
  invokeStyle,      // Invoke 风格 (专业 AI 工具)
  discordStyle,     // Discord 风格 (社交应用)
  cassetteFuturism, // 未来磁带主义 (复古未来)
  motorolaFixBeeper,// 摩托罗拉传呼机 (LCD 电子)
  pureLight,        // 纯净白风格 (极简浅色)
}

extension AppStyleExtension on AppStyle {
  String get displayName {
    switch (this) {
      case AppStyle.naiStyle:
        return 'NAI';
      case AppStyle.linearStyle:
        return 'Linear';
      case AppStyle.invokeStyle:
        return 'Invoke';
      case AppStyle.discordStyle:
        return 'Discord';
      case AppStyle.cassetteFuturism:
        return '未来磁带主义';
      case AppStyle.motorolaFixBeeper:
        return 'Motorola Fix Beeper';
      case AppStyle.pureLight:
        return '纯净白';
    }
  }

  String get description {
    switch (this) {
      case AppStyle.naiStyle:
        return 'NovelAI 官网经典深色风格';
      case AppStyle.linearStyle:
        return '现代极简深色，灵感源自 Linear';
      case AppStyle.invokeStyle:
        return '专业 AI 工具风格';
      case AppStyle.discordStyle:
        return '熟悉的社交应用风格';
      case AppStyle.cassetteFuturism:
        return '温暖、模拟数字混合的复古未来风格';
      case AppStyle.motorolaFixBeeper:
        return '复古传呼机/LCD 电子风格';
      case AppStyle.pureLight:
        return '清爽极简浅色主题';
    }
  }
}

/// 应用主题管理器
class AppTheme {
  AppTheme._();

  /// 获取指定风格的主题
  static ThemeData getTheme(AppStyle style, Brightness brightness) {
    switch (style) {
      case AppStyle.naiStyle:
        return _naiStyleTheme(brightness);
      case AppStyle.linearStyle:
        return _linearStyleTheme(brightness);
      case AppStyle.invokeStyle:
        return _invokeStyleTheme(brightness);
      case AppStyle.discordStyle:
        return _discordStyleTheme(brightness);
      case AppStyle.cassetteFuturism:
        return _cassetteFuturismTheme(brightness);
      case AppStyle.motorolaFixBeeper:
        return _motorolaFixBeeperTheme(brightness);
      case AppStyle.pureLight:
        return _pureLightTheme(brightness);
    }
  }

  // ==================== NAI Style ====================
  // NovelAI 官网风格
  static ThemeData _naiStyleTheme(Brightness brightness) {
    // NAI 官网配色 (参考)
    // 背景色: #15151d (主背景)
    // 侧边栏/卡片: #1c1c26
    // 强调色: #F2F2F2 (主要文本), #3F4177 (主品牌色/按钮)
    // 激活/高亮: #5E6AD2 (或者接近的紫色)
    
    const primaryColor = Color(0xFF5E6AD2); // 保持原有的紫色作为主色调，或者调整为 NAI 更准确的颜色
    const backgroundColor = Color(0xFF15151d); // NAI 官网深色背景
    const surfaceColor = Color(0xFF1c1c26);    // 卡片/侧边栏颜色
    const cardColor = Color(0xFF1c1c26);
    const accentColor = Color(0xFF3F4177);     // NAI 品牌深紫色

    return FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: primaryColor,
        primaryContainer: accentColor,
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
        inputDecoratorRadius: 4.0,
        inputDecoratorBorderWidth: 1.0,
        cardRadius: 8.0,
        cardElevation: 0.0,
        elevatedButtonRadius: 4.0,
        outlinedButtonRadius: 4.0,
        textButtonRadius: 4.0,
        dialogRadius: 8.0,
        bottomSheetRadius: 12.0,
        chipRadius: 4.0,
      ),
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: const Color(0xFF2A2A35), // 稍浅的分割线
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFEDEDEF),
        onError: Colors.white,
      ),
      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.defaultCompact, // 将适配为新的侧边栏
          blurStrength: 0.0, // NAI 风格较少使用毛玻璃，更多是实色
          borderWidth: 1.0,
          borderColor: const Color(0xFF2A2A35),
          shadowIntensity: 0.2,
          containerDecoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A35), width: 1),
          ),
        ),
      ],
    );
  }

  // ==================== Linear Style ====================
  // 现代极简深色风格，灵感源自 Linear 官网
  static ThemeData _linearStyleTheme(Brightness brightness) {
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

  // ==================== Cassette Futurism Style ====================
  // 温暖、模拟数字混合的 "未来磁带主义" 风格 (原赛博朋克重构)
  static ThemeData _cassetteFuturismTheme(Brightness brightness) {
    // 配色: 暖深灰、焦橙色、芥末黄、复古青色
    const primaryColor = Color(0xFFFF7043); // 焦橙色
    const secondaryColor = Color(0xFF26A69A); // 复古青
    const backgroundColor = Color(0xFF2C2C2C); // 暖深灰
    const surfaceColor = Color(0xFF373737); // 稍亮的灰
    const cardColor = Color(0xFF424242); 
    const tertiaryColor = Color(0xFFFFD54F); // 芥末黄

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
      blendLevel: 0, // 无混合，强调纯色
      appBarStyle: FlexAppBarStyle.background,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 0,
        inputDecoratorRadius: 16.0, // 胶囊状或大圆角
        inputDecoratorBorderWidth: 2.0, // 粗边框
        cardRadius: 16.0,
        elevatedButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        textButtonRadius: 12.0,
        dialogRadius: 20.0,
        bottomSheetRadius: 24.0,
        chipRadius: 8.0,
      ),
      useMaterial3: true,
      fontFamily: GoogleFonts.exo2().fontFamily, // 几何感强
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
          navBarStyle: AppNavBarStyle.material, // 后续可定制
          interactionStyle: AppInteractionStyle.physical, // 启用物理按键交互
          enableCrtEffect: false,
          enableGlowEffect: false,
          enableNeonGlow: false,
          borderWidth: 2.0,
          borderColor: Color(0xFF505050),
          containerDecoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFF505050), width: 2)),
          ),
        ),
      ],
    );
  }

  // ==================== Motorola Fix Beeper Style ====================
  // 复古传呼机/LCD 电子风格 (原复古终端重构)
  static ThemeData _motorolaFixBeeperTheme(Brightness brightness) {
    // 配色: 深青/灰绿背景 (LCD 屏感)，黑色文字 (高对比度)
    // LCD 背景: #78909C (Blue Grey 400) 或更偏绿 #8FA38F
    // 文字: Black
    
    const primaryColor = Color(0xFF212121); // 近乎黑色的文字色作为主色
    const secondaryColor = Color(0xFF455A64); // 深灰蓝
    const backgroundColor = Color(0xFF8FA38F); // 典型 LCD 背景色
    const surfaceColor = Color(0xFF809680);    // 稍深一点
    const cardColor = Color(0xFF809680);

    return FlexThemeData.light( // 使用 Light 模式基础，因为背景较亮
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
        inputDecoratorRadius: 2.0, // 锐利的小圆角
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
      fontFamily: GoogleFonts.vt323().fontFamily, // 保持像素字体，但后面会调整
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
        onSurface: primaryColor, // 黑色文字
        onError: Colors.white,
        background: backgroundColor,
        onBackground: primaryColor,
      ),
      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.retroBottom,
          interactionStyle: AppInteractionStyle.digital, // 启用数字电子交互
          usePixelFont: true,
          enableDotMatrix: true, // 保留点阵，增强 LCD 感
          enableCrtEffect: false, // 移除 CRT
          borderWidth: 2.0,
          borderColor: primaryColor,
          containerDecoration: BoxDecoration(
            color: cardColor,
            border: Border.all(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(4),
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
