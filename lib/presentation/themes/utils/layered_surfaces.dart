/// Layered Surfaces - 背景色层次工具
///
/// 用于计算深度层叠风格的背景色层次
/// 使用 Material 3 的 surfaceContainerHighest（主题中明确定义的最亮容器色）
library;

import 'package:flutter/material.dart';

/// 背景色层次工具类
///
/// 基于主题中明确定义的 surfaceContainerHighest：
/// - Level 0: surface（页面背景）
/// - Level 1: surfaceContainerHighest（卡片背景 - 明确定义的最亮色）
/// - Level 2: surfaceContainerHighest + 提亮（悬停背景）
class LayeredSurfaces {
  LayeredSurfaces._();

  /// 计算比基准色更亮的颜色
  ///
  /// [color] 基准颜色
  /// [percent] 亮度提升百分比（0-100）
  static Color brighten(Color color, double percent) {
    final hsl = HSLColor.fromColor(color);
    final newLightness = (hsl.lightness + percent / 100).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }

  /// 计算比基准色更暗的颜色
  ///
  /// [color] 基准颜色
  /// [percent] 亮度降低百分比（0-100）
  static Color darken(Color color, double percent) {
    final hsl = HSLColor.fromColor(color);
    final newLightness = (hsl.lightness - percent / 100).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }

  /// Level 0: 页面背景
  static Color pageBackground(ColorScheme colorScheme) {
    return colorScheme.surface;
  }

  /// Level 1: 卡片背景（使用 surfaceContainerHighest - 主题中明确定义的最亮色）
  static Color cardBackground(ColorScheme colorScheme, {double delta = 0.10}) {
    return colorScheme.surfaceContainerHighest;
  }

  /// Level 2: 悬停卡片背景（在 surfaceContainerHighest 基础上再亮一点）
  static Color hoverCardBackground(ColorScheme colorScheme) {
    final base = colorScheme.surfaceContainerHighest;
    if (colorScheme.brightness == Brightness.dark) {
      return brighten(base, 8);
    } else {
      return darken(base, 3);
    }
  }

  /// Level 3: 激活/选中背景
  static Color activeBackground(ColorScheme colorScheme) {
    final base = hoverCardBackground(colorScheme);
    if (colorScheme.brightness == Brightness.dark) {
      return brighten(base, 5);
    } else {
      return darken(base, 2);
    }
  }

  /// 获取指定层级的背景色
  ///
  /// [level] 层级 0-3
  static Color getLevel(ColorScheme colorScheme, int level) {
    switch (level) {
      case 0:
        return pageBackground(colorScheme);
      case 1:
        return cardBackground(colorScheme);
      case 2:
        return hoverCardBackground(colorScheme);
      case 3:
        return activeBackground(colorScheme);
      default:
        return cardBackground(colorScheme);
    }
  }
}
