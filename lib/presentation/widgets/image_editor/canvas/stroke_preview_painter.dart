import 'package:flutter/material.dart';

import '../core/editor_state.dart';
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
    if (!state.isDrawing || points.isEmpty) {
      return;
    }

    final canvasSize = state.canvasSize;
    final controller = state.canvasController;

    canvas.save();
    canvas.translate(controller.offset.dx, controller.offset.dy);

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
    canvas.clipRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));
    _drawCurrentStroke(canvas, points);
    canvas.restore();
  }

  void _drawCurrentStroke(Canvas canvas, List<Offset> points) {
    final tool = state.currentTool;
    if (tool == null || !tool.isPaintTool) return;

    double size = 20.0;
    double opacity = 1.0;
    double hardness = 0.8;
    Color color = state.foregroundColor;
    bool isEraser = false;

    if (tool is BrushTool) {
      size = tool.settings.size;
      opacity = tool.settings.opacity;
      hardness = tool.settings.hardness;
    } else if (tool is EraserTool) {
      size = tool.size;
      hardness = tool.hardness;
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
          : color.withValues(alpha: opacity)
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

  @override
  bool shouldRepaint(covariant StrokePreviewPainter oldDelegate) {
    return state != oldDelegate.state;
  }
}
