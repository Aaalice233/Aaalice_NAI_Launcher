import 'package:flutter/material.dart';

/// 内阴影绘制器 - 用于创建凹陷立体感效果
///
/// 通过边缘渐变模拟内阴影效果，适用于：
/// - 开关轨道
/// - 滑块轨道
/// - 输入框背景
class InsetShadowPainter extends CustomPainter {
  final Color shadowColor;
  final double shadowBlur;
  final double borderRadius;

  const InsetShadowPainter({
    required this.shadowColor,
    required this.shadowBlur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

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
      stops: const [0.0, 0.4, 1.0],
    );

    final topRect = Rect.fromLTWH(0, 0, size.width, shadowBlur * 2);
    final topPaint = Paint()..shader = topGradient.createShader(topRect);
    canvas.drawRect(topRect, topPaint);

    // 左侧内阴影
    final leftGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        shadowColor.withOpacity(shadowColor.opacity * 0.5),
        Colors.transparent,
      ],
    );

    final leftRect = Rect.fromLTWH(0, 0, shadowBlur, size.height);
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

    final rightRect = Rect.fromLTWH(
      size.width - shadowBlur,
      0,
      shadowBlur,
      size.height,
    );
    final rightPaint = Paint()..shader = rightGradient.createShader(rightRect);
    canvas.drawRect(rightRect, rightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InsetShadowPainter oldDelegate) {
    return oldDelegate.shadowColor != shadowColor ||
        oldDelegate.shadowBlur != shadowBlur ||
        oldDelegate.borderRadius != borderRadius;
  }
}
