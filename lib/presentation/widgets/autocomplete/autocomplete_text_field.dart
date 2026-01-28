import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/inset_shadow_container.dart';
import '../prompt/prompt_formatter_wrapper.dart';
import 'autocomplete_controller.dart';
import 'autocomplete_wrapper.dart';

/// 带自动补全的文本输入框
/// 支持逗号分隔的多标签输入，识别 NAI 特殊语法
///
/// 注意：推荐使用 [AutocompleteWrapper] + [ThemedInput] 的组合方式，
/// 以获得更好的灵活性和可维护性。
///
/// 推荐用法：
/// ```dart
/// AutocompleteWrapper(
///   controller: controller,
///   config: AutocompleteConfig(),
///   child: ThemedInput(
///     controller: controller,
///     hintText: '输入标签',
///   ),
/// )
/// ```
class AutocompleteTextField extends ConsumerWidget {
  /// 文本控制器
  final TextEditingController controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 装饰
  final InputDecoration? decoration;

  /// 最大行数
  final int? maxLines;

  /// 最小行数
  final int? minLines;

  /// 是否扩展填满可用空间
  final bool expands;

  /// 文本样式
  final TextStyle? style;

  /// 值改变回调
  final ValueChanged<String>? onChanged;

  /// 提交回调
  final ValueChanged<String>? onSubmitted;

  /// 自动补全配置
  final AutocompleteConfig config;

  /// 是否启用自动补全
  final bool enableAutocomplete;

  /// 是否启用自动格式化（失焦时自动格式化提示词）
  final bool enableAutoFormat;

  /// 是否启用 SD 语法自动转换（失焦时将 SD 权重语法转换为 NAI 格式）
  final bool enableSdSyntaxAutoConvert;

  /// 是否使用立体效果（InsetShadowContainer包装）
  final bool useInsetShadow;

  /// 圆角半径
  final double borderRadius;

  const AutocompleteTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.config = const AutocompleteConfig(),
    this.enableAutocomplete = true,
    this.enableAutoFormat = true,
    this.enableSdSyntaxAutoConvert = false,
    this.useInsetShadow = true,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 构建 InputDecoration
    // 如果使用立体效果，移除边框；否则保留原有装饰
    final effectiveDecoration = useInsetShadow
        ? (decoration ?? const InputDecoration()).copyWith(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding:
                decoration?.contentPadding ?? const EdgeInsets.all(12),
          )
        : decoration;

    // 构建基础 TextField
    // 注意：不要将 focusNode 传给 TextField，因为 AutocompleteWrapper 会用 Focus 包装整个组件
    // 如果两者都使用同一个 focusNode，会导致 "Tried to make a child into a parent of itself" 错误
    final textField = TextField(
      controller: controller,
      decoration: effectiveDecoration,
      maxLines: expands ? null : maxLines,
      minLines: expands ? null : minLines,
      expands: expands,
      textAlignVertical: expands ? TextAlignVertical.top : null,
      style: style,
      onChanged: enableAutocomplete ? null : onChanged,
      onSubmitted: onSubmitted,
    );

    // 使用立体效果包装
    final wrappedTextField = useInsetShadow
        ? InsetShadowContainer(
            borderRadius: borderRadius,
            child: textField,
          )
        : textField;

    // 使用 AutocompleteWrapper 提供自动补全功能
    Widget result = AutocompleteWrapper(
      controller: controller,
      focusNode: focusNode,
      config: config,
      enabled: enableAutocomplete,
      onChanged: onChanged,
      textStyle: style,
      contentPadding: effectiveDecoration?.contentPadding,
      maxLines: maxLines,
      expands: expands,
      child: wrappedTextField,
    );

    // 如果启用格式化功能，外层包装 PromptFormatterWrapper
    if (enableAutoFormat || enableSdSyntaxAutoConvert) {
      result = PromptFormatterWrapper(
        controller: controller,
        focusNode: focusNode,
        enableAutoFormat: enableAutoFormat,
        enableSdSyntaxAutoConvert: enableSdSyntaxAutoConvert,
        onChanged: onChanged,
        child: result,
      );
    }

    return result;
  }
}
