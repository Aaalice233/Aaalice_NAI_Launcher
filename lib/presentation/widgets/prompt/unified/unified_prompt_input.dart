import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/nai_prompt_parser.dart';
import '../../../../data/models/prompt/prompt_tag.dart';
import '../../autocomplete/autocomplete_text_field.dart';
import '../nai_syntax_controller.dart';
import '../tag_view.dart';
import 'unified_prompt_config.dart';

/// 统一提示词输入组件
///
/// 封装文本输入和标签视图的切换逻辑，支持：
/// - 文本模式：自动补全、语法高亮
/// - 标签模式：拖拽排序、批量操作、权重调整
///
/// 使用示例：
/// ```dart
/// UnifiedPromptInput(
///   config: UnifiedPromptConfig.characterEditor,
///   controller: _promptController,
///   onChanged: (text) => print('Text changed: $text'),
///   onTagsChanged: (tags) => print('Tags changed: ${tags.length}'),
/// )
/// ```
class UnifiedPromptInput extends ConsumerStatefulWidget {
  /// 配置
  final UnifiedPromptConfig config;

  /// 外部文本控制器（可选）
  /// 如果提供，组件将使用此控制器并同步状态
  final TextEditingController? controller;

  /// 焦点节点（可选）
  final FocusNode? focusNode;

  /// 输入装饰
  final InputDecoration? decoration;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 标签列表变化回调
  final ValueChanged<List<PromptTag>>? onTagsChanged;

  /// 视图模式变化回调
  final ValueChanged<PromptViewMode>? onViewModeChanged;

  /// 提交回调（按 Enter 键时触发，不阻止 Shift+Enter 换行）
  final ValueChanged<String>? onSubmitted;

  /// 最大行数（文本模式）
  final int? maxLines;

  /// 最小行数（文本模式）
  final int? minLines;

  /// 是否扩展填满空间
  final bool expands;

  const UnifiedPromptInput({
    super.key,
    this.config = const UnifiedPromptConfig(),
    this.controller,
    this.focusNode,
    this.decoration,
    this.onChanged,
    this.onTagsChanged,
    this.onViewModeChanged,
    this.onSubmitted,
    this.maxLines,
    this.minLines,
    this.expands = false,
  });

  @override
  ConsumerState<UnifiedPromptInput> createState() => _UnifiedPromptInputState();
}

class _UnifiedPromptInputState extends ConsumerState<UnifiedPromptInput> {
  /// 内部文本控制器（当未提供外部控制器时使用）
  TextEditingController? _internalController;

  /// 语法高亮控制器
  NaiSyntaxController? _syntaxController;

  /// 焦点节点
  FocusNode? _internalFocusNode;

  /// 当前视图模式
  late PromptViewMode _viewMode;

  /// 当前标签列表（标签模式下使用）
  List<PromptTag> _tags = [];

  /// 获取有效的文本控制器
  TextEditingController get _effectiveController {
    if (widget.config.enableSyntaxHighlight) {
      return _syntaxController!;
    }
    return widget.controller ?? _internalController!;
  }

  /// 获取有效的焦点节点
  FocusNode get _effectiveFocusNode {
    return widget.focusNode ?? _internalFocusNode!;
  }

  @override
  void initState() {
    super.initState();
    _viewMode = widget.config.initialViewMode;

    // 初始化内部控制器（如果需要）
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }

    // 初始化语法高亮控制器
    if (widget.config.enableSyntaxHighlight) {
      final initialText = widget.controller?.text ?? '';
      _syntaxController = NaiSyntaxController(
        text: initialText,
        highlightEnabled: true,
      );
    }

