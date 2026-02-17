import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/vibe/vibe_library_category.dart';
import 'category_item.dart';

/// Vibe 分类树视图组件
/// Vibe Category Tree View Component
///
/// 用于显示可展开/折叠的分类树结构，支持选择、重命名、删除等操作
/// Used to display an expandable/collapsible category tree structure,
/// supporting selection, rename, delete, and other operations.
class VibeCategoryTreeView extends ConsumerStatefulWidget {
  /// 所有分类列表
  final List<VibeLibraryCategory> categories;

  /// 当前选中的分类ID（null表示全部）
  final String? selectedCategoryId;

  /// 分类下的条目数量映射（分类ID -> 数量）
  final Map<String, int> categoryEntryCounts;

  /// 是否显示"全部"选项
  final bool showAllOption;

  /// "全部"选项的条目数量
  final int allEntriesCount;

  /// 选择分类回调
  final void Function(String? categoryId) onCategorySelected;

  /// 重命名分类回调
  final void Function(String categoryId, String newName)? onRename;

  /// 删除分类回调
  final void Function(String categoryId)? onDelete;

  /// 添加子分类回调
  final void Function(String parentId)? onAddSubCategory;

  /// 展开/折叠分类回调
  final void Function(String categoryId, bool isExpanded)? onExpandChanged;

  /// 创建一个 [VibeCategoryTreeView] 组件
  const VibeCategoryTreeView({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.categoryEntryCounts,
    this.showAllOption = true,
    this.allEntriesCount = 0,
    required this.onCategorySelected,
    this.onRename,
    this.onDelete,
    this.onAddSubCategory,
    this.onExpandChanged,
  });

  @override
  ConsumerState<VibeCategoryTreeView> createState() =>
      _VibeCategoryTreeViewState();
}

class _VibeCategoryTreeViewState extends ConsumerState<VibeCategoryTreeView> {
  /// 已展开的分类ID集合
  final Set<String> _expandedCategoryIds = {};

  /// 获取分类树结构
  Map<String?, List<VibeLibraryCategory>> get _categoryTree {
    final tree = <String?, List<VibeLibraryCategory>>{};
    for (final category in widget.categories) {
      final parentId = category.parentId;
      tree.putIfAbsent(parentId, () => []).add(category);
    }
    for (final children in tree.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return tree;
  }

  /// 获取根级分类
  List<VibeLibraryCategory> get _rootCategories {
    return _categoryTree[null] ?? [];
  }

  /// 获取子分类
  List<VibeLibraryCategory> _getChildren(String parentId) {
    return _categoryTree[parentId] ?? [];
  }

  /// 检查分类是否有子分类
  bool _hasChildren(String categoryId) {
    return _getChildren(categoryId).isNotEmpty;
  }

  /// 检查分类是否已展开
  bool _isExpanded(String categoryId) {
    return _expandedCategoryIds.contains(categoryId);
  }

  /// 切换分类展开状态
  void _toggleExpand(String categoryId) {
    setState(() {
      if (_expandedCategoryIds.contains(categoryId)) {
        _expandedCategoryIds.remove(categoryId);
      } else {
        _expandedCategoryIds.add(categoryId);
      }
    });
    widget.onExpandChanged?.call(
      categoryId,
      _expandedCategoryIds.contains(categoryId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rootCategories = _rootCategories;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rootCategories.length + (widget.showAllOption ? 1 : 0),
      itemBuilder: (context, index) {
        // "全部"选项
        if (widget.showAllOption && index == 0) {
          return CategoryItem(
            icon: Icons.folder_copy_outlined,
            iconColor: theme.colorScheme.primary,
            label: '全部',
            count: widget.allEntriesCount,
            isSelected: widget.selectedCategoryId == null,
            depth: 0,
            hasChildren: false,
            isExpanded: false,
            onTap: () => widget.onCategorySelected(null),
          );
        }

        // 分类项目
        final categoryIndex = widget.showAllOption ? index - 1 : index;
        final category = rootCategories[categoryIndex];

        return _buildCategoryItem(category, 0);
      },
    );
  }

  /// 构建分类项目（递归构建子分类）
  Widget _buildCategoryItem(VibeLibraryCategory category, int depth) {
    final children = _getChildren(category.id);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _isExpanded(category.id);
    final entryCount = widget.categoryEntryCounts[category.id] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CategoryItem(
          icon: Icons.folder_outlined,
          label: category.name,
          count: entryCount,
          isSelected: widget.selectedCategoryId == category.id,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onTap: () => widget.onCategorySelected(category.id),
          onExpand: hasChildren ? () => _toggleExpand(category.id) : null,
          onRename: widget.onRename != null
              ? (newName) => widget.onRename!(category.id, newName)
              : null,
          onDelete: widget.onDelete != null
              ? () => widget.onDelete!(category.id)
              : null,
          onAddSubCategory: widget.onAddSubCategory != null
              ? () => widget.onAddSubCategory!(category.id)
              : null,
        ),
        // 递归渲染子分类
        if (hasChildren && isExpanded)
          ...children.map((child) => _buildCategoryItem(child, depth + 1)),
      ],
    );
  }

  /// 展开指定分类及其所有父分类
  void expandToCategory(String categoryId) {
    final path = _getCategoryPath(categoryId);
    setState(() {
      for (final category in path) {
        _expandedCategoryIds.add(category.id);
      }
    });
  }

  /// 获取分类路径
  List<VibeLibraryCategory> _getCategoryPath(String categoryId) {
    final path = <VibeLibraryCategory>[];
    String? currentId = categoryId;

    while (currentId != null) {
      final category = widget.categories.cast<VibeLibraryCategory?>().firstWhere(
            (c) => c?.id == currentId,
            orElse: () => null,
          );
      if (category == null) break;
      path.insert(0, category);
      currentId = category.parentId;
    }

    return path;
  }

  /// 展开所有分类
  void expandAll() {
    setState(() {
      _expandedCategoryIds.addAll(
        widget.categories.map((c) => c.id),
      );
    });
  }

  /// 折叠所有分类
  void collapseAll() {
    setState(() {
      _expandedCategoryIds.clear();
    });
  }
}
