import 'package:flutter/material.dart';

import 'input_surface_container.dart';
import 'input_surface_decoration.dart';

/// 带表单验证的统一样式输入框组件
///
/// 使用共享深色填充与清晰、无发光的聚焦和错误轮廓。
/// 支持 [validator] 验证功能和错误提示显示。
class ThemedFormInput extends StatefulWidget {
  /// 文本控制器
  final TextEditingController? controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 提示文字
  final String? hintText;

  /// 标签文字
  final String? labelText;

  /// 键盘操作类型
  final TextInputAction? textInputAction;

  /// 输入类型
  final TextInputType? keyboardType;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 表单字段提交回调
  final ValueChanged<String>? onFieldSubmitted;

  /// 验证器
  final FormFieldValidator<String>? validator;

  /// 自动验证模式
  final AutovalidateMode? autovalidateMode;

  /// 是否只读
  final bool readOnly;

  /// 最大字符数
  final int? maxLength;

  /// 是否自动获取焦点
  final bool autofocus;

  /// 初始值；未传 [controller] 时作为输入内容，之后的外部更新在输入框未聚焦时同步
  final String? initialValue;

  /// 文本对齐方式
  final TextAlign textAlign;

  /// 额外的 InputDecoration，呈现规则见 [InputSurfaceDecoration]；
  /// [validator] 的错误优先于 [InputDecoration.errorText]
  final InputDecoration? decoration;

  const ThemedFormInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.autovalidateMode,
    this.readOnly = false,
    this.maxLength,
    this.autofocus = false,
    this.initialValue,
    this.textAlign = TextAlign.start,
    this.decoration,
  });

  @override
  State<ThemedFormInput> createState() => _ThemedFormInputState();
}

class _ThemedFormInputState extends State<ThemedFormInput> {
  TextEditingController? _ownedController;
  late String _observedText;
  bool _editing = false;
  bool _initialValueChangedWhileEditing = false;

  TextEditingController get _controller =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue);
    }
    _observedText = _controller.text;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(ThemedFormInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final previous = oldWidget.controller ?? _ownedController!;
      previous.removeListener(_handleTextChanged);
      if (widget.controller == null) {
        _ownedController = TextEditingController.fromValue(previous.value);
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _observedText = _controller.text;
      _controller.addListener(_handleTextChanged);
    } else if (widget.controller == null &&
        widget.initialValue != oldWidget.initialValue) {
      if (_editing) {
        _initialValueChangedWhileEditing = true;
      } else {
        _showInitialValue();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  // 编辑中不覆盖：调用方常把输入规整后回传（如去掉末尾逗号），实时写回会吞掉正在输入的字符
  void _handleFocusChange(bool focused) {
    _editing = focused;
    if (focused || !_initialValueChangedWhileEditing) return;
    _initialValueChangedWhileEditing = false;
    if (widget.controller == null) _showInitialValue();
  }

  void _showInitialValue() {
    final value = widget.initialValue ?? '';
    if (_controller.text != value) _controller.text = value;
  }

  // 程序写入的内容不经过 onChanged，需要重建才能让自动校验读到新内容
  void _handleTextChanged() {
    if (_controller.text == _observedText) return;
    _observedText = _controller.text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final surface = InputSurfaceDecoration(
      widget.decoration,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelText: widget.labelText,
      hintText: widget.hintText,
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _handleFocusChange,
      child: Builder(
        builder: (focusContext) {
          final hasFocus = Focus.of(focusContext).hasFocus;
          final validator = widget.validator;
          return FormField<String>(
            initialValue: _controller.text,
            validator: validator == null
                ? null
                : (_) => validator(_controller.text),
            autovalidateMode:
                widget.autovalidateMode ?? AutovalidateMode.disabled,
            builder: (field) {
              final supporting = surface.supportingText(field.errorText);
              // 恒用 Column 包裹：错误出现或消失时输入框不重建，焦点与输入法连接不中断
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InputSurfaceContainer(
                    hasError: surface.hasError(field.errorText),
                    isFocused: hasFocus,
                    child: _buildTextField(field, surface.fieldDecoration),
                  ),
                  if (supporting != null) supporting,
                ],
              );
            },
          );
        },
      ),
    );
  }

  TextField _buildTextField(
    FormFieldState<String> field,
    InputDecoration decoration,
  ) {
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      onChanged: (value) {
        field.didChange(value);
        widget.onChanged?.call(value);
      },
      onSubmitted: widget.onFieldSubmitted,
      readOnly: widget.readOnly,
      maxLength: widget.maxLength,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      textAlignVertical: TextAlignVertical.center,
      decoration: decoration,
    );
  }
}
