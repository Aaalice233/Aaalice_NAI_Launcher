import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_state.dart';

/// 键盘状态管理
class KeyboardState {
  bool isSpacePressed = false;
  bool isShiftPressed = false;
  bool isCtrlPressed = false;
  bool isAltPressed = false;

  /// 从硬件键盘同步状态
  void syncFromHardware() {
    final keyboard = HardwareKeyboard.instance;
    isShiftPressed = keyboard.isShiftPressed;
    isCtrlPressed = keyboard.isControlPressed;
    isAltPressed = keyboard.isAltPressed;
  }

  /// 从事件更新状态
  void updateFromEvent(KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (isDown) isSpacePressed = true;
      if (isUp) isSpacePressed = false;
    }

    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      if (isDown) isShiftPressed = true;
      if (isUp) isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    }

    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight) {
      if (isDown) isCtrlPressed = true;
      if (isUp) isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    }

    if (event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight) {
      if (isDown) isAltPressed = true;
      if (isUp) isAltPressed = HardwareKeyboard.instance.isAltPressed;
    }
  }

  /// 重置状态
  void reset() {
    isSpacePressed = false;
    isShiftPressed = false;
    isCtrlPressed = false;
    isAltPressed = false;
  }
}

/// 手势状态管理
class GestureState {
  /// 是否正在平移
  bool isPanning = false;

  /// 是否中键平移
  bool isMiddleButtonPanning = false;

  /// 是否主按钮（左键）按下
  bool isPrimaryButtonDown = false;

  /// 是否处于笔刷大小调整模式
  bool isBrushSizeMode = false;

  /// 上一次平移位置
  Offset? lastPanPosition;

  /// 笔刷大小调整起始位置
  Offset? brushSizeStartPosition;

  /// 初始笔刷大小
  double initialBrushSize = 0;

  /// 初始缩放比例
  double initialScale = 1.0;

  /// 光标位置
  Offset? cursorPosition;

  /// 重置状态
  void reset() {
    isPanning = false;
    isMiddleButtonPanning = false;
    isPrimaryButtonDown = false;
    isBrushSizeMode = false;
    lastPanPosition = null;
    brushSizeStartPosition = null;
    initialBrushSize = 0;
    initialScale = 1.0;
  }
}

/// 输入处理器
/// 负责处理键盘、鼠标、手势等输入事件
class InputHandler {
  final EditorState state;
  final KeyboardState keyboard = KeyboardState();
  final GestureState gesture = GestureState();

  /// 焦点节点引用（用于检查焦点状态）
  final FocusNode focusNode;

  /// 状态变化回调（通知 UI 更新光标等）
  final VoidCallback onStateChanged;

  InputHandler({
    required this.state,
    required this.focusNode,
    required this.onStateChanged,
  });

  /// 处理键盘事件
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    // 同步修饰键状态
    keyboard.syncFromHardware();
    keyboard.updateFromEvent(event);

    // 空格键 - 进入平移模式
    if (event.logicalKey == LogicalKeyboardKey.space) {
      onStateChanged();
      return KeyEventResult.handled;
    }

