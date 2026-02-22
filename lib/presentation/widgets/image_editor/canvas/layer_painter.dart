import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/app_logger.dart';
import '../core/editor_state.dart';
import '../tools/brush_tool.dart';
import '../tools/eraser_tool.dart';

/// 棋盘格缓存管理器
/// 使用 ImageShader 预缓存棋盘格图案，避免每帧重复绘制
class _CheckerboardCache {
  static ui.Image? _image;
  static ui.ImageShader? _shader;
  static bool _isInitializing = false;

  /// 棋盘格单元格大小
  static const double cellSize = 16.0;

  /// 棋盘格颜色
  static final Color color1 = Colors.grey.shade300;
  static final Color color2 = Colors.grey.shade100;

  /// 获取棋盘格 Shader
  static ui.ImageShader? get shader {
    if (_shader != null) return _shader;
    if (!_isInitializing) {
      _initializeAsync();
    }
    return null;
  }

  /// 异步初始化棋盘格图像
  static Future<void> _initializeAsync() async {
    if (_isInitializing || _image != null) return;
    _isInitializing = true;

    try {
      // 创建 2x2 单元格的图案（用于平铺）
      const patternSize = cellSize * 2;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final paint1 = Paint()..color = color1;
      final paint2 = Paint()..color = color2;

      // 绘制 2x2 棋盘格图案
      // [1][2]
      // [2][1]
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, cellSize, cellSize),
        paint1,
      );
      canvas.drawRect(
        const Rect.fromLTWH(cellSize, 0, cellSize, cellSize),
        paint2,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, cellSize, cellSize, cellSize),
        paint2,
      );
      canvas.drawRect(
        const Rect.fromLTWH(cellSize, cellSize, cellSize, cellSize),
        paint1,
      );

      final picture = recorder.endRecording();
      _image = await picture.toImage(patternSize.toInt(), patternSize.toInt());
      picture.dispose();

      // 创建平铺 Shader
      _shader = ui.ImageShader(
        _image!,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        Matrix4.identity().storage,
      );
    } catch (e) {
      AppLogger.w('Failed to initialize checkerboard cache: $e', 'ImageEditor');
    } finally {
      _isInitializing = false;
    }
  }

  /// 释放缓存（通常不需要调用，除非显式清理）
  // ignore: unused_element
  static void dispose() {
    _shader = null;
    _image?.dispose();
    _image = null;
  }
}

/// 图层绘制器
/// 负责绘制所有图层内容
class LayerPainter extends CustomPainter {
  final EditorState state;

  /// 使用 renderNotifier 而非整个 state
  /// 这样只有在渲染相关变化时才会触发重绘
  /// 切换活动图层等 UI 操作不会导致画布重绘
  LayerPainter({required this.state}) : super(repaint: state.renderNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final canvasSize = state.canvasSize;
    final controller = state.canvasController;

    // 保存状态
    canvas.save();

    // 应用基础变换（平移和缩放）
    canvas.translate(controller.offset.dx, controller.offset.dy);

    // 应用旋转和镜像（以画布中心为基准）
    final centerX = canvasSize.width * controller.scale / 2;
    final centerY = canvasSize.height * controller.scale / 2;

    if (controller.rotation != 0 || controller.isMirroredHorizontally) {
      canvas.translate(centerX, centerY);

      if (controller.rotation != 0) {
        canvas.rotate(controller.rotation);
      }

      if (controller.isMirroredHorizontally) {
        canvas.scale(-1.0, 1.0);
      }

      canvas.translate(-centerX, -centerY);
    }

    canvas.scale(controller.scale);

    // 绘制画布背景（棋盘格表示透明）
    _drawCheckerboard(canvas, canvasSize);

    // 绘制白色画布底色
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

    // 裁剪到画布范围，防止笔画超出边界
    canvas.clipRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));

    // 获取视口边界用于空间剔除优化
    // 这可以避免渲染不在视口内的图层，提高性能（特别是放大查看时）
    final viewportBounds = controller.viewportBounds;

    // 绘制所有图层（传入视口边界以启用空间剔除优化）
    state.layerManager.renderAll(canvas, canvasSize, viewportBounds: viewportBounds);

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
    final Color color = state.foregroundColor;
    bool isEraser = false;

    if (tool is BrushTool) {
      size = tool.settings.size;
      opacity = tool.settings.opacity;
      hardness = tool.settings.hardness;
    } else if (tool is EraserTool) {
      size = tool.size;
      hardness = tool.hardness;
      isEraser = true;
    }

    final paint = Paint()
      ..color =
          isEraser ? Colors.grey.withOpacity(0.5) : color.withOpacity(opacity)
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
  /// 使用 ImageShader 缓存优化性能
  void _drawCheckerboard(Canvas canvas, Size size) {
    final shader = _CheckerboardCache.shader;

    if (shader != null) {
      // 使用缓存的 Shader 绘制（高性能）
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = shader,
      );
    } else {
      // 回退方案：Shader 未准备好时使用传统方式
      // 仅在首帧或初始化失败时触发
      const cellSize = _CheckerboardCache.cellSize;
      final paint1 = Paint()..color = _CheckerboardCache.color1;
      final paint2 = Paint()..color = _CheckerboardCache.color2;

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
  }

  @override
  bool shouldRepaint(covariant LayerPainter oldDelegate) {
    // repaint: renderNotifier 已经处理了渲染相关的变化监听
    // shouldRepaint 只需处理 CustomPainter 本身的属性变化
    // 返回 false 避免工具切换等无关操作触发不必要的重绘
    return false;
  }
}

