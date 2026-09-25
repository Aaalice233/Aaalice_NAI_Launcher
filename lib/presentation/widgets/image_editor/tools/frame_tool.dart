import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import '../frame/frame_tool_panel.dart';
import 'tool_base.dart';

/// 取景框工具：在框内按住拖动按 64 像素一格平移取景框，松手后一次性提交
class FrameTool extends EditorTool {
  static const String toolId = 'frame';

  Rect? _dragStartFrame;
  Offset? _dragStartPoint;

  @override
  String get id => toolId;

  @override
  String get name => 'Frame';

  @override
  IconData get icon => Icons.open_with;

  @override
  LogicalKeyboardKey? get shortcutKey => LogicalKeyboardKey.keyV;

  @override
  bool isAvailableIn(EditorState state) => state.frameCommands != null;

  @override
  void onPointerDown(PointerDownEvent event, EditorState state) {
    final commands = state.frameCommands;
    final frame = state.frame;
    if (commands == null ||
        !commands.canMoveFrame ||
        !frame.contains(event.localPosition)) {
      return;
    }
    _dragStartFrame = frame;
    _dragStartPoint = event.localPosition;
  }

  @override
  void onPointerMove(PointerMoveEvent event, EditorState state) {
    final startFrame = _dragStartFrame;
    final startPoint = _dragStartPoint;
    final commands = state.frameCommands;
    if (startFrame == null || startPoint == null || commands == null) return;
    state.setFramePreview(
      commands.resolveMove(startFrame, event.localPosition - startPoint),
    );
  }

  @override
  void onPointerUp(PointerUpEvent event, EditorState state) {
    final startFrame = _dragStartFrame;
    final movedFrame = state.framePreviewNotifier.value;
    _endDrag(state);
    final commands = state.frameCommands;
    if (startFrame == null || movedFrame == null || commands == null) return;
    commands.commitMove(startFrame, movedFrame);
  }

  @override
  void onPointerCancel(EditorState state) {
    _endDrag(state);
    state.cancelStroke();
  }

  @override
  void onDeactivateFast(EditorState state) => _endDrag(state);

  void _endDrag(EditorState state) {
    _dragStartFrame = null;
    _dragStartPoint = null;
    state.setFramePreview(null);
  }

  @override
  Widget buildSettingsPanel(BuildContext context, EditorState state) {
    return FrameToolPanel(state: state);
  }
}
