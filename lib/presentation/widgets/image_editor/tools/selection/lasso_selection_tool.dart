import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/editor_state.dart';
import 'base_selection_tool.dart';

/// 套索选区工具（自由选区）
class LassoSelectionTool extends BaseSelectionTool {
  final List<Offset> _points = [];

  @override
  String get id => 'lasso_selection';

  @override
  String get name => 'Lasso Selection';

  @override
  IconData get icon => Icons.gesture;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyL;

  @override
  String? get helpText =>
      'Hold and drag to draw a freeform selection. Release to close it automatically.';

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    final pos = event.localPosition;
    if (beginOutlineDrag(state, pos)) return;

    state.clearPreview();
    _points
      ..clear()
      ..add(pos);
    _updatePreviewPath(state);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (updateOutlineDrag(state, event.localPosition)) return;

    if (_points.isNotEmpty) {
      final point = event.localPosition;
      if ((_points.last - point).distance > 3) {
        _points.add(point);
        _updatePreviewPath(state);
      }
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (endOutlineDrag(state)) return;
    if (_points.isEmpty) return;

    commitNewSelection(state, _points.length >= 3 ? (_createPath()..close()) : null);
    _points.clear();
  }

  @override
  void onSelectionCancel() {
    _points.clear();
  }

  void _updatePreviewPath(EditorState state) {
    if (_points.length < 2) {
      state.setPreviewPath(null);
      return;
    }

    final path = _createPath();
    path.lineTo(_points.first.dx, _points.first.dy);
    state.setPreviewPath(path);
  }

  Path _createPath() {
    final path = Path();
    if (_points.isEmpty) return path;

    path.moveTo(_points.first.dx, _points.first.dy);

    if (_points.length <= 2) {
      for (int i = 1; i < _points.length; i++) {
        path.lineTo(_points[i].dx, _points[i].dy);
      }
    } else {
      for (int i = 1; i < _points.length - 1; i++) {
        final p0 = _points[i];
        final p1 = _points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(_points.last.dx, _points.last.dy);
    }

    return path;
  }
}
