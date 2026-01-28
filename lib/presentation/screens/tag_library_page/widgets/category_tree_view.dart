import 'package:flutter/material.dart';

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

  const CategoryTreeView({
    super.key,
    required this.categories,
    required this.entries,
    this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onCategoryRename,
    required this.onCategoryDelete,
    required this.onAddSubCategory,
  });

  @override
  State<CategoryTreeView> createState() => _CategoryTreeViewState();
}

class _CategoryTreeViewState extends State<CategoryTreeView> {
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // 全部条目
        _CategoryItem(
          icon: Icons.folder_outlined,
          label: context.l10n.tagLibrary_allEntries,
          count: widget.entries.length,
          isSelected: widget.selectedCategoryId == null,
          onTap: () => widget.onCategorySelected(null),
        ),

        // 收藏
        _CategoryItem(
          icon: Icons.star_outline,
          iconColor: Colors.amber,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryItem(
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
        ),
        if (hasChildren && isExpanded)
          ...children
              .map((child) => _buildCategoryNode(theme, child, depth + 1)),
      ],
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
