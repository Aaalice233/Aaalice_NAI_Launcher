/// Layered Shadow - 深度层叠风格多层阴影系统
///
/// 设计理念：
/// - 每层阴影递进式增强：近→中→远距离的三维空间感
/// - spreadRadius 为负值收缩阴影，避免过于扩散
/// - offset.dy 逐级增大，模拟光源从上方照射的自然效果
/// - 透明度梯度控制，层次分明但不刺眼
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/modules/shadow/shadow_module.dart';

/// 深度层叠风格的多层阴影系统
///
/// 四级阴影层级：
/// - Level 1: 轻微层叠（静态卡片、列表项）
/// - Level 2: 标准层叠（默认卡片、面板）
/// - Level 3: 明显层叠（悬停卡片、激活状态）
/// - Level 4: 极致层叠（模态对话框、最高层级浮层）
class LayeredShadow extends BaseShadowModule {
  const LayeredShadow();

  /// Level 1: 轻微层叠（静态卡片、列表项）
  /// 2层阴影，blur 2-4px，最大 offset 2px
  @override
  List<BoxShadow> get elevation1 => const [
        BoxShadow(
          color: Color(0x0A000000), // 4% opacity - 近距离软阴影
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0F000000), // 6% opacity - 中距离定义边界
          blurRadius: 4,
          spreadRadius: -0.5,
          offset: Offset(0, 2),
        ),
      ];

  /// Level 2: 标准层叠（默认卡片、面板）
  /// 3层阴影，blur 3-12px，最大 offset 6px
  @override
  List<BoxShadow> get elevation2 => const [
        BoxShadow(
          color: Color(0x0A000000), // 4% opacity
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x14000000), // 8% opacity
          blurRadius: 6,
          spreadRadius: -1,
          offset: Offset(0, 3),
        ),
        BoxShadow(
          color: Color(0x1F000000), // 12% opacity - 远距离氛围阴影
          blurRadius: 12,
          spreadRadius: -2,
          offset: Offset(0, 6),
        ),
      ];

  /// Level 3: 明显层叠（悬停卡片、激活状态）
  /// 4层阴影，blur 4-24px，最大 offset 12px
  @override
  List<BoxShadow> get elevation3 => const [
        BoxShadow(
          color: Color(0x0A000000), // 4% opacity
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x14000000), // 8% opacity
          blurRadius: 8,
          spreadRadius: -1,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x1F000000), // 12% opacity
          blurRadius: 16,
          spreadRadius: -2,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x29000000), // 16% opacity - 强氛围阴影
          blurRadius: 24,
          spreadRadius: -3,
          offset: Offset(0, 12),
        ),
      ];

  /// 默认卡片使用 Level 2
  @override
  List<BoxShadow> get cardShadow => elevation2;
}

/// 深度层叠阴影 - 暗色模式变体
///
/// 暗色背景下阴影需更强才能显现，透明度整体提升约 50%
class LayeredShadowDark extends BaseShadowModule {
  const LayeredShadowDark();

  @override
  List<BoxShadow> get elevation1 => const [
        BoxShadow(
          color: Color(0x14000000), // 8% opacity
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x1A000000), // 10% opacity
          blurRadius: 4,
          spreadRadius: -0.5,
          offset: Offset(0, 2),
        ),
      ];

  @override
  List<BoxShadow> get elevation2 => const [
        BoxShadow(
          color: Color(0x14000000), // 8% opacity
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x29000000), // 16% opacity
          blurRadius: 6,
          spreadRadius: -1,
          offset: Offset(0, 3),
        ),
        BoxShadow(
          color: Color(0x3D000000), // 24% opacity
          blurRadius: 12,
          spreadRadius: -2,
          offset: Offset(0, 6),
        ),
      ];

  @override
  List<BoxShadow> get elevation3 => const [
        BoxShadow(
          color: Color(0x14000000), // 8% opacity
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x29000000), // 16% opacity
          blurRadius: 8,
          spreadRadius: -1,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x3D000000), // 24% opacity
          blurRadius: 16,
          spreadRadius: -2,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x52000000), // 32% opacity
          blurRadius: 24,
          spreadRadius: -3,
          offset: Offset(0, 12),
        ),
      ];

  @override
  List<BoxShadow> get cardShadow => elevation2;
}
