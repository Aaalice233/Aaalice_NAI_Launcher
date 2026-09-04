import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/context_menu_anchor.dart';
import '../../../widgets/common/library_classification_drag.dart';
import '../../../widgets/gallery/gallery_album_tree_view.dart';
import '../../../widgets/gallery/gallery_sidebar.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 分类树视图
class CategoryTreeView extends StatefulWidget {
  final List<TagLibraryCategory> categories;
  final List<TagLibraryEntry> entries;
  final String? selectedCategoryId;
  final Set<String> expandedCategoryIds;
  final ValueChanged<Set<String>> onExpandedCategoryIdsChanged;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName) onCategoryRename;
  final ValueChanged<String> onCategoryDelete;
  final ValueChanged<String?> onAddSubCategory;
  final ValueChanged<String?>? onAddEntry;

  /// 分类移动到新父级（跨层级移动）
  final void Function(String categoryId, String? newParentId)? onCategoryMove;

  /// 分类在同级内重排序
  final void Function(String? parentId, int oldIndex, int newIndex)?
  onCategoryReorder;

  /// 词条拖拽到分类
  final void Function(String entryId, String? categoryId)? onEntryDrop;
  final ValueChanged<String>? onEntryFavoriteDrop;
  final bool includeAllEntries;

  const CategoryTreeView({
    super.key,
    required this.categories,
    required this.entries,
    this.selectedCategoryId,
    required this.expandedCategoryIds,
    required this.onExpandedCategoryIdsChanged,
    required this.onCategorySelected,
    required this.onCategoryRename,
    required this.onCategoryDelete,
    required this.onAddSubCategory,
    this.onAddEntry,
    this.onCategoryMove,
    this.onCategoryReorder,
    this.onEntryDrop,
    this.onEntryFavoriteDrop,
    this.includeAllEntries = true,
  });

  @override
  State<CategoryTreeView> createState() => _CategoryTreeViewState();
}

class _CategoryTreeViewState extends State<CategoryTreeView> {
  /// 当前正在被拖拽悬停的分类ID
  String? _hoveredCategoryId;

  /// 悬停自动展开定时器
  Timer? _autoExpandTimer;

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  void _startAutoExpandTimer(String categoryId) {
    _autoExpandTimer?.cancel();
    _autoExpandTimer = Timer(const Duration(milliseconds: 800), () {
      if (_hoveredCategoryId == categoryId && mounted) {
        _setCategoryExpanded(categoryId, true);
      }
    });
  }

  void _setCategoryExpanded(String categoryId, bool expanded) {
    if (widget.expandedCategoryIds.contains(categoryId) == expanded) return;
    final nextExpandedIds = Set<String>.of(widget.expandedCategoryIds);
    if (expanded) {
      nextExpandedIds.add(categoryId);
    } else {
      nextExpandedIds.remove(categoryId);
    }
    widget.onExpandedCategoryIdsChanged(nextExpandedIds);
  }

  void _cancelAutoExpandTimer() {
    _autoExpandTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showEmptyAreaContextMenu(context, details.globalPosition);
      },
      behavior: HitTestBehavior.translucent,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (widget.includeAllEntries)
            _buildEntryDropTarget(
              categoryId: null,
              child: GalleryAllImagesItem(
                icon: Icons.folder_outlined,
                selectedIcon: Icons.folder,
                label: context.l10n.tagLibrary_allEntries,
                count: widget.entries.length,
                isSelected: widget.selectedCategoryId == null,
                onTap: () => widget.onCategorySelected(null),
              ),
            ),

          LibraryClassificationDropTarget<TagLibraryEntry>(
            enabled: widget.onEntryFavoriteDrop != null,
            canAccept: (entry) => !entry.isFavorite,
            onAccept: (entry) => widget.onEntryFavoriteDrop?.call(entry.id),
            child: GallerySidebarFavoritesItem(
              key: const ValueKey('tag-library-favorites'),
              label: context.l10n.tagLibrary_favorites,
              count: widget.entries.where((e) => e.isFavorite).length,
              isSelected: widget.selectedCategoryId == 'favorites',
              onTap: () => widget.onCategorySelected('favorites'),
            ),
          ),

