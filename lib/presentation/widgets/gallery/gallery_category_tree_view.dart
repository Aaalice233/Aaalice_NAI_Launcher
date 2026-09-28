import '../../utils/gallery_drop_reader.dart';
export '../../utils/gallery_drop_reader.dart'
    show galleryInternalDragPathFromLocalData;

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../../data/models/gallery/gallery_category.dart';
import '../../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../common/context_menu_anchor.dart';
import '../common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'gallery_scan_progress_panel.dart';
import 'library_sidebar_drag_item.dart';
import '../../utils/library_sidebar_sort.dart';

enum _GalleryCategoryAction {
  rename,
  addSubCategory,
  moveUp,
  moveToRoot,
  delete,
}

/// Gallery category tree view with drag-drop support
class GalleryCategoryTreeView extends StatefulWidget {
  final List<GalleryCategory> categories;
  final int totalImageCount;
  final int favoriteCount;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName)? onCategoryRename;
  final ValueChanged<String>? onCategoryDelete;
  final ValueChanged<String?>? onAddSubCategory;
  final void Function(String categoryId, String? newParentId)? onCategoryMove;
  final Future<bool> Function(
    String categoryId,
    String targetId,
    GalleryTreeDropSlot slot,
  )?
  onCategoryMoveToSlot;
  final Future<void> Function(List<String> imagePaths, String? categoryId)?
  onImagesDrop;
  final VoidCallback? onSyncWithFileSystem;

  /// 是否渲染顶部固定的「全部图片 / 收藏」节点；
  /// 与相簿区并列展示时传 false 避免入口重复。
  final bool includeRootNodes;
  final bool embedded;
  final bool showScanProgress;
  final LibrarySidebarSort sort;

  const GalleryCategoryTreeView({
    super.key,
    required this.categories,
    required this.totalImageCount,
    this.sort = LibrarySidebarSort.original,
    this.favoriteCount = 0,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.onCategoryRename,
    this.onCategoryDelete,
    this.onAddSubCategory,
    this.onCategoryMove,
    this.onCategoryMoveToSlot,
    this.onImagesDrop,
    this.onSyncWithFileSystem,
    this.includeRootNodes = true,
    this.embedded = false,
    this.showScanProgress = true,
  });

  @override
  State<GalleryCategoryTreeView> createState() =>
      _GalleryCategoryTreeViewState();
}

class _GalleryCategoryTreeViewState extends State<GalleryCategoryTreeView> {
  final Set<String> _expandedIds = {};
  final Set<String> _superDraggingCategoryIds = {};

  @override
  void didUpdateWidget(covariant GalleryCategoryTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新出现的分类（新建子分类/同步入册）自动展开其祖先链，
    // 保证新节点立即可见；与相簿树行为保持一致
    if (oldWidget.categories == widget.categories) return;
    final oldIds = {for (final category in oldWidget.categories) category.id};
    final parentOf = {
      for (final category in widget.categories) category.id: category.parentId,
    };
    var changed = false;
    for (final category in widget.categories) {
      if (oldIds.contains(category.id)) continue;
      var parentId = category.parentId;
      while (parentId != null && !_expandedIds.contains(parentId)) {
        changed = true;
        _expandedIds.add(parentId);
        parentId = parentOf[parentId];
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final categoryList = ListView(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(vertical: widget.embedded ? 0 : 8),
      children: [
        if (widget.includeRootNodes) ...[
          _buildImageDropTarget(
            categoryId: null,
            child: _CategoryItem(
              icon: Icons.photo_library_outlined,
              label: context.l10n.localGallery_allImages,
              count: widget.totalImageCount,
              isSelected: widget.selectedCategoryId == null,
              onTap: () => widget.onCategorySelected(null),
            ),
          ),
          _CategoryItem(
            icon: widget.selectedCategoryId == 'favorites'
                ? Icons.favorite
                : Icons.favorite_border,
            iconColor: Colors.red.shade400,
            label: context.l10n.common_favorite,
            count: widget.favoriteCount,
            isSelected: widget.selectedCategoryId == 'favorites',
            onTap: () => widget.onCategorySelected('favorites'),
          ),
        ],
        if (widget.includeRootNodes && widget.categories.isNotEmpty)
          const ThemedDivider(height: 16, indent: 12, endIndent: 12),
        ..._sorted(
          widget.categories.rootCategories,
        ).map((category) => _buildCategoryNode(theme, category, 0)),
      ],
    );

    return GestureDetector(
      onSecondaryTapUp: widget.onAddSubCategory != null
          ? (details) =>
                _showEmptyAreaContextMenu(context, details.globalPosition)
          : null,
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (widget.embedded) categoryList else Expanded(child: categoryList),
          if (widget.showScanProgress) const GalleryScanProgressPanel(),
        ],
      ),
    );
  }

