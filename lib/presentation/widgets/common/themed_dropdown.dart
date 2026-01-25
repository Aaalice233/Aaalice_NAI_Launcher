import 'package:flutter/material.dart';
import 'inset_shadow_container.dart';

/// 带内阴影效果的下拉选择器
///
/// 自动从主题扩展读取内阴影配置，提供统一的立体感效果。
class ThemedDropdown<T> extends StatelessWidget {
  /// 当前选中的值
  final T? value;

  /// 下拉选项列表
  final List<DropdownMenuItem<T>> items;

  /// 选择回调
  final ValueChanged<T?>? onChanged;

  /// 提示文本
  final String? hintText;

  /// 是否扩展宽度
  final bool isExpanded;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 选中项构建器（用于自定义选中项显示）
  final List<Widget> Function(BuildContext)? selectedItemBuilder;

  /// 图标
  final Widget? icon;

  /// 容器圆角
  final double borderRadius;

  const ThemedDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.isExpanded = true,
    this.focusNode,
    this.selectedItemBuilder,
    this.icon,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return InsetShadowContainer(
      borderRadius: borderRadius,
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: isExpanded,
        focusNode: focusNode,
        selectedItemBuilder: selectedItemBuilder,
        icon: icon,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
    );
  }
}

/// 带内阴影效果的文本输入框
///
/// 自动从主题扩展读取内阴影配置，提供统一的立体感效果。
class ThemedTextField extends StatelessWidget {
  /// 控制器
  final TextEditingController? controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 提示文本
  final String? hintText;

  /// 标签文本
  final String? labelText;

  /// 前缀图标
  final Widget? prefixIcon;

  /// 后缀图标
  final Widget? suffixIcon;

  /// 是否隐藏文本
  final bool obscureText;

  /// 键盘类型
  final TextInputType? keyboardType;

  /// 最大行数
  final int? maxLines;

  /// 最小行数
  final int? minLines;

  /// 值改变回调
  final ValueChanged<String>? onChanged;

  /// 提交回调
  final ValueChanged<String>? onSubmitted;

  /// 是否自动获取焦点
  final bool autofocus;

  /// 文本样式
  final TextStyle? style;

  /// 输入格式化器
  final List<dynamic>? inputFormatters;

  /// 容器圆角
  final double borderRadius;

  const ThemedTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.style,
    this.inputFormatters,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InsetShadowContainer(
      borderRadius: borderRadius,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        style: style,
        cursorColor: theme.colorScheme.primary,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          // 浮动标签样式
          labelStyle: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          floatingLabelStyle: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
