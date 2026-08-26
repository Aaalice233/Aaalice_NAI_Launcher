import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';

/// 统一语义色面容器。
///
/// 默认只用色面和圆角表达层级；调用方传入的装饰会覆盖对应属性。
class ThemedContainer extends StatelessWidget {
  const ThemedContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.decoration,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxDecoration? decoration;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(theme.appTheme.cardRadius),
    );
    final custom = decoration;
    final effectiveDecoration = custom == null
        ? base
        : BoxDecoration(
            color: custom.color ?? base.color,
            border: custom.border ?? base.border,
            borderRadius: custom.shape == BoxShape.circle
                ? null
                : custom.borderRadius ?? base.borderRadius,
            boxShadow: custom.boxShadow ?? base.boxShadow,
            gradient: custom.gradient ?? base.gradient,
            image: custom.image ?? base.image,
            backgroundBlendMode:
                custom.backgroundBlendMode ?? base.backgroundBlendMode,
            shape: custom.shape,
          );

    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: effectiveDecoration,
      child: child,
    );
  }
}
