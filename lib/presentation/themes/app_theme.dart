import 'package:flutter/material.dart';

// Import all 16 theme presets
import 'presets/bold_retro_theme.dart';
import 'presets/grunge_collage_theme.dart';
import 'presets/fluid_saturated_theme.dart';
import 'presets/material_you_theme.dart';
import 'presets/flat_design_theme.dart';
import 'presets/hand_drawn_theme.dart';
import 'presets/midnight_editorial_theme.dart';
import 'presets/zen_minimalist_theme.dart';
import 'presets/minimal_glass_theme.dart';
import 'presets/neo_dark_theme.dart';
import 'presets/pro_ai_theme.dart';
import 'presets/social_theme.dart';
import 'presets/retro_wave_theme.dart';
import 'presets/brutalist_theme.dart';
import 'presets/apple_light_theme.dart';
import 'presets/system_theme.dart';
import 'theme_extension.dart';

/// 风格类型枚举 - 16 套主题
enum AppStyle {
  // 8 套新设计主题
  boldRetro, // 复古现代主义
  grungeCollage, // 拼贴朋克
  fluidSaturated, // 流体饱和
  materialYou, // Material You
  flatDesign, // 扁平设计
  handDrawn, // 手绘风格
  midnightEditorial, // 午夜编辑
  zenMinimalist, // 禅意极简
  // 8 套重构主题 (原 styles/ 目录)
  minimalGlass, // 原 herdingStyle - 金黄深青
  neoDark, // 原 linearStyle - Linear 风格
  proAi, // 原 invokeStyle - InvokeAI 风格
  social, // 原 discordStyle - Discord 风格
  retroWave, // 原 cassetteFuturism - 复古未来
  brutalist, // 原 motorolaFixBeeper - LCD 电子
  appleLight, // 原 pureLight - 纯净白
  system, // 跟随系统
}

extension AppStyleExtension on AppStyle {
  String get displayName {
    switch (this) {
      case AppStyle.boldRetro:
        return BoldRetroTheme.displayName;
      case AppStyle.grungeCollage:
        return GrungeCollageTheme.displayName;
      case AppStyle.fluidSaturated:
        return FluidSaturatedTheme.displayName;
      case AppStyle.materialYou:
        return MaterialYouTheme.displayName;
      case AppStyle.flatDesign:
        return FlatDesignTheme.displayName;
      case AppStyle.handDrawn:
        return HandDrawnTheme.displayName;
      case AppStyle.midnightEditorial:
        return MidnightEditorialTheme.displayName;
      case AppStyle.zenMinimalist:
        return ZenMinimalistTheme.displayName;
      case AppStyle.minimalGlass:
        return MinimalGlassTheme.displayName;
      case AppStyle.neoDark:
        return NeoDarkTheme.displayName;
      case AppStyle.proAi:
        return ProAiTheme.displayName;
      case AppStyle.social:
        return SocialTheme.displayName;
      case AppStyle.retroWave:
        return RetroWaveTheme.displayName;
      case AppStyle.brutalist:
        return BrutalistTheme.displayName;
      case AppStyle.appleLight:
        return AppleLightTheme.displayName;
      case AppStyle.system:
        return SystemTheme.displayName;
    }
  }

  String get description {
    switch (this) {
      case AppStyle.boldRetro:
        return BoldRetroTheme.description;
      case AppStyle.grungeCollage:
        return GrungeCollageTheme.description;
      case AppStyle.fluidSaturated:
        return FluidSaturatedTheme.description;
      case AppStyle.materialYou:
        return MaterialYouTheme.description;
      case AppStyle.flatDesign:
        return FlatDesignTheme.description;
      case AppStyle.handDrawn:
        return HandDrawnTheme.description;
      case AppStyle.midnightEditorial:
        return MidnightEditorialTheme.description;
      case AppStyle.zenMinimalist:
        return ZenMinimalistTheme.description;
      case AppStyle.minimalGlass:
        return MinimalGlassTheme.description;
      case AppStyle.neoDark:
        return NeoDarkTheme.description;
      case AppStyle.proAi:
        return ProAiTheme.description;
      case AppStyle.social:
        return SocialTheme.description;
      case AppStyle.retroWave:
        return RetroWaveTheme.description;
      case AppStyle.brutalist:
        return BrutalistTheme.description;
      case AppStyle.appleLight:
        return AppleLightTheme.description;
      case AppStyle.system:
        return SystemTheme.description;
    }
  }

