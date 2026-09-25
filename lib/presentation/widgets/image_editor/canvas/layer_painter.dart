import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../common/image_viewport_surface.dart';
import '../core/editor_state.dart';

class CheckerboardCacheKey {
  const CheckerboardCacheKey({
    required this.canvasSize,
    required this.cellSize,
    required this.color1,
    required this.color2,
  });

  final Size canvasSize;
  final double cellSize;
  final Color color1;
  final Color color2;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CheckerboardCacheKey &&
            other.canvasSize == canvasSize &&
            other.cellSize == cellSize &&
            other.color1 == color1 &&
            other.color2 == color2;
  }

  @override
  int get hashCode => Object.hash(canvasSize, cellSize, color1, color2);
}

/// 棋盘格缓存管理器
/// 缓存棋盘格 Picture，避免每帧重复绘制单元格
class _CheckerboardCache {
  static CheckerboardCacheKey? _key;
  static ui.Picture? _picture;
  static int _recordCount = 0;

  /// 棋盘格单元格大小
  static const double cellSize = 16.0;

  /// 棋盘格颜色
  static final Color color1 = Colors.grey.shade300;
  static final Color color2 = Colors.grey.shade100;

  static CheckerboardCacheKey? get currentKey => _key;
  static int get recordCount => _recordCount;

  static void draw(Canvas canvas, CheckerboardCacheKey key) {
    final picture = _pictureFor(key);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, key.canvasSize.width, key.canvasSize.height),
    );
    canvas.drawPicture(picture);
    canvas.restore();
  }

  static ui.Picture _pictureFor(CheckerboardCacheKey key) {
    if (_picture != null && _key == key) {
      return _picture!;
    }

    _picture?.dispose();
    _key = key;
    _picture = _recordPicture(key);
    _recordCount++;
    return _picture!;
  }

  static ui.Picture _recordPicture(CheckerboardCacheKey key) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint1 = Paint()..color = key.color1;
    final paint2 = Paint()..color = key.color2;

    for (double y = 0; y < key.canvasSize.height; y += key.cellSize) {
      for (double x = 0; x < key.canvasSize.width; x += key.cellSize) {
        final isEven = ((x ~/ key.cellSize) + (y ~/ key.cellSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, key.cellSize, key.cellSize),
          isEven ? paint1 : paint2,
        );
      }
    }

    return recorder.endRecording();
  }

  /// 释放缓存（通常不需要调用，除非显式清理）
  // ignore: unused_element
  static void dispose() {
    _picture?.dispose();
    _picture = null;
    _key = null;
    _recordCount = 0;
  }
}

/// 图层绘制器
/// 负责绘制所有图层内容
class LayerPainter extends CustomPainter {
  final EditorState state;
  final bool showTransparentCanvasBackground;

  /// 框外内容照常绘制并压暗，表示保留但不会送出
  final bool revealOutsideFrame;

  static final Color _outsideFrameScrim = ImageViewportSurface.background
      .withValues(alpha: 0.72);

  /// 使用 renderNotifier 而非整个 state
  /// 这样只有在渲染相关变化时才会触发重绘
  /// 切换活动图层等 UI 操作不会导致画布重绘
  LayerPainter({
    required this.state,
    this.showTransparentCanvasBackground = false,
    this.revealOutsideFrame = false,
  }) : super(repaint: state.renderNotifier);

  @visibleForTesting
  static CheckerboardCacheKey? get debugCheckerboardCacheKey {
    return _CheckerboardCache.currentKey;
  }

  @visibleForTesting
  static int get debugCheckerboardRecordCount {
    return _CheckerboardCache.recordCount;
  }

  @visibleForTesting
  static void debugResetCheckerboardCache() {
    _CheckerboardCache.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frame = state.displayFrame;
    final controller = state.canvasController;

    // 保存状态
    canvas.save();

    // 平移、以取景框中心旋转/镜像、缩放
    controller.applyViewTransform(canvas, state.frame);

    // 绘制画布背景（棋盘格表示透明）
    _drawCheckerboard(canvas, frame);

    // 绘制白色画布底色
    if (!showTransparentCanvasBackground) {
      canvas.drawRect(frame, Paint()..color = Colors.white);
    }

    if (!revealOutsideFrame) {
      // 裁剪到取景框范围，防止笔画超出边界
      canvas.clipRect(frame);
    }

    // 获取视口边界用于空间剔除优化
    // 这可以避免渲染不在视口内的图层，提高性能（特别是放大查看时）
    final viewportBounds = controller.viewportBounds;

    // 绘制所有图层（传入视口边界以启用空间剔除优化）
    state.layerManager.renderAll(
      canvas,
      viewportBounds: viewportBounds,
      filterQuality: FilterQuality.medium,
    );

    if (revealOutsideFrame) {
      _drawOutsideFrameScrim(canvas, frame);
    }

    // 恢复状态
    canvas.restore();
  }

  void _drawOutsideFrameScrim(Canvas canvas, Rect frame) {
    canvas.save();
    canvas.clipRect(frame, clipOp: ui.ClipOp.difference);
    canvas.drawPaint(Paint()..color = _outsideFrameScrim);
    canvas.restore();
  }

