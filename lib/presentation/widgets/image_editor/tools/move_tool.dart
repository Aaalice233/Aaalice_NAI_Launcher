import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import 'move_tool_panel.dart';
import 'tool_base.dart';

/// 移动工具：有选区时移动当前图层在选区内的像素，否则平移整个图层；
/// 拖动外接框的缩放或旋转手柄进入自由变换
class MoveTool extends EditorTool {
  static const String toolId = 'move';

  /// 本次拖动由自由变换接管
  bool _transforming = false;

  @override
  String get id => toolId;

  @override
  String get name => 'Move';

  @override
  IconData get icon => Icons.open_with;

  @override
  LogicalKeyboardKey? get shortcutKey => LogicalKeyboardKey.keyV;

  /// Alt 用于以中心为基准缩放，不切换临时拾色器
  @override
  bool get handlesAltKey => true;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    _transforming = state.layerTransformer.pointerDown(
      event.localPosition,
      event.kind,
    );
    if (!_transforming) state.layerMover.begin(event.localPosition);
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    if (_transforming) {
      final keyboard = HardwareKeyboard.instance;
      state.layerTransformer.pointerMove(
        event.localPosition,
        shift: keyboard.isShiftPressed,
        alt: keyboard.isAltPressed,
      );
    } else {
      state.layerMover.update(event.localPosition);
    }
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    if (_transforming) {
      state.layerTransformer.pointerUp();
    } else {
      state.layerMover.end();
    }
    _transforming = false;
  }

  @override
  void onPointerHover(PointerHoverEvent event, EditorState state) {
    state.layerTransformer.hover(event.localPosition, event.kind);
  }

  @override
  void onPointerCancel(EditorState state) {
    state.layerTransformer.pointerCancel();
    state.layerMover.cancel();
    state.cancelStroke();
    _transforming = false;
  }

  /// 换工具即确认变换，已写回的结果保留
  @override
  void onDeactivateFast(EditorState state) {
    state.layerMover.cancel();
    state.layerTransformer.apply();
    _transforming = false;
  }

  @override
  bool onArrowNudge(EditorState state, Offset delta) {
    final transformer = state.layerTransformer;
    if (transformer.isActive) {
      transformer.nudge(delta);
    } else {
      state.layerMover.nudge(delta);
    }
    return true;
  }

  @override
  bool onConfirm(EditorState state) {
    final transformer = state.layerTransformer;
    if (!transformer.isActive) return false;
    transformer.apply();
    return true;
  }

  @override
  bool onEscape(EditorState state) {
    final transformer = state.layerTransformer;
    if (!transformer.isActive) return false;
    transformer.cancel();
    return true;
  }

  @override
  bool onMultiTouchStart(EditorState state, Offset focal) =>
      state.layerTransformer.pinchStart(focal);

  @override
  void onMultiTouchUpdate(
    EditorState state,
    Offset focal,
    double scale,
    double rotation,
  ) {
    state.layerTransformer.pinchUpdate(focal, scale, rotation);
  }

  @override
  void onMultiTouchEnd(EditorState state) => state.layerTransformer.pinchEnd();

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return MoveToolPanel(state: state);
  }
}
