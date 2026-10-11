import 'package:flutter/material.dart';

import '../core/editor_state.dart';
import 'focused_overlay_painter.dart';

/// 把文档坐标中的聚焦区与上下文裁切区按视图变换投到屏幕上绘制
class FocusedContextOverlayPainter extends CustomPainter {
  FocusedContextOverlayPainter({
    required this.state,
    required this.focusAreaRect,
    required this.contextCrop,
    super.repaint,
  });

  final EditorState state;
  final Rect focusAreaRect;
  final Rect contextCrop;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = state.canvasController
        .getTransformMatrix(state.frame)
        .storage;
    final screenSelectionPath = (Path()..addRect(focusAreaRect)).transform(
      matrix,
    );
    final screenContextPath = (Path()..addRect(contextCrop)).transform(matrix);

    FocusedOverlayPainter(
      contextPath: screenContextPath,
      focusPath: screenSelectionPath,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant FocusedContextOverlayPainter oldDelegate) {
    return contextCrop != oldDelegate.contextCrop ||
        focusAreaRect != oldDelegate.focusAreaRect ||
        state != oldDelegate.state;
  }
}
