import 'package:flutter/material.dart';

import '../theme_extension.dart';

/// Herding 风格 - 金黄与深青的现代优雅风格
/// 灵感来源: herdi.ng
class HerdingStyle {
  HerdingStyle._();

  // 核心配色
  static const primaryColor = Color(0xFFD4A843); // 金黄色主色
  static const accentColor = Color(0xFF1095C1); // 青蓝色
  static const backgroundColor = Color(0xFF11191F); // 主背景
  static const surfaceColor = Color(0xFF141E26); // 次级背景
  static const cardColor = Color(0xFF18232C); // 卡片背景
  static const dividerColor = Color(0xFF1F2D38); // 边框色

  // 文字色
  static const textPrimary = Color(0xFFEDF1F4);
  static const textSecondary = Color(0xFFA2AFB9);
  static const textMuted = Color(0xFF738290);

  static ThemeData createTheme(Brightness brightness, String? fontFamily) {
    const colorScheme = ColorScheme.dark(
      primary: primaryColor,
      onPrimary: Color(0xFF1A1A1A),
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
      outline: textMuted,
      outlineVariant: Color(0xFF24333E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
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
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(
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
          accentBarColor: primaryColor,
          containerDecoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dividerColor, width: 1),
          ),
        ),
      ],
    );
  }
}
