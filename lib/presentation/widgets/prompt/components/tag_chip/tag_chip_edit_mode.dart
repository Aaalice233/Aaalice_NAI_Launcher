import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/image_generation_provider.dart';
import '../../../autocomplete/autocomplete.dart';
import '../../core/prompt_tag_config.dart';

/// 标签内联编辑组件
/// 双击标签时显示，支持直接编辑标签文本
class TagChipEditMode extends ConsumerStatefulWidget {
  /// 初始文本
  final String initialText;

  /// 文本变化回调
  final ValueChanged<String> onTextChanged;

  /// 编辑完成回调
  final VoidCallback onEditComplete;

  /// 编辑取消回调
  final VoidCallback onEditCancel;

  /// 是否紧凑模式
  final bool compact;

  /// 背景色
  final Color? backgroundColor;

  /// 边框色
  final Color? borderColor;

  const TagChipEditMode({
    super.key,
    required this.initialText,
    required this.onTextChanged,
    required this.onEditComplete,
    required this.onEditCancel,
    this.compact = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  ConsumerState<TagChipEditMode> createState() => _TagChipEditModeState();
}

class _TagChipEditModeState extends ConsumerState<TagChipEditMode> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // 将下划线转换为空格显示
    _controller = TextEditingController(
      text: widget.initialText.replaceAll('_', ' '),
    );
    _focusNode = FocusNode();

    // 自动获取焦点并全选
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });

    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _hasChanges = true;
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commitEdit();
    }
  }

  void _commitEdit() {
    final newText = _controller.text.trim();
    if (newText.isEmpty) {
      widget.onEditCancel();
      return;
    }

    // 将空格转换回下划线
    final formattedText = newText.replaceAll(' ', '_');

    if (_hasChanges && formattedText != widget.initialText) {
      widget.onTextChanged(formattedText);
    }
    widget.onEditComplete();
  }

  void _cancelEdit() {
    widget.onEditCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = widget.compact;
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _cancelEdit();
          }
        }
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: TagChipSizes.editInputMinWidth,
          maxWidth: TagChipSizes.editInputMaxWidth,
        ),
        child: IntrinsicWidth(
          child: AutocompleteTextField(
            controller: _controller,
            focusNode: _focusNode,
            enableAutocomplete: enableAutocomplete,
            config: const AutocompleteConfig(
              maxSuggestions: 10,
              showTranslation: true,
              autoInsertComma: false,
            ),
            style: TextStyle(
              fontSize: compact
                  ? TagChipSizes.compactFontSize
                  : TagChipSizes.normalFontSize,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: TagChipSizes.editInputPadding,
                vertical: compact ? 8 : 10,
              ),
              filled: true,
              fillColor: widget.backgroundColor ??
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  compact
                      ? TagChipSizes.compactBorderRadius
                      : TagChipSizes.normalBorderRadius,
                ),
                borderSide: BorderSide(
                  color: widget.borderColor ?? theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  compact
                      ? TagChipSizes.compactBorderRadius
                      : TagChipSizes.normalBorderRadius,
                ),
                borderSide: BorderSide(
                  color: widget.borderColor ?? theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  compact
                      ? TagChipSizes.compactBorderRadius
                      : TagChipSizes.normalBorderRadius,
                ),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (_) => _commitEdit(),
          ),
        ),
      ),
    );
  }
}
