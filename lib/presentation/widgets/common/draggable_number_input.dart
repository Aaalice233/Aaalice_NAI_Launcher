import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 可拖拽调整的数值输入组件
/// 支持：单击编辑、拖拽调整、滚轮微调
class DraggableNumberInput extends StatefulWidget {
  /// 当前值
  final int value;

  /// 最小值
  final int min;

  /// 最大值（null 表示无上限）
  final int? max;

  /// 值变化回调
  final ValueChanged<int> onChanged;

  /// 前缀（如 "×"）
  final String prefix;

  /// 步进值（拖拽时每移动多少像素增加1）
  final double dragSensitivity;

  const DraggableNumberInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.prefix = '×',
    this.dragSensitivity = 20.0,
  });

  @override
  State<DraggableNumberInput> createState() => _DraggableNumberInputState();
}

class _DraggableNumberInputState extends State<DraggableNumberInput> {
  bool _isDragging = false;
  bool _isEditing = false;
  double _dragStartX = 0;
  int _dragStartValue = 0;
  late TextEditingController _editController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(DraggableNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_isEditing) {
      _editController.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  int _clampValue(int value) {
    if (value < widget.min) return widget.min;
    if (widget.max != null && value > widget.max!) return widget.max!;
    return value;
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _finishEditing();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.value.toString();
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
    _focusNode.requestFocus();
  }

  void _finishEditing() {
    final newValue = int.tryParse(_editController.text) ?? widget.value;
    final clampedValue = _clampValue(newValue);
    widget.onChanged(clampedValue);
    setState(() {
      _isEditing = false;
      _editController.text = clampedValue.toString();
    });
  }

  void _onDragStart(DragStartDetails details) {
    if (_isEditing) return;
    setState(() {
      _isDragging = true;
      _dragStartX = details.globalPosition.dx;
      _dragStartValue = widget.value;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isEditing) return;

    final delta = details.globalPosition.dx - _dragStartX;
    final valueDelta = (delta / widget.dragSensitivity).round();
    final newValue = _clampValue(_dragStartValue + valueDelta);

    if (newValue != widget.value) {
      widget.onChanged(newValue);
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  void _onScroll(PointerScrollEvent event) {
    final delta = event.scrollDelta.dy > 0 ? -1 : 1;
    final newValue = _clampValue(widget.value + delta);
    if (newValue != widget.value) {
      widget.onChanged(newValue);
      // 如果正在编辑，同步更新输入框内容
      if (_isEditing) {
        _editController.text = newValue.toString();
        _editController.selection = TextSelection.collapsed(
          offset: _editController.text.length,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return MouseRegion(
      cursor: _isEditing
          ? SystemMouseCursors.text
          : SystemMouseCursors.resizeLeftRight,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _onScroll(event);
          }
        },
        child: GestureDetector(
          onTap: _isEditing ? null : _startEditing,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 前缀
                Text(
                  widget.prefix,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 2),
                // 数值/输入框
                _isEditing
                    ? Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent) {
                            _onScroll(event);
                          }
                        },
                        child: IntrinsicWidth(
                          child: TextField(
                            controller: _editController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onSubmitted: (_) => _finishEditing(),
                          ),
                        ),
                      )
                    : Text(
                        widget.value.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
