import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../image_editor_controller.dart';
import '../tools/tool_type.dart';
import 'canvas_painter.dart';

/// 编辑器画布组件
class EditorCanvas extends StatefulWidget {
  final ImageEditorController controller;

  const EditorCanvas({
    super.key,
    required this.controller,
  });

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas>
    with SingleTickerProviderStateMixin {
  // Marching Ants 动画控制器
  late AnimationController _marchingAntsController;

  // 手势状态
  bool _isSpacePressed = false;
  bool _isPanning = false;
  bool _isShiftPressed = false;
  bool _isAltPressed = false;
  Offset? _lastPanPosition;
  double _lastScale = 1.0;

  // 选区绘制状态
  Offset? _selectionStart;
  Rect? _currentSelectionRect;

  // 是否已初始化视图
  bool _viewInitialized = false;

  @override
  void initState() {
    super.initState();
    _marchingAntsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();

    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _marchingAntsController.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 首次渲染时，适应视口大小
        if (!_viewInitialized && widget.controller.baseImage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.controller.fitToViewport(
              Size(constraints.maxWidth, constraints.maxHeight),
            );
            _viewInitialized = true;
          });
        }

        return Focus(
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: MouseRegion(
            cursor: _getCursor(),
            onHover: _handleHover,
            onExit: (_) => setState(() => _lastPointerPosition = null),
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              child: GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: ClipRect(
                  child: Stack(
                    children: [
                      // 棋盘格背景
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CheckerboardPainter(),
                        ),
                      ),

                      // 主画布
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CanvasPainter(
                            baseImage: widget.controller.baseImage,
                            strokes: widget.controller.imageStrokes,
                            currentStroke: widget.controller.currentStroke,
                            maskPath: widget.controller.maskPath,
                            currentTool: widget.controller.currentTool,
                            scale: widget.controller.scale,
                            offset: widget.controller.offset,
                          ),
                        ),
                      ),

                      // 选区预览（正在绘制的选区）
                      if (_currentSelectionRect != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SelectionPreviewPainter(
                              rect: _currentSelectionRect!,
                              isEllipse:
                                  widget.controller.currentTool == ToolType.ellipseSelect,
                              scale: widget.controller.scale,
                              offset: widget.controller.offset,
                              isSubtractive: _isAltPressed,
                            ),
                          ),
                        ),

