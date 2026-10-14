import 'package:flutter/material.dart';

import '../core/editor_state.dart';
import '../core/transform_geometry.dart';

/// 移动工具的变换框：外框、八个缩放手柄与旋转手柄，按屏幕像素定尺寸，缩放视图时大小不变
class TransformOverlayPainter extends CustomPainter {
  TransformOverlayPainter({required this.state, required this.metrics})
    : super(
        repaint: Listenable.merge([
          state.renderNotifier,
          state.layerTransformer,
          state.canvasController,
          state.frameNotifier,
        ]),
      );

  final EditorState state;

  /// 与命中判定使用同一套尺寸，画出来的手柄就是能按住的位置
  final TransformHandleMetrics metrics;

  // 黑色宽线垫底、白色细线在上，深浅图像上都可辨
  static final Paint _outline = Paint()
    ..color = Colors.black
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;
  static final Paint _line = Paint()
    ..color = Colors.white
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  static final Paint _handleFill = Paint()..color = Colors.white;
  static final Paint _handleBorder = Paint()
    ..color = Colors.black
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final params = state.layerTransformer.params;
    if (params == null) return;
    final controller = state.canvasController;
    final frame = state.frame;
    Offset toScreen(Offset point) =>
        controller.canvasToScreen(point, frame: frame);

    final outline = Path()
      ..addPolygon(params.corners.map(toScreen).toList(), true);
    final top = toScreen(params.pointAt(const Offset(0, -1)));
    final rotate = toScreen(
      params.rotateHandle(metrics.rotateHandleOffset / controller.scale),
    );
    for (final paint in [_outline, _line]) {
      canvas.drawPath(outline, paint);
      canvas.drawLine(top, rotate, paint);
    }

    // 触屏命中区比可见手柄大，手柄只画到便于辨认的尺寸
    final side = (metrics.hitRadius * 2 / 3).clamp(8.0, 14.0);
    canvas.drawCircle(rotate, side / 2, _handleFill);
    canvas.drawCircle(rotate, side / 2, _handleBorder);
    for (final handle in TransformHandle.values) {
      final rect = Rect.fromCenter(
        center: toScreen(params.pointAt(handle.unit)),
        width: side,
        height: side,
      );
      canvas.drawRect(rect, _handleFill);
      canvas.drawRect(rect, _handleBorder);
    }
  }

  @override
  bool shouldRepaint(TransformOverlayPainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.metrics != metrics;
}