  /// 该主题是否支持深色模式
  bool get supportsDarkMode {
    switch (this) {
      case AppStyle.boldRetro:
        return BoldRetroTheme.supportsDarkMode;
      case AppStyle.grungeCollage:
        return GrungeCollageTheme.supportsDarkMode;
      case AppStyle.fluidSaturated:
        return FluidSaturatedTheme.supportsDarkMode;
      case AppStyle.materialYou:
        return MaterialYouTheme.supportsDarkMode;
      case AppStyle.flatDesign:
        return FlatDesignTheme.supportsDarkMode;
      case AppStyle.handDrawn:
        return HandDrawnTheme.supportsDarkMode;
      case AppStyle.midnightEditorial:
        return MidnightEditorialTheme.supportsDarkMode;
      case AppStyle.zenMinimalist:
        return ZenMinimalistTheme.supportsDarkMode;
      case AppStyle.minimalGlass:
        return MinimalGlassTheme.supportsDarkMode;
      case AppStyle.neoDark:
        return NeoDarkTheme.supportsDarkMode;
      case AppStyle.proAi:
        return ProAiTheme.supportsDarkMode;
      case AppStyle.social:
        return SocialTheme.supportsDarkMode;
      case AppStyle.retroWave:
        return RetroWaveTheme.supportsDarkMode;
      case AppStyle.brutalist:
        return BrutalistTheme.supportsDarkMode;
      case AppStyle.appleLight:
        return AppleLightTheme.supportsDarkMode;
      case AppStyle.system:
        return SystemTheme.supportsDarkMode;
    }
  }
}

/// 应用主题管理器
class AppTheme {
  AppTheme._();

