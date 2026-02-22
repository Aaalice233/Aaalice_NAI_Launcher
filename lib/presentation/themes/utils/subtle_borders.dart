/// Subtle Borders - 微光边框工具
///
/// 提供精致的微光边框样式，替代粗糙的透明线框
/// 1px 固定宽度，精致但不突兀
library;

import 'package:flutter/material.dart';

/// 微光边框工具类
///
/// 提供三种边框样式：
/// - light: 亮色主题微光边框（白色 60% 透明度）
/// - dark: 暗色主题微光边框（白色 15% 透明度）
/// - accent: 主题色微光边框（强调场景）
class SubtleBorders {
  SubtleBorders._();

  /// 根据主题亮度自动选择微光边框
  static BoxBorder auto(ColorScheme colorScheme) {
    if (colorScheme.brightness == Brightness.dark) {
      return darkBorder(colorScheme);
    }
    return lightBorder(colorScheme);
  }

  /// 亮色主题微光边框
  ///
  /// 白色微光，60% 透明度，营造高级感
  static BoxBorder lightBorder(ColorScheme colorScheme) {
    return Border.all(
      color: Colors.white.withOpacity(0.6),
      width: 1.0,
    );
  }

  /// 暗色主题微光边框
  ///
  /// 降低强度至 15%，避免过亮
  static BoxBorder darkBorder(ColorScheme colorScheme) {
    return Border.all(
      color: Colors.white.withOpacity(0.15),
      width: 1.0,
    );
  }

  /// 主题色微光边框（强调场景）
  static BoxBorder accentBorder(ColorScheme colorScheme) {
    return Border.all(
      color: colorScheme.primary.withOpacity(0.3),
      width: 1.0,
    );
  }

  /// 无边框
  static BoxBorder none() {
    return Border.all(
      color: Colors.transparent,
      width: 0,
    );
  }

  /// 获取 BorderSide（用于单边边框场景）
  static BorderSide autoSide(ColorScheme colorScheme) {
    if (colorScheme.brightness == Brightness.dark) {
      return BorderSide(
        color: Colors.white.withOpacity(0.15),
        width: 1.0,
      );
    }
    return BorderSide(
      color: Colors.white.withOpacity(0.6),
      width: 1.0,
    );
  }

  /// 顶部高光边框（用于卡片顶部光泽效果）
  static BoxBorder topHighlight(ColorScheme colorScheme) {
    final opacity = colorScheme.brightness == Brightness.dark ? 0.12 : 0.4;
    return Border(
      top: BorderSide(
        color: Colors.white.withOpacity(opacity),
        width: 1.0,
      ),
      left: BorderSide(
        color: Colors.white.withOpacity(opacity * 0.5),
        width: 1.0,
      ),
      right: BorderSide.none,
      bottom: BorderSide.none,
    );
  }
}
