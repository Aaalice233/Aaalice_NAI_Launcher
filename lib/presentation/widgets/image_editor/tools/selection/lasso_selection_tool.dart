import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/editor_state.dart';
import 'base_selection_tool.dart';

/// 套索选区工具（自由选区）
class LassoSelectionTool extends BaseSelectionTool {
  /// 采集的点
  final List<Offset> _points = [];

  @override
  String get id => 'lasso_selection';

  @override
  String get name => '套索选区';

  @override
  IconData get icon => Icons.gesture;

  @override
  LogicalKeyboardKey get shortcutKey => LogicalKeyboardKey.keyL;

  @override
  String? get helpText => '按住鼠标拖动绘制自由形状选区，松开自动闭合';

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    // 开始绘制时清除旧选区
    state.clearSelection(saveHistory: false);
    state.clearPreview();
    _points.clear();
    final point = event.localPosition;
    _points.add(point);
    _updatePreviewPath(state);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (_points.isNotEmpty) {
      final point = event.localPosition;

      // 简化路径：只有距离足够远才添加新点
      if (_points.isEmpty || (_points.last - point).distance > 3) {
        _points.add(point);
        _updatePreviewPath(state);
      }
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (_points.length >= 3) {
      final path = _createPath();
      path.close(); // 闭合路径
      state.setSelection(path); // 确认选区（自动清除预览）
    } else {
      state.clearPreview();
    }
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
    // 添加回到起点的虚线预览
    path.lineTo(_points.first.dx, _points.first.dy);
    state.setPreviewPath(path);
  }

  Path _createPath() {
    final path = Path();
    if (_points.isEmpty) return path;

    path.moveTo(_points.first.dx, _points.first.dy);

    // 使用平滑曲线连接点
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