  void _showEmptyAreaContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: contextMenuAnchorAt(context, position),
      items: [
        PopupMenuItem(
          onTap: () => widget.onAddSubCategory?.call(null),
          child: Row(
            children: [
              const Icon(Icons.create_new_folder, size: 18),
              const SizedBox(width: 8),
              Text(context.l10n.localGallery_createCategoryTitle),
            ],
          ),
        ),
      ],
    );
  }

  int _depthOf(GalleryCategory category) {
    var depth = 0;
    String? currentId = category.parentId;
    while (currentId != null) {
      depth++;
      currentId = widget.categories.findById(currentId)?.parentId;
    }
    return depth;
  }

  Widget _buildCategoryNode(
    ThemeData theme,
    GalleryCategory category,
    int depth,
  ) {
    final children = _sorted(
      widget.categories.where((c) => c.parentId == category.id),
    );
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(category.id);

    Widget categoryItem = _CategoryItem(
      icon: hasChildren
          ? (isExpanded ? Icons.folder_open : Icons.folder)
          : Icons.folder_outlined,
      label: category.displayName,
      count: category.imageCount,
      isSelected: widget.selectedCategoryId == category.id,
      depth: depth,
      hasChildren: hasChildren,
      isExpanded: isExpanded,
      onTap: () => widget.onCategorySelected(category.id),
      onExpand: hasChildren
          ? () => setState(() {
              if (isExpanded) {
                _expandedIds.remove(category.id);
              } else {
                _expandedIds.add(category.id);
              }
            })
          : null,
      onRename: widget.onCategoryRename != null
          ? (newName) => widget.onCategoryRename!(category.id, newName)
          : null,
      onDelete: widget.onCategoryDelete != null
          ? () => widget.onCategoryDelete!(category.id)
          : null,
      onAddSubCategory: widget.onAddSubCategory != null
          ? () => widget.onAddSubCategory!(category.id)
          : null,
      onMoveUp:
          category.parentId != null &&
              _depthOf(category) >= 2 &&
              widget.onCategoryMove != null
          ? () {
              final parent = widget.categories.findById(category.parentId!);
              widget.onCategoryMove!(category.id, parent?.parentId);
            }
          : null,
      onMoveToRoot: category.parentId != null && widget.onCategoryMove != null
          ? () => widget.onCategoryMove!(category.id, null)
          : null,
    );

    if (widget.onCategoryMoveToSlot != null) {
      categoryItem = LibrarySidebarDragItem<GalleryCategory>(
        key: ValueKey(('folder-drag', category.id)),
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
        onExpand: () => setState(() => _expandedIds.add(category.id)),
        child: categoryItem,
      );
    }

    categoryItem = _buildImageDropTarget(
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

  List<GalleryCategory> _sorted(Iterable<GalleryCategory> categories) =>
      sortLibrarySidebarItems(
        categories,
        sort: widget.sort,
        idOf: (c) => c.id,
        nameOf: (c) => c.name,
        countOf: (c) => c.imageCount,
        orderOf: (c) => c.sortOrder,
      );

  Widget _buildImageDropTarget({
    required String? categoryId,
    required Widget child,
  }) {
    if (widget.onImagesDrop == null) return child;

    final dragTarget = Builder(
      builder: (context) {
        final showDropEffect = _superDraggingCategoryIds.contains(
          categoryId ?? '__root__',
        );
        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: showDropEffect
                ? LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.15),
                      Colors.green.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: showDropEffect
                ? const Border(left: BorderSide(color: Colors.green, width: 4))
                : null,
            borderRadius: showDropEffect ? BorderRadius.circular(8) : null,
          ),
          child: child,
        );
      },
    );

    // Touch classification is available through the explicit card action.
    if (!PlatformCapabilities.current.supportsExternalFileDrop) {
      return dragTarget;
    }

    return DropRegion(
      formats: galleryDropFormats,
      onDropOver: (event) {
        if (event.session.allowedOperations.contains(DropOperation.copy) &&
            canAcceptGalleryDrop(event.session.items)) {
          final key = categoryId ?? '__root__';
          if (!_superDraggingCategoryIds.contains(key)) {
            setState(() => _superDraggingCategoryIds.add(key));
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (event) {
        final key = categoryId ?? '__root__';
        if (_superDraggingCategoryIds.contains(key)) {
          setState(() => _superDraggingCategoryIds.remove(key));
        }
      },
      onPerformDrop: (event) async {
        final key = categoryId ?? '__root__';
        if (_superDraggingCategoryIds.contains(key)) {
          setState(() => _superDraggingCategoryIds.remove(key));
        }

        await performGalleryDrop(
          context,
          event,
          (paths) => widget.onImagesDrop!(paths, categoryId),
        );
      },
      child: dragTarget,
    );
  }
}

class _CategoryItem extends StatefulWidget {
  final IconData icon;
  final Color? iconColor;
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
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveToRoot;

  const _CategoryItem({
    required this.icon,
    this.iconColor,
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
    this.onMoveUp,
    this.onMoveToRoot,
  });

  @override
  State<_CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<_CategoryItem> {
  bool _isHovering = false;
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.label);
  }

  @override
  void didUpdateWidget(covariant _CategoryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label && !_isEditing) {
      _editController.text = widget.label;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactionPolicy = context.interactionPolicy;
    final isTouch = interactionPolicy.touchAvailable;
    const controlExtent = 48.0;
    final indent = (12.0 + widget.depth * 16.0).clamp(12.0, 44.0).toDouble();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onSecondaryTapUp: widget.onRename != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.colorScheme.primaryContainer
                : (_isHovering
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.07)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: controlExtent),
              child: Padding(
                padding: EdgeInsets.only(left: indent, right: isTouch ? 0 : 8),
                child: Row(
                  children: [
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
                          width: controlExtent,
                          height: controlExtent,
                        ),
                      )
                    else
                      const SizedBox.square(dimension: controlExtent),
                    Icon(
                      widget.icon,
                      size: 18,
                      color:
                          widget.iconColor ??
                          (widget.isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
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
                              onTapOutside: (_) =>
                                  setState(() => _isEditing = false),
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
                    if (_isHovering && widget.onRename != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 14,
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    Text(
                      widget.count.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                    if (isTouch &&
                        (widget.onRename != null ||
                            widget.onAddSubCategory != null ||
                            widget.onMoveToRoot != null ||
                            widget.onDelete != null))
                      PopupMenuButton<_GalleryCategoryAction>(
                        tooltip: context.l10n.common_moreActions,
                        onSelected: (action) {
                          switch (action) {
                            case _GalleryCategoryAction.rename:
                              setState(() => _isEditing = true);
                            case _GalleryCategoryAction.addSubCategory:
                              widget.onAddSubCategory?.call();
                            case _GalleryCategoryAction.moveUp:
                              widget.onMoveUp?.call();
                            case _GalleryCategoryAction.moveToRoot:
                              widget.onMoveToRoot?.call();
                            case _GalleryCategoryAction.delete:
                              widget.onDelete?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          if (widget.onRename != null)
                            PopupMenuItem(
                              value: _GalleryCategoryAction.rename,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.edit),
                                title: Text(context.l10n.common_rename),
                              ),
                            ),
                          if (widget.onAddSubCategory != null)
                            PopupMenuItem(
                              value: _GalleryCategoryAction.addSubCategory,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.create_new_folder),
                                title: Text(
                                  context
                                      .l10n
                                      .localGallery_createSubCategoryTitle,
                                ),
                              ),
                            ),
                          if (widget.onMoveUp != null)
                            PopupMenuItem(
                              value: _GalleryCategoryAction.moveUp,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.arrow_upward),
                                title: Text(
                                  context.l10n.localGallery_moveCategoryUp,
                                ),
                              ),
                            ),
                          if (widget.onMoveToRoot != null)
                            PopupMenuItem(
                              value: _GalleryCategoryAction.moveToRoot,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.drive_file_move_outline,
                                ),
                                title: Text(
                                  context.l10n.localGallery_moveToRoot,
                                ),
                              ),
                            ),
                          if (widget.onDelete != null)
                            PopupMenuItem(
                              value: _GalleryCategoryAction.delete,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                                title: Text(context.l10n.common_delete),
                              ),
                            ),
                        ],
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

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: contextMenuAnchorAt(context, position),
      items: [
        if (widget.onRename != null)
          PopupMenuItem(
            onTap: () => Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) setState(() => _isEditing = true);
            }),
            child: Row(
              children: [
                const Icon(Icons.edit, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.common_rename),
              ],
            ),
          ),
        if (widget.onAddSubCategory != null)
          PopupMenuItem(
            onTap: widget.onAddSubCategory,
            child: Row(
              children: [
                const Icon(Icons.create_new_folder, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.localGallery_createSubCategoryTitle),
              ],
            ),
          ),
        if (widget.onMoveUp != null)
          PopupMenuItem(
            onTap: widget.onMoveUp,
            child: Row(
              children: [
                const Icon(Icons.arrow_upward, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.localGallery_moveCategoryUp),
              ],
            ),
          ),
        if (widget.onMoveToRoot != null)
          PopupMenuItem(
            onTap: widget.onMoveToRoot,
            child: Row(
              children: [
                const Icon(Icons.drive_file_move_outline, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.localGallery_moveToRoot),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem(
            onTap: widget.onDelete,
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
      ],
    );
  }
}
