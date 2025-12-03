import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/editor_state.dart';

/// 图层绘制器
/// 负责绘制所有图层内容
class LayerPainter extends CustomPainter {
  final EditorState state;

  /// 缓存的棋盘格图案
  static ui.Image? _checkerboardCache;
  static Size? _checkerboardCacheSize;

  LayerPainter({required this.state}) : super(repaint: state);

  @override
  void paint(Canvas canvas, Size size) {
    final canvasSize = state.canvasSize;
    final controller = state.canvasController;

    // 保存状态
    canvas.save();

    // 应用变换
    canvas.translate(controller.offset.dx, controller.offset.dy);
    canvas.scale(controller.scale);

    // 绘制画布背景（棋盘格表示透明）
    _drawCheckerboard(canvas, canvasSize);

    // 绘制白色画布底色
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

    // 绘制所有图层
    state.layerManager.renderAll(canvas, canvasSize);

    // 绘制当前正在绘制的笔画
    if (state.isDrawing && state.currentStrokePoints.isNotEmpty) {
      _drawCurrentStroke(canvas);
    }

    // 恢复状态
    canvas.restore();
  }

  /// 绘制当前正在绘制的笔画
  void _drawCurrentStroke(Canvas canvas) {
    final points = state.currentStrokePoints;
    if (points.isEmpty) return;

    final tool = state.currentTool;
    if (tool == null || !tool.isPaintTool) return;

    // 获取当前工具的设置
    double size = 20.0;
    double opacity = 1.0;
    double hardness = 0.8;
    Color color = state.foregroundColor;
    bool isEraser = false;

    if (tool.id == 'brush') {
      final brushTool = tool as dynamic;
      size = brushTool.settings.size;
      opacity = brushTool.settings.opacity;
      hardness = brushTool.settings.hardness;
    } else if (tool.id == 'eraser') {
      final eraserTool = tool as dynamic;
      size = eraserTool.size;
      hardness = eraserTool.hardness;
      isEraser = true;
    }

    final paint = Paint()
      ..color = isEraser ? Colors.grey.withOpacity(0.5) : color.withOpacity(opacity)
      ..strokeWidth = size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (hardness < 1.0) {
      final sigma = size * (1.0 - hardness) * 0.5;
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    }

    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        size / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      final path = _createSmoothPath(points);
      canvas.drawPath(path, paint);
    }
  }

  /// 创建平滑路径
  Path _createSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
    } else {
      for (int i = 1; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(points.last.dx, points.last.dy);
    }

    return path;
  }

  /// 绘制棋盘格背景（表示透明区域）
  void _drawCheckerboard(Canvas canvas, Size size) {
    const cellSize = 16.0;
    final paint1 = Paint()..color = Colors.grey.shade300;
    final paint2 = Paint()..color = Colors.grey.shade100;

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LayerPainter oldDelegate) {
    // CustomPainter 使用 repaint: state 自动监听状态变化
    // 所以这里不需要手动比较，repaint Listenable 会自动触发重绘
    return false;
  }
}

/// 选区绘制器
/// 绘制选区蚂蚁线动画
class SelectionPainter extends CustomPainter {
  final EditorState state;
  final Animation<double> animation;

  SelectionPainter({
    required this.state,
    required this.animation,
  }) : super(repaint: Listenable.merge([state, animation]));

  @override
  void paint(Canvas canvas, Size size) {
    final controller = state.canvasController;

    canvas.save();
    canvas.translate(controller.offset.dx, controller.offset.dy);
    canvas.scale(controller.scale);

    // 绘制选区预览（矩形/椭圆）
    if (state.selectionPreview != null) {
      _drawSelectionPreview(canvas, state.selectionPreview!);
    }

    // 绘制套索预览
    if (state.lassoPreviewPath != null) {
      _drawLassoPreview(canvas, state.lassoPreviewPath!);
    }

    // 绘制已确认的选区（蚂蚁线）
    if (state.selectionPath != null) {
      _drawMarchingAnts(canvas, state.selectionPath!);
    }

    canvas.restore();
  }

  /// 绘制选区预览
  void _drawSelectionPreview(Canvas canvas, Rect rect) {
    final tool = state.currentTool;
    Path path;

    if (tool?.id == 'ellipse_selection') {
      path = Path()..addOval(rect);
    } else {
      path = Path()..addRect(rect);
    }

    // 填充半透明
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue.withOpacity(0.1)
        ..style = PaintingStyle.fill,
    );

    // 边框
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  /// 绘制套索预览
  void _drawLassoPreview(Canvas canvas, Path path) {
    // 填充半透明
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue.withOpacity(0.1)
        ..style = PaintingStyle.fill,
    );

    // 实线部分
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  /// 绘制蚂蚁线（选区边框动画）
  void _drawMarchingAnts(Canvas canvas, Path path) {
    // 白色底线
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 黑色虚线（动画）
    final dashOffset = animation.value * 16.0;
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    _drawDashedPath(canvas, path, paint, dashOffset);
  }

  /// 绘制虚线路径
  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashOffset) {
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = dashOffset % 16.0;
      bool draw = true;

      while (distance < metric.length) {
        final nextDistance = distance + 4.0; // 虚线长度
        if (nextDistance > metric.length) break;

        if (draw) {
          final extractPath = metric.extractPath(distance, nextDistance);
          canvas.drawPath(extractPath, paint);
        }

        distance = nextDistance + 4.0; // 间隔长度
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    // repaint Listenable 会自动触发重绘
    return false;
  }
}

/// 光标绘制器
/// 绘制画笔光标预览
class CursorPainter extends CustomPainter {
  final EditorState state;
  final Offset? cursorPosition;

  CursorPainter({
    required this.state,
    this.cursorPosition,
  });
  // 注意：不使用 repaint: state，因为光标位置通过 setState 更新，
  // 每次 setState 都会创建新的 CursorPainter 实例

  @override
  void paint(Canvas canvas, Size size) {
    if (cursorPosition == null) return;

    final tool = state.currentTool;
    if (tool == null) return;

    // 只为绘画工具显示光标
    if (!tool.isPaintTool) return;

    final radius = tool.getCursorRadius(state);
    final scale = state.canvasController.scale;
    final scaledRadius = radius * scale;

    // 光标圆圈
    canvas.drawCircle(
      cursorPosition!,
      scaledRadius,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    canvas.drawCircle(
      cursorPosition!,
      scaledRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // 中心点
    canvas.drawCircle(
      cursorPosition!,
      2,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant CursorPainter oldDelegate) {
    return cursorPosition != oldDelegate.cursorPosition;
  }
}
