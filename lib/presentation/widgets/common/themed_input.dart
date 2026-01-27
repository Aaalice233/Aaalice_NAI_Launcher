import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inset_shadow_container.dart';

/// 统一样式的输入框组件
///
/// 使用 [InsetShadowContainer] 包装，提供立体感效果。
/// 支持单行和多行模式，统一圆角和样式。
class ThemedInput extends StatelessWidget {
  /// 文本控制器
  final TextEditingController? controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 提示文字
  final String? hintText;

  /// 帮助文字（显示在输入框下方）
  final String? helperText;

  /// 最大行数，null表示无限制
  final int? maxLines;

  /// 最小行数
  final int minLines;

  /// 是否自动扩展
  final bool expands;

  /// 键盘操作类型
  final TextInputAction? textInputAction;

  /// 输入类型
  final TextInputType? keyboardType;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 提交回调
  final ValueChanged<String>? onSubmitted;

  /// 是否只读
  final bool readOnly;

  /// 是否启用
  final bool enabled;

  /// 圆角半径
  final double borderRadius;

  /// 内边距
  final EdgeInsetsGeometry contentPadding;

  /// 输入格式化器
  final List<TextInputFormatter>? inputFormatters;

  /// 前缀图标
  final Widget? prefixIcon;

  /// 后缀图标
  final Widget? suffixIcon;

  /// 是否遮挡文本（密码输入）
  final bool obscureText;

  /// 最大字符数
  final int? maxLength;

  /// 文本样式
  final TextStyle? style;

  /// 提示文字样式
  final TextStyle? hintStyle;

  /// 是否自动获取焦点
  final bool autofocus;

  const ThemedInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.maxLines = 1,
    this.minLines = 1,
    this.expands = false,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.borderRadius = 8.0,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLength,
    this.style,
    this.hintStyle,
    this.autofocus = false,
  });

  /// 创建多行输入框
  const ThemedInput.multiline({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.maxLines,
    this.minLines = 3,
    this.expands = false,
    this.textInputAction,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.borderRadius = 8.0,
    this.contentPadding = const EdgeInsets.all(12),
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLength,
    this.style,
    this.hintStyle,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final textField = TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      readOnly: readOnly,
      enabled: enabled,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLength: maxLength,
      style: style,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: contentPadding,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isDense: true,
        counterText: '', // 隐藏字符计数
      ),
    );

    final container = InsetShadowContainer(
      borderRadius: borderRadius,
      enabled: enabled ? null : false,
      child: textField,
    );

    // 如果有帮助文字，添加在下方
    if (helperText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          container,
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              helperText!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      );
    }

    return container;
  }
}