                      // 遮罩叠加层预览（半透明）- 有遮罩时始终显示
                      if (widget.controller.maskPath != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: MaskOverlayPainter(
                              baseImage: widget.controller.baseImage,
                              maskPath: widget.controller.maskPath,
                              scale: widget.controller.scale,
                              offset: widget.controller.offset,
                            ),
                          ),
                        ),

                      // Marching Ants 动画 - 有遮罩时始终显示
                      if (widget.controller.maskPath != null)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _marchingAntsController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: MarchingAntsPainter(
                                  selectionPath: widget.controller.maskPath,
                                  phase: _marchingAntsController.value * 8,
                                  scale: widget.controller.scale,
                                  offset: widget.controller.offset,
                                ),
                              );
                            },
                          ),
                        ),

                      // 笔刷大小预览（跟随鼠标）- 仅绘画工具显示
                      if (_lastPointerPosition != null &&
                          widget.controller.currentTool.isPaintTool)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _BrushCursorPainter(
                              position: _lastPointerPosition!,
                              brushSize: widget.controller.brushSettings.size,
                              scale: widget.controller.scale,
                              offset: widget.controller.offset,
                              color: widget.controller.currentColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 获取当前光标样式
  MouseCursor _getCursor() {
    if (_isSpacePressed || _isPanning) {
      return SystemMouseCursors.grab;
    }
    final tool = widget.controller.currentTool;
    if (tool == ToolType.rectSelect || tool == ToolType.ellipseSelect) {
      return SystemMouseCursors.precise;
    }
    // 画笔和橡皮擦使用自定义光标（通过 BrushCursorPainter 显示）
    return SystemMouseCursors.none;
  }

  // 鼠标位置（用于笔刷预览）
  Offset? _lastPointerPosition;

  /// 处理鼠标悬停
  void _handleHover(PointerHoverEvent event) {
    final tool = widget.controller.currentTool;
    // 只有画笔和橡皮擦工具显示笔刷预览
    if (tool == ToolType.brush || tool == ToolType.eraser) {
      setState(() {
        _lastPointerPosition = event.localPosition;
      });
    }
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // 空格键：切换平移模式
    if (event.logicalKey == LogicalKeyboardKey.space) {
      _isSpacePressed = event is KeyDownEvent;
      return KeyEventResult.handled;
    }

    // Shift/Alt 键状态更新
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      _isShiftPressed = event is KeyDownEvent;
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight) {
      _isAltPressed = event is KeyDownEvent;
      return KeyEventResult.handled;
    }

    // 快捷键
    if (event is KeyDownEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      // Escape: 取消当前操作
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelCurrentOperation();
        return KeyEventResult.handled;
      }

      // Ctrl+Z: 撤销
      if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.keyZ) {
        widget.controller.undo();
        return KeyEventResult.handled;
      }

      // Ctrl+Y 或 Ctrl+Shift+Z: 重做
      if ((isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) ||
          (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyZ)) {
        widget.controller.redo();
        return KeyEventResult.handled;
      }

      // B: 画笔
      if (event.logicalKey == LogicalKeyboardKey.keyB) {
        widget.controller.setTool(ToolType.brush);
        return KeyEventResult.handled;
      }

      // E: 橡皮擦
      if (event.logicalKey == LogicalKeyboardKey.keyE) {
        widget.controller.setTool(ToolType.eraser);
        return KeyEventResult.handled;
      }

      // R: 矩形选框
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        widget.controller.setTool(ToolType.rectSelect);
        return KeyEventResult.handled;
      }

      // O: 椭圆选框
      if (event.logicalKey == LogicalKeyboardKey.keyO) {
        widget.controller.setTool(ToolType.ellipseSelect);
        return KeyEventResult.handled;
      }

      // [: 减小笔刷大小
      if (event.logicalKey == LogicalKeyboardKey.bracketLeft) {
        final newSize = widget.controller.brushSettings.size - 5;
        widget.controller.setBrushSize(newSize);
        return KeyEventResult.handled;
      }

      // ]: 增大笔刷大小
      if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
        final newSize = widget.controller.brushSettings.size + 5;
        widget.controller.setBrushSize(newSize);
        return KeyEventResult.handled;
      }

      // 0: 重置缩放到 100%
      if (event.logicalKey == LogicalKeyboardKey.digit0) {
        widget.controller.setScale(1.0);
        return KeyEventResult.handled;
      }

      // F: 适应屏幕
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          widget.controller.fitToViewport(renderBox.size);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// 取消当前操作
  void _cancelCurrentOperation() {
    // 取消正在绘制的选区
    if (_currentSelectionRect != null) {
      setState(() {
        _selectionStart = null;
        _currentSelectionRect = null;
      });
    }
    // 取消正在绘制的笔画 - 需要在 controller 中添加方法
    widget.controller.cancelCurrentStroke();
  }

  /// 处理鼠标滚轮事件
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // 滚轮缩放 - 向光标位置缩放
      final oldScale = widget.controller.scale;
      final delta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
      final newScale = (oldScale + delta).clamp(0.1, 10.0);

      if (newScale != oldScale) {
        // 计算缩放中心点（光标位置）
        final localPosition = event.localPosition;
        final canvasPoint = (localPosition - widget.controller.offset) / oldScale;

        // 计算新的偏移量，使缩放中心保持不变
        final newOffset = localPosition - canvasPoint * newScale;

        widget.controller.setScale(newScale);
        widget.controller.setOffset(newOffset);
      }
    }
  }

  /// 处理缩放/平移开始
  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = widget.controller.scale;
    _lastPanPosition = details.focalPoint;

    // 判断是否为平移操作
    if (_isSpacePressed || details.pointerCount >= 2) {
      _isPanning = true;
      return;
    }

    // 选区工具
    if (_isSelectionTool()) {
      _selectionStart = _toCanvasPoint(details.focalPoint);
      return;
    }

    // 开始绘制
    final canvasPoint = _toCanvasPoint(details.focalPoint);
    widget.controller.startStroke(canvasPoint);
  }

  /// 处理缩放/平移更新
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // 双指缩放
    if (details.pointerCount >= 2) {
      final newScale = _lastScale * details.scale;
      widget.controller.setScale(newScale);

      // 同时平移
      if (_lastPanPosition != null) {
        final delta = details.focalPoint - _lastPanPosition!;
        final newOffset = widget.controller.offset + delta;
        widget.controller.setOffset(newOffset);
        _lastPanPosition = details.focalPoint;
      }
      return;
    }

    // 平移
    if (_isPanning && _lastPanPosition != null) {
      final delta = details.focalPoint - _lastPanPosition!;
      final newOffset = widget.controller.offset + delta;
      widget.controller.setOffset(newOffset);
      _lastPanPosition = details.focalPoint;
      return;
    }

    // 选区工具
    if (_isSelectionTool() && _selectionStart != null) {
      final currentPoint = _toCanvasPoint(details.focalPoint);
      setState(() {
        _currentSelectionRect = Rect.fromPoints(_selectionStart!, currentPoint);
      });
      return;
    }

    // 绘制
    final canvasPoint = _toCanvasPoint(details.focalPoint);
    widget.controller.updateStroke(canvasPoint);
  }

  /// 处理缩放/平移结束
  void _handleScaleEnd(ScaleEndDetails details) {
    _isPanning = false;
    _lastPanPosition = null;

    // 完成选区
    if (_isSelectionTool() && _currentSelectionRect != null) {
      final isEllipse = widget.controller.currentTool == ToolType.ellipseSelect;
      // Shift: 加法选区, Alt: 减法选区, 默认: 替换选区
      final additive = _isShiftPressed || (!_isAltPressed && widget.controller.maskPath == null);
      final subtractive = _isAltPressed;

      if (subtractive) {
        // Alt 按下：减法选区
        if (isEllipse) {
          widget.controller.addEllipseSelection(_currentSelectionRect!, additive: false);
        } else {
          widget.controller.addRectSelection(_currentSelectionRect!, additive: false);
        }
      } else {
        // Shift 或首次：加法选区
        if (isEllipse) {
          widget.controller.addEllipseSelection(_currentSelectionRect!, additive: additive);
        } else {
          widget.controller.addRectSelection(_currentSelectionRect!, additive: additive);
        }
      }
      _selectionStart = null;
      setState(() {
        _currentSelectionRect = null;
      });
      return;
    }

    // 完成绘制
    widget.controller.endStroke();
  }

  /// 转换屏幕坐标到画布坐标
  Offset _toCanvasPoint(Offset screenPoint) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPoint = renderBox.globalToLocal(screenPoint);
    return (localPoint - widget.controller.offset) / widget.controller.scale;
  }

  /// 是否为选区工具
  bool _isSelectionTool() {
    return widget.controller.currentTool == ToolType.rectSelect ||
        widget.controller.currentTool == ToolType.ellipseSelect;
  }
}

