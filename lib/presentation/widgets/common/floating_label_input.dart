import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 精致的浮动标签输入组件
///
/// 使用 Flutter 内置的浮动标签功能，无需额外的外层容器
/// 标签在输入框内显示，聚焦或有内容时动画移动到左上角
class FloatingLabelInput extends StatelessWidget {
  /// 标签文本（必填）
  final String label;

  /// 文本控制器
  final TextEditingController? controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 提示文字
  final String? hintText;

  /// 前缀图标
  final IconData? prefixIcon;

  /// 后缀组件
  final Widget? suffix;

  /// 是否遮挡文本（密码输入）
  final bool obscureText;

  /// 键盘类型
  final TextInputType? keyboardType;

  /// 键盘操作类型
  final TextInputAction? textInputAction;

  /// 提交回调
  final ValueChanged<String>? onFieldSubmitted;

  /// 验证器
  final FormFieldValidator<String>? validator;

  /// 自动验证模式
  final AutovalidateMode autovalidateMode;

  /// 输入格式化器
  final List<TextInputFormatter>? inputFormatters;

  /// 是否启用
  final bool enabled;

  /// 是否必填（显示 * 标记）
  final bool required;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  const FloatingLabelInput({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.inputFormatters,
    this.enabled = true,
    this.required = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labelText = required ? '$label *' : label;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: suffix,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}

/// 密码输入框专用组件
///
/// 内置密码可见性切换功能
class FloatingLabelPasswordInput extends StatefulWidget {
  /// 标签文本
  final String label;

  /// 文本控制器
  final TextEditingController? controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 提示文字
  final String? hintText;

  /// 键盘操作类型
  final TextInputAction? textInputAction;

  /// 提交回调
  final ValueChanged<String>? onFieldSubmitted;

  /// 验证器
  final FormFieldValidator<String>? validator;

  /// 自动验证模式
  final AutovalidateMode autovalidateMode;

  /// 是否必填
  final bool required;

  /// 可见性切换回调（如果需要外部控制）
  final ValueChanged<bool>? onVisibilityChanged;

  /// 外部控制的可见性状态
  final bool? isVisible;

  const FloatingLabelPasswordInput({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.required = false,
    this.onVisibilityChanged,
    this.isVisible,
  });

  @override
  State<FloatingLabelPasswordInput> createState() =>
      _FloatingLabelPasswordInputState();
}

class _FloatingLabelPasswordInputState
    extends State<FloatingLabelPasswordInput> {
  bool _obscureText = true;

  bool get _isObscured =>
      widget.isVisible != null ? !widget.isVisible! : _obscureText;

  void _toggleVisibility() {
    if (widget.onVisibilityChanged != null) {
      widget.onVisibilityChanged!(!_isObscured);
    } else {
      setState(() {
        _obscureText = !_obscureText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingLabelInput(
      label: widget.label,
      controller: widget.controller,
      focusNode: widget.focusNode,
      hintText: widget.hintText,
      prefixIcon: Icons.lock_outline,
      obscureText: _isObscured,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      required: widget.required,
      suffix: IconButton(
        icon: Icon(
          _isObscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
        ),
        onPressed: _toggleVisibility,
        splashRadius: 20,
      ),
    );
  }
}
