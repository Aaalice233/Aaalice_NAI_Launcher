import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../utils/text_selection_utils.dart';
import '../common/app_toast.dart';
import 'prompt_blur_formatting.dart';
import 'tag_editor_scope.dart';

/// 提示词格式化包装器
/// 为任意输入组件提供失焦时自动格式化功能
///
/// 职责单一：只负责格式化、SD语法转换和数值权重闭合补空格
/// 与 AutocompleteWrapper 分离，可独立使用或组合使用
class PromptFormatterWrapper extends StatefulWidget {
  /// 被包装的输入组件
  final Widget child;

  /// 文本控制器
  final TextEditingController controller;

  /// 焦点节点（可选，如果不提供则需要外层有 Focus）
  final FocusNode? focusNode;

  /// 是否启用自动格式化（失焦时自动格式化提示词）
  final bool enableAutoFormat;

  /// 是否启用 SD 语法自动转换（失焦时将 SD 权重语法转换为 NAI 格式）
  final bool enableSdSyntaxAutoConvert;

  /// 是否在失焦时给以数字结尾的数值权重内容在闭合 :: 前补空格
  final bool separateNumericWeightClosing;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  const PromptFormatterWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.focusNode,
    this.enableAutoFormat = true,
    this.enableSdSyntaxAutoConvert = false,
    this.separateNumericWeightClosing = false,
    this.onChanged,
  });

  @override
  State<PromptFormatterWrapper> createState() => _PromptFormatterWrapperState();
}

class _PromptFormatterWrapperState extends State<PromptFormatterWrapper> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PromptFormatterWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) {
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      if (mounted && TagEditorScope.maybeOf(context)?.tagMode == true) return;
      _formatOnBlur();
    }
  }

  /// 失焦时格式化提示词
  void _formatOnBlur() {
    final originalValue = widget.controller.value;
    if (originalValue.text.isEmpty) return;

    final result = PromptBlurFormatting.apply(
      originalValue.text,
      context.l10n,
      sdSyntaxAutoConvert: widget.enableSdSyntaxAutoConvert,
      autoFormat: widget.enableAutoFormat,
      separateNumericWeightClosing: widget.separateNumericWeightClosing,
    );
    final text = result.text;
    if (text == originalValue.text) return;

    final selection = TextSelectionUtils.preserveLineAndColumnSelection(
      oldText: originalValue.text,
      newText: text,
      selection: originalValue.selection,
    );
    widget.controller.value = originalValue.copyWith(
      text: text,
      selection: selection,
      composing: TextRange.empty,
    );
    widget.onChanged?.call(text);
    if (mounted && result.messages.isNotEmpty) {
      AppToast.info(context, result.messages.join(' + '));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有任何失焦改写，直接返回子组件
    if (!PromptBlurFormatting.enabled(
      sdSyntaxAutoConvert: widget.enableSdSyntaxAutoConvert,
      autoFormat: widget.enableAutoFormat,
      separateNumericWeightClosing: widget.separateNumericWeightClosing,
    )) {
      return widget.child;
    }

    // 如果提供了外部 focusNode，不需要额外包装 Focus
    if (widget.focusNode != null) {
      return widget.child;
    }

    // 使用内部 focusNode 包装
    return Focus(focusNode: _focusNode, child: widget.child);
  }
}