  /// 获取指定风格的主题
  ///
  /// [fontFamily] 为空字符串或 null 时，保留主题原生字体；
  /// 有值时用用户选择覆盖主题字体。
  static ThemeData getTheme(AppStyle style, Brightness brightness,
      {String? fontFamily,}) {
    // 判断是否使用主题原生字体：fontFamily 为 null 或空字符串时保留主题字体
    final useThemeFont = fontFamily == null || fontFamily.isEmpty;

    // 获取基础主题
    final ThemeData baseTheme = switch (style) {
      AppStyle.boldRetro => brightness == Brightness.light
          ? BoldRetroTheme.light
          : BoldRetroTheme.dark,
      AppStyle.grungeCollage => brightness == Brightness.light
          ? GrungeCollageTheme.light
          : GrungeCollageTheme.dark,
      AppStyle.fluidSaturated => brightness == Brightness.light
          ? FluidSaturatedTheme.light
          : FluidSaturatedTheme.dark,
      AppStyle.materialYou => brightness == Brightness.light
          ? MaterialYouTheme.light
          : MaterialYouTheme.dark,
      AppStyle.flatDesign => brightness == Brightness.light
          ? FlatDesignTheme.light
          : FlatDesignTheme.dark,
      AppStyle.handDrawn => brightness == Brightness.light
          ? HandDrawnTheme.light
          : HandDrawnTheme.dark,
      AppStyle.midnightEditorial => brightness == Brightness.light
          ? MidnightEditorialTheme.light
          : MidnightEditorialTheme.dark,
      AppStyle.zenMinimalist => brightness == Brightness.light
          ? ZenMinimalistTheme.light
          : ZenMinimalistTheme.dark,
      AppStyle.minimalGlass => brightness == Brightness.light
          ? MinimalGlassTheme.light
          : MinimalGlassTheme.dark,
      AppStyle.neoDark =>
        brightness == Brightness.light ? NeoDarkTheme.light : NeoDarkTheme.dark,
      AppStyle.proAi =>
        brightness == Brightness.light ? ProAiTheme.light : ProAiTheme.dark,
      AppStyle.social =>
        brightness == Brightness.light ? SocialTheme.light : SocialTheme.dark,
      AppStyle.retroWave => brightness == Brightness.light
          ? RetroWaveTheme.light
          : RetroWaveTheme.dark,
      AppStyle.brutalist => brightness == Brightness.light
          ? BrutalistTheme.light
          : BrutalistTheme.dark,
      AppStyle.appleLight => brightness == Brightness.light
          ? AppleLightTheme.light
          : AppleLightTheme.dark,
      AppStyle.system =>
        brightness == Brightness.light ? SystemTheme.light : SystemTheme.dark,
    };

    // 如果使用主题原生字体，直接返回，只添加统一的 Tooltip 样式
    // 如果用户选择了字体，则覆盖 textTheme
    return baseTheme.copyWith(
      textTheme: useThemeFont
          ? baseTheme.textTheme
          : baseTheme.textTheme.apply(fontFamily: fontFamily),
      primaryTextTheme: useThemeFont
          ? baseTheme.primaryTextTheme
          : baseTheme.primaryTextTheme.apply(fontFamily: fontFamily),
      // 统一的紧凑 Tooltip 样式
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: baseTheme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: baseTheme.dividerColor,
            width: 1,
          ),
        ),
        textStyle: TextStyle(
          color: baseTheme.colorScheme.onSurface.withOpacity(0.8),
          fontSize: 12,
          fontFamily: useThemeFont ? null : fontFamily,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// 获取指定风格的主题扩展
  static AppThemeExtension getExtension(AppStyle style, Brightness brightness) {
    return switch (style) {
      AppStyle.boldRetro => brightness == Brightness.light
          ? BoldRetroTheme.lightExtension
          : BoldRetroTheme.darkExtension,
      AppStyle.grungeCollage => brightness == Brightness.light
          ? GrungeCollageTheme.lightExtension
          : GrungeCollageTheme.darkExtension,
      AppStyle.fluidSaturated => brightness == Brightness.light
          ? FluidSaturatedTheme.lightExtension
          : FluidSaturatedTheme.darkExtension,
      AppStyle.materialYou => brightness == Brightness.light
          ? MaterialYouTheme.lightExtension
          : MaterialYouTheme.darkExtension,
      AppStyle.flatDesign => brightness == Brightness.light
          ? FlatDesignTheme.lightExtension
          : FlatDesignTheme.darkExtension,
      AppStyle.handDrawn => brightness == Brightness.light
          ? HandDrawnTheme.lightExtension
          : HandDrawnTheme.darkExtension,
      AppStyle.midnightEditorial => brightness == Brightness.light
          ? MidnightEditorialTheme.lightExtension
          : MidnightEditorialTheme.darkExtension,
      AppStyle.zenMinimalist => brightness == Brightness.light
          ? ZenMinimalistTheme.lightExtension
          : ZenMinimalistTheme.darkExtension,
      AppStyle.minimalGlass => brightness == Brightness.light
          ? MinimalGlassTheme.lightExtension
          : MinimalGlassTheme.darkExtension,
      AppStyle.neoDark => brightness == Brightness.light
          ? NeoDarkTheme.lightExtension
          : NeoDarkTheme.darkExtension,
      AppStyle.proAi => brightness == Brightness.light
          ? ProAiTheme.lightExtension
          : ProAiTheme.darkExtension,
      AppStyle.social => brightness == Brightness.light
          ? SocialTheme.lightExtension
          : SocialTheme.darkExtension,
      AppStyle.retroWave => brightness == Brightness.light
          ? RetroWaveTheme.lightExtension
          : RetroWaveTheme.darkExtension,
      AppStyle.brutalist => brightness == Brightness.light
          ? BrutalistTheme.lightExtension
          : BrutalistTheme.darkExtension,
      AppStyle.appleLight => brightness == Brightness.light
          ? AppleLightTheme.lightExtension
          : AppleLightTheme.darkExtension,
      AppStyle.system => brightness == Brightness.light
          ? SystemTheme.lightExtension
          : SystemTheme.darkExtension,
    };
  }
}
