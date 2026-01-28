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

  /// 点击回调
  final GestureTapCallback? onTap;

  /// 编辑完成回调
  final VoidCallback? onEditingComplete;

  /// 文本对齐方式
  final TextAlign textAlign;

  /// 垂直对齐方式
  final TextAlignVertical? textAlignVertical;

  /// 光标颜色
  final Color? cursorColor;

  /// 点击输入框外部时的回调
  final TapRegionCallback? onTapOutside;

  /// 额外的 InputDecoration（会与默认配置合并）
  /// 用于兼容需要额外装饰属性的场景
  final InputDecoration? decoration;

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
    this.onTap,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.cursorColor,
    this.onTapOutside,
    this.decoration,
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
    this.onTap,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.cursorColor,
    this.onTapOutside,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 构建基础 InputDecoration
    var inputDecoration = InputDecoration(
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
    );

    // 如果提供了额外的 decoration，合并属性
    if (decoration != null) {
      inputDecoration = inputDecoration.copyWith(
        labelText: decoration!.labelText,
        labelStyle: decoration!.labelStyle,
        floatingLabelStyle: decoration!.floatingLabelStyle,
        helperText: decoration!.helperText,
        helperStyle: decoration!.helperStyle,
        errorText: decoration!.errorText,
        errorStyle: decoration!.errorStyle,
        prefix: decoration!.prefix,
        prefixText: decoration!.prefixText,
        prefixStyle: decoration!.prefixStyle,
        suffix: decoration!.suffix,
        suffixText: decoration!.suffixText,
        suffixStyle: decoration!.suffixStyle,
        counter: decoration!.counter,
        counterStyle: decoration!.counterStyle,
        filled: decoration!.filled,
        fillColor: decoration!.fillColor,
      );
    }

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
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      onTapOutside: onTapOutside,
      readOnly: readOnly,
      enabled: enabled,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLength: maxLength,
      style: style,
      autofocus: autofocus,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      cursorColor: cursorColor,
      decoration: inputDecoration,
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
