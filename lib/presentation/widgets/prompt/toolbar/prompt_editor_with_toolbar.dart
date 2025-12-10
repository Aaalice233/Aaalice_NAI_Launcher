import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/prompt_tag.dart';
import '../../../providers/prompt_view_mode_provider.dart';
import '../unified/unified_prompt_config.dart';
import '../unified/unified_prompt_input.dart';
import 'prompt_editor_toolbar.dart';
import 'prompt_editor_toolbar_config.dart';

/// 带工具栏的提示词编辑器组合组件
///
/// 将 [PromptEditorToolbar] 和 [UnifiedPromptInput] 组合在一起，
/// 提供开箱即用的提示词编辑体验。
///
/// 支持两种视图模式管理方式：
/// - 使用共享 Provider（默认）：视图模式从 [promptViewModeNotifierProvider] 读取，
///   适用于需要与主界面同步的场景（如角色提示词编辑器）
/// - 使用本地状态：设置 [useSharedViewMode] 为 false，视图模式由组件内部管理
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

  /// 标签列表变化回调
  final ValueChanged<List<PromptTag>>? onTagsChanged;

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

  /// 是否使用共享的视图模式 Provider
  ///
  /// 为 true 时，视图模式从 [promptViewModeNotifierProvider] 读取，
  /// 与主界面保持同步。
  /// 为 false 时，使用组件内部状态管理视图模式。
  ///
  /// 默认为 true，适用于角色提示词编辑器等需要跟随主界面的场景。
  final bool useSharedViewMode;

  const PromptEditorWithToolbar({
    super.key,
    this.toolbarConfig = const PromptEditorToolbarConfig(),
    this.inputConfig = const UnifiedPromptConfig(),
    this.controller,
    this.focusNode,
    this.decoration,
    this.onChanged,
    this.onTagsChanged,
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
    this.useSharedViewMode = true,
  });

  @override
  ConsumerState<PromptEditorWithToolbar> createState() =>
      _PromptEditorWithToolbarState();
}

class _PromptEditorWithToolbarState
    extends ConsumerState<PromptEditorWithToolbar> {
  /// 当前视图模式（仅在不使用共享 Provider 时使用）
  late PromptViewMode _localViewMode;

  /// 内部文本控制器（当未提供外部控制器时使用）
  TextEditingController? _internalController;

  /// 获取有效的文本控制器
  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  /// 获取当前视图模式
  PromptViewMode get _viewMode {
    if (widget.useSharedViewMode) {
      return ref.watch(promptViewModeNotifierProvider);
    }
    return _localViewMode;
  }

  @override
  void initState() {
    super.initState();
    _localViewMode = widget.inputConfig.initialViewMode;

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

  /// 处理视图模式变化
  void _handleViewModeChanged(PromptViewMode mode) {
    if (widget.useSharedViewMode) {
      // 使用共享 Provider 时，更新 Provider 状态
      ref.read(promptViewModeNotifierProvider.notifier).setViewMode(mode);
    } else {
      // 使用本地状态
      setState(() {
        _localViewMode = mode;
      });
    }
  }

  /// 处理清空操作
  void _handleClear() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onTagsChanged?.call([]);
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否有任何工具栏按钮需要显示
    final hasToolbar = widget.toolbarConfig.showViewModeToggle ||
        widget.toolbarConfig.showRandomButton ||
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
                viewMode: _viewMode,
                onViewModeChanged: _handleViewModeChanged,
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
            config: widget.inputConfig.copyWith(
              // 禁用 UnifiedPromptInput 内置的视图切换，由工具栏控制
              enableViewModeToggle: false,
              initialViewMode: _viewMode,
            ),
            controller: _effectiveController,
            focusNode: widget.focusNode,
            decoration: widget.decoration,
            onChanged: widget.onChanged,
            onTagsChanged: widget.onTagsChanged,
            onViewModeChanged: _handleViewModeChanged,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            expands: widget.expands,
          ),
        ),
      ],
    );
  }
}