/// 选区绘制器
/// 绘制选区蚂蚁线动画
class SelectionPainter extends CustomPainter {
  final EditorState state;
  final Animation<double> animation;

  /// 缓存的选区路径
  static Path? _cachedPath;

  /// 缓存的 PathMetrics（避免每帧重新计算）
  static List<ui.PathMetric>? _cachedMetrics;

  /// 使用 renderNotifier 和 animation 的合并监听
  /// 只有渲染相关变化才会触发重绘
  SelectionPainter({
    required this.state,
    required this.animation,
  }) : super(repaint: Listenable.merge([state.renderNotifier, animation]));

  @override
  void paint(Canvas canvas, Size size) {
    final controller = state.canvasController;
    final canvasSize = state.canvasSize;

    canvas.save();
    canvas.translate(controller.offset.dx, controller.offset.dy);

    // 应用旋转和镜像（以画布中心为基准）
    final centerX = canvasSize.width * controller.scale / 2;
    final centerY = canvasSize.height * controller.scale / 2;

    if (controller.rotation != 0 || controller.isMirroredHorizontally) {
      canvas.translate(centerX, centerY);

      if (controller.rotation != 0) {
        canvas.rotate(controller.rotation);
      }

      if (controller.isMirroredHorizontally) {
        canvas.scale(-1.0, 1.0);
      }

      canvas.translate(-centerX, -centerY);
    }

    canvas.scale(controller.scale);

    // 绘制预览（绘制中）
    if (state.previewPath != null) {
      _drawMarchingAnts(canvas, state.previewPath!);
    }

    // 绘制已确认的选区（蚂蚁线）
    if (state.selectionPath != null) {
      _drawMarchingAnts(canvas, state.selectionPath!);
    }

    canvas.restore();
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

  /// 绘制虚线路径（使用缓存的 PathMetrics）
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dashOffset,
  ) {
    // 检查路径是否变化，仅在变化时重新计算 metrics
    if (_cachedPath != path) {
      _cachedPath = path;
      _cachedMetrics = path.computeMetrics().toList();
    }

    final metrics = _cachedMetrics;
    if (metrics == null) return;

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
/// 绘制画笔光标预览和工具图标
class CursorPainter extends CustomPainter {
  final EditorState state;
  final Offset? cursorPosition;

  /// 缓存的图标 TextPainter
  static final Map<int, TextPainter> _iconCache = {};

  /// 使用 cursorNotifier 而非整个 state
  /// 这样只有光标位置变化时才会触发重绘
  /// 避免其他 UI 操作导致光标不必要的重绘
  CursorPainter({
    required this.state,
    this.cursorPosition,
  }) : super(repaint: state.cursorNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    if (cursorPosition == null) return;

    final tool = state.currentTool;
    if (tool == null) return;

    final scale = state.canvasController.scale;
    Offset iconPosition;

    // 绘画工具：绘制圆圈光标
    if (tool.isPaintTool) {
      final radius = tool.getCursorRadius(state);
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

      // 图标位置：圆圈右下角
      iconPosition = cursorPosition! + Offset(scaledRadius, scaledRadius);
    } else {
      // 非绘画工具：图标在光标右下角
      iconPosition = cursorPosition! + const Offset(8, 8);
    }

    // 绘制工具图标
    _drawToolIcon(canvas, iconPosition, tool.icon);
  }

  /// 获取或创建缓存的 TextPainter
  static TextPainter _getIconPainter(IconData icon) {
    final cacheKey = icon.codePoint;
    if (_iconCache.containsKey(cacheKey)) {
      return _iconCache[cacheKey]!;
    }

    const iconSize = 14.0;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: iconSize,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    _iconCache[cacheKey] = painter;
    return painter;
  }

  /// 绘制工具图标
  void _drawToolIcon(Canvas canvas, Offset position, IconData icon) {
    const iconSize = 14.0;
    const bgRadius = iconSize / 2 + 2;

    // 绘制背景圆
    canvas.drawCircle(
      position,
      bgRadius,
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    // 绘制白色边框
    canvas.drawCircle(
      position,
      bgRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 使用缓存的 TextPainter 绘制图标
    final textPainter = _getIconPainter(icon);
    textPainter.paint(
      canvas,
      position - const Offset(iconSize / 2, iconSize / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CursorPainter oldDelegate) {
    // repaint: cursorNotifier 已经处理了光标位置变化的监听
    // shouldRepaint 只需处理 CustomPainter 本身的属性变化
    // 返回 false 避免不必要的重绘检查
    return false;
  }
}
