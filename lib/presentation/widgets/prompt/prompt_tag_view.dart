import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/nai_prompt_parser.dart';
import '../../../data/models/prompt/prompt_tag.dart';
import '../autocomplete/autocomplete.dart';
import 'prompt_tag_chip.dart';

/// 提示词标签视图组件
/// 将提示词以可视化标签形式展示，支持拖拽排序、批量操作等
class PromptTagView extends ConsumerStatefulWidget {
  /// 当前标签列表
  final List<PromptTag> tags;

  /// 标签变化回调
  final ValueChanged<List<PromptTag>> onTagsChanged;

  /// 是否只读
  final bool readOnly;

  /// 是否显示添加按钮
  final bool showAddButton;

  /// 是否紧凑模式
  final bool compact;

  /// 空状态提示文本
  final String? emptyHint;

  /// 最大高度
  final double? maxHeight;

  const PromptTagView({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.readOnly = false,
    this.showAddButton = true,
    this.compact = false,
    this.emptyHint,
    this.maxHeight,
  });

  @override
  ConsumerState<PromptTagView> createState() => _PromptTagViewState();
}

class _PromptTagViewState extends ConsumerState<PromptTagView> {
  bool _isAddingTag = false;
  final TextEditingController _addTagController = TextEditingController();
  final FocusNode _addTagFocusNode = FocusNode();
  int? _dragTargetIndex;

  @override
  void dispose() {
    _addTagController.dispose();
    _addTagFocusNode.dispose();
    super.dispose();
  }

  void _handleDeleteTag(String id) {
    final newTags = NaiPromptParser.removeTag(widget.tags, id);
    widget.onTagsChanged(newTags);
  }

  void _handleToggleEnabled(String id) {
    final newTags = NaiPromptParser.toggleTagEnabled(widget.tags, id);
    widget.onTagsChanged(newTags);
  }

  void _handleWeightChanged(String id, double newWeight) {
    final clampedWeight =
        newWeight.clamp(PromptTag.minWeight, PromptTag.maxWeight);
    final newTags = widget.tags.map((tag) {
      if (tag.id == id) {
        return tag.copyWith(weight: clampedWeight);
      }
      return tag;
    }).toList();
    widget.onTagsChanged(newTags);
  }

  void _handleTextChanged(String id, String newText) {
    final newTags = widget.tags.map((tag) {
      if (tag.id == id) {
        return tag.copyWith(text: newText.trim());
      }
      return tag;
    }).toList();
    widget.onTagsChanged(newTags);
  }

  /// 是否为移动平台
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  void _handleTagTap(String id) {
    final newTags = widget.tags.map((tag) {
      if (tag.id == id) {
        return tag.toggleSelected();
      }
      return tag;
    }).toList();
    widget.onTagsChanged(newTags);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final newTags = NaiPromptParser.moveTag(widget.tags, oldIndex, newIndex);
    widget.onTagsChanged(newTags);
    HapticFeedback.lightImpact();
  }

  void _startAddTag() {
    setState(() {
      _isAddingTag = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addTagFocusNode.requestFocus();
    });
  }

  void _cancelAddTag() {
    setState(() {
      _isAddingTag = false;
      _addTagController.clear();
    });
  }

  void _confirmAddTag() {
    final text = _addTagController.text.trim();
    if (text.isEmpty) {
      _cancelAddTag();
      return;
    }

    final parts =
        text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    var newTags = List<PromptTag>.from(widget.tags);

    for (final part in parts) {
      newTags = NaiPromptParser.insertTag(newTags, newTags.length, part);
    }

    widget.onTagsChanged(newTags);
    _addTagController.clear();
    _addTagFocusNode.requestFocus();
  }

  void _deleteSelectedTags() {
    final newTags = widget.tags.removeSelected();
    widget.onTagsChanged(newTags);
  }

  void _toggleSelectedEnabled() {
    final hasEnabledSelected = widget.tags.selectedTags.any((t) => t.enabled);
    final newTags = hasEnabledSelected
        ? widget.tags.disableSelected()
        : widget.tags.enableSelected();
    widget.onTagsChanged(newTags);
  }

