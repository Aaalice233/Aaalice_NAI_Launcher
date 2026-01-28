import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../widgets/common/themed_divider.dart';

/// 分类树视图
class CategoryTreeView extends StatefulWidget {
  final List<TagLibraryCategory> categories;
  final List<TagLibraryEntry> entries;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName) onCategoryRename;
  final ValueChanged<String> onCategoryDelete;
  final ValueChanged<String?> onAddSubCategory;

  /// 分类移动到新父级（跨层级移动）
  final void Function(String categoryId, String? newParentId)? onCategoryMove;

  /// 分类在同级内重排序
  final void Function(String? parentId, int oldIndex, int newIndex)?
      onCategoryReorder;

  /// 词条拖拽到分类
  final void Function(String entryId, String? categoryId)? onEntryDrop;

  const CategoryTreeView({
    super.key,
    required this.categories,
    required this.entries,
    this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onCategoryRename,
    required this.onCategoryDelete,
    required this.onAddSubCategory,
    this.onCategoryMove,
    this.onCategoryReorder,
    this.onEntryDrop,
  });

  @override
  State<CategoryTreeView> createState() => _CategoryTreeViewState();
}

class _CategoryTreeViewState extends State<CategoryTreeView> {
  final Set<String> _expandedIds = {};

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
        setState(() {
          _expandedIds.add(categoryId);
        });
      }
    });
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
          // 全部条目 - 可接收词条拖拽（移动到无分类）
          _buildEntryDropTarget(
            categoryId: null,
            child: _CategoryItem(
              icon: Icons.folder_outlined,
              label: context.l10n.tagLibrary_allEntries,
              count: widget.entries.length,
              isSelected: widget.selectedCategoryId == null,
              onTap: () => widget.onCategorySelected(null),
            ),
          ),

          // 收藏 - 不接收拖拽
          _CategoryItem(
            icon: widget.selectedCategoryId == 'favorites'
                ? Icons.favorite
                : Icons.favorite_border,
            iconColor: Colors.red.shade400,
            label: context.l10n.tagLibrary_favorites,
            count: widget.entries.where((e) => e.isFavorite).length,
            isSelected: widget.selectedCategoryId == 'favorites',
            onTap: () => widget.onCategorySelected('favorites'),
          ),

          if (widget.categories.isNotEmpty) ...[
            const ThemedDivider(height: 16, indent: 12, endIndent: 12),
          ],

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
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
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
    final isExpanded = _expandedIds.contains(category.id);
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
          ? () {
              setState(() {
                if (isExpanded) {
                  _expandedIds.remove(category.id);
                } else {
                  _expandedIds.add(category.id);
                }
              });
            }
          : null,
      onRename: (newName) => widget.onCategoryRename(category.id, newName),
      onDelete: () => widget.onCategoryDelete(category.id),
      onAddSubCategory: () => widget.onAddSubCategory(category.id),
      // 仅当分类不在根目录时显示"移动到根目录"选项
      onMoveToRoot: category.parentId != null && widget.onCategoryMove != null
          ? () => widget.onCategoryMove!(category.id, null)
          : null,
    );

    // 包装为可拖拽
    categoryItem = _buildDraggableCategory(category, categoryItem);

    // 包装为拖拽目标（接收分类和词条）
    categoryItem = _buildCategoryDragTarget(theme, category, categoryItem);
    categoryItem =
        _buildEntryDropTarget(categoryId: category.id, child: categoryItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        categoryItem,
        if (hasChildren && isExpanded)
          ...children
              .map((child) => _buildCategoryNode(theme, child, depth + 1)),
      ],
    );
  }

  /// 构建可拖拽的分类节点
  Widget _buildDraggableCategory(
    TagLibraryCategory category,
    Widget child,
  ) {
    if (widget.onCategoryMove == null && widget.onCategoryReorder == null) {
      return child;
    }

    final theme = Theme.of(context);

    return Draggable<TagLibraryCategory>(
      data: category,
      feedback: Material(
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
              color: theme.colorScheme.primary.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder,
                size: 18,
                color: theme.colorScheme.primary,
              ),
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
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: child,
      ),
      onDragStarted: () {
        HapticFeedback.mediumImpact();
      },
      onDragEnd: (_) {
        _cancelAutoExpandTimer();
        setState(() {
          _hoveredCategoryId = null;
        });
      },
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
        if (widget.categories
            .wouldCreateCycle(draggedCategory.id, targetCategory.id)) {
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
        setState(() {
          _expandedIds.add(targetCategory.id);
          _hoveredCategoryId = null;
        });
        _cancelAutoExpandTimer();
      },
      onMove: (details) {
        if (_hoveredCategoryId != targetCategory.id) {
          setState(() {
            _hoveredCategoryId = targetCategory.id;
          });
          // 如果有子分类，启动自动展开定时器
          final hasChildren =
              widget.categories.getChildren(targetCategory.id).isNotEmpty;
          if (hasChildren && !_expandedIds.contains(targetCategory.id)) {
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
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isAccepting
                ? theme.colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            border: isAccepting
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : isRejected
                    ? Border.all(
                        color: theme.colorScheme.error.withOpacity(0.5),
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
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isAccepting
                ? LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.15),
                      Colors.green.withOpacity(0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: isAccepting
                ? const Border(
                    left: BorderSide(
                      color: Colors.green,
                      width: 4,
                    ),
                  )
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
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indent = 12.0 + widget.depth * 16.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onSecondaryTapUp: widget.onRename != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.only(
                left: indent,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  // 展开/折叠按钮
                  if (widget.hasChildren)
                    GestureDetector(
                      onTap: widget.onExpand,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          widget.isExpanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 20),

                  // 图标
                  Icon(
                    widget.icon,
                    size: 18,
                    color: widget.iconColor ??
                        (widget.isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),

                  // 名称
                  Expanded(
                    child: _isEditing
                        ? TextField(
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

                  // 拖拽提示图标（悬停时显示）
                  if (_isHovering && widget.onRename != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 14,
                        color: theme.colorScheme.outline.withOpacity(0.5),
                      ),
                    ),

                  // 数量
                  Text(
                    widget.count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
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
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              setState(() => _isEditing = true);
            });
          },
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
                Text(context.l10n.tagLibrary_addSubCategory),
              ],
            ),
          ),
        // 移动到根目录（仅当不在根目录时显示）
        if (widget.onMoveToRoot != null)
          PopupMenuItem(
            onTap: widget.onMoveToRoot,
            child: Row(
              children: [
                const Icon(Icons.drive_file_move_outline, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.tagLibrary_moveToRoot),
              ],
            ),
          ),
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
