/// 将颜色、排版、形状和动效四类有效模块组合成完整主题。
///
/// 阴影、纹理、玻璃和主题专属分割线模块曾经只声明不消费，现已移除；
/// 浮层深度与结构分隔统一由语义组件主题控制。
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// Composes the effective theme modules into a complete [ThemeData].
class ThemeComposer {
  /// The color module providing ColorScheme.
  final ColorSchemeModule color;

  /// The typography module providing TextTheme and font families.
  final TypographyModule typography;

  /// The shape module providing border radius and ShapeBorder.
  final ShapeModule shape;

  /// The motion module providing animation parameters.
  final MotionModule motion;

  /// Creates a ThemeComposer with all effective modules.
  const ThemeComposer({
    required this.color,
    required this.typography,
    required this.shape,
    required this.motion,
  });

  /// Builds a complete [ThemeData] for the given brightness.
  ///
  /// If dark mode is requested but not supported by the color module,
  /// the light scheme will be used as a fallback, and brightness will
  /// match the fallback scheme to avoid assertion errors.
  ThemeData buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Get the appropriate color scheme and effective brightness
    ColorScheme colorScheme;
    Brightness effectiveBrightness;

    if (isDark && color.supportsDarkMode) {
      colorScheme = color.darkScheme;
      effectiveBrightness = Brightness.dark;
    } else if (isDark && !color.supportsDarkMode) {
      // Fallback: use light scheme - brightness MUST match the ColorScheme
      colorScheme = color.lightScheme;
      effectiveBrightness = colorScheme.brightness;
    } else {
      colorScheme = color.lightScheme;
      // Use the actual brightness from ColorScheme to avoid mismatch
      // (some dark-only themes return darkScheme for lightScheme)
      effectiveBrightness = colorScheme.brightness;
    }

    // Build text theme with proper colors applied
    final textTheme = _applyColorToTextTheme(
      typography.textTheme,
      colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: effectiveBrightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [buildExtension(effectiveBrightness)],

      // Icon theme - ensures icons have good visibility by default
      // Uses onSurface for proper contrast on surface backgrounds
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),

      // Apply divider module colors to Flutter's built-in divider
      dividerColor: colorScheme.onSurface.withValues(alpha: 0.08),
      dividerTheme: DividerThemeData(
        color: colorScheme.onSurface.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),

