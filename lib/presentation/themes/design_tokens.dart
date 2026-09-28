import 'package:flutter/material.dart';

/// 设计系统常量
///
/// 统一的设计 Token，用于保持整个应用的视觉一致性。
/// 使用静态常量，通过 `DesignTokens.xxx` 访问。
abstract class DesignTokens {
  DesignTokens._();

  // ============================================
  // 间距常量 (Spacing)
  // ============================================

  /// 超小间距 - 4px
  static const double spacingXxs = 4.0;

  /// 小间距 - 8px
  static const double spacingXs = 8.0;

  /// 中小间距 - 12px
  static const double spacingSm = 12.0;

  /// 中间距 - 16px
  static const double spacingMd = 16.0;

  /// 大间距 - 24px
  static const double spacingLg = 24.0;

  /// 超大间距 - 32px
  static const double spacingXl = 32.0;

  // ============================================
  // 毛玻璃参数 (Glassmorphism)
  // ============================================

  /// 毛玻璃模糊半径 - 12px
  static const double glassBlurRadius = 12.0;

  /// 毛玻璃背景不透明度 - 0.85
  static const double glassOpacity = 0.85;

  /// 毛玻璃边框不透明度 - 0.2
  static const double glassBorderOpacity = 0.2;

  // ============================================
  // 圆角常量 (Border Radius) - 深度层叠风格：小圆角
  // ============================================

  /// 小圆角 - 4px
  static const double radiusSm = 4.0;

  /// 中圆角 - 6px
  static const double radiusMd = 6.0;

  /// 大圆角 - 8px
  static const double radiusLg = 8.0;

  /// 超大圆角 - 12px
  static const double radiusXl = 12.0;

  // ============================================
  // 图标大小常量 (Icon Sizes)
  // ============================================

  /// 小图标 - 18px
  static const double iconSm = 18.0;

  /// 中图标 - 24px (默认)
  static const double iconMd = 24.0;

  /// 大图标 - 32px
  static const double iconLg = 32.0;

  // ============================================
  // Toast 参数
  // ============================================

  /// Toast 最大堆叠数量
  static const int toastMaxStack = 3;

  /// Toast 短时显示 - 3秒 (success/info)
  static const Duration toastDurationShort = Duration(seconds: 3);

  /// Toast 长时显示 - 5秒 (error/warning)
  static const Duration toastDurationLong = Duration(seconds: 5);

  // ============================================
  // 便捷方法
  // ============================================

  /// 获取圆角 BorderRadius
  static BorderRadius borderRadius(double radius) =>
      BorderRadius.circular(radius);

  /// 小圆角 BorderRadius
  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);

  /// 中圆角 BorderRadius
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);

  /// 大圆角 BorderRadius
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);

  /// 超大圆角 BorderRadius
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
}
