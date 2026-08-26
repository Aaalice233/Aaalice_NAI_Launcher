import 'package:flutter/material.dart';

/// 输入与选择控件的语义色面容器。
///
/// 名称为兼容旧调用方保留；组件不再绘制凹槽内阴影或常驻完整边框。错误与
/// 焦点是唯一默认显示完整状态边界的场景。
class InsetShadowContainer extends StatelessWidget {
  const InsetShadowContainer({
    super.key,
    required this.child,
    this.borderRadius = 8,
    this.shadowDepth,
    this.shadowBlur,
    this.enabled,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.padding,
    this.hasError = false,
    this.isFocused = false,
  });

  final Widget child;
  final double borderRadius;

  /// 保留旧构造 API；统一色面不再渲染内阴影，因此这些参数不会改变外观。
  final double? shadowDepth;
  final double? shadowBlur;
  final bool? enabled;

  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final bool hasError;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveBorderWidth = hasError || isFocused ? 1.2 : borderWidth;
    final effectiveBorderColor = hasError
        ? colors.error
        : isFocused
        ? colors.primary
        : borderColor ?? colors.outlineVariant.withValues(alpha: 0.28);

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorderWidth > 0
            ? Border.all(
                color: effectiveBorderColor,
                width: effectiveBorderWidth,
              )
            : null,
      ),
      padding: padding,
      child: child,
    );
  }
}
