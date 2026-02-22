import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/tag_library/tag_library_category.dart';

/// 批量转移分类对话框
class BulkMoveCategoryDialog extends StatelessWidget {
  final List<TagLibraryCategory> categories;
  final String? currentCategoryId;

  const BulkMoveCategoryDialog({
    super.key,
    required this.categories,
    this.currentCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.drive_file_move_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('移动到分类'),
        ],
      ),
      content: SizedBox(
        width: 320,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择目标分类：',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    // 根目录选项
                    _CategoryTile(
                      id: null,
                      name: context.l10n.tagLibrary_rootCategory,
                      isSelected: currentCategoryId == null,
                      onTap: () => Navigator.of(context).pop(null),
                      depth: 0,
                    ),
                    const Divider(height: 1, indent: 8, endIndent: 8),
                    // 分类树
                    ..._buildCategoryTree(context, null),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ],
    );
  }

  /// 递归构建分类树
  List<Widget> _buildCategoryTree(
    BuildContext context,
    String? parentId, {
    int depth = 0,
  }) {
    final result = <Widget>[];

    final children = categories.where((c) => c.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final category in children) {
      result.add(
        _CategoryTile(
          id: category.id,
          name: category.displayName,
          isSelected: category.id == currentCategoryId,
          onTap: () => Navigator.of(context).pop(category.id),
          depth: depth,
        ),
      );

      // 递归添加子分类
      result.addAll(
        _buildCategoryTree(context, category.id, depth: depth + 1),
      );
    }

    return result;
  }
}

/// 分类列表项
class _CategoryTile extends StatelessWidget {
  final String? id;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final int depth;

  const _CategoryTile({
    required this.id,
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.fromLTRB(8 + depth * 20, 10, 12, 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.folder : Icons.folder_outlined,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
