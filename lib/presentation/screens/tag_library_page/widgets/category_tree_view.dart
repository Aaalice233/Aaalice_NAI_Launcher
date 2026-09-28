import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/context_menu_anchor.dart';
import '../../../widgets/common/library_classification_drag.dart';
import '../../../widgets/gallery/gallery_album_tree_view.dart';
import '../../../widgets/gallery/gallery_sidebar.dart';
import '../../../widgets/gallery/library_sidebar_drag_item.dart';
import '../../../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../../../utils/library_sidebar_sort.dart';
import '../../../utils/library_category_counts.dart';
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

  final Future<bool> Function(
    String id,
    String targetId,
    GalleryTreeDropSlot slot,
  )?
  onCategoryMoveToSlot;
  final LibrarySidebarSort sort;

  /// 词条拖拽到分类
  final FutureOr<void> Function(String entryId, String? categoryId)?
  onEntryDrop;
  final FutureOr<void> Function(String)? onEntryFavoriteDrop;
  final bool includeAllEntries;
  final bool embedded;

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
    this.onCategoryMoveToSlot,
    this.sort = LibrarySidebarSort.original,
    this.onEntryDrop,
    this.onEntryFavoriteDrop,
    this.includeAllEntries = true,
    this.embedded = false,
  });

  @override
  State<CategoryTreeView> createState() => _CategoryTreeViewState();
}

class _CategoryTreeViewState extends State<CategoryTreeView> {
  Map<String, int> _counts = const {};
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _counts = libraryCategoryCounts({
      for (final category in widget.categories) category.id: category.parentId,
    }, widget.entries.map((entry) => entry.categoryId));

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showEmptyAreaContextMenu(context, details.globalPosition);
      },
      behavior: HitTestBehavior.translucent,
      child: ListView(
        shrinkWrap: widget.embedded,
        primary: widget.embedded ? false : null,
        physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
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
            kind: AgentChatResourceKind.tagLibraryEntry,
            resolve: (id) =>
                widget.entries.where((entry) => entry.id == id).singleOrNull,
            enabled: widget.onEntryFavoriteDrop != null,
            needsChange: (entry) => !entry.isFavorite,
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
          ..._sorted(
            widget.categories.rootCategories,
          ).map((category) => _buildCategoryNode(theme, category, 0)),
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
    final children = _sorted(
      widget.categories.where((c) => c.parentId == category.id),
    );
    final hasChildren = children.isNotEmpty;
    final isExpanded = widget.expandedCategoryIds.contains(category.id);
    final entryCount = _counts[category.id] ?? 0;

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

    if (widget.onCategoryMoveToSlot != null) {
      categoryItem = LibrarySidebarDragItem<TagLibraryCategory>(
        key: ValueKey(('tag-category-drag', category.id)),
        item: category,
        label: category.displayName,
        icon: Icons.folder_outlined,
        canDrop: (source, slot) =>
            source.id != category.id &&
            !widget.categories.wouldCreateCycle(
              source.id,
              slot == GalleryTreeDropSlot.child
                  ? category.id
                  : category.parentId,
            ) &&
            !(slot == GalleryTreeDropSlot.child &&
                source.parentId == category.id),
        onDrop: (source, slot) =>
            widget.onCategoryMoveToSlot!(source.id, category.id, slot),
        onExpand: () => _setCategoryExpanded(category.id, true),
        child: categoryItem,
      );
    }
    categoryItem = _buildEntryDropTarget(
      categoryId: category.id,
      child: categoryItem,
    );

    return Column(
      key: ValueKey(category.id),
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

  Widget _buildEntryDropTarget({
    required String? categoryId,
    required Widget child,
  }) {
    if (widget.onEntryDrop == null) {
      return child;
    }

    return LibraryClassificationDropTarget<TagLibraryEntry>(
      kind: AgentChatResourceKind.tagLibraryEntry,
      resolve: (id) =>
          widget.entries.where((entry) => entry.id == id).singleOrNull,
      needsChange: (entry) => entry.categoryId != categoryId,
      onAccept: (entry) => widget.onEntryDrop?.call(entry.id, categoryId),
      child: Builder(
        builder: (context) {
          final isAccepting =
              LibraryClassificationDropTargetStatus.isAcceptingOf(context);

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
                  ? const Border(
                      left: BorderSide(color: Colors.green, width: 4),
                    )
                  : null,
              borderRadius: isAccepting ? BorderRadius.circular(8) : null,
            ),
            child: child,
          );
        },
      ),
    );
  }

  List<TagLibraryCategory> _sorted(Iterable<TagLibraryCategory> categories) =>
      sortLibrarySidebarItems(
        categories,
        sort: widget.sort,
        idOf: (c) => c.id,
        nameOf: (c) => c.displayName,
        countOf: (c) => _counts[c.id] ?? 0,
        orderOf: (c) => c.sortOrder,
      );
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
