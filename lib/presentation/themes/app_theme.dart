import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'styles/styles.dart';

/// 风格类型枚举
enum AppStyle {
  herdingStyle,     // herdi.ng 风格 (金黄深青) - 默认
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

    final ThemeData baseTheme = switch (style) {
      AppStyle.herdingStyle => HerdingStyle.createTheme(brightness, font),
      AppStyle.linearStyle => LinearStyle.createTheme(brightness, font),
      AppStyle.invokeStyle => InvokeStyle.createTheme(brightness, font),
      AppStyle.discordStyle => DiscordStyle.createTheme(brightness, font),
      AppStyle.cassetteFuturism => CassetteFuturismStyle.createTheme(brightness, font),
      AppStyle.motorolaFixBeeper => MotorolaBeeperStyle.createTheme(brightness, font),
      AppStyle.pureLight => PureLightStyle.createTheme(brightness, font),
    };

    // 应用自定义字体
    return baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: font),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: font),
    );
  }
}