      // 普通卡片依靠语义色面区分层级，不叠加常驻描边和阴影。
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shape.largeRadius),
          side: BorderSide.none,
        ),
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // 深度层叠风格：按钮配置
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: shape.buttonShape as OutlinedBorder?,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape.buttonShape as OutlinedBorder?,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      // OutlinedButton 作为兼容入口保留，但视觉统一为次级 tonal action，
      // 避免页面上出现成排的白色空心框。
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape.buttonShape as OutlinedBorder?,
          side: BorderSide.none,
          foregroundColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surfaceContainerHighest,
          disabledBackgroundColor: colorScheme.onSurface.withValues(
            alpha: 0.04,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape.buttonShape as OutlinedBorder?,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      // 深度层叠风格：输入框使用纯色背景 + 无边框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        // 深度层叠：移除边框，使用纯背景色差
        border: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.72),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
          borderSide: BorderSide(
            color: colorScheme.error.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _extractBorderRadius(shape.inputShape),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        // 显式设置 hintStyle，确保在所有主题下都有足够的对比度
        hintStyle: TextStyle(color: colorScheme.outline, fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),

      // 深度层叠风格：下拉菜单使用阴影 + 小圆角
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(shape.menuRadius),
            ),
          ),
          backgroundColor: WidgetStatePropertyAll(
            colorScheme.surfaceContainerHigh,
          ),
          elevation: const WidgetStatePropertyAll(0), // 使用自定义阴影
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.15),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shape.menuRadius),
        ),
        color: colorScheme.surfaceContainerHigh,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(shape.menuRadius),
            ),
          ),
          backgroundColor: WidgetStatePropertyAll(
            colorScheme.surfaceContainerHigh,
          ),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.15),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(shape.smallRadius),
            ),
          ),
        ),
      ),

      // 深度层叠风格：对话框配置
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shape.mediumRadius),
        ),
        backgroundColor: colorScheme.surfaceContainerHigh,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
      ),

      // 深度层叠风格：底部弹窗配置
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(shape.mediumRadius),
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerHigh,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        surfaceTintColor: Colors.transparent,
      ),

      // 深度层叠风格：Chip 配置
      //
      // 背景既然改用 primary 系，前景必须同族取 onPrimaryContainer。
      // Material 3 给 ChoiceChip 的默认标签色是 onSecondaryContainer，
      // 跨族之后对比度失去保证——多数预设并未认真配 secondary 系，
      // onSecondaryContainer 常直接是纯白或纯黑，会变成浅底白字。
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shape.smallRadius),
        ),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        // 两项都必须从 textTheme 派生：Chip 对 labelStyle 是"有则取之"而非
        // 合并，传裸 TextStyle 会把默认的 labelLarge 整个顶掉，字体随之丢失。
        // 用户自定义字体由 AppTheme._applyFontConfig 再同步进来。
        //
        // labelStyle 不能省：ChoiceChip 选中时走 secondaryLabelStyle，但
        // FilterChip 选中时仍走 labelStyle，省掉会让它回退到 M3 默认的
        // onSecondaryContainer，与这里的背景不同族。
        labelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
        checkmarkColor: colorScheme.onPrimaryContainer,
      ),

      // 深度层叠风格：Tooltip 配置
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: effectiveBrightness == Brightness.dark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(shape.smallRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: TextStyle(
          color: effectiveBrightness == Brightness.dark
              ? colorScheme.onSurface
              : colorScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),

      // Apply motion to page transitions
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ModularPageTransitionBuilder(motion),
          TargetPlatform.iOS: _ModularPageTransitionBuilder(motion),
          TargetPlatform.windows: _ModularPageTransitionBuilder(motion),
          TargetPlatform.macOS: _ModularPageTransitionBuilder(motion),
          TargetPlatform.linux: _ModularPageTransitionBuilder(motion),
        },
      ),
    );
  }

  /// Builds an [AppThemeExtension] for the given brightness.
  ///
  /// The extension contains additional theme properties not covered
  /// by standard [ThemeData].
  AppThemeExtension buildExtension(Brightness brightness) {
    final colorScheme = brightness == Brightness.dark && color.supportsDarkMode
        ? color.darkScheme
        : color.lightScheme;
    return AppThemeExtension(
      borderColor: colorScheme.outlineVariant,
      dividerColor: colorScheme.onSurface.withValues(alpha: 0.08),
      dividerThickness: 1,
      useDivider: true,
      controlRadius: shape.smallRadius,
      cardRadius: shape.largeRadius,
      dialogRadius: shape.mediumRadius,
      menuRadius: shape.menuRadius,
      fastDuration: motion.fastDuration,
      normalDuration: motion.normalDuration,
      slowDuration: motion.slowDuration,
      standardCurve: motion.standardCurve,
      enterCurve: motion.enterCurve,
      exitCurve: motion.exitCurve,
    );
  }

  /// Applies the given color to all text styles in the theme.
  TextTheme _applyColorToTextTheme(TextTheme textTheme, Color color) {
    return textTheme.apply(bodyColor: color, displayColor: color);
  }

  /// Extracts BorderRadius from a ShapeBorder.
  BorderRadius _extractBorderRadius(ShapeBorder shapeBorder) {
    if (shapeBorder is RoundedRectangleBorder) {
      return shapeBorder.borderRadius as BorderRadius;
    }
    // Default fallback
    return BorderRadius.circular(shape.smallRadius);
  }
}

/// Custom page transition builder that uses motion module parameters.
class _ModularPageTransitionBuilder extends PageTransitionsBuilder {
  final MotionModule motion;

  const _ModularPageTransitionBuilder(this.motion);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: motion.enterCurve,
      reverseCurve: motion.exitCurve,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
