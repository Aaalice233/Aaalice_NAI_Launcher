import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../unified/unified_prompt_config.dart';
import '../unified/unified_prompt_input.dart';
import 'prompt_editor_toolbar.dart';
import 'prompt_editor_toolbar_config.dart';

/// 带工具栏的提示词编辑器组合组件
///
/// 将 [PromptEditorToolbar] 和 [UnifiedPromptInput] 组合在一起，
/// 提供开箱即用的提示词编辑体验。
///
/// 使用示例：
/// ```dart
/// PromptEditorWithToolbar(
///   toolbarConfig: PromptEditorToolbarConfig.characterEditor,
///   inputConfig: UnifiedPromptConfig.characterEditor,
///   controller: _promptController,
///   onChanged: (text) => print('Text changed: $text'),
/// )
/// ```
class PromptEditorWithToolbar extends ConsumerStatefulWidget {
  /// 工具栏配置
  final PromptEditorToolbarConfig toolbarConfig;

  /// 输入组件配置
  final UnifiedPromptConfig inputConfig;

  /// 外部文本控制器（可选）
  final TextEditingController? controller;

  /// 焦点节点（可选）
  final FocusNode? focusNode;

  /// 输入装饰
  final InputDecoration? decoration;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 随机按钮点击回调
  final VoidCallback? onRandomPressed;

  /// 随机按钮长按回调
  final VoidCallback? onRandomLongPressed;

  /// 全屏按钮点击回调
  final VoidCallback? onFullscreenPressed;

  /// 设置按钮点击回调
  final VoidCallback? onSettingsPressed;

  /// 清空完成回调（在内容被清空后调用）
  final VoidCallback? onCleared;

  /// 最大行数（文本模式）
  final int? maxLines;

  /// 最小行数（文本模式）
  final int? minLines;

  /// 是否扩展填满空间
  final bool expands;

  /// 工具栏前置自定义按钮
  final List<Widget>? toolbarLeadingActions;

  /// 工具栏后置自定义按钮
  final List<Widget>? toolbarTrailingActions;

  const PromptEditorWithToolbar({
    super.key,
    this.toolbarConfig = const PromptEditorToolbarConfig(),
    this.inputConfig = const UnifiedPromptConfig(),
    this.controller,
    this.focusNode,
    this.decoration,
    this.onChanged,
    this.onRandomPressed,
    this.onRandomLongPressed,
    this.onFullscreenPressed,
    this.onSettingsPressed,
    this.onCleared,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.toolbarLeadingActions,
    this.toolbarTrailingActions,
  });

  @override
  ConsumerState<PromptEditorWithToolbar> createState() =>
      _PromptEditorWithToolbarState();
}

class _PromptEditorWithToolbarState
    extends ConsumerState<PromptEditorWithToolbar> {
  /// 内部文本控制器（当未提供外部控制器时使用）
  TextEditingController? _internalController;

  /// 获取有效的文本控制器
  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();

    // 初始化内部控制器（如果需要）
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
  }

  @override
  void didUpdateWidget(PromptEditorWithToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 外部控制器变化
    if (widget.controller != oldWidget.controller) {
      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  /// 处理清空操作
  void _handleClear() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否有任何工具栏按钮需要显示
    final hasToolbar = widget.toolbarConfig.showRandomButton ||
        widget.toolbarConfig.showFullscreenButton ||
        widget.toolbarConfig.showClearButton ||
        widget.toolbarConfig.showSettingsButton ||
        (widget.toolbarLeadingActions?.isNotEmpty ?? false) ||
        (widget.toolbarTrailingActions?.isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 工具栏
        if (hasToolbar) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PromptEditorToolbar(
                config: widget.toolbarConfig,
                onRandomPressed: widget.onRandomPressed,
                onRandomLongPressed: widget.onRandomLongPressed,
                onFullscreenPressed: widget.onFullscreenPressed,
                onClearPressed: _handleClear,
                onSettingsPressed: widget.onSettingsPressed,
                leadingActions: widget.toolbarLeadingActions,
                trailingActions: widget.toolbarTrailingActions,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 输入组件
        Flexible(
          child: UnifiedPromptInput(
            config: widget.inputConfig,
            controller: _effectiveController,
            focusNode: widget.focusNode,
            decoration: widget.decoration,
            onChanged: widget.onChanged,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            expands: widget.expands,
          ),
        ),
      ],
    );
  }
}
