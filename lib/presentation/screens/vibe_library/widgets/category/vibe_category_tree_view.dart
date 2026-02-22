import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/vibe/vibe_library_category.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'vibe_category_item.dart';

/// Vibe分类树视图
///
/// 用于在Vibe库侧边栏显示分类树结构，支持展开/折叠、拖拽排序、右键菜单等功能
class VibeCategoryTreeView extends StatefulWidget {
  final List<VibeLibraryCategory> categories;
  final int totalEntryCount;
  final int favoriteCount;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final void Function(String id, String newName)? onCategoryRename;
  final ValueChanged<String>? onCategoryDelete;
  final ValueChanged<String?>? onAddSubCategory;

  /// 分类移动到新父级（跨层级移动）
  final void Function(String categoryId, String? newParentId)? onCategoryMove;

  const VibeCategoryTreeView({
    super.key,
    required this.categories,
    required this.totalEntryCount,
    required this.favoriteCount,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.onCategoryRename,
    this.onCategoryDelete,
    this.onAddSubCategory,
    this.onCategoryMove,
  });

  @override
  State<VibeCategoryTreeView> createState() => _VibeCategoryTreeViewState();
}

class _VibeCategoryTreeViewState extends State<VibeCategoryTreeView> {
  final Set<String> _expandedIds = <String>{};

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
          // 全部Vibe
          VibeCategoryItem(
            icon: Icons.auto_awesome_outlined,
            label: context.l10n.vibeLibrary_allVibes,
            count: widget.totalEntryCount,
            isSelected: widget.selectedCategoryId == null,
            onTap: () => widget.onCategorySelected(null),
          ),
          // 收藏
          VibeCategoryItem(
            icon: widget.selectedCategoryId == 'favorites'
                ? Icons.favorite
                : Icons.favorite_border,
            iconColor: theme.colorScheme.error,
            label: context.l10n.vibeLibrary_favorites,
            count: widget.favoriteCount,
            isSelected: widget.selectedCategoryId == 'favorites',
            onTap: () => widget.onCategorySelected('favorites'),
          ),
          if (widget.categories.isNotEmpty)
            const ThemedDivider(height: 16, indent: 12, endIndent: 12),
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
          onTap: () => widget.onAddSubCategory?.call(null),
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
    VibeLibraryCategory category,
    int depth,
  ) {
    final children = widget.categories.getChildren(category.id).sortedByOrder();
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedIds.contains(category.id);

    // 构建基础分类项
    Widget categoryItem = VibeCategoryItem(
      icon: hasChildren
          ? (isExpanded ? Icons.folder_open : Icons.folder)
          : Icons.folder_outlined,
      label: category.displayName,
      count: _getCategoryChildCount(category.id),
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
      onRename: widget.onCategoryRename != null
          ? (newName) => widget.onCategoryRename!(category.id, newName)
          : null,
      onDelete: widget.onCategoryDelete != null
          ? () => widget.onCategoryDelete!(category.id)
          : null,
      onAddSubCategory: widget.onAddSubCategory != null
          ? () => widget.onAddSubCategory!(category.id)
          : null,
    );

    // 包装为可拖拽组件
    categoryItem = _buildDraggableCategory(theme, category, categoryItem);

    // 包装为拖放目标（接收分类）
    categoryItem = _buildCategoryDragTarget(theme, category, categoryItem);

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
    ThemeData theme,
    VibeLibraryCategory category,
    Widget child,
  ) {
    if (widget.onCategoryMove == null) {
      return child;
    }

    return Draggable<VibeLibraryCategory>(
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
    VibeLibraryCategory targetCategory,
    Widget child,
  ) {
    if (widget.onCategoryMove == null) {
      return child;
    }

    return DragTarget<VibeLibraryCategory>(
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

  /// 获取分类下的直接子分类数量
  ///
  /// 注意：Vibe库使用子分类数量作为显示计数，
  /// 因为Vibe条目直接存储在文件系统中，没有按分类聚合的计数
  int _getCategoryChildCount(String categoryId) {
    return widget.categories.getChildren(categoryId).length;
  }
}