          // 分类树
          ...widget.categories.rootCategories.sortedByOrder().map(
            (category) => _buildCategoryNode(theme, category, 0),
          ),
        ],
      ),
    );
  }

  /// 空白区域右键菜单
  void _showEmptyAreaContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: contextMenuAnchorAt(context, position),
      items: [
        if (widget.onAddEntry != null)
          PopupMenuItem(
            onTap: () => widget.onAddEntry?.call(null),
            child: Row(
              children: [
                const Icon(Icons.add_box_outlined, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.tagLibrary_addEntry),
              ],
            ),
          ),
        PopupMenuItem(
          onTap: () => widget.onAddSubCategory(null),
          child: Row(
            children: [
              const Icon(Icons.create_new_folder, size: 18),
              const SizedBox(width: 8),
              Text(context.l10n.tagLibrary_newCategory),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryNode(
    ThemeData theme,
    TagLibraryCategory category,
    int depth,
  ) {
    final children = widget.categories.getChildren(category.id).sortedByOrder();
    final hasChildren = children.isNotEmpty;
    final isExpanded = widget.expandedCategoryIds.contains(category.id);
    final entryCount = _getCategoryEntryCount(category.id);

    // 构建分类项内容
    Widget categoryItem = _CategoryItem(
      icon: hasChildren
          ? (isExpanded ? Icons.folder_open : Icons.folder)
          : Icons.folder_outlined,
      label: category.displayName,
      count: entryCount,
      isSelected: widget.selectedCategoryId == category.id,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      onTap: () => widget.onCategorySelected(category.id),
      onExpand: hasChildren
          ? () => _setCategoryExpanded(category.id, !isExpanded)
          : null,
      onRename: (newName) => widget.onCategoryRename(category.id, newName),
      onDelete: () => widget.onCategoryDelete(category.id),
      onAddSubCategory: () => widget.onAddSubCategory(category.id),
      onAddEntry: widget.onAddEntry == null
          ? null
          : () => widget.onAddEntry?.call(category.id),
      // 仅当分类不在根目录时显示"移动到根目录"选项
      onMoveToRoot: category.parentId != null && widget.onCategoryMove != null
          ? () => widget.onCategoryMove!(category.id, null)
          : null,
    );

    // 包装为可拖拽
    categoryItem = _buildDraggableCategory(category, categoryItem);

    // 包装为拖拽目标（接收分类和词条）
    categoryItem = _buildCategoryDragTarget(theme, category, categoryItem);
    categoryItem = _buildEntryDropTarget(
      categoryId: category.id,
      child: categoryItem,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        categoryItem,
        if (hasChildren && isExpanded)
          ...children.map(
            (child) => _buildCategoryNode(theme, child, depth + 1),
          ),
      ],
    );
  }

  /// 构建可拖拽的分类节点
  Widget _buildDraggableCategory(TagLibraryCategory category, Widget child) {
    if (widget.onCategoryMove == null && widget.onCategoryReorder == null) {
      return child;
    }

    final theme = Theme.of(context);

    final feedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: theme.colorScheme.surfaceContainerHigh,
      shadowColor: Colors.black45,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    final childWhenDragging = Opacity(opacity: 0.4, child: child);
    void onDragStarted() => HapticFeedback.mediumImpact();
    void onDragEnd(DraggableDetails _) {
      _cancelAutoExpandTimer();
      setState(() => _hoveredCategoryId = null);
    }

    if (context.interactionPolicy.shouldExposeTouchAlternatives) {
      return LongPressDraggable<TagLibraryCategory>(
        data: category,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        onDragStarted: onDragStarted,
        onDragEnd: onDragEnd,
        child: child,
      );
    }
    return Draggable<TagLibraryCategory>(
      data: category,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      onDragStarted: onDragStarted,
      onDragEnd: onDragEnd,
      child: child,
    );
  }

  /// 构建分类拖拽目标（接收其他分类拖入成为子分类）
  Widget _buildCategoryDragTarget(
    ThemeData theme,
    TagLibraryCategory targetCategory,
    Widget child,
  ) {
    if (widget.onCategoryMove == null) {
      return child;
    }

    return DragTarget<TagLibraryCategory>(
      onWillAcceptWithDetails: (details) {
        final draggedCategory = details.data;
        // 不能拖到自己
        if (draggedCategory.id == targetCategory.id) return false;
        // 检查循环引用
        if (widget.categories.wouldCreateCycle(
          draggedCategory.id,
          targetCategory.id,
        )) {
          return false;
        }
        // 已经是子分类则不接受
        if (draggedCategory.parentId == targetCategory.id) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onCategoryMove?.call(details.data.id, targetCategory.id);
        // 自动展开目标分类
        _setCategoryExpanded(targetCategory.id, true);
        setState(() => _hoveredCategoryId = null);
        _cancelAutoExpandTimer();
      },
      onMove: (details) {
        if (_hoveredCategoryId != targetCategory.id) {
          setState(() {
            _hoveredCategoryId = targetCategory.id;
          });
          // 如果有子分类，启动自动展开定时器
          final hasChildren = widget.categories
              .getChildren(targetCategory.id)
              .isNotEmpty;
          if (hasChildren &&
              !widget.expandedCategoryIds.contains(targetCategory.id)) {
            _startAutoExpandTimer(targetCategory.id);
          }
        }
      },
      onLeave: (_) {
        if (_hoveredCategoryId == targetCategory.id) {
          setState(() {
            _hoveredCategoryId = null;
          });
          _cancelAutoExpandTimer();
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;
        final isRejected = rejectedData.isNotEmpty;

        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isAccepting
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: isAccepting
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : isRejected
                ? Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );
      },
    );
  }

  /// 构建词条拖拽目标
  Widget _buildEntryDropTarget({
    required String? categoryId,
    required Widget child,
  }) {
    if (widget.onEntryDrop == null) {
      return child;
    }

    return DragTarget<TagLibraryEntry>(
      onWillAcceptWithDetails: (details) {
        // 如果词条已经在这个分类，不接受
        if (details.data.categoryId == categoryId) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        HapticFeedback.heavyImpact();
        widget.onEntryDrop?.call(details.data.id, categoryId);
      },
      builder: (context, candidateData, rejectedData) {
        final isAccepting = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isAccepting
                ? LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.15),
                      Colors.green.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: isAccepting
                ? const Border(left: BorderSide(color: Colors.green, width: 4))
                : null,
            borderRadius: isAccepting ? BorderRadius.circular(8) : null,
          ),
          child: child,
        );
      },
    );
  }

  int _getCategoryEntryCount(String categoryId) {
    final categoryIds = {
      categoryId,
      ...widget.categories.getDescendantIds(categoryId),
    };
    return widget.entries
        .where((e) => categoryIds.contains(e.categoryId))
        .length;
  }
}

