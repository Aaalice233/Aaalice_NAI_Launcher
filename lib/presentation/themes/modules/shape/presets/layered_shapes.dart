/// Layered Shapes - 深度层叠风格小圆角系统
///
/// 设计理念：
/// - 小圆角保持精致专业感，避免极简风格的大圆角
/// - 统一使用偶数值，视觉协调
/// - 圆角范围 4-8px，适合工具类软件
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shape/shape_module.dart';

/// 深度层叠风格的小圆角系统
///
/// 圆角参数：
/// - small: 4px - 小组件（按钮、标签、芯片）
/// - medium: 6px - 中等组件（输入框、小卡片）
/// - large: 8px - 大组件（主卡片、对话框）
/// - menu: 6px - 菜单和弹出层
class LayeredShapes extends BaseShapeModule {
  const LayeredShapes();

  @override
  double get smallRadius => 4.0;

  @override
  double get mediumRadius => 6.0;

  @override
  double get largeRadius => 8.0;

  @override
  double get menuRadius => 6.0;

  @override
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mediumRadius),
      );

  @override
  ShapeBorder get buttonShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );

  @override
  ShapeBorder get inputShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(smallRadius),
      );

  @override
  ShapeBorder get menuShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuRadius),
      );
}
