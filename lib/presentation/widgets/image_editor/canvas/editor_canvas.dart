import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_state.dart';
import '../core/input_handler.dart';
import 'layer_painter.dart';
import 'stroke_preview_painter.dart';

/// 编辑器画布组件
/// 处理绑制、手势和键盘交互
class EditorCanvas extends StatefulWidget {
  final EditorState state;
  final bool suppressSelectionOverlay;
  final bool showTransparentCanvasBackground;
  final bool Function(Offset localPosition)? shouldSuppressPointerInput;

  const EditorCanvas({
    super.key,
    required this.state,
    this.suppressSelectionOverlay = false,
    this.showTransparentCanvasBackground = false,
    this.shouldSuppressPointerInput,
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
  final Set<int> _suppressedPointers = <int>{};

  @override
  void initState() {
    super.initState();

    // 初始化输入处理器
    _inputHandler = InputHandler(
      state: widget.state,
      focusNode: _focusNode,
      onStateChanged: () => setState(() {}),
    );

    // 初始化选区动画（仅在存在选区或预览路径时循环播放）
    _selectionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    widget.state.renderNotifier.addListener(_syncSelectionAnimation);
    _syncSelectionAnimation();

    // 添加硬件键盘监听（优先级高于 IME，解决中文输入法下快捷键失效问题）
    HardwareKeyboard.instance.addHandler(_inputHandler.handleHardwareKey);
  }

  void _syncSelectionAnimation() {
    final hasSelection =
        widget.state.previewPath != null || widget.state.selectionPath != null;
    if (hasSelection && !_selectionAnimationController.isAnimating) {
      _selectionAnimationController.repeat();
    } else if (!hasSelection && _selectionAnimationController.isAnimating) {
      _selectionAnimationController.stop();
    }
  }

  @override
  void didUpdateWidget(EditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.renderNotifier.removeListener(_syncSelectionAnimation);
      widget.state.renderNotifier.addListener(_syncSelectionAnimation);
      _syncSelectionAnimation();
    }
  }

  @override
  void dispose() {
    widget.state.renderNotifier.removeListener(_syncSelectionAnimation);
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
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        onPointerMove: _handlePointerMove,
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
                  builder: (context, _, __) {
                    // Alt 模式或拾色器工具时都显示拾色器界面
                    final isColorPicker = _inputHandler.isColorPickerActive;
                    final cursorPosition = _inputHandler.cursorPosition;

                    return ClipRect(
                      child: Stack(
                        children: [
                          // 背景 - 独立重绘区域（静态内容）
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: Container(color: Colors.grey.shade800),
                            ),
                          ),

                          // 图层绘制 - 不使用 RepaintBoundary 以避免缓存问题
                          Positioned.fill(
                            child: CustomPaint(
                              painter: LayerPainter(
                                state: widget.state,
                                showTransparentCanvasBackground:
                                    widget.showTransparentCanvasBackground,
                              ),
                            ),
                          ),

                          // 当前笔画预览 - 仅实时预览，不写入图层数据
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: StrokePreviewPainter(
                                  state: widget.state,
                                ),
                                willChange: true,
                              ),
                            ),
                          ),

                          // 选区绘制 - 独立重绘区域（有动画，频繁更新）
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: SelectionPainter(
                                  state: widget.state,
                                  animation: _selectionAnimationController,
                                  suppressSelectionOverlay:
                                      widget.suppressSelectionOverlay,
                                ),
                              ),
                            ),
                          ),

                          // 光标绘制 - 独立重绘区域（每次指针移动都重绘，
                          // 不隔离会连带整幅图层重绘，willChange 也会污染整块画布的光栅缓存）
                          // Alt 模式下不显示笔刷光标（显示系统精确光标）
                          if (cursorPosition != null && !isColorPicker)
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: CursorPainter(state: widget.state),
                                  willChange: true,
                                ),
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

  void _handlePointerDown(PointerDownEvent event) {
    if ((event.buttons & kPrimaryButton) != 0 &&
        _shouldSuppressPointer(event)) {
      _suppressedPointers.add(event.pointer);
      widget.state.cancelStroke();
      return;
    }

    _inputHandler.handlePointerDown(event);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_suppressedPointers.contains(event.pointer)) {
      return;
    }

    _inputHandler.handlePointerMove(event);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_suppressedPointers.remove(event.pointer)) {
      // down 被抑制但 GestureDetector 仍收到了整段手势，这里必须补回状态出口
      _inputHandler.cancelTransientGestures();
      return;
    }

    _inputHandler.handlePointerUp(event);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_suppressedPointers.remove(event.pointer)) {
      _inputHandler.cancelTransientGestures();
      return;
    }
    _inputHandler.handlePointerCancel(event);
  }

  bool _shouldSuppressPointer(PointerDownEvent event) {
    return widget.shouldSuppressPointerInput?.call(event.localPosition) ??
        false;
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
