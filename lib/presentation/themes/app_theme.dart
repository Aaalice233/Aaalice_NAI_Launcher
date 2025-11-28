import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_extension.dart';

/// 风格类型枚举
enum AppStyle {
  herdingStyle,     // herdi.ng 风格 (金黄深青) - 默认
  defaultStyle,     // 默认风格 (深蓝色调)
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
      case AppStyle.herdingStyle:
        return 'Herding';
      case AppStyle.defaultStyle:
        return 'NAI 默认';
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
      case AppStyle.herdingStyle:
        return '金黄与深青的现代优雅风格';
      case AppStyle.defaultStyle:
        return '深蓝色调深色主题';
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

  /// 默认中文字体
  static String? get _defaultFont => GoogleFonts.notoSansSc().fontFamily;

  /// 获取指定风格的主题
  static ThemeData getTheme(AppStyle style, Brightness brightness, {String? fontFamily}) {
    final font = fontFamily ?? _defaultFont;

    ThemeData baseTheme;
    switch (style) {
      case AppStyle.herdingStyle:
        baseTheme = _herdingStyleTheme(brightness);
        break;
      case AppStyle.defaultStyle:
        baseTheme = _defaultStyleTheme(brightness);
        break;
      case AppStyle.linearStyle:
        baseTheme = _linearStyleTheme(brightness);
        break;
      case AppStyle.invokeStyle:
        baseTheme = _invokeStyleTheme(brightness);
        break;
      case AppStyle.discordStyle:
        baseTheme = _discordStyleTheme(brightness);
        break;
      case AppStyle.cassetteFuturism:
        baseTheme = _cassetteFuturismTheme(brightness);
        break;
      case AppStyle.motorolaFixBeeper:
        baseTheme = _motorolaFixBeeperTheme(brightness);
        break;
      case AppStyle.pureLight:
        baseTheme = _pureLightTheme(brightness);
        break;
    }

    // 应用自定义字体
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: font),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: font),
    );
  }

  // ==================== Herding Style ====================
  // herdi.ng 风格 - 金黄与深青的现代优雅风格
  static ThemeData _herdingStyleTheme(Brightness brightness) {
    // 核心配色 - 来自 herdi.ng
    const primaryColor = Color(0xFFD4A843);      // 金黄色主色
    const accentColor = Color(0xFF1095C1);       // 青蓝色
    const backgroundColor = Color(0xFF11191F);   // 主背景
    const surfaceColor = Color(0xFF141E26);      // 次级背景
    const cardColor = Color(0xFF18232C);         // 卡片背景
    const dividerColor = Color(0xFF1F2D38);      // 边框色

    // 文字色
    const textPrimary = Color(0xFFEDF1F4);
    const textSecondary = Color(0xFFA2AFB9);
    const textMuted = Color(0xFF738290);

    final colorScheme = const ColorScheme.dark(
      primary: primaryColor,
      onPrimary: Color(0xFF1A1A1A),              // 金黄按钮上的深色文字
      primaryContainer: Color(0xFF8B7A3A),
      onPrimaryContainer: Colors.white,
      secondary: accentColor,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF0D6E8A),
      onSecondaryContainer: Colors.white,
      tertiary: Color(0xFFE1E6EB),
      onTertiary: Color(0xFF1A1A1A),
      tertiaryContainer: Color(0xFF4A5056),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFC62828),
      onError: Colors.white,
      surface: surfaceColor,
      onSurface: textSecondary,
      surfaceContainerLowest: backgroundColor,
      surfaceContainerLow: backgroundColor,
      surfaceContainer: surfaceColor,
      surfaceContainerHigh: cardColor,
      surfaceContainerHighest: cardColor,
      outline: dividerColor,
      outlineVariant: Color(0xFF24333E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: _defaultFont,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: dividerColor,
      canvasColor: backgroundColor,

      // AppBar - 无边框，融入背景
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      // Card - 中等圆角，细边框
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // 输入框 - 圆角，填充背景
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // 按钮 - 金黄色主按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textSecondary,
          side: const BorderSide(color: dividerColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        iconColor: textMuted,
        textColor: textSecondary,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: textMuted,
      ),

      // Chip - 圆角胶囊
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        side: const BorderSide(color: dividerColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Popup Menu
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),

      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceColor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: dividerColor, width: 1),
            ),
          ),
        ),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: dividerColor, width: 1),
        ),
        textStyle: const TextStyle(color: textSecondary),
      ),

      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(dividerColor),
        radius: const Radius.circular(4),
      ),

      // Slider - 金黄色轨道
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: dividerColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
      ),

      // Switch - 金黄色开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return dividerColor;
        }),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return textMuted;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: textMuted, width: 1.5),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress Indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: dividerColor,
      ),

      // Tab Bar
      tabBarTheme: const TabBarTheme(
        labelColor: textPrimary,
        unselectedLabelColor: textMuted,
        indicatorColor: primaryColor,
      ),

      // Navigation Rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: const IconThemeData(color: primaryColor),
        unselectedIconTheme: const IconThemeData(color: textMuted),
        indicatorColor: primaryColor.withOpacity(0.15),
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: surfaceColor,
      ),

      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.defaultCompact,
          blurStrength: 0.0,
          borderWidth: 1.0,
          borderColor: dividerColor,
          shadowIntensity: 0.1,
          accentBarColor: primaryColor,  // 金黄分割条颜色
          containerDecoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dividerColor, width: 1),
          ),
        ),
      ],
    );
  }

  // ==================== Default Style ====================
  // 默认深蓝色调主题
  static ThemeData _defaultStyleTheme(Brightness brightness) {
    // NAI 官网真实配色 (2024)
    // 背景色系: #0E0F21 (主背景), #13152C (次), #191B31 (三级), #22253F (四级)
    // 文字: #FFFFFF (主), #F5F3C2 (奶油黄标题), #9CDCFF (用户输入), #F4C7FF (编辑)
    // 错误: #FF7878

    const primaryColor = Color(0xFF5E6AD2);     // 主色紫色
    const backgroundColor = Color(0xFF0E0F21); // 主背景 (深蓝黑)
    const surfaceColor = Color(0xFF13152C);    // 次背景/卡片
    const cardColor = Color(0xFF191B31);       // 三级背景
    const dividerColor = Color(0xFF22253F);    // 四级/分割线
    const accentYellow = Color(0xFFF5F3C2);    // 奶油黄强调色


    // 直接构建 ThemeData，避免 FlexColorScheme 颜色混合
    final colorScheme = const ColorScheme.dark(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3D4090),
      onPrimaryContainer: Colors.white,
      secondary: accentYellow,
      onSecondary: Color(0xFF1A1A1A),
      secondaryContainer: Color(0xFF5B5A4E),
      onSecondaryContainer: Colors.white,
      tertiary: Color(0xFF9CDCFF),
      onTertiary: Color(0xFF1A1A1A),
      tertiaryContainer: Color(0xFF4A6A7A),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFFF7878),
      onError: Colors.white,
      surface: surfaceColor,
      onSurface: Colors.white,
      surfaceContainerLowest: backgroundColor,
      surfaceContainerLow: backgroundColor,
      surfaceContainer: surfaceColor,
      surfaceContainerHigh: cardColor,
      surfaceContainerHighest: cardColor,
      outline: dividerColor,
      outlineVariant: Color(0xFF2A2D45),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: _defaultFont,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dialogBackgroundColor: surfaceColor,
      dividerColor: dividerColor,
      canvasColor: backgroundColor,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      // Card
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: dividerColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: primaryColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),

      // Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: dividerColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: Colors.white70,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        side: const BorderSide(color: dividerColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),

      // Popup Menu
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
      ),

      // Dropdown
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceColor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: dividerColor, width: 1),
            ),
          ),
        ),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: dividerColor, width: 1),
        ),
        textStyle: const TextStyle(color: Colors.white),
      ),

      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(dividerColor),
        radius: const Radius.circular(4),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: dividerColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.white70;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return dividerColor;
        }),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.white70;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(color: Colors.white70, width: 1.5),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: dividerColor,
      ),

      // Tab Bar
      tabBarTheme: const TabBarTheme(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        indicatorColor: primaryColor,
      ),

      // Navigation Rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: const IconThemeData(color: primaryColor),
        unselectedIconTheme: const IconThemeData(color: Colors.white70),
        indicatorColor: primaryColor.withOpacity(0.2),
      ),

      // Drawer
      drawerTheme: const DrawerThemeData(
        backgroundColor: surfaceColor,
      ),

      extensions: [
        AppThemeExtension(
          navBarStyle: AppNavBarStyle.defaultCompact,
          blurStrength: 0.0,
          borderWidth: 1.0,
          borderColor: dividerColor,
          shadowIntensity: 0.1,
          accentBarColor: accentYellow,  // 奶油黄强调色
          containerDecoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: dividerColor, width: 1),
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
      fontFamily: _defaultFont,
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
          accentBarColor: primaryColor,  // 紫蓝色强调
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
      fontFamily: _defaultFont,
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
          accentBarColor: primaryColor,  // 淡紫色强调
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
      fontFamily: _defaultFont,
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
          accentBarColor: blurple,  // Blurple 强调色
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
      fontFamily: _defaultFont,
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
          accentBarColor: primaryColor,  // 焦橙色强调
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
      fontFamily: _defaultFont,
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
          accentBarColor: primaryColor,  // 黑色强调（LCD风格）
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
      fontFamily: _defaultFont,
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
          accentBarColor: primaryColor,  // 蓝色强调
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
