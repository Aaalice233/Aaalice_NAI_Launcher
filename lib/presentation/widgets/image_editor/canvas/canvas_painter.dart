import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tools/stroke.dart';
import '../tools/tool_type.dart';

/// 画布绘制器
class CanvasPainter extends CustomPainter {
  final ui.Image? baseImage;
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final Path? maskPath;
  final ToolType currentTool;
  final double scale;
  final Offset offset;

  CanvasPainter({
    this.baseImage,
    required this.strokes,
    this.currentStroke,
    this.maskPath,
    required this.currentTool,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // 应用变换
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // 绘制基础图像
    if (baseImage != null) {
      canvas.drawImage(baseImage!, Offset.zero, Paint());
    }

    // 使用 saveLayer 来支持橡皮擦的 BlendMode.clear
    if (strokes.isNotEmpty || currentStroke != null) {
      final imageRect = baseImage != null
          ? Rect.fromLTWH(0, 0, baseImage!.width.toDouble(), baseImage!.height.toDouble())
          : Rect.fromLTWH(0, 0, size.width / scale, size.height / scale);

      canvas.saveLayer(imageRect, Paint());

      // 绘制 IMAGE 层笔画
      for (final stroke in strokes) {
        _drawStroke(canvas, stroke);
      }

      // 绘制当前正在绘制的笔画
      if (currentStroke != null) {
        _drawStroke(canvas, currentStroke!);
      }

      canvas.restore();
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final isEraser = stroke.tool == ToolType.eraser;

    final paint = Paint()
      ..color = isEraser
          ? Colors.white
          : stroke.color.withOpacity(stroke.brush.opacity)
      ..strokeWidth = stroke.brush.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // 橡皮擦使用 clear 混合模式
    if (isEraser) {
      paint.blendMode = BlendMode.clear;
    }

    if (stroke.points.length == 1) {
      // 单点：画圆点（使用 fill 样式）
      final center = stroke.points.first;
      final fillPaint = Paint()
        ..color = isEraser
            ? Colors.white
            : stroke.color.withOpacity(stroke.brush.opacity)
        ..style = PaintingStyle.fill;

      // 橡皮擦单点也需要使用 clear 混合模式
      if (isEraser) {
        fillPaint.blendMode = BlendMode.clear;
      }

      canvas.drawCircle(center, stroke.brush.size / 2, fillPaint);
    } else {
      // 多点：绘制平滑路径
      final path = _createSmoothPath(stroke.points);
      canvas.drawPath(path, paint);
    }
  }

  /// 创建平滑路径
  Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length < 3) {
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    } else {
      // 使用二次贝塞尔曲线平滑
      for (int i = 1; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];

        final midX = (p1.dx + p2.dx) / 2;
        final midY = (p1.dy + p2.dy) / 2;

        path.quadraticBezierTo(p1.dx, p1.dy, midX, midY);
      }

      // 连接最后一个点
      final last = points.last;
      path.lineTo(last.dx, last.dy);
    }

    return path;
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return baseImage != oldDelegate.baseImage ||
        strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke ||
        maskPath != oldDelegate.maskPath ||
        currentTool != oldDelegate.currentTool ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset;
  }
}

/// 棋盘格背景绘制器
class CheckerboardPainter extends CustomPainter {
  final double cellSize;
  final Color color1;
  final Color color2;

  CheckerboardPainter({
    this.cellSize = 10.0,
    this.color1 = const Color(0xFF3a3a3a),
    this.color2 = const Color(0xFF2a2a2a),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final rect = Rect.fromLTWH(
          col * cellSize,
          row * cellSize,
          cellSize,
          cellSize,
        );
        final isEven = (row + col) % 2 == 0;
        canvas.drawRect(rect, isEven ? paint1 : paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) {
    return cellSize != oldDelegate.cellSize ||
        color1 != oldDelegate.color1 ||
        color2 != oldDelegate.color2;
  }
}

/// 遮罩叠加层绘制器（半透明预览）
class MaskOverlayPainter extends CustomPainter {
  final ui.Image? baseImage;
  final Path? maskPath;
  final double scale;
  final Offset offset;
  final Color overlayColor;

  MaskOverlayPainter({
    this.baseImage,
    this.maskPath,
    required this.scale,
    required this.offset,
    this.overlayColor = const Color(0x40FF6B6B), // 半透明红色
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (baseImage == null || maskPath == null) return;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // 绘制遮罩区域的半透明叠加
    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath!, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MaskOverlayPainter oldDelegate) {
    return baseImage != oldDelegate.baseImage ||
        maskPath != oldDelegate.maskPath ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset ||
        overlayColor != oldDelegate.overlayColor;
  }
}

/// Marching Ants 流动虚线绘制器
class MarchingAntsPainter extends CustomPainter {
  final Path? selectionPath;
  final double phase;
  final double scale;
  final Offset offset;

  MarchingAntsPainter({
    this.selectionPath,
    required this.phase,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionPath == null) return;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // 白色底线
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale;

    canvas.drawPath(selectionPath!, whitePaint);

    // 黑色虚线（带动画相位）
    final blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale;

    // 创建虚线效果
    final dashPath = _createDashedPath(selectionPath!, 4.0 / scale, phase);
    canvas.drawPath(dashPath, blackPaint);

    canvas.restore();
  }

  /// 创建虚线路径
  Path _createDashedPath(Path source, double dashLength, double phase) {
    final result = Path();
    final metrics = source.computeMetrics();

    for (final metric in metrics) {
      double distance = phase % (dashLength * 2);
      bool draw = true;

      while (distance < metric.length) {
        final start = distance;
        final end = math.min(distance + dashLength, metric.length);

        if (draw) {
          final extractedPath = metric.extractPath(start, end);
          result.addPath(extractedPath, Offset.zero);
        }

        distance += dashLength;
        draw = !draw;
      }
    }

    return result;
  }

  @override
  bool shouldRepaint(covariant MarchingAntsPainter oldDelegate) {
    return selectionPath != oldDelegate.selectionPath ||
        phase != oldDelegate.phase ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset;
  }
}
