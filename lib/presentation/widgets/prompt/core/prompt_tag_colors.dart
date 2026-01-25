import 'dart:math' as math;
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

/// 分类渐变色配置
class CategoryGradient {
  CategoryGradient._();

  // ========== 渐变色定义 (WCAG AA 合规) ==========

  /// Category 0 (General) - 蓝色渐变
  static const LinearGradient general = LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Category 1 (Character) - 紫色渐变
  static const LinearGradient character = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Category 2 (Copyright) - 粉色渐变
  static const LinearGradient copyright = LinearGradient(
    colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Category 3 (Meta) - 青色渐变
  static const LinearGradient meta = LinearGradient(
    colors: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Category 4 (Artist) - 橙色渐变
  static const LinearGradient artist = LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ========== 渐变色缓存 ==========

  static final Map<int, LinearGradient> _gradientCache = {};

  /// 根据分类获取渐变色
  ///
  /// [category] 分类编号 (0-4)
  /// 返回对应的 LinearGradient，如果分类无效则返回通用渐变
  static LinearGradient getGradientByCategory(int category) {
    // 检查缓存
    if (_gradientCache.containsKey(category)) {
      return _gradientCache[category]!;
    }

    // 根据分类返回对应的渐变
    final gradient = switch (category) {
      1 => character,
      2 => copyright,
      3 => meta,
      4 => artist,
      _ => general, // 0 或其他默认值
    };

    // 缓存结果
    _gradientCache[category] = gradient;
    return gradient;
  }

  /// 清除渐变色缓存（用于主题切换时）
  static void clearCache() {
    _gradientCache.clear();
  }

  /// 获取渐变色的起始色（用于文本颜色计算）
  static Color getGradientStartColor(int category) {
    final gradient = getGradientByCategory(category);
    return gradient.colors.first;
  }

  /// 获取渐变色的结束色
  static Color getGradientEndColor(int category) {
    final gradient = getGradientByCategory(category);
    return gradient.colors.last;
  }

  /// 生成带透明度的渐变色（用于禁用或悬停状态）
  static LinearGradient getGradientWithOpacity(
    int category, {
    double opacity = 1.0,
  }) {
    final baseGradient = getGradientByCategory(category);
    return LinearGradient(
      colors: baseGradient.colors
          .map((color) => color.withOpacity(opacity))
          .toList(),
      begin: baseGradient.begin,
      end: baseGradient.end,
      stops: baseGradient.stops,
    );
  }

  /// 根据主题调整渐变色（用于暗色模式优化）
  static LinearGradient getThemedGradient(
    int category, {
    required bool isDark,
  }) {
    final baseGradient = getGradientByCategory(category);

    // 暗色模式下增加亮度，亮色模式下保持原样
    if (isDark) {
      return LinearGradient(
        colors: baseGradient.colors.map((color) {
          // 增加颜色亮度以适应暗色背景
          final hsl = HSLColor.fromColor(color);
          return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
        }).toList(),
        begin: baseGradient.begin,
        end: baseGradient.end,
        stops: baseGradient.stops,
      );
    }

    return baseGradient;
  }

  /// 计算渐变色的对比度颜色（返回黑色或白色文本以确保 WCAG AA 合规）
  static Color getContrastColor(int category) {
    final startColor = getGradientStartColor(category);
    // 计算亮度
    final luminance = (0.299 * startColor.red +
            0.587 * startColor.green +
            0.114 * startColor.blue) /
        255.0;
    // 返回黑色或白色以确保对比度 ≥ 4.5:1
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// 验证渐变色是否符合 WCAG AA 标准（对比度 ≥ 4.5:1）
  static bool meetsWCAGAA(int category, Color textColor) {
    final startColor = getGradientStartColor(category);
    final luminance1 = _calculateLuminance(startColor);
    final luminance2 = _calculateLuminance(textColor);
    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;
    final contrastRatio = (lighter + 0.05) / (darker + 0.05);
    return contrastRatio >= 4.5;
  }

  /// 计算相对亮度（用于 WCAG 对比度计算）
  static double _calculateLuminance(Color color) {
    final r = _channelToLuminance(color.red / 255.0);
    final g = _channelToLuminance(color.green / 255.0);
    final b = _channelToLuminance(color.blue / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 将颜色通道转换为亮度分量
  static double _channelToLuminance(double channel) {
    return channel <= 0.03928
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
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