  void _selectAll() {
    final allSelected = widget.tags.every((t) => t.selected);
    final newTags = widget.tags.toggleSelectAll(!allSelected);
    widget.onTagsChanged(newTags);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = widget.tags.any((t) => t.selected);

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyA &&
              HardwareKeyboard.instance.isControlPressed) {
            _selectAll();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.delete && hasSelection) {
            _deleteSelectedTags();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.keyD &&
              HardwareKeyboard.instance.isControlPressed &&
              hasSelection) {
            _toggleSelectedEnabled();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        constraints: widget.maxHeight != null
            ? BoxConstraints(maxHeight: widget.maxHeight!)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 批量操作工具栏
            if (hasSelection && !widget.readOnly) _buildBatchActionBar(theme),

            // 标签区域
            Flexible(
              child: widget.tags.isEmpty && !_isAddingTag
                  ? _buildEmptyState(theme)
                  : _buildTagsArea(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchActionBar(ThemeData theme) {
    final selectedCount = widget.tags.selectedTags.length;
    final hasEnabledSelected = widget.tags.selectedTags.any((t) => t.enabled);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            theme.colorScheme.primary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '已选 $selectedCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const Spacer(),
          _buildActionButton(
            icon: hasEnabledSelected ? Icons.visibility_off : Icons.visibility,
            label: hasEnabledSelected ? '禁用' : '启用',
            onTap: _toggleSelectedEnabled,
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: '删除',
            onTap: _deleteSelectedTags,
            theme: theme,
            isDestructive: true,
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final newTags = widget.tags.toggleSelectAll(false);
                widget.onTagsChanged(newTags);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface.withOpacity(0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变图标容器
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.15),
                    theme.colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                size: 36,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '开始创作',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.emptyHint ?? '添加标签来描述你想要的画面',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            if (widget.showAddButton && !widget.readOnly) ...[
              const SizedBox(height: 24),
              _buildPrimaryAddButton(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryAddButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _startAddTag,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '添加标签',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagsArea(ThemeData theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // 现有标签
            for (var i = 0; i < widget.tags.length; i++)
              _buildDragTarget(i, widget.tags[i], theme),

            // 添加标签按钮或输入框
            if (widget.showAddButton && !widget.readOnly)
              _isAddingTag
                  ? _buildAddTagInput(theme)
                  : _buildAddTagButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDragTarget(int index, PromptTag tag, ThemeData theme) {
    if (widget.readOnly) {
      return PromptTagChip(
        tag: tag,
        compact: widget.compact,
        showWeightControls: false,
        onTap: () => _handleTagTap(tag.id),
      );
    }

    Widget tagWidget = DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        setState(() => _dragTargetIndex = index);
        return details.data != index;
      },
      onLeave: (_) {
        setState(() => _dragTargetIndex = null);
      },
      onAcceptWithDetails: (details) {
        _handleReorder(details.data, index);
        setState(() => _dragTargetIndex = null);
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = _dragTargetIndex == index && candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(left: isTarget ? 28 : 0),
          child: Stack(
            children: [
              // 插入指示器
              if (isTarget)
                Positioned(
                  left: 0,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),

              // 标签卡片
              DraggablePromptTagChip(
                tag: tag,
                index: index,
                onDelete: () => _handleDeleteTag(tag.id),
                onTap: () => _handleTagTap(tag.id),
                onDoubleTap: () => _handleToggleEnabled(tag.id),
                onWeightChanged: (weight) =>
                    _handleWeightChanged(tag.id, weight),
                onTextChanged: (text) => _handleTextChanged(tag.id, text),
                showWeightControls: !widget.compact,
              ),
            ],
          ),
        );
      },
    );

    // 移动端支持滑动删除
    if (_isMobile) {
      tagWidget = Dismissible(
        key: Key(tag.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.error.withOpacity(0.1),
                theme.colorScheme.error.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.delete_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
        ),
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          return true;
        },
        onDismissed: (_) => _handleDeleteTag(tag.id),
        child: tagWidget,
      );
    }

    return tagWidget;
  }

  Widget _buildAddTagButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _startAddTag,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1.5,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.primary.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: theme.colorScheme.primary.withOpacity(0.8),
              ),
              const SizedBox(width: 6),
              Text(
                '添加',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTagInput(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SizedBox(
                  height: 34,
                  child: AutocompleteTextField(
                    controller: _addTagController,
                    focusNode: _addTagFocusNode,
                    config: const AutocompleteConfig(
                      maxSuggestions: 10,
                      showTranslation: true,
                      autoInsertComma: false,
                    ),
                    decoration: InputDecoration(
                      hintText: '输入标签...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _confirmAddTag(),
                  ),
                ),
              ),
              // 确认按钮
              _buildMiniIconButton(
                icon: Icons.check,
                color: theme.colorScheme.primary,
                onTap: _confirmAddTag,
              ),
              // 取消按钮
              _buildMiniIconButton(
                icon: Icons.close,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                onTap: _cancelAddTag,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

/// 带标题的标签视图
class TitledPromptTagView extends StatelessWidget {
  final String title;
  final List<PromptTag> tags;
  final ValueChanged<List<PromptTag>> onTagsChanged;
  final bool readOnly;
  final bool showAddButton;
  final Widget? trailing;

  const TitledPromptTagView({
    super.key,
    required this.title,
    required this.tags,
    required this.onTagsChanged,
    this.readOnly = false,
    this.showAddButton = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tags.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        PromptTagView(
          tags: tags,
          onTagsChanged: onTagsChanged,
          readOnly: readOnly,
          showAddButton: showAddButton,
        ),
      ],
    );
  }
}
