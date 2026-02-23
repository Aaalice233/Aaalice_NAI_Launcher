import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_prompt_formatter.dart';
import '../../../core/utils/sd_to_nai_converter.dart';
import '../common/app_toast.dart';

/// 提示词格式化包装器
/// 为任意输入组件提供失焦时自动格式化功能
///
/// 职责单一：只负责格式化和SD语法转换
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

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  const PromptFormatterWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.focusNode,
    this.enableAutoFormat = true,
    this.enableSdSyntaxAutoConvert = false,
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
      _formatOnBlur();
    }
  }

  /// 失焦时格式化提示词
  void _formatOnBlur() {
    var text = widget.controller.text;
    if (text.isEmpty) return;

    var changed = false;
    final messages = <String>[];

    // SD 语法自动转换（优先于格式化，因为格式化可能会影响转换结果）
    if (widget.enableSdSyntaxAutoConvert) {
      final converted = SdToNaiConverter.convert(text);
      if (converted != text) {
        text = converted;
        changed = true;
        messages.add('SD→NAI');
      }
    }

    // 自动格式化
    if (widget.enableAutoFormat) {
      final formatted = NaiPromptFormatter.format(text);
      if (formatted != text) {
        text = formatted;
        changed = true;
        if (!messages.contains('SD→NAI')) {
          messages.add(context.l10n.prompt_formatted);
        }
      }
    }

    if (changed) {
      widget.controller.text = text;
      widget.onChanged?.call(text);
      if (mounted && messages.isNotEmpty) {
        AppToast.info(context, messages.join(' + '));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果两个功能都未启用，直接返回子组件
    if (!widget.enableAutoFormat && !widget.enableSdSyntaxAutoConvert) {
      return widget.child;
    }

    // 如果提供了外部 focusNode，不需要额外包装 Focus
    if (widget.focusNode != null) {
      return widget.child;
    }

    // 使用内部 focusNode 包装
    return Focus(
      focusNode: _focusNode,
      child: widget.child,
    );
  }
}
