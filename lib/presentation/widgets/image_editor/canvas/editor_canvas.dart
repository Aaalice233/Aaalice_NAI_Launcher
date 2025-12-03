import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import 'layer_painter.dart';

/// 编辑器画布组件
/// 处理绑制、手势和键盘交互
class EditorCanvas extends StatefulWidget {
  final EditorState state;

  const EditorCanvas({
    super.key,
    required this.state,
  });

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas>
    with SingleTickerProviderStateMixin {
  // 键盘状态
  bool _isSpacePressed = false;
  bool _isShiftPressed = false;
  bool _isCtrlPressed = false;
  bool _isAltPressed = false;

  // 平移状态
  bool _isPanning = false;
  Offset? _lastPanPosition;

  // 缩放手势的初始scale（用于双指缩放）
  double _initialScale = 1.0;

  // 光标位置
  Offset? _cursorPosition;

  // 选区动画控制器
  late AnimationController _selectionAnimationController;

  // 焦点节点
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();
  }

  @override
  void dispose() {
    _selectionAnimationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        onPointerHover: _handlePointerHover,
        child: GestureDetector(
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          child: MouseRegion(
            cursor: _getCursor(),
            onExit: (_) {
              setState(() {
                _cursorPosition = null;
              });
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 更新视口尺寸
                widget.state.canvasController.setViewportSize(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );

                return ClipRect(
                  child: Stack(
                    children: [
                      // 背景
                      Positioned.fill(
                        child: Container(
                          color: Colors.grey.shade800,
                        ),
                      ),

                      // 图层绑制
                      Positioned.fill(
                        child: CustomPaint(
                          painter: LayerPainter(state: widget.state),
                          isComplex: true,
                          willChange: true,
                        ),
                      ),

                      // 选区绑制
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SelectionPainter(
                            state: widget.state,
                            animation: _selectionAnimationController,
                          ),
                        ),
                      ),

                      // 光标绘制
                      if (_cursorPosition != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CursorPainter(
                              state: widget.state,
                              cursorPosition: _cursorPosition,
                            ),
                            willChange: true,
                          ),
                        ),

                      // 拾色器预览
                      if (widget.state.currentTool?.id == 'color_picker')
                        _buildColorPickerOverlay(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 构建拾色器预览覆盖层
  Widget _buildColorPickerOverlay() {
    final tool = widget.state.currentTool;
    if (tool == null) return const SizedBox.shrink();

    final cursor = tool.buildCursor(widget.state);
    if (cursor == null) return const SizedBox.shrink();

    return cursor;
  }

  /// 同步修饰键状态
  /// 用于处理窗口切换后状态不同步的问题
  void _syncModifierKeys() {
    final keyboard = HardwareKeyboard.instance;
    _isShiftPressed = keyboard.isShiftPressed;
    _isCtrlPressed = keyboard.isControlPressed;
    _isAltPressed = keyboard.isAltPressed;
  }

  /// 获取光标样式
  MouseCursor _getCursor() {
    if (_isPanning || _isSpacePressed) {
      return SystemMouseCursors.grab;
    }

    final tool = widget.state.currentTool;
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

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isUp = event is KeyUpEvent;

    // 同步修饰键状态（使用 HardwareKeyboard 确保状态准确）
    // 这可以处理窗口切换后状态不同步的问题
    _syncModifierKeys();

    // 更新空格键状态
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (isDown) _isSpacePressed = true;
      if (isUp) _isSpacePressed = false;
      setState(() {});
      return KeyEventResult.handled;
    }

    // Shift 键
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      if (isDown) _isShiftPressed = true;
      if (isUp) _isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      return KeyEventResult.handled;
    }

    // Ctrl 键
    if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
        event.logicalKey == LogicalKeyboardKey.controlRight) {
      if (isDown) _isCtrlPressed = true;
      if (isUp) _isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
      return KeyEventResult.handled;
    }

    // Alt 键
    if (event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight) {
      if (isDown) _isAltPressed = true;
      if (isUp) _isAltPressed = HardwareKeyboard.instance.isAltPressed;
      return KeyEventResult.handled;
    }

    // 快捷键处理
    if (isDown && _isCtrlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyZ:
          if (_isShiftPressed) {
            widget.state.redo();
          } else {
            widget.state.undo();
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyY:
          widget.state.redo();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit0:
          widget.state.canvasController.resetTo100();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.equal:
        case LogicalKeyboardKey.add:
          widget.state.canvasController.zoomIn();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.minus:
          widget.state.canvasController.zoomOut();
          return KeyEventResult.handled;
      }
    }

    // 工具快捷键
    if (isDown && !_isCtrlPressed) {
      for (final tool in widget.state.tools) {
        if (tool.shortcutKey == event.logicalKey) {
          widget.state.setTool(tool);
          return KeyEventResult.handled;
        }
      }

      // 其他快捷键
      switch (event.logicalKey) {
        case LogicalKeyboardKey.escape:
          widget.state.cancelStroke();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
        case LogicalKeyboardKey.backspace:
          if (widget.state.selectionPath != null) {
            widget.state.clearSelection();
          }
          return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// 处理鼠标滚轮
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (_isCtrlPressed) {
        // Ctrl + 滚轮 = 缩放
        final delta = event.scrollDelta.dy;
        if (delta < 0) {
          widget.state.canvasController.zoomIn(focalPoint: event.localPosition);
        } else {
          widget.state.canvasController.zoomOut(focalPoint: event.localPosition);
        }
      } else {
        // 滚轮 = 平移
        widget.state.canvasController.pan(
          Offset(-event.scrollDelta.dx, -event.scrollDelta.dy),
        );
      }
    }
  }

  /// 处理鼠标悬停
  void _handlePointerHover(PointerHoverEvent event) {
    setState(() {
      _cursorPosition = event.localPosition;
    });
  }

  /// 处理缩放/平移手势开始
  void _handleScaleStart(ScaleStartDetails details) {
    // 空格按下时进入平移模式
    if (_isSpacePressed || details.pointerCount > 1) {
      _isPanning = true;
      _lastPanPosition = details.focalPoint;
      // 保存手势开始时的缩放比例，用于计算增量缩放
      _initialScale = widget.state.canvasController.scale;
      setState(() {});
      return;
    }

    // 更新光标位置
    setState(() {
      _cursorPosition = details.localFocalPoint;
    });

    // 触发工具的指针按下
    final tool = widget.state.currentTool;
    if (tool != null) {
      // 将屏幕坐标转换为画布坐标
      final canvasPosition = widget.state.canvasController.screenToCanvas(
        details.localFocalPoint,
      );
      tool.onPointerDown(
        PointerDownEvent(position: canvasPosition),
        widget.state,
      );
    }
  }

  /// 处理缩放/平移手势更新
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isPanning) {
      // 平移模式
      if (_lastPanPosition != null) {
        final delta = details.focalPoint - _lastPanPosition!;
        widget.state.canvasController.pan(delta);
        _lastPanPosition = details.focalPoint;
      }

      // 双指缩放：使用初始scale乘以手势累积scale
      if (details.pointerCount > 1 && details.scale != 1.0) {
        final newScale = _initialScale * details.scale;
        widget.state.canvasController.setScale(
          newScale,
          focalPoint: details.localFocalPoint,
        );
      }
      return;
    }

    // 更新光标位置（保持屏幕坐标用于显示）
    setState(() {
      _cursorPosition = details.localFocalPoint;
    });

    // 触发工具的指针移动
    final tool = widget.state.currentTool;
    if (tool != null) {
      // 将屏幕坐标转换为画布坐标
      final canvasPosition = widget.state.canvasController.screenToCanvas(
        details.localFocalPoint,
      );
      tool.onPointerMove(
        PointerMoveEvent(position: canvasPosition),
        widget.state,
      );
    }
  }

  /// 处理缩放/平移手势结束
  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isPanning) {
      _isPanning = false;
      _lastPanPosition = null;
      setState(() {});
      return;
    }

    // 触发工具的指针抬起
    final tool = widget.state.currentTool;
    if (tool != null) {
      // 使用最后的光标位置转换为画布坐标
      final canvasPosition = _cursorPosition != null
          ? widget.state.canvasController.screenToCanvas(_cursorPosition!)
          : Offset.zero;
      tool.onPointerUp(
        PointerUpEvent(position: canvasPosition),
        widget.state,
      );
    }
  }
}
