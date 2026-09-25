import 'package:flutter/material.dart';

import '../core/editor_state.dart';
import '../tools/clone_stamp_tool.dart';

/// 仿制图章源点准星，按屏幕像素定尺寸，缩放视图时大小不变
class CloneSourceMarkerPainter extends CustomPainter {
  CloneSourceMarkerPainter({required this.state, required this.tool})
    : super(
        repaint: Listenable.merge([
          tool.sourceMarker,
          state.canvasController,
          state.frameNotifier,
        ]),
      );

  final EditorState state;
  final CloneStampTool tool;

  // 中心留空，露出正被取样的像素
  static const double _gap = 3;
  static const double _armEnd = 11;

  // 黑色宽线垫底、白色细线在上，深浅图像上都可辨
  static final Paint _outline = Paint()
    ..color = Colors.black
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  static final Paint _line = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.25
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static const List<Offset> _directions = [
    Offset(1, 0),
    Offset(-1, 0),
    Offset(0, 1),
    Offset(0, -1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final position = tool.sourceMarker.value;
    if (position == null) return;

    // 与图层渲染同一矩阵；canvasToScreen 在旋转叠加镜像时次序不同，会偏离像素
    final center = MatrixUtils.transformPoint(
      state.canvasController.getTransformMatrix(state.frame),
      position,
    );
    for (final paint in [_outline, _line]) {
      for (final direction in _directions) {
        canvas.drawLine(
          center + direction * _gap,
          center + direction * _armEnd,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CloneSourceMarkerPainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.tool != tool;
}
