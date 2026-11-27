import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../themes/app_theme.dart';

part 'theme_provider.g.dart';

/// 主题配置状态（模式 + 浅色/深色各自风格）
@immutable
class ThemeSettings {
  final ThemeMode themeMode;
  final AppStyle lightStyle;
  final AppStyle darkStyle;

  const ThemeSettings({
    this.themeMode = ThemeMode.dark,
    this.lightStyle = AppStyle.grungeCollage,
    this.darkStyle = AppStyle.grungeCollage,
  });

  Brightness effectiveBrightness(Brightness platformBrightness) =>
      switch (themeMode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => platformBrightness,
      };

  AppStyle styleFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkStyle : lightStyle;

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    AppStyle? lightStyle,
    AppStyle? darkStyle,
  }) => ThemeSettings(
    themeMode: themeMode ?? this.themeMode,
    lightStyle: lightStyle ?? this.lightStyle,
    darkStyle: darkStyle ?? this.darkStyle,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSettings &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          lightStyle == other.lightStyle &&
          darkStyle == other.darkStyle;

  @override
  int get hashCode => Object.hash(themeMode, lightStyle, darkStyle);

  @override
  String toString() =>
      'ThemeSettings(themeMode: $themeMode, lightStyle: $lightStyle, darkStyle: $darkStyle)';
}

/// 主题状态 Notifier
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  ThemeSettings build() {
    final storage = ref.read(localStorageServiceProvider);
    final legacyStyle =
        _parseStyle(storage.getThemeIndex()) ?? AppStyle.grungeCollage;
    final themeMode =
        _parseThemeMode(storage.getThemeMode()) ??
        (legacyStyle.supportsDarkMode ? ThemeMode.dark : ThemeMode.light);

    final storedLight = _parseStyle(storage.getLightThemeIndex());
    final lightStyle = (storedLight != null && storedLight.supportsLightMode)
        ? storedLight
        : (legacyStyle.supportsLightMode
              ? legacyStyle
              : AppStyle.grungeCollage);

    final storedDark = _parseStyle(storage.getDarkThemeIndex());
    final darkStyle = (storedDark != null && storedDark.supportsDarkMode)
        ? storedDark
        : (legacyStyle.supportsDarkMode ? legacyStyle : AppStyle.grungeCollage);

    return ThemeSettings(
      themeMode: themeMode,
      lightStyle: lightStyle,
      darkStyle: darkStyle,
    );
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    final next = state.copyWith(themeMode: mode);
    state = next;

    final storage = ref.read(localStorageServiceProvider);
    await storage.setThemeMode(_encodeThemeMode(mode));
    await storage.setThemeIndex(
      (mode == ThemeMode.light ? next.lightStyle : next.darkStyle).index,
    );
  }

  /// 设置浅色主题风格
  Future<void> setLightStyle(AppStyle style) async {
    if (!style.supportsLightMode) return;
    final next = state.copyWith(lightStyle: style);
    state = next;

    final storage = ref.read(localStorageServiceProvider);
    await storage.setLightThemeIndex(style.index);
    if (next.themeMode == ThemeMode.light) {
      await storage.setThemeIndex(style.index);
    }
  }

  /// 设置深色主题风格
  Future<void> setDarkStyle(AppStyle style) async {
    if (!style.supportsDarkMode) return;
    final next = state.copyWith(darkStyle: style);
    state = next;

    final storage = ref.read(localStorageServiceProvider);
    await storage.setDarkThemeIndex(style.index);
    if (next.themeMode != ThemeMode.light) {
      await storage.setThemeIndex(style.index);
    }
  }

  /// 在当前有效亮度下在深色与浅色模式间切换
  Future<void> toggleBrightness(Brightness platformBrightness) async {
    final isDark =
        state.effectiveBrightness(platformBrightness) == Brightness.dark;
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// 切换到当前亮度下的下一个主题风格
  Future<void> nextStyle(Brightness platformBrightness) async {
    final effective = state.effectiveBrightness(platformBrightness);
    final styles = AppTheme.stylesForBrightness(effective);
    final current = state.styleFor(effective);
    final currentIndex = styles.indexOf(current);
    final next = styles[(currentIndex + 1) % styles.length];
    if (effective == Brightness.dark) {
      await setDarkStyle(next);
    } else {
      await setLightStyle(next);
    }
  }

  static AppStyle? _parseStyle(int? index) {
    if (index == null || index < 0 || index >= AppStyle.values.length) {
      return null;
    }
    return AppStyle.values[index];
  }

  static ThemeMode? _parseThemeMode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => null,
  };

  static String _encodeThemeMode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}
