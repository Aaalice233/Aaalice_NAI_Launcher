import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_prompt_parser.dart';
import '../../../data/models/prompt/prompt_tag.dart';
import '../../providers/image_generation_provider.dart';
import '../autocomplete/autocomplete.dart';
import 'components/batch_selection/selection_overlay.dart';
import 'components/tag_chip/tag_chip.dart';
import 'components/tag_chip/tag_chip_animations.dart';
import 'core/prompt_tag_config.dart';
import 'tag_group_browser.dart';
import 'tag_favorite_panel.dart';
import 'tag_template_panel.dart';

/// 重构后的提示词标签视图组件
/// 支持框选、拖拽排序、批量操作、内联编辑等
class TagView extends ConsumerStatefulWidget {
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

  /// 是否启用框选（桌面端）
  final bool enableBoxSelection;

  /// 是否显示加载骨架屏
  final bool isLoading;

  const TagView({
    super.key,
    required this.tags,
    required this.onTagsChanged,
    this.readOnly = false,
    this.showAddButton = true,
    this.compact = false,
    this.emptyHint,
    this.maxHeight,
    this.enableBoxSelection = true,
    this.isLoading = false,
  });

  @override
  ConsumerState<TagView> createState() => _TagViewState();
}

class _TagViewState extends ConsumerState<TagView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isAddingTag = false;
  final TextEditingController _addTagController = TextEditingController();
  final FocusNode _addTagFocusNode = FocusNode();
  int? _dragTargetIndex;
  String? _editingTagId;

  // 框选相关
  final List<GlobalKey> _tagKeys = [];
  final BoxSelectionController _selectionController = BoxSelectionController();

  // Tab 控制
  late TabController _tabController;

  // Tab 状态持久化
  int _currentTabIndex = 0;

  // 入场动画相关
  late AnimationController _entranceController;

  // 骨架屏加载动画相关
  late AnimationController _shimmerController;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _updateTagKeys();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _currentTabIndex,
    );
    _tabController.addListener(_handleTabChange);

    // 初始化入场动画控制器
    _entranceController = TagChipAnimationControllerFactory.createEntranceController(this);
    _entranceController.forward();

    // 初始化骨架屏shimmer动画控制器
    _shimmerController = TagChipAnimationControllerFactory.createShimmerController(this);
    _shimmerController.repeat();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void didUpdateWidget(TagView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tags.length != oldWidget.tags.length) {
      _updateTagKeys();
    }
  }

  void _updateTagKeys() {
    while (_tagKeys.length < widget.tags.length) {
      _tagKeys.add(GlobalKey());
    }
    while (_tagKeys.length > widget.tags.length) {
      _tagKeys.removeLast();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _addTagController.dispose();
    _addTagFocusNode.dispose();
    _selectionController.dispose();
    _tabController.dispose();
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ========== 标签操作 ==========

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

  // ========== 编辑模式 ==========

  void _enterEditMode(String id) {
    setState(() {
      _editingTagId = id;
    });
  }

  void _exitEditMode() {
    setState(() {
      _editingTagId = null;
    });
  }

  // ========== 添加标签 ==========

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

  // ========== 批量操作 ==========

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

  void _clearSelection() {
    final newTags = widget.tags.toggleSelectAll(false);
    widget.onTagsChanged(newTags);
  }

  // ========== 框选回调 ==========

  List<Rect> _getTagRects() {
    final rects = <Rect>[];
    for (var i = 0; i < _tagKeys.length; i++) {
      final key = _tagKeys[i];
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        rects.add(position & renderBox.size);
      }
    }
    return rects;
  }

  void _handleBoxSelection(Set<int> indices) {
    final newTags = widget.tags
        .asMap()
        .map((index, tag) {
          final isSelected = indices.contains(index);
          return MapEntry(index, tag.copyWith(selected: isSelected));
        })
        .values
        .toList();
    widget.onTagsChanged(newTags);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final hasSelection = widget.tags.any((t) => t.selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab Bar
        _buildTabBar(theme),

        // Tab Content
        Flexible(
          child: Container(
            constraints: widget.maxHeight != null
                ? BoxConstraints(maxHeight: widget.maxHeight! - 48)
                : null,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tags Tab - 现有的标签视图
                KeyedSubtree(
                  key: const ValueKey('tags_tab'),
                  child: _buildTagsTabContent(theme, hasSelection),
                ),

                // Groups Tab - 标签分组浏览器
                KeyedSubtree(
                  key: const ValueKey('groups_tab'),
                  child: _buildGroupsTabContent(theme),
                ),

                // Favorites Tab - 收藏面板
                KeyedSubtree(
                  key: const ValueKey('favorites_tab'),
                  child: _buildFavoritesTabContent(theme),
                ),

                // Templates Tab - 模板面板
                KeyedSubtree(
                  key: const ValueKey('templates_tab'),
                  child: _buildTemplatesTabContent(theme),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.l10n.tag_tabTags),
                      const SizedBox(width: 6),
                      _buildTagCountBadge(theme),
                    ],
                  ),
                ),
                Tab(text: context.l10n.tag_tabGroups),
                Tab(text: context.l10n.tag_tabFavorites),
                Tab(text: context.l10n.tag_tabTemplates),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
              indicatorSize: TabBarIndicatorSize.label,
              dividerHeight: 0,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签计数徽章
  Widget _buildTagCountBadge(ThemeData theme) {
    final totalCount = widget.tags.length;
    final enabledCount = widget.tags.where((t) => t.enabled).length;

    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    return _TagCountBadge(
      totalCount: totalCount,
      enabledCount: enabledCount,
      tags: widget.tags,
      theme: theme,
    );
  }

  Widget _buildTagsTabContent(ThemeData theme, bool hasSelection) {
    Widget content = Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Ctrl+A 全选
          if (event.logicalKey == LogicalKeyboardKey.keyA &&
              HardwareKeyboard.instance.isControlPressed) {
            _selectAll();
            return KeyEventResult.handled;
          }
          // Delete 删除选中
          if (event.logicalKey == LogicalKeyboardKey.delete && hasSelection) {
            _deleteSelectedTags();
            return KeyEventResult.handled;
          }
          // Ctrl+D 切换启用/禁用
          if (event.logicalKey == LogicalKeyboardKey.keyD &&
              HardwareKeyboard.instance.isControlPressed &&
              hasSelection) {
            _toggleSelectedEnabled();
            return KeyEventResult.handled;
          }
          // Escape 清除选择/取消编辑
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_editingTagId != null) {
              _exitEditMode();
              return KeyEventResult.handled;
            }
            if (hasSelection) {
              _clearSelection();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        constraints: widget.maxHeight != null
            ? BoxConstraints(maxHeight: widget.maxHeight! - 48)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 批量操作工具栏（加载状态不显示）
            if (hasSelection && !widget.readOnly && !widget.isLoading)
              _buildBatchActionBar(theme),

            // 标签区域
            Flexible(
              child: widget.isLoading
                  ? _buildSkeletonLoading(theme)
                  : widget.tags.isEmpty && !_isAddingTag
                      ? _buildEmptyState(theme)
                      : widget.tags.isEmpty && _isAddingTag
                          ? Center(child: _buildAddTagInput(theme))
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _buildTagsArea(theme),
                            ),
            ),
          ],
        ),
      ),
    );

    // 桌面端添加框选功能
    if (!_isMobile && widget.enableBoxSelection && !widget.readOnly) {
      content = BoxSelectionOverlay(
        enabled: true,
        getTagRects: _getTagRects,
        onSelectionChanged: _handleBoxSelection,
        child: content,
      );
    }

    return content;
  }

  Widget _buildGroupsTabContent(ThemeData theme) {
    return TagGroupBrowser(
      onTagsChanged: (tagTexts) {
        // 将标签文本列表转换为 PromptTag 列表并添加到当前标签
        var newTags = List<PromptTag>.from(widget.tags);
        for (final tagText in tagTexts) {
          if (!newTags.any((t) => t.text == tagText)) {
            newTags = NaiPromptParser.insertTag(newTags, newTags.length, tagText);
          }
        }
        widget.onTagsChanged(newTags);
      },
      selectedTags: widget.tags.map((t) => t.text).toList(),
      readOnly: widget.readOnly,
    );
  }

  Widget _buildFavoritesTabContent(ThemeData theme) {
    return TagFavoritePanel(
      currentTags: widget.tags,
      onTagsChanged: widget.onTagsChanged,
      readOnly: widget.readOnly,
      compact: widget.compact,
    );
  }

  Widget _buildTemplatesTabContent(ThemeData theme) {
    return TagTemplatePanel(
      currentTags: widget.tags,
      onTagsChanged: widget.onTagsChanged,
      selectedTags: widget.tags.selectedTags,
      readOnly: widget.readOnly,
      compact: widget.compact,
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
              context.l10n.tag_selected(selectedCount),
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
            label: hasEnabledSelected
                ? context.l10n.tag_disable
                : context.l10n.tag_enable,
            onTap: _toggleSelectedEnabled,
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: context.l10n.tag_delete,
            onTap: _deleteSelectedTags,
            theme: theme,
            isDestructive: true,
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _clearSelection,
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 插画图标容器
                    _buildEmptyStateIllustration(theme, value),
                    const SizedBox(height: 24),

                    // 主提示文本
                    Text(
                      widget.emptyHint ?? context.l10n.tag_emptyHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 次要提示文本
                    Text(
                      context.l10n.tag_emptyHintSub,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    // 添加按钮
                    if (widget.showAddButton && !widget.readOnly) ...[
                      const SizedBox(height: 24),
                      _buildAddTagButton(theme),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyStateIllustration(ThemeData theme, double animValue) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.15),
                  theme.colorScheme.primary.withOpacity(0.05),
                  theme.colorScheme.primary.withOpacity(0.02),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutBack,
                builder: (context, iconValue, child) {
                  return Transform.rotate(
                    angle: (1 - iconValue) * 0.3,
                    child: Opacity(
                      opacity: iconValue,
                      child: Icon(
                        Icons.label_outline_rounded,
                        size: 56,
                        color: theme.colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagsArea(ThemeData theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: TagSpacing.horizontal,
          runSpacing: TagSpacing.vertical,
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
    final isEditing = _editingTagId == tag.id;

    // 创建错峰入场动画
    final opacityAnimation = createStaggeredEntranceAnimation(
      index: index,
      controller: _entranceController,
    );

    final slideAnimation = createEntranceSlideAnimation(_entranceController);

    if (widget.readOnly) {
      final tagChip = TagChip(
        tag: tag,
        compact: widget.compact,
        showControls: false,
        onTap: () => _handleTagTap(tag.id),
      );

      return Container(
        key: _tagKeys.length > index ? _tagKeys[index] : null,
        child: TagChipEntranceBuilder(
          opacityAnimation: opacityAnimation,
          slideAnimation: slideAnimation,
          child: tagChip,
        ),
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
              Container(
                key: _tagKeys.length > index ? _tagKeys[index] : null,
                child: TagChipEntranceBuilder(
                  opacityAnimation: opacityAnimation,
                  slideAnimation: slideAnimation,
                  child: DraggableTagChip(
                    tag: tag,
                    index: index,
                    onDelete: () => _handleDeleteTag(tag.id),
                    onTap: () => _handleTagTap(tag.id),
                    onToggleEnabled: () => _handleToggleEnabled(tag.id),
                    onWeightChanged: (weight) =>
                        _handleWeightChanged(tag.id, weight),
                    onTextChanged: (text) => _handleTextChanged(tag.id, text),
                    showControls: !widget.compact,
                    compact: widget.compact,
                    isEditing: isEditing,
                    onEnterEdit: () => _enterEditMode(tag.id),
                    onExitEdit: _exitEditMode,
                  ),
                ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 按钮部分
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _startAddTag,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
                color: theme.colorScheme.primary.withOpacity(0.05),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 14,
                    color: theme.colorScheme.primary.withOpacity(0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.tag_add,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 占位符（与翻译行对齐）
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2),
            child: Text(
              ' ',
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: theme.colorScheme.onSurface.withOpacity(0),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddTagInput(ThemeData theme) {
    final enableAutocomplete = ref.watch(autocompleteSettingsProvider);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: AutocompleteTextField(
                  controller: _addTagController,
                  focusNode: _addTagFocusNode,
                  enableAutocomplete: enableAutocomplete,
                  config: const AutocompleteConfig(
                    maxSuggestions: 10,
                    showTranslation: true,
                    autoInsertComma: false,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.tag_inputHint,
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10,),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _confirmAddTag(),
                ),
              ),
              _buildMiniIconButton(
                icon: Icons.check,
                color: theme.colorScheme.primary,
                onTap: _confirmAddTag,
              ),
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

  /// 构建骨架屏加载视图
  Widget _buildSkeletonLoading(ThemeData theme) {
    // 生成不同宽度的骨架芯片以模拟真实标签
    final skeletonWidths = [80.0, 120.0, 100.0, 90.0, 110.0, 85.0, 95.0, 105.0];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: TagSpacing.horizontal,
                runSpacing: TagSpacing.vertical,
                children: skeletonWidths.map((width) {
                  return SizedBox(
                    width: width,
                    height: widget.compact ? 28.0 : 32.0,
                    child: TagChipShimmerBuilder(
                      shimmerAnimation: _shimmerController,
                      width: width,
                      height: widget.compact ? 28.0 : 32.0,
                      borderRadius: BorderRadius.circular(
                        widget.compact
                            ? TagBorderRadius.small
                            : TagBorderRadius.small,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 标签计数徽章组件
/// 显示总标签数，悬停/点击时显示分类统计
class _TagCountBadge extends StatefulWidget {
  final int totalCount;
  final int enabledCount;
  final List<PromptTag> tags;
  final ThemeData theme;

  const _TagCountBadge({
    required this.totalCount,
    required this.enabledCount,
    required this.tags,
    required this.theme,
  });

  @override
  State<_TagCountBadge> createState() => _TagCountBadgeState();
}

class _TagCountBadgeState extends State<_TagCountBadge> {
  bool _isHovering = false;
  OverlayEntry? _overlayEntry;

  Map<int, int> _getCategoryBreakdown() {
    final breakdown = <int, int>{};
    for (final tag in widget.tags) {
      breakdown[tag.category] = (breakdown[tag.category] ?? 0) + 1;
    }
    return breakdown;
  }

  String _getCategoryName(int category) {
    return switch (category) {
      0 => context.l10n.tag_categoryGeneral,
      1 => context.l10n.tag_categoryArtist,
      3 => context.l10n.tag_categoryCopyright,
      4 => context.l10n.tag_categoryCharacter,
      5 => context.l10n.tag_categoryMeta,
      _ => 'Unknown',
    };
  }

  void _showBreakdownMenu() {
    _hideOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _BreakdownMenu(
        position: Rect.fromLTWH(
          position.dx,
          position.dy + size.height + 4,
          size.width,
          size.height,
        ),
        breakdown: _getCategoryBreakdown(),
        getCategoryName: _getCategoryName,
        onDismiss: _hideOverlay,
        theme: widget.theme,
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) {
        setState(() => _isHovering = false);
        _hideOverlay();
      },
      child: GestureDetector(
        onTap: () {
          if (_overlayEntry == null) {
            _showBreakdownMenu();
          } else {
            _hideOverlay();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.theme.colorScheme.primary.withOpacity(0.2),
                widget.theme.colorScheme.primary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.theme.colorScheme.primary.withOpacity(_isHovering ? 0.5 : 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.totalCount.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.enabledCount < widget.totalCount) ...[
                const SizedBox(width: 2),
                Text(
                  '(${widget.enabledCount})',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 分类统计弹出菜单
class _BreakdownMenu extends StatelessWidget {
  final Rect position;
  final Map<int, int> breakdown;
  final String Function(int) getCategoryName;
  final VoidCallback onDismiss;
  final ThemeData theme;

  const _BreakdownMenu({
    required this.position,
    required this.breakdown,
    required this.getCategoryName,
    required this.onDismiss,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final sortedCategories = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Positioned(
            left: position.left - 50,
            top: position.top,
            child: GestureDetector(
              onTap: () {},
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
                          theme.colorScheme.surfaceContainerHigh.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            context.l10n.tag_countBadgeBreakdown,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        // 分类统计列表
                        ...sortedCategories.map((entry) {
                          final categoryName = getCategoryName(entry.key);
                          final count = entry.value;
                          final percentage = (count / breakdown.values.reduce((a, b) => a + b) * 100);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                // 分类名称
                                Expanded(
                                  child: Text(
                                    categoryName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                                // 数量
                                Text(
                                  count.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 百分比条
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: percentage / 100,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.primary,
                                            theme.colorScheme.primary.withOpacity(0.7),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
