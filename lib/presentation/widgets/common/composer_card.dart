/// ComposerCard - Composer 组件专用高级卡片
///
/// 为核心交互组件（如提示词编辑器）设计的强化层叠卡片
/// 特点：Level 3 阴影 + 8px 圆角 + 12% 亮度提升 + 渐变边框强调
library;

import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/utils/layered_surfaces.dart';
import 'package:nai_launcher/presentation/widgets/common/elevated_card.dart';

/// Composer 组件专用高级卡片
///
/// 使用更强的视觉层叠效果，适用于核心交互组件：
/// - Level 3 高阶阴影，视觉上"浮"在页面上
/// - 8px 圆角，大组件使用更大圆角
/// - 12% 亮度提升，确保内容区域突出
/// - 可选主题色渐变边框强调
class ComposerCard extends StatelessWidget {
  const ComposerCard({
    super.key,
    required this.child,
    this.enableGradientBorder = false,
    this.padding,
    this.margin,
    this.onTap,
  });

  /// 子组件
  final Widget child;

  /// 是否启用主题色渐变边框强调
  final bool enableGradientBorder;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 渐变边框：主题色 + 白色混合的微光
    Gradient? gradientBorder;
    if (enableGradientBorder) {
      gradientBorder = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primary.withOpacity(0.25),
          colorScheme.primary.withOpacity(0.15),
          Colors.white.withOpacity(0.3),
        ],
      );
    }

    return ElevatedCard(
      elevation: CardElevation.level3,
      borderRadius: 8.0,
      enableSubtleBorder: !enableGradientBorder,
      backgroundColor: LayeredSurfaces.cardBackground(colorScheme, delta: 0.12),
      gradientBorder: gradientBorder,
      gradientBorderWidth: 1.5,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }
}

/// 轻量级 Composer 卡片
///
/// 适用于次要的 Composer 组件，使用 Level 2 阴影
class ComposerCardLight extends StatelessWidget {
  const ComposerCardLight({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ElevatedCard(
      elevation: CardElevation.level2,
      borderRadius: 6.0,
      enableSubtleBorder: true,
      backgroundColor: LayeredSurfaces.cardBackground(colorScheme, delta: 0.08),
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }
}
