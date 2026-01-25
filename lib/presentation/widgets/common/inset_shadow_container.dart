import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

/// 内阴影容器 - 创造凹陷立体感效果
///
/// 通过边缘渐变模拟内阴影效果，让容器看起来像是"凹陷"在界面中。
/// 适用于输入框、编辑区域等需要立体感的场景。
///
/// 默认从主题扩展 [AppThemeExtension] 读取配置：
/// - enableInsetShadow: 是否启用内阴影
/// - insetShadowDepth: 阴影深度
/// - insetShadowBlur: 阴影模糊范围
///
/// 也可以通过参数手动覆盖这些值。
class InsetShadowContainer extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 容器圆角
  final double borderRadius;

  /// 内阴影深度（0.0-1.0），值越大阴影越明显
  /// 如果为 null，从主题扩展读取
  final double? shadowDepth;

  /// 阴影模糊范围
  /// 如果为 null，从主题扩展读取
  final double? shadowBlur;

  /// 是否启用内阴影
  /// 如果为 null，从主题扩展读取
  final bool? enabled;

  /// 背景颜色（如果为 null，使用主题的 surfaceContainerLowest）
  final Color? backgroundColor;

  /// 边框颜色（如果为 null，使用主题的 outline）
  final Color? borderColor;

  /// 边框宽度
  final double borderWidth;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  const InsetShadowContainer({
    super.key,
    required this.child,
    this.borderRadius = 8.0,
    this.shadowDepth,
    this.shadowBlur,
    this.enabled,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appExt = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    // 从主题扩展读取配置，允许参数覆盖
    final isEnabled = enabled ?? appExt?.enableInsetShadow ?? true;
    final depth = shadowDepth ?? appExt?.insetShadowDepth ?? 0.12;
    final blur = shadowBlur ?? appExt?.insetShadowBlur ?? 8.0;

    // 背景色 - 深色主题用更深的颜色，浅色主题用更浅的颜色
    final bgColor = backgroundColor ??
        (isDark
            ? Color.lerp(theme.colorScheme.surface, Colors.black, 0.3)!
            : Color.lerp(theme.colorScheme.surface, Colors.black, 0.02)!);

    // 边框色
    final border = borderColor ?? theme.colorScheme.outline.withOpacity(0.2);

    // 如果禁用内阴影，直接返回简单容器
    if (!isEnabled) {
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: border, width: borderWidth),
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      );
    }

    // 阴影色 - 深色主题用黑色，浅色主题用深灰色
    final shadowColor = isDark
        ? Colors.black.withOpacity(depth * 1.5)
        : Colors.black.withOpacity(depth);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        child: CustomPaint(
          foregroundPainter: _InsetShadowPainter(
            shadowColor: shadowColor,
            shadowBlur: blur,
            borderRadius: borderRadius - borderWidth,
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 内阴影绘制器
class _InsetShadowPainter extends CustomPainter {
  final Color shadowColor;
  final double shadowBlur;
  final double borderRadius;

  _InsetShadowPainter({
    required this.shadowColor,
    required this.shadowBlur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 保存画布状态，应用圆角裁剪
    canvas.save();
    canvas.clipRRect(rrect);

    // 顶部内阴影 - 最明显
    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        shadowColor,
        shadowColor.withOpacity(shadowColor.opacity * 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 1.0],
    );

    final topRect = Rect.fromLTWH(0, 0, size.width, shadowBlur * 2);
    final topPaint = Paint()..shader = topGradient.createShader(topRect);
    canvas.drawRect(topRect, topPaint);

    // 左侧内阴影
    final leftGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        shadowColor.withOpacity(shadowColor.opacity * 0.7),
        Colors.transparent,
      ],
    );

    final leftRect = Rect.fromLTWH(0, 0, shadowBlur * 1.5, size.height);
    final leftPaint = Paint()..shader = leftGradient.createShader(leftRect);
    canvas.drawRect(leftRect, leftPaint);

    // 右侧内阴影（更轻微）
    final rightGradient = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        shadowColor.withOpacity(shadowColor.opacity * 0.4),
        Colors.transparent,
      ],
    );

    final rightRect =
        Rect.fromLTWH(size.width - shadowBlur, 0, shadowBlur, size.height);
    final rightPaint = Paint()..shader = rightGradient.createShader(rightRect);
    canvas.drawRect(rightRect, rightPaint);

    // 底部高光（模拟光源从上方照射）- 可选的微妙效果
    // 在深色主题中添加底部微弱高光增加立体感
    if (shadowColor.opacity > 0.1) {
      final bottomHighlight = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.white.withOpacity(0.02),
          Colors.transparent,
        ],
      );

      final bottomRect = Rect.fromLTWH(
          0, size.height - shadowBlur * 0.5, size.width, shadowBlur * 0.5,);
      final bottomPaint = Paint()
        ..shader = bottomHighlight.createShader(bottomRect);
      canvas.drawRect(bottomRect, bottomPaint);
    }

    // 恢复画布状态
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InsetShadowPainter oldDelegate) {
    return oldDelegate.shadowColor != shadowColor ||
        oldDelegate.shadowBlur != shadowBlur ||
        oldDelegate.borderRadius != borderRadius;
  }
}
