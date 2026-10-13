import 'package:flutter/material.dart';

import '../core/editor_state.dart';
import '../core/stroke_rendering.dart';
import '../tools/blur_tool.dart';
import '../tools/brush_tool.dart';
import '../tools/clone_stamp_tool.dart';
import '../tools/eraser_tool.dart';

/// Paints the in-progress stroke only.
///
/// This overlay is visual-only. It must not mutate layers, history, snapshots,
/// export state, or raster caches.
class StrokePreviewPainter extends CustomPainter {
  StrokePreviewPainter({required this.state})
    : super(
        repaint: Listenable.merge([
          state.strokePreviewNotifier,
          state.canvasController,
        ]),
      );

  final EditorState state;

  @override
  void paint(Canvas canvas, Size size) {
    final points = state.currentStrokePoints;
    // 蒙版上的画笔笔画由图层绘制器画进蒙版层，与已有蒙版合成同一种颜色
    if (!state.isDrawing || points.isEmpty || state.isPaintingMask) {
      return;
    }

    final frame = state.frame;
    final controller = state.canvasController;

    canvas.save();
    controller.applyViewTransform(canvas, frame);
    canvas.clipRect(frame);
    _drawCurrentStroke(
      canvas,
      points,
      magnified: controller.scale > 1,
      visible: controller.visiblePartOf(frame),
    );
    canvas.restore();
  }

  void _drawCurrentStroke(
    Canvas canvas,
    List<Offset> points, {
    required bool magnified,
    required Rect visible,
  }) {
    final tool = state.currentTool;
    if (tool == null || !tool.isPaintTool) return;

    double size = 20.0;
    double opacity = 1.0;
    double hardness = 0.8;
    Color color = state.foregroundColor;
    bool isEraser = false;

    if (tool is BrushTool) {
      final style = tool.strokeStyleFor(state);
      size = style.size;
      color = style.color;
      opacity = style.opacity;
      hardness = style.hardness;
    } else if (tool is EraserTool) {
      size = tool.size;
      hardness = tool.hardnessFor(state);
      isEraser = true;
    } else if (tool is BlurTool) {
      size = tool.size;
      color = const Color(0xFF90CAF9);
      opacity = 0.25;
      hardness = 0.0;
    } else if (tool is CloneStampTool) {
      if (tool.canvasSnapshot != null && tool.sourceOffset != null) {
        tool.drawRealtimePreview(canvas, points);
        return;
      }
      size = tool.size;
      opacity = 0.3;
      hardness = 0.5;
      color = Colors.cyanAccent;
    }

    final paint = Paint()
      ..color = isEraser
          ? Colors.grey.withValues(alpha: 0.5)
          : color.withValues(alpha: opacity);

    final soft = StrokeRendering.blurSigma(size: size, hardness: hardness) > 0;
    if (soft && magnified) {
      StrokeRendering.drawAtDocumentResolution(
        canvas,
        points,
        paint,
        size: size,
        hardness: hardness,
        visible: visible,
      );
    } else {
      StrokeRendering.draw(
        canvas,
        points,
        paint,
        size: size,
        hardness: hardness,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StrokePreviewPainter oldDelegate) {
    return state != oldDelegate.state;
  }
}
