import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/image_generation_provider.dart';
import '../../../autocomplete/autocomplete.dart';
import '../../core/prompt_tag_config.dart';
import '../../core/prompt_tag_colors.dart';

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

  /// 标签分类（用于渐变背景）
  final int category;

  const TagChipEditMode({
    super.key,
    required this.initialText,
    required this.onTextChanged,
    required this.onEditComplete,
    required this.onEditCancel,
    this.compact = false,
    this.backgroundColor,
    this.borderColor,
    this.category = 0,
  });

  @override
  ConsumerState<TagChipEditMode> createState() => _TagChipEditModeState();
}

class _TagChipEditModeState extends ConsumerState<TagChipEditMode>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasChanges = false;

  // Focus glow animation controller
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // 将下划线转换为空格显示
    _controller = TextEditingController(
      text: widget.initialText.replaceAll('_', ' '),
    );
    _focusNode = FocusNode();

    // Initialize glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeOut),
    );

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
    _glowController.dispose();
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
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (_focusNode.hasFocus) {
      if (!reducedMotion) {
        _glowController.forward();
      }
    } else {
      if (!reducedMotion) {
        _glowController.reverse();
      }
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

    // Get gradient based on category
    final gradient = CategoryGradient.getThemedGradient(
      widget.category,
      isDark: theme.brightness == Brightness.dark,
    );
    final gradientColor = CategoryGradient.getGradientStartColor(widget.category);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _cancelEdit();
          }
        }
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          // Calculate glow opacity based on animation
          final glowOpacity = _glowAnimation.value * 0.3;
          final borderWidth = 1.5 + (_glowAnimation.value * 0.5);

          return Container(
            constraints: const BoxConstraints(
              minWidth: TagChipSizes.editInputMinWidth,
              maxWidth: TagChipSizes.editInputMaxWidth,
            ),
            decoration: BoxDecoration(
              // Gradient background with reduced opacity
              gradient: LinearGradient(
                colors: gradient.colors
                    .map((color) => color.withOpacity(0.08))
                    .toList(),
                begin: gradient.begin,
                end: gradient.end,
              ),
              borderRadius: BorderRadius.circular(
                compact
                    ? TagChipSizes.compactBorderRadius
                    : TagChipSizes.normalBorderRadius,
              ),
              // Glow effect on focus
              boxShadow: _focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: gradientColor.withOpacity(glowOpacity),
                        blurRadius: 8 + (_glowAnimation.value * 4),
                        spreadRadius: _glowAnimation.value * 2,
                      ),
                    ]
                  : null,
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
                  filled: false, // Use transparent to show gradient
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      compact
                          ? TagChipSizes.compactBorderRadius
                          : TagChipSizes.normalBorderRadius,
                    ),
                    borderSide: BorderSide(
                      color: widget.borderColor ??
                          gradientColor.withOpacity(0.3),
                      width: borderWidth,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      compact
                          ? TagChipSizes.compactBorderRadius
                          : TagChipSizes.normalBorderRadius,
                    ),
                    borderSide: BorderSide(
                      color: widget.borderColor ??
                          gradientColor.withOpacity(0.3),
                      width: borderWidth,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      compact
                          ? TagChipSizes.compactBorderRadius
                          : TagChipSizes.normalBorderRadius,
                    ),
                    borderSide: BorderSide(
                      color: gradientColor,
                      width: borderWidth,
                    ),
                  ),
                ),
                onSubmitted: (_) => _commitEdit(),
              ),
            ),
          );
        },
      ),
    );
  }
}
