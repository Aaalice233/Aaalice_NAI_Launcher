import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'canvas_controller.dart';
import 'editor_state.dart';

/// 视图控制动作，键盘快捷键、桌面工具栏与触屏菜单共用同一份定义
enum EditorViewAction {
  fitToWindow(Icons.fit_screen),
  actualSize(Icons.looks_one_outlined, LogicalKeyboardKey.digit1),
  fitWidth(Icons.width_full, LogicalKeyboardKey.digit3),
  fitHeight(Icons.height, LogicalKeyboardKey.digit2),
  rotateLeft(Icons.rotate_left, LogicalKeyboardKey.digit4),
  rotateRight(Icons.rotate_right, LogicalKeyboardKey.digit6),
  resetRotation(Icons.settings_backup_restore, LogicalKeyboardKey.digit5),
  mirror(Icons.flip, LogicalKeyboardKey.keyF),
  resetView(Icons.restart_alt, LogicalKeyboardKey.keyR);

  const EditorViewAction(this.icon, [this.shortcutKey]);

  final IconData icon;

  /// 无修饰键时触发的快捷键
  final LogicalKeyboardKey? shortcutKey;

  String? get shortcutLabel => shortcutKey?.keyLabel.toUpperCase();

  /// 开关型动作需要把当前状态呈现为选中
  bool get isToggle => this == mirror;

  bool isActiveIn(CanvasController controller) =>
      this == mirror && controller.isMirroredHorizontally;

  /// 带快捷键的动作按键位顺序排列
  static final List<EditorViewAction> byShortcut =
      values.where((action) => action.shortcutKey != null).toList()
        ..sort((a, b) => a.shortcutLabel!.compareTo(b.shortcutLabel!));

  static EditorViewAction? forShortcut(LogicalKeyboardKey key) {
    for (final action in values) {
      if (action.shortcutKey == key) return action;
    }
    return null;
  }

  void perform(EditorState state) {
    final controller = state.canvasController;
    switch (this) {
      case fitToWindow:
        controller.fitToViewport(state.frame);
      case actualSize:
        controller.resetTo100(frame: state.frame);
      case fitWidth:
        controller.fitToWidth(state.frame);
      case fitHeight:
        controller.fitToHeight(state.frame);
      case rotateLeft:
        controller.rotateLeft();
      case rotateRight:
        controller.rotateRight();
      case resetRotation:
        controller.resetRotation();
      case mirror:
        controller.toggleMirrorHorizontal();
      case resetView:
        controller.resetView(state.frame);
    }
  }
}