/// 选区预览绘制器
class _SelectionPreviewPainter extends CustomPainter {
  final Rect rect;
  final bool isEllipse;
  final double scale;
  final Offset offset;
  final bool isSubtractive;

  _SelectionPreviewPainter({
    required this.rect,
    required this.isEllipse,
    required this.scale,
    required this.offset,
    this.isSubtractive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // 填充预览（半透明）
    final fillPaint = Paint()
      ..color = isSubtractive
          ? const Color(0x30FF6B6B) // 减法：红色
          : const Color(0x306BFF6B) // 加法：绿色
      ..style = PaintingStyle.fill;

    if (isEllipse) {
      canvas.drawOval(rect, fillPaint);
    } else {
      canvas.drawRect(rect, fillPaint);
    }

    // 边框
    final strokePaint = Paint()
      ..color = isSubtractive ? Colors.red : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / scale;

    if (isEllipse) {
      canvas.drawOval(rect, strokePaint);
    } else {
      canvas.drawRect(rect, strokePaint);
    }

    // 虚线效果
    final dashPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / scale;

    // 简单虚线
    final path = isEllipse ? (Path()..addOval(rect)) : (Path()..addRect(rect));
    canvas.drawPath(path, dashPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SelectionPreviewPainter oldDelegate) {
    return rect != oldDelegate.rect ||
        isEllipse != oldDelegate.isEllipse ||
        scale != oldDelegate.scale ||
        offset != oldDelegate.offset ||
        isSubtractive != oldDelegate.isSubtractive;
  }
}

/// 笔刷光标绘制器
class _BrushCursorPainter extends CustomPainter {
  final Offset position;
  final double brushSize;
  final double scale;
  final Offset offset;
  final Color color;

  _BrushCursorPainter({
    required this.position,
    required this.brushSize,
    required this.scale,
    required this.offset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 计算实际显示的笔刷大小
    final displaySize = brushSize * scale;

    // 外圈（白色）
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(position, displaySize / 2, outerPaint);

    // 内圈（黑色）
    final innerPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(position, displaySize / 2 - 1, innerPaint);

    // 中心点
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, 2, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _BrushCursorPainter oldDelegate) {
    return position != oldDelegate.position ||
        brushSize != oldDelegate.brushSize ||
        scale != oldDelegate.scale ||
        color != oldDelegate.color;
  }
}