    // 初始化焦点节点（如果需要）
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }

    // 监听外部控制器变化
    widget.controller?.addListener(_syncFromExternalController);

    // 初始化标签列表
    _updateTagsFromText();
  }

  @override
  void didUpdateWidget(UnifiedPromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 外部控制器变化
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_syncFromExternalController);
      widget.controller?.addListener(_syncFromExternalController);

      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController();
      }

      _syncFromExternalController();
    }

    // 语法高亮配置变化
    if (widget.config.enableSyntaxHighlight !=
        oldWidget.config.enableSyntaxHighlight) {
      if (widget.config.enableSyntaxHighlight && _syntaxController == null) {
        _syntaxController = NaiSyntaxController(
          text: _effectiveController.text,
          highlightEnabled: true,
        );
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncFromExternalController);
    _internalController?.dispose();
    _syntaxController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  /// 同步外部控制器变化到内部状态
  void _syncFromExternalController() {
    if (widget.controller == null) return;

    final externalText = widget.controller!.text;

    // 同步到语法高亮控制器
    if (_syntaxController != null && _syntaxController!.text != externalText) {
      _syntaxController!.text = externalText;
    }

    // 更新标签列表
    _updateTagsFromText();
  }

  /// 从文本更新标签列表
  void _updateTagsFromText() {
    final text = widget.controller?.text ??
        _syntaxController?.text ??
        _internalController?.text ??
        '';
    _tags = NaiPromptParser.parse(text);
  }

  /// 切换视图模式
  void _toggleViewMode() {
    setState(() {
      if (_viewMode == PromptViewMode.text) {
        // 文本 -> 标签：解析文本
        _tags = NaiPromptParser.parse(_effectiveController.text);
        _viewMode = PromptViewMode.tags;
      } else {
        // 标签 -> 文本：序列化标签
        final text = NaiPromptParser.toPromptString(_tags);
        _updateControllerText(text);
        _viewMode = PromptViewMode.text;
      }
    });
    widget.onViewModeChanged?.call(_viewMode);
  }

  /// 更新控制器文本
  void _updateControllerText(String text) {
    if (_syntaxController != null) {
      _syntaxController!.text = text;
    }
    if (_internalController != null) {
      _internalController!.text = text;
    }
    if (widget.controller != null) {
      widget.controller!.text = text;
    }
  }

  /// 处理文本变化
  void _handleTextChanged(String text) {
    // 同步到外部控制器
    if (widget.controller != null && widget.controller!.text != text) {
      widget.controller!.text = text;
    }

    // 更新标签列表
    _tags = NaiPromptParser.parse(text);

    // 触发回调
    widget.onChanged?.call(text);
  }

  /// 处理标签变化
  void _handleTagsChanged(List<PromptTag> tags) {
    setState(() {
      _tags = tags;
    });

    // 同步到文本
    final text = NaiPromptParser.toPromptString(tags);
    _updateControllerText(text);

    // 触发回调
    widget.onTagsChanged?.call(tags);
    widget.onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 视图模式切换按钮（如果启用）
        if (widget.config.enableViewModeToggle && !widget.config.compact)
          _buildViewModeToggle(theme),

        // 主内容区域
        Flexible(
          child: _viewMode == PromptViewMode.text
              ? _buildTextMode(theme)
              : _buildTagMode(theme),
        ),
      ],
    );
  }

  /// 构建视图模式切换按钮
  Widget _buildViewModeToggle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildToggleButton(
            icon: Icons.text_fields,
            label: 'Text',
            isSelected: _viewMode == PromptViewMode.text,
            onTap: () {
              if (_viewMode != PromptViewMode.text) {
                _toggleViewMode();
              }
            },
            theme: theme,
          ),
          const SizedBox(width: 4),
          _buildToggleButton(
            icon: Icons.label_outline,
            label: 'Tags',
            isSelected: _viewMode == PromptViewMode.tags,
            onTap: () {
              if (_viewMode != PromptViewMode.tags) {
                _toggleViewMode();
              }
            },
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.config.readOnly ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建文本模式视图
  Widget _buildTextMode(ThemeData theme) {
    final effectiveDecoration = widget.decoration ??
        InputDecoration(
          hintText: widget.config.hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        );

    if (widget.config.enableAutocomplete) {
      return AutocompleteTextField(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        decoration: effectiveDecoration,
        maxLines: widget.expands ? null : widget.maxLines,
        minLines: widget.expands ? null : widget.minLines,
        expands: widget.expands,
        onChanged: _handleTextChanged,
        onSubmitted: widget.onSubmitted,
        config: widget.config.autocompleteConfig,
        enableAutocomplete: !widget.config.readOnly,
        enableAutoFormat: widget.config.enableAutoFormat,
        enableSdSyntaxAutoConvert: widget.config.enableSdSyntaxAutoConvert,
      );
    }

    // 不启用自动补全时，使用普通 TextField
    return TextField(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      decoration: effectiveDecoration,
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.expands ? null : widget.minLines,
      expands: widget.expands,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      readOnly: widget.config.readOnly,
      onChanged: _handleTextChanged,
      onSubmitted: widget.onSubmitted,
    );
  }

  /// 构建标签模式视图
  Widget _buildTagMode(ThemeData theme) {
    return TagView(
      tags: _tags,
      onTagsChanged: _handleTagsChanged,
      readOnly: widget.config.readOnly,
      showAddButton: !widget.config.readOnly,
      compact: widget.config.compact,
      emptyHint: widget.config.emptyHint,
      maxHeight: widget.config.maxHeight,
    );
  }
}