  /// 绘制棋盘格背景（表示透明区域）
  /// 使用 Picture 缓存优化性能
  void _drawCheckerboard(Canvas canvas, Rect frame) {
    final key = CheckerboardCacheKey(
      canvasSize: frame.size,
      cellSize: _CheckerboardCache.cellSize,
      color1: _CheckerboardCache.color1,
      color2: _CheckerboardCache.color2,
    );

    canvas.save();
    canvas.translate(frame.left, frame.top);
    _CheckerboardCache.draw(canvas, key);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LayerPainter oldDelegate) {
    // repaint: renderNotifier 已经处理了渲染相关的变化监听
    // shouldRepaint 只需处理 CustomPainter 本身的属性变化
    // 返回 false 避免工具切换等无关操作触发不必要的重绘
    return showTransparentCanvasBackground !=
            oldDelegate.showTransparentCanvasBackground ||
        revealOutsideFrame != oldDelegate.revealOutsideFrame;
  }
}

class VirtualOutpaintMaskPainter extends CustomPainter {
  final EditorState state;

  /// 给定取景框局部坐标下待生成的空白区域
  final List<Rect> Function(Rect frame) maskRectsFor;

  VirtualOutpaintMaskPainter({required this.state, required this.maskRectsFor})
    : super(repaint: state.renderNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    // 跟随平移预览，拖动过程中就能看到哪些区域会被生成
    final frame = state.displayFrame;
    final maskRects = maskRectsFor(frame);
    if (maskRects.isEmpty) {
      return;
    }

    final controller = state.canvasController;

    canvas.save();
    controller.applyViewTransform(canvas, state.frame);
    canvas.translate(frame.left, frame.top);
    canvas.clipRect(Offset.zero & frame.size);

    final fill = Paint()..color = const Color(0x5560AAFF);
    final outline = Paint()
      ..color = const Color(0xFF60AAFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / controller.scale.clamp(0.01, double.infinity);

    for (final rect in maskRects) {
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, outline);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VirtualOutpaintMaskPainter oldDelegate) {
    return state != oldDelegate.state ||
        maskRectsFor != oldDelegate.maskRectsFor;
  }
}

/// 选区绘制器
/// 绘制选区蚂蚁线动画
class SelectionPainter extends CustomPainter {
  final EditorState state;
  final Animation<double> animation;
  final bool suppressSelectionOverlay;

  /// 缓存的选区路径
  static Path? _cachedPath;

  /// 缓存的 PathMetrics（避免每帧重新计算）
  static List<ui.PathMetric>? _cachedMetrics;

  /// 使用 renderNotifier 和 animation 的合并监听
  /// 只有渲染相关变化才会触发重绘
  SelectionPainter({
    required this.state,
    required this.animation,
    this.suppressSelectionOverlay = false,
  }) : super(repaint: Listenable.merge([state.renderNotifier, animation]));

  @override
  void paint(Canvas canvas, Size size) {
    if (suppressSelectionOverlay) {
      return;
    }

    final controller = state.canvasController;

    canvas.save();
    controller.applyViewTransform(canvas, state.frame);

    // 绘制预览（绘制中）
    if (state.previewPath != null) {
      _drawMarchingAnts(canvas, state.previewPath!);
    }

    // 绘制已确认的选区（蚂蚁线）
    if (state.selectionPath != null) {
      if (state.selectionManager.isTransforming) {
        final bounds = state.selectionManager.transformedBounds;
        if (bounds != null) {
          final transformedPath = Path()..addRect(bounds);
          _drawMarchingAnts(canvas, transformedPath);
          _drawTransformHandles(canvas, bounds, controller.scale);
        }
      } else {
        _drawMarchingAnts(canvas, state.selectionPath!);
      }
    }

    canvas.restore();
  }

  /// 绘制变换控制点
  void _drawTransformHandles(Canvas canvas, Rect bounds, double viewScale) {
    final handleSize = 6.0 / viewScale;
    final handlePaint = Paint()..color = Colors.white;
    final handleBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / viewScale;

    final corners = [
      bounds.topLeft,
      bounds.topCenter,
      bounds.topRight,
      bounds.centerLeft,
      bounds.centerRight,
      bounds.bottomLeft,
      bounds.bottomCenter,
      bounds.bottomRight,
    ];

    for (final corner in corners) {
      final rect = Rect.fromCenter(
        center: corner,
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRect(rect, handlePaint);
      canvas.drawRect(rect, handleBorder);
    }
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

  /// 缓存的图标 TextPainter
  static final Map<int, TextPainter> _iconCache = {};

  /// 位置在 paint 时直接读 cursorNotifier，不经构造参数捕获，
  /// 避免 widget 重建与重绘不同步时画出旧坐标
  CursorPainter({required this.state}) : super(repaint: state.cursorNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final cursorPosition = state.cursorNotifier.value;
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
        cursorPosition,
        scaledRadius,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.drawCircle(
        cursorPosition,
        scaledRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );

      // 中心点
      canvas.drawCircle(cursorPosition, 2, Paint()..color = Colors.black);

      // 图标位置：圆圈右下角
      iconPosition = cursorPosition + Offset(scaledRadius, scaledRadius);
    } else {
      // 非绘画工具：图标在光标右下角
      iconPosition = cursorPosition + const Offset(8, 8);
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
      Paint()..color = Colors.black.withValues(alpha: 0.7),
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
    // 位置变化由 repaint: cursorNotifier 驱动，这里只处理 painter 自身依赖的变化
    return state != oldDelegate.state;
  }
}