/// 分类项
class _CategoryItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onExpand;
  final void Function(String)? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSubCategory;
  final VoidCallback? onAddEntry;
  final VoidCallback? onMoveToRoot;

  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    this.depth = 0,
    this.hasChildren = false,
    this.isExpanded = false,
    required this.onTap,
    this.onExpand,
    this.onRename,
    this.onDelete,
    this.onAddSubCategory,
    this.onAddEntry,
    this.onMoveToRoot,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  bool _isActionMenuOpen = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.label);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Deep imported hierarchies must retain room for the label and action menu
    // instead of pushing the row beyond a compact bottom sheet.
    final indent = (12.0 + widget.depth * 16.0).clamp(12.0, 44.0).toDouble();
    // 菜单打开后指针被遮罩挡在行外，必须保住按钮挂载，否则选中值随按钮一起消失。
    final showActions =
        widget.onRename != null &&
        (!context.interactionPolicy.precisePointerAvailable ||
            _isHovering ||
            _isActionMenuOpen);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onSecondaryTapUp: widget.onRename != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        // 悬停色立即切换，避免鼠标快速移动时前后两行同时残留高亮。
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primaryContainer
                : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: indent,
                  end: showActions ? 0 : 8,
                ),
                child: Row(
                  children: [
                    // 展开/折叠按钮在触屏上保留完整点击区域；叶节点使用等宽占位。
                    if (widget.hasChildren)
                      IconButton(
                        onPressed: widget.onExpand,
                        tooltip: widget.isExpanded
                            ? context.l10n.common_collapse
                            : context.l10n.common_expand,
                        icon: Icon(
                          widget.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.outline,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                      )
                    else
                      const SizedBox(width: 48, height: 48),

                    // 图标
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),

                    // 名称
                    Expanded(
                      child: _isEditing
                          ? ThemedInput(
                              controller: _editController,
                              autofocus: true,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  widget.onRename?.call(value.trim());
                                }
                                setState(() => _isEditing = false);
                              },
                              onTapOutside: (_) {
                                setState(() => _isEditing = false);
                              },
                            )
                          : Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: widget.isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: widget.isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),

                    // 数量
                    Text(
                      widget.count.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: widget.isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (showActions)
                      PopupMenuButton<_CategoryAction>(
                        key: const ValueKey('category-item-actions-menu'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).moreButtonTooltip,
                        onOpened: () =>
                            setState(() => _isActionMenuOpen = true),
                        onCanceled: () =>
                            setState(() => _isActionMenuOpen = false),
                        onSelected: (action) {
                          setState(() => _isActionMenuOpen = false);
                          _handleAction(action);
                        },
                        itemBuilder: _buildActionItems,
                        icon: const Icon(Icons.more_vert, size: 20),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final action = await showMenu<_CategoryAction>(
      context: context,
      position: contextMenuAnchorAt(context, position),
      items: _buildActionItems(context),
    );
    if (mounted && action != null) _handleAction(action);
  }

  List<PopupMenuEntry<_CategoryAction>> _buildActionItems(
    BuildContext context,
  ) {
    return [
      PopupMenuItem(
        value: _CategoryAction.rename,
        child: Row(
          children: [
            const Icon(Icons.edit, size: 18),
            const SizedBox(width: 8),
            Text(context.l10n.common_rename),
          ],
        ),
      ),
      if (widget.onAddEntry != null)
        PopupMenuItem(
          value: _CategoryAction.addEntry,
          child: Row(
            children: [
              const Icon(Icons.add_box_outlined, size: 18),
              const SizedBox(width: 8),
              Text(context.l10n.tagLibrary_addEntry),
            ],
          ),
        ),
      if (widget.onAddSubCategory != null)
        PopupMenuItem(
          value: _CategoryAction.addSubCategory,
          child: Row(
            children: [
              const Icon(Icons.create_new_folder, size: 18),
              const SizedBox(width: 8),
              Text(context.l10n.tagLibrary_addSubCategory),
            ],
          ),
        ),
      if (widget.onMoveToRoot != null)
        PopupMenuItem(
          value: _CategoryAction.moveToRoot,
          child: Row(
            children: [
              const Icon(Icons.drive_file_move_outline, size: 18),
              const SizedBox(width: 8),
              Text(context.l10n.tagLibrary_moveToRoot),
            ],
          ),
        ),
      PopupMenuItem(
        value: _CategoryAction.delete,
        child: Row(
          children: [
            Icon(
              Icons.delete,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.common_delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    ];
  }

  void _handleAction(_CategoryAction action) {
    switch (action) {
      case _CategoryAction.rename:
        _editController.text = widget.label;
        setState(() => _isEditing = true);
      case _CategoryAction.addSubCategory:
        widget.onAddSubCategory?.call();
      case _CategoryAction.addEntry:
        widget.onAddEntry?.call();
      case _CategoryAction.moveToRoot:
        widget.onMoveToRoot?.call();
      case _CategoryAction.delete:
        widget.onDelete?.call();
    }
  }
}

enum _CategoryAction { rename, addEntry, addSubCategory, moveToRoot, delete }
