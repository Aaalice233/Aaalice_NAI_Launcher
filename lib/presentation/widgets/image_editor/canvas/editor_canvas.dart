import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import '../core/input_handler.dart';
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
  /// 输入处理器
  late InputHandler _inputHandler;

  /// 选区动画控制器
  late AnimationController _selectionAnimationController;

  /// 焦点节点
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // 初始化输入处理器
    _inputHandler = InputHandler(
      state: widget.state,
      focusNode: _focusNode,
      onStateChanged: () => setState(() {}),
    );

    // 初始化选区动画
    _selectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();

    // 添加硬件键盘监听（优先级高于 IME，解决中文输入法下快捷键失效问题）
    HardwareKeyboard.instance.addHandler(_inputHandler.handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_inputHandler.handleHardwareKey);
    _selectionAnimationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _inputHandler.handleKeyEvent,
      child: Listener(
        onPointerSignal: _inputHandler.handlePointerSignal,
        onPointerHover: _inputHandler.handlePointerHover,
        onPointerDown: _inputHandler.handlePointerDown,
        onPointerUp: _inputHandler.handlePointerUp,
        onPointerMove: _inputHandler.handlePointerMove,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onScaleStart: _inputHandler.handleScaleStart,
          onScaleUpdate: _inputHandler.handleScaleUpdate,
          onScaleEnd: _inputHandler.handleScaleEnd,
          child: MouseRegion(
            cursor: _inputHandler.getCursor(),
            onExit: _inputHandler.handleMouseExit,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 更新视口尺寸
                widget.state.canvasController.setViewportSize(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );

                // 使用 toolNotifier 监听工具切换（轻量级，不触发画布重绘）
                // renderNotifier 由 CustomPainter 内部监听
                return ValueListenableBuilder<String?>(
                  valueListenable: widget.state.toolNotifier,
                  builder: (context, toolId, _) {
                    // Alt 模式或拾色器工具时都显示拾色器界面
                    final isColorPicker = toolId == 'color_picker' ||
                        _inputHandler.keyboard.isAltPressed;
                    final cursorPosition = _inputHandler.cursorPosition;

                    return ClipRect(
                      child: Stack(
                        children: [
                          // 背景 - 独立重绘区域（静态内容）
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: Container(
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),

                          // 图层绘制 - 不使用 RepaintBoundary 以避免缓存问题
                          Positioned.fill(
                            child: CustomPaint(
                              painter: LayerPainter(state: widget.state),
                            ),
                          ),

                          // 选区绘制 - 独立重绘区域（有动画，频繁更新）
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: SelectionPainter(
                                  state: widget.state,
                                  animation: _selectionAnimationController,
                                ),
                              ),
                            ),
                          ),

                          // 光标绘制 - 高频更新，不使用 RepaintBoundary
                          // Alt 模式下不显示笔刷光标（显示系统精确光标）
                          if (cursorPosition != null && !isColorPicker)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: CursorPainter(
                                  state: widget.state,
                                  cursorPosition: cursorPosition,
                                ),
                                willChange: true,
                              ),
                            ),

                          // 拾色器预览
                          if (isColorPicker) ..._buildColorPickerOverlayList(),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 构建拾色器预览覆盖层列表
  List<Widget> _buildColorPickerOverlayList() {
    final tool = widget.state.currentTool;
    if (tool == null) return const [];

    final cursor = tool.buildCursor(
      widget.state,
      screenCursorPosition: _inputHandler.cursorPosition,
    );
    if (cursor == null) return const [];

    return [cursor];
  }
}