    // Shift 键
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      return KeyEventResult.handled;
    }

    // Ctrl 键
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight) {
      return KeyEventResult.handled;
    }

    // Alt 键 - 临时切换到拾色器
    if (event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight) {
      // 仅处理 DOWN 和 UP 事件，忽略 REPEAT 事件
      if (isDown) {
        state.enterTemporaryColorPicker();
      } else if (isUp && !keyboard.isAltPressed) {
        state.exitTemporaryColorPicker();
      }
      // 不调用 onStateChanged() - toolNotifier 已自动更新 UI
      // 避免 setState 打断事件流（如滚轮）
      return KeyEventResult.handled;
    }

    // Ctrl 快捷键
    if (isDown && keyboard.isCtrlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyZ:
          if (keyboard.isShiftPressed) {
            state.redo();
          } else {
            state.undo();
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyY:
          state.redo();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit0:
          state.canvasController.resetTo100(canvasSize: state.canvasSize);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.equal:
        case LogicalKeyboardKey.add:
          state.canvasController.zoomIn();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.minus:
          state.canvasController.zoomOut();
          return KeyEventResult.handled;
      }
    }

    // Krita 风格视图快捷键（无修饰键）
    if (isDown && !keyboard.isCtrlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.digit1:
          state.canvasController.resetTo100(canvasSize: state.canvasSize);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit2:
          state.canvasController.fitToHeight(state.canvasSize);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit3:
          state.canvasController.fitToWidth(state.canvasSize);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit4:
          state.canvasController.rotateLeft();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit5:
          state.canvasController.resetRotation();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit6:
          state.canvasController.rotateRight();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyF:
          state.canvasController.toggleMirrorHorizontal();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyR:
          state.canvasController.resetView(state.canvasSize);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyX:
          state.swapColors();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.bracketLeft:
          state.setBrushSize(state.brushSize - 5);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.bracketRight:
          state.setBrushSize(state.brushSize + 5);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyI:
          state.decreaseBrushOpacity();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyO:
          state.increaseBrushOpacity();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.escape:
          state.cancelStroke();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
        case LogicalKeyboardKey.backspace:
          if (state.selectionPath != null) {
            state.clearSelection();
          }
          return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// 硬件键盘处理（优先级高于 IME，用于工具快捷键）
  bool handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!focusNode.hasFocus) return false;
    if (HardwareKeyboard.instance.isControlPressed) return false;

    // 处理工具快捷键
    for (final tool in state.tools) {
      if (tool.shortcutKey == event.logicalKey) {
        state.setTool(tool);
        return true;
      }
    }

    return false;
  }

  /// 处理鼠标滚轮
  void handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy;
      if (delta < 0) {
        state.canvasController.zoomIn(focalPoint: event.localPosition);
      } else {
        state.canvasController.zoomOut(focalPoint: event.localPosition);
      }
    }
  }

  /// 处理鼠标悬停
  void handlePointerHover(PointerHoverEvent event) {
    gesture.cursorPosition = event.localPosition;
    onStateChanged();

    // 触发工具的悬停事件
    final tool = state.currentTool;
    if (tool != null) {
      final canvasPosition = state.canvasController.screenToCanvas(
        event.localPosition,
        canvasSize: state.canvasSize,
      );
      tool.onPointerHover(
        PointerHoverEvent(position: canvasPosition),
        state,
      );
    }
  }

  /// 处理指针按下
  void handlePointerDown(PointerDownEvent event) {
    keyboard.syncFromHardware();
    gesture.isPrimaryButtonDown = (event.buttons & kPrimaryButton) != 0;

    // 中键平移
    if (event.buttons == kMiddleMouseButton) {
      gesture.isMiddleButtonPanning = true;
      gesture.lastPanPosition = event.position;
      onStateChanged();
      return;
    }

    // 右键 - 不触发绘画
    if (event.buttons == kSecondaryMouseButton) {
      return;
    }

    // Shift + 左键 - 笔刷大小调整
    if (HardwareKeyboard.instance.isShiftPressed &&
        event.buttons == kPrimaryButton) {
      final tool = state.currentTool;
      if (tool != null && (tool.id == 'brush' || tool.id == 'eraser')) {
        gesture.isBrushSizeMode = true;
        gesture.brushSizeStartPosition = event.localPosition;
        gesture.initialBrushSize = state.brushSize;
        onStateChanged();
        return;
      }
    }

    // 直接调用工具的 onPointerDown（使用原始指针事件，避免 GestureDetector 延迟）
    if (gesture.isPrimaryButtonDown && !keyboard.isSpacePressed) {
      final tool = state.currentTool;
      if (tool != null) {
        final canvasPosition = state.canvasController.screenToCanvas(
          event.localPosition,
          canvasSize: state.canvasSize,
        );
        tool.onPointerDown(
          PointerDownEvent(position: canvasPosition),
          state,
        );
      }
    }
  }

  /// 处理指针抬起
  void handlePointerUp(PointerUpEvent event) {
    // 结束中键平移
    if (gesture.isMiddleButtonPanning) {
      gesture.isMiddleButtonPanning = false;
      gesture.lastPanPosition = null;
      onStateChanged();
    }

    // 结束笔刷大小调整
    if (gesture.isBrushSizeMode) {
      gesture.isBrushSizeMode = false;
      gesture.brushSizeStartPosition = null;
      gesture.isPrimaryButtonDown = false;
      onStateChanged();
      return;
    }

    // 直接调用工具的 onPointerUp（使用原始指针事件，避免 GestureDetector 延迟）
    if (gesture.isPrimaryButtonDown && !gesture.isPanning) {
      final tool = state.currentTool;
      if (tool != null) {
        final canvasPosition = state.canvasController.screenToCanvas(
          event.localPosition,
          canvasSize: state.canvasSize,
        );
        tool.onPointerUp(
          PointerUpEvent(position: canvasPosition),
          state,
        );
      }
      gesture.isPrimaryButtonDown = false;
    }
  }

  /// 处理指针移动
  void handlePointerMove(PointerMoveEvent event) {
    // 中键平移
    if (gesture.isMiddleButtonPanning && gesture.lastPanPosition != null) {
      final delta = event.position - gesture.lastPanPosition!;
      state.canvasController.pan(delta);
      gesture.lastPanPosition = event.position;
      gesture.cursorPosition = event.localPosition;
      onStateChanged();
      return;
    }

    // 笔刷大小调整
    if (gesture.isBrushSizeMode && gesture.brushSizeStartPosition != null) {
      final deltaX =
          event.localPosition.dx - gesture.brushSizeStartPosition!.dx;
      final sizeFactor = 1.0 + deltaX / 200.0;
      final newSize = (gesture.initialBrushSize * sizeFactor).clamp(1.0, 500.0);
      state.setBrushSize(newSize);
      gesture.cursorPosition = gesture.brushSizeStartPosition;
      onStateChanged();
      return;
    }

    // 正常模式 - 更新光标位置
    gesture.cursorPosition = event.localPosition;
    onStateChanged();

    // 直接调用工具的 onPointerMove（使用原始指针事件，避免 GestureDetector 延迟）
    if (gesture.isPrimaryButtonDown &&
        !gesture.isPanning &&
        !keyboard.isSpacePressed) {
      final tool = state.currentTool;
      if (tool != null) {
        final canvasPosition = state.canvasController.screenToCanvas(
          event.localPosition,
          canvasSize: state.canvasSize,
        );
        tool.onPointerMove(
          PointerMoveEvent(position: canvasPosition),
          state,
        );
      }
    }
  }

  /// 处理鼠标退出
  void handleMouseExit(PointerExitEvent event) {
    if (HardwareKeyboard.instance.isAltPressed) return;
    gesture.cursorPosition = null;
    onStateChanged();
  }

  /// 处理缩放/平移手势开始
  void handleScaleStart(ScaleStartDetails details) {
    // 笔刷大小调整模式
    if (gesture.isBrushSizeMode) {
      return;
    }

    keyboard.syncFromHardware();

    // Shift + 点击进入笔刷大小调整模式
    if (HardwareKeyboard.instance.isShiftPressed) {
      final tool = state.currentTool;
      if (tool != null && (tool.id == 'brush' || tool.id == 'eraser')) {
        gesture.isBrushSizeMode = true;
        gesture.brushSizeStartPosition = details.localFocalPoint;
        gesture.initialBrushSize = state.brushSize;
        onStateChanged();
        return;
      }
    }

    // 空格或多指 - 平移模式
    if (keyboard.isSpacePressed || details.pointerCount > 1) {
      gesture.isPanning = true;
      gesture.lastPanPosition = details.focalPoint;
      gesture.initialScale = state.canvasController.scale;
      onStateChanged();
      return;
    }

    // 更新光标位置
    gesture.cursorPosition = details.localFocalPoint;
    onStateChanged();
    // 工具事件已移至 handlePointerDown 直接处理
  }

  /// 处理缩放/平移手势更新
  void handleScaleUpdate(ScaleUpdateDetails details) {
    // 笔刷大小调整模式
    if (gesture.isBrushSizeMode) {
      if (gesture.brushSizeStartPosition != null) {
        final deltaX =
            details.localFocalPoint.dx - gesture.brushSizeStartPosition!.dx;
        final sizeFactor = 1.0 + deltaX / 200.0;
        final newSize =
            (gesture.initialBrushSize * sizeFactor).clamp(1.0, 500.0);
        state.setBrushSize(newSize);
        gesture.cursorPosition = gesture.brushSizeStartPosition;
        onStateChanged();
      }
      return;
    }

    if (gesture.isPanning) {
      // 平移
      if (gesture.lastPanPosition != null) {
        final delta = details.focalPoint - gesture.lastPanPosition!;
        state.canvasController.pan(delta);
        gesture.lastPanPosition = details.focalPoint;
      }

      // 双指缩放
      if (details.pointerCount > 1 && details.scale != 1.0) {
        final newScale = gesture.initialScale * details.scale;
        state.canvasController.setScale(
          newScale,
          focalPoint: details.localFocalPoint,
        );
      }
      return;
    }

    // 更新光标位置
    gesture.cursorPosition = details.localFocalPoint;
    onStateChanged();
    // 工具事件已移至 handlePointerMove 直接处理
  }

  /// 处理缩放/平移手势结束
  void handleScaleEnd(ScaleEndDetails details) {
    // 笔刷大小调整模式
    if (gesture.isBrushSizeMode) {
      return;
    }

    if (gesture.isPanning) {
      gesture.isPanning = false;
      gesture.lastPanPosition = null;
      onStateChanged();
      return;
    }
    // 工具事件已移至 handlePointerUp 直接处理
  }

  /// 获取当前光标样式
  MouseCursor getCursor() {
    if (gesture.isPanning ||
        keyboard.isSpacePressed ||
        gesture.isMiddleButtonPanning) {
      return SystemMouseCursors.grab;
    }

    if (gesture.isBrushSizeMode) {
      return SystemMouseCursors.resizeLeftRight;
    }

    // Alt 键按下时显示拾色器光标
    if (keyboard.isAltPressed) {
      return SystemMouseCursors.precise;
    }

    final tool = state.currentTool;
    if (tool == null) return SystemMouseCursors.basic;

    switch (tool.id) {
      case 'brush':
      case 'eraser':
        return SystemMouseCursors.none;
      case 'rect_selection':
      case 'ellipse_selection':
      case 'lasso_selection':
        return SystemMouseCursors.precise;
      case 'color_picker':
        return SystemMouseCursors.precise;
      default:
        return SystemMouseCursors.basic;
    }
  }

  /// 获取当前光标位置
  Offset? get cursorPosition => gesture.cursorPosition;
}
