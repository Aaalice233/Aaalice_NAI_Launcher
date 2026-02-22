import 'dart:math';

import 'package:flutter/material.dart';

/// 圆形进度环绘制器
class CircularProgressPainter extends CustomPainter {
  /// 进度值 (0.0 - 1.0)
  final double progress;

  /// 进度环颜色
  final Color color;

  /// 背景环颜色
  final Color? backgroundColor;

  /// 线条宽度
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    this.backgroundColor,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // 背景圆环
    final bgPaint = Paint()
      ..color = backgroundColor ?? color.withOpacity(0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆弧
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawArc(
        rect,
        -pi / 2, // 从顶部开始
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 圆形进度环组件
class CircularProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Color? backgroundColor;
  final double size;
  final double strokeWidth;
  final Widget? child;

  const CircularProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.backgroundColor,
    this.size = 56.0,
    this.strokeWidth = 4.0,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: CircularProgressPainter(
              progress: progress,
              color: color,
              backgroundColor: backgroundColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}
