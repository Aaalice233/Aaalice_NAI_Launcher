import 'package:flutter/material.dart';

/// 统一的标签颜色系统
/// 整合分类颜色和特殊标签类型颜色
class PromptTagColors {
  PromptTagColors._();

  // ========== 分类颜色 ==========

  /// 艺术家 - 珊瑚粉
  static const Color artist = Color(0xFFFF6B6B);

  /// 角色 - 翠绿
  static const Color character = Color(0xFF4ECDC4);

  /// 版权 - 紫罗兰
  static const Color copyright = Color(0xFFA855F7);

  /// 通用 - 天蓝
  static const Color general = Color(0xFF60A5FA);

  /// 元数据 - 琥珀
  static const Color meta = Color(0xFFFBBF24);

  // ========== 特殊标签类型颜色 ==========

  /// LORA - 橙色
  static const Color lora = Color(0xFFFF9500);

  /// Embedding - 紫色
  static const Color embedding = Color(0xFF9C27B0);

  /// Wildcard - 绿色
  static const Color wildcard = Color(0xFF4CAF50);

  // ========== 权重指示颜色 ==========

  /// 增强权重 - 橙色
  static const Color weightIncrease = Color(0xFFFF9500);

  /// 减弱权重 - 蓝色
  static const Color weightDecrease = Color(0xFF007AFF);

  /// 根据分类获取颜色
  static Color getByCategory(int category) {
    return switch (category) {
      1 => artist,
      3 => copyright,
      4 => character,
      5 => meta,
      _ => general,
    };
  }

  /// 根据标签文本检测特殊类型并返回颜色
  static Color? getSpecialTypeColor(String text) {
    final lowerText = text.toLowerCase();

    // LORA 检测
    if (lowerText.startsWith('<lora:') || lowerText.contains('lora:')) {
      return lora;
    }

    // Embedding 检测
    if (lowerText.startsWith('<embed:') ||
        lowerText.startsWith('embedding:') ||
        lowerText.contains('ti:')) {
      return embedding;
    }

    // Wildcard 检测
    if (lowerText.contains('__') && lowerText.contains('__')) {
      return wildcard;
    }

    return null;
  }

  /// 获取权重颜色
  static Color getWeightColor(double weight) {
    if (weight > 1.0) return weightIncrease;
    if (weight < 1.0) return weightDecrease;
    return Colors.transparent;
  }

  /// 生成背景色（基于主色的低透明度版本）
  static Color getBackgroundColor(
    Color baseColor, {
    bool isSelected = false,
    bool isEnabled = true,
    required ThemeData theme,
  }) {
    if (!isEnabled) {
      return theme.colorScheme.surfaceContainerHighest.withOpacity(0.2);
    }
    return baseColor.withOpacity(isSelected ? 0.25 : 0.12);
  }

  /// 生成边框色
  static Color getBorderColor(
    Color baseColor, {
    bool isSelected = false,
    bool isHovered = false,
    bool isEnabled = true,
    required ThemeData theme,
  }) {
    if (!isEnabled) {
      return theme.colorScheme.outline.withOpacity(0.15);
    }
    if (isSelected) return baseColor.withOpacity(0.7);
    if (isHovered) return baseColor.withOpacity(0.5);
    return baseColor.withOpacity(0.25);
  }
}

/// 权重颜色渐变配置
class WeightColorGradient {
  WeightColorGradient._();

  /// 获取增强权重的渐变色（根据权重强度）
  static List<Color> getIncreaseGradient(int bracketLayers) {
    final intensity = (bracketLayers / 10).clamp(0.0, 1.0);
    return [
      PromptTagColors.weightIncrease.withOpacity(0.1 + intensity * 0.2),
      PromptTagColors.weightIncrease.withOpacity(0.05 + intensity * 0.1),
    ];
  }

  /// 获取减弱权重的渐变色（根据权重强度）
  static List<Color> getDecreaseGradient(int bracketLayers) {
    final intensity = (bracketLayers.abs() / 10).clamp(0.0, 1.0);
    return [
      PromptTagColors.weightDecrease.withOpacity(0.1 + intensity * 0.2),
      PromptTagColors.weightDecrease.withOpacity(0.05 + intensity * 0.1),
    ];
  }
}
