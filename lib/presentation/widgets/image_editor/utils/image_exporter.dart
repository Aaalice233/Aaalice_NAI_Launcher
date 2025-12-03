import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tools/stroke.dart';
import '../tools/tool_type.dart';

/// 图像导出工具
class ImageExporter {
  /// 导出带有笔画的图像
  static Future<Uint8List> exportWithStrokes(
    ui.Image baseImage,
    List<Stroke> strokes,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制基础图像
    canvas.drawImage(baseImage, Offset.zero, Paint());

    // 绘制所有笔画
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(baseImage.width, baseImage.height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// 导出遮罩图像 (黑色背景 + 白色选区)
  static Future<Uint8List> exportMask(
    int width,
    int height,
    Path maskPath,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 黑色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.black,
    );

    // 白色选区
    canvas.drawPath(
      maskPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// 绘制笔画
  static void _drawStroke(Canvas canvas, Stroke stroke) {
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
  static Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length < 3) {
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    } else {
      for (int i = 1; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];

        final midX = (p1.dx + p2.dx) / 2;
        final midY = (p1.dy + p2.dy) / 2;

        path.quadraticBezierTo(p1.dx, p1.dy, midX, midY);
      }

      final last = points.last;
      path.lineTo(last.dx, last.dy);
    }

    return path;
  }
}
