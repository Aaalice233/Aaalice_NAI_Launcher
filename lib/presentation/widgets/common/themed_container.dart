import 'dart:ui';
import 'package:flutter/material.dart';
import '../../themes/theme_extension.dart';

class ThemedContainer extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxDecoration? decoration;
  final Clip clipBehavior;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();

    // 合并默认装饰和传入的装饰
    final defaultDecoration = extension?.containerDecoration ??
        BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
        );

    final effectiveDecoration = decoration != null
        ? defaultDecoration.copyWith(
            color: decoration!.color,
            border: decoration!.border,
            borderRadius: decoration!.borderRadius,
            boxShadow: decoration!.boxShadow,
            gradient: decoration!.gradient,
            image: decoration!.image,
          )
        : defaultDecoration;

    final double blur = extension?.blurStrength ?? 0.0;

    final Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: effectiveDecoration.copyWith(
        // 如果启用了模糊，背景色应该由内部 Container 处理或者半透明
        color: blur > 0
            ? effectiveDecoration.color?.withOpacity(0.5)
            : effectiveDecoration.color,
      ),
      child: child,
    );

    // 如果有模糊效果 (Linear Style)
    if (blur > 0) {
      return Container(
        margin: margin, // Margin 需要在外部
        child: ClipRRect(
          borderRadius: effectiveDecoration.borderRadius as BorderRadius? ??
              BorderRadius.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              width: width,
              height: height,
              padding: padding,
              decoration: effectiveDecoration.copyWith(
                color: effectiveDecoration.color?.withOpacity(0.3) ??
                    Colors.transparent,
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return content;
  }
}
