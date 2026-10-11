import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../common/checkerboard_pattern.dart';
import '../../common/image_viewport_surface.dart';
import '../core/editor_state.dart';

/// 图层绘制器
/// 负责绘制所有图层内容
class LayerPainter extends CustomPainter {
  final EditorState state;
  final bool showTransparentCanvasBackground;

  /// 框外内容照常绘制并压暗，表示保留但不会送出
  final bool revealOutsideFrame;

  /// 决定透明底纹的纹理精度
  final double devicePixelRatio;

  static final CheckerboardPattern _checkerboard = CheckerboardPattern(
    cellSize: 16,
    evenColor: Colors.grey.shade300,
    oddColor: Colors.grey.shade100,
  );

  static final Color _outsideFrameScrim = ImageViewportSurface.background
      .withValues(alpha: 0.72);

  /// 使用 renderNotifier 而非整个 state
  /// 这样只有在渲染相关变化时才会触发重绘
  /// 切换活动图层等 UI 操作不会导致画布重绘
  LayerPainter({
    required this.state,
    this.showTransparentCanvasBackground = false,
    this.revealOutsideFrame = false,
    this.devicePixelRatio = 1.0,
  }) : super(repaint: state.renderNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = state.displayFrame;
    final controller = state.canvasController;

    // 保存状态
    canvas.save();

    // 平移、以取景框中心旋转/镜像、缩放
    controller.applyViewTransform(canvas, state.frame);

    // 透明画布用棋盘格表示透明，否则铺白色底色
    if (showTransparentCanvasBackground) {
      _checkerboard.paint(
        canvas,
        frame,
        origin: frame.topLeft,
        pixelScale: controller.scale * devicePixelRatio,
      );
    } else {
      canvas.drawRect(frame, Paint()..color = Colors.white);
    }

    if (!revealOutsideFrame) {
      // 裁剪到取景框范围，防止笔画超出边界
      canvas.clipRect(frame);
    }

    // 获取视口边界用于空间剔除优化
    // 这可以避免渲染不在视口内的图层，提高性能（特别是放大查看时）
    final viewportBounds = controller.viewportBounds(state.frame);

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

  @override
  bool shouldRepaint(covariant LayerPainter oldDelegate) {
    // repaint: renderNotifier 已经处理了渲染相关的变化监听
    // shouldRepaint 只需处理 CustomPainter 本身的属性变化
    // 返回 false 避免工具切换等无关操作触发不必要的重绘
    return showTransparentCanvasBackground !=
            oldDelegate.showTransparentCanvasBackground ||
        revealOutsideFrame != oldDelegate.revealOutsideFrame ||
        devicePixelRatio != oldDelegate.devicePixelRatio;
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

    // 绘制新选区期间旧选区让位；拖动中显示平移后的轮廓
    final selection = state.previewPath ?? state.selectionManager.displayPath;
    if (selection != null) {
      _drawMarchingAnts(canvas, selection);
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
