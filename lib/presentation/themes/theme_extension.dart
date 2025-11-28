import 'package:flutter/material.dart';

/// 导航栏样式枚举
enum AppNavBarStyle {
  material, // 标准 Material 导航
  discordSide, // Discord 风格侧边栏
  retroBottom, // 复古底部导航
  defaultCompact, // 默认风格紧凑导航 (原 linearCompact)
}

/// 交互风格枚举
enum AppInteractionStyle {
  material, // 标准 Material 交互 (水波纹等)
  physical, // 物理按键 (位移反馈，无水波纹)
  digital, // 数字瞬变 (无过渡，反色/实心)
}

/// 应用主题扩展
/// 用于定义标准 ThemeData 之外的样式属性
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  /// 容器装饰 (用于卡片、面板背景)
  final BoxDecoration? containerDecoration;

  /// 模糊强度 (用于 Linear 风格)
  final double blurStrength;

  /// 是否使用像素字体 (用于 Motorola 风格)
  final bool usePixelFont;

  /// 导航栏样式
  final AppNavBarStyle navBarStyle;

  /// 交互风格
  final AppInteractionStyle interactionStyle;

  /// 主要按钮样式
  final ButtonStyle? primaryButtonStyle;

  /// 边框颜色 (用于高对比度风格)
  final Color? borderColor;

  /// 边框宽度
  final double borderWidth;

  /// 是否启用 CRT 扫描线效果
  final bool enableCrtEffect;

  /// 是否启用辉光效果
  final bool enableGlowEffect;

  /// 是否启用点阵背景效果 (用于复古终端风格)
  final bool enableDotMatrix;

  /// 是否启用霓虹发光效果 (用于赛博朋克风格)
  final bool enableNeonGlow;

  /// 发光颜色 (用于霓虹效果)
  final Color? glowColor;

  /// 阴影强度 (0.0-1.0)
  final double shadowIntensity;

  /// 是否为浅色主题
  final bool isLightTheme;

  /// 强调分割条颜色 (herdi.ng 风格金黄色横条)
  final Color? accentBarColor;

  const AppThemeExtension({
    this.containerDecoration,
    this.blurStrength = 0.0,
    this.usePixelFont = false,
    this.navBarStyle = AppNavBarStyle.material,
    this.interactionStyle = AppInteractionStyle.material,
    this.primaryButtonStyle,
    this.borderColor,
    this.borderWidth = 0.0,
    this.enableCrtEffect = false,
    this.enableGlowEffect = false,
    this.enableDotMatrix = false,
    this.enableNeonGlow = false,
    this.glowColor,
    this.shadowIntensity = 0.0,
    this.isLightTheme = false,
    this.accentBarColor,
  });

  @override
  AppThemeExtension copyWith({
    BoxDecoration? containerDecoration,
    double? blurStrength,
    bool? usePixelFont,
    AppNavBarStyle? navBarStyle,
    AppInteractionStyle? interactionStyle,
    ButtonStyle? primaryButtonStyle,
    Color? borderColor,
    double? borderWidth,
    bool? enableCrtEffect,
    bool? enableGlowEffect,
    bool? enableDotMatrix,
    bool? enableNeonGlow,
    Color? glowColor,
    double? shadowIntensity,
    bool? isLightTheme,
    Color? accentBarColor,
  }) {
    return AppThemeExtension(
      containerDecoration: containerDecoration ?? this.containerDecoration,
      blurStrength: blurStrength ?? this.blurStrength,
      usePixelFont: usePixelFont ?? this.usePixelFont,
      navBarStyle: navBarStyle ?? this.navBarStyle,
      interactionStyle: interactionStyle ?? this.interactionStyle,
      primaryButtonStyle: primaryButtonStyle ?? this.primaryButtonStyle,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      enableCrtEffect: enableCrtEffect ?? this.enableCrtEffect,
      enableGlowEffect: enableGlowEffect ?? this.enableGlowEffect,
      enableDotMatrix: enableDotMatrix ?? this.enableDotMatrix,
      enableNeonGlow: enableNeonGlow ?? this.enableNeonGlow,
      glowColor: glowColor ?? this.glowColor,
      shadowIntensity: shadowIntensity ?? this.shadowIntensity,
      isLightTheme: isLightTheme ?? this.isLightTheme,
      accentBarColor: accentBarColor ?? this.accentBarColor,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }

    return AppThemeExtension(
      containerDecoration: BoxDecoration.lerp(
        containerDecoration,
        other.containerDecoration,
        t,
      ),
      blurStrength:
          uiLerpDouble(blurStrength, other.blurStrength, t) ?? blurStrength,
      usePixelFont: t < 0.5 ? usePixelFont : other.usePixelFont,
      navBarStyle: t < 0.5 ? navBarStyle : other.navBarStyle,
      interactionStyle: t < 0.5 ? interactionStyle : other.interactionStyle,
      primaryButtonStyle:
          ButtonStyle.lerp(primaryButtonStyle, other.primaryButtonStyle, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      borderWidth:
          uiLerpDouble(borderWidth, other.borderWidth, t) ?? borderWidth,
      enableCrtEffect: t < 0.5 ? enableCrtEffect : other.enableCrtEffect,
      enableGlowEffect: t < 0.5 ? enableGlowEffect : other.enableGlowEffect,
      enableDotMatrix: t < 0.5 ? enableDotMatrix : other.enableDotMatrix,
      enableNeonGlow: t < 0.5 ? enableNeonGlow : other.enableNeonGlow,
      glowColor: Color.lerp(glowColor, other.glowColor, t),
      shadowIntensity:
          uiLerpDouble(shadowIntensity, other.shadowIntensity, t) ?? shadowIntensity,
      isLightTheme: t < 0.5 ? isLightTheme : other.isLightTheme,
      accentBarColor: Color.lerp(accentBarColor, other.accentBarColor, t),
    );
  }

  /// 辅助方法：处理 double 插值
  double? uiLerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}
