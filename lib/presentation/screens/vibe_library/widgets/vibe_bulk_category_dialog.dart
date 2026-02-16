import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_category.dart';

/// Vibe 批量移动分类选择对话框
///
/// 用于选择批量移动操作的目标分类，包括：
/// - 显示分类树结构
/// - 支持选择目标分类（单选）
/// - 包含"未分类"选项
/// - 确认后返回选中的分类 ID（null 表示未分类）
class VibeBulkCategoryDialog extends ConsumerStatefulWidget {
  /// 所有分类列表
  final List<VibeLibraryCategory> categories;

  /// 当前选中的分类 ID（可选，用于排除）
  final String? excludeCategoryId;

  /// 要移动的条目数量（用于显示提示）
  final int entryCount;

  const VibeBulkCategoryDialog({
    super.key,
    required this.categories,
    this.excludeCategoryId,
    required this.entryCount,
  });

  /// 显示批量移动分类选择对话框
  ///
  /// 返回选中的分类 ID，如果用户取消则返回 null
  /// 返回空字符串 '' 表示选择"未分类"
  static Future<String?> show({
    required BuildContext context,
    required List<VibeLibraryCategory> categories,
    String? excludeCategoryId,
    required int entryCount,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (context) => VibeBulkCategoryDialog(
        categories: categories,
        excludeCategoryId: excludeCategoryId,
        entryCount: entryCount,
      ),
    );
  }

  @override
  ConsumerState<VibeBulkCategoryDialog> createState() =>
      _VibeBulkCategoryDialogState();
}

class _VibeBulkCategoryDialogState
    extends ConsumerState<VibeBulkCategoryDialog> {
  /// 选中的分类 ID
  /// - null: 未选择
  /// - '': 未分类
  /// - 其他: 具体分类 ID
  String? _selectedCategoryId;

  /// 展开的分类
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // 默认展开所有根级分类
    for (final category in widget.categories) {
      if (category.parentId == null) {
        _expandedCategories.add(category.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.drive_file_move_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '选择目标分类',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 提示文本
              Text(
                '将 ${widget.entryCount} 个 Vibe 移动到:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),

              const SizedBox(height: 16),

              // 分类列表
              Expanded(child: _buildCategoryList(theme)),

              const Divider(height: 24),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.common_cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedCategoryId != null
                        ? () => Navigator.of(context).pop(_selectedCategoryId)
                        : null,
                    child: Text(l10n.common_confirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分类列表
  Widget _buildCategoryList(ThemeData theme) {
    // 构建分类树结构
    final rootCategories = widget.categories
        .where((c) => c.parentId == null)
        .sortedByOrder()
        .toList();

    return ListView.builder(
      itemCount: rootCategories.length + 1, // +1 为未分类选项
      itemBuilder: (context, index) {
        // 第一项是未分类
        if (index == 0) {
          return _buildUncategorizedTile(theme);
        }

        // 然后是分类树
        final category = rootCategories[index - 1];
        return _buildCategoryTile(category, 0);
      },
    );
  }

  /// 构建未分类选项
  Widget _buildUncategorizedTile(ThemeData theme) {
    final isSelected = _selectedCategoryId == '';

    return InkWell(
      onTap: () {
        setState(() => _selectedCategoryId = '');
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary)
              : null,
        ),
        child: Row(
          children: [
            Radio<String?>(
              value: '',
              groupValue: _selectedCategoryId,
              onChanged: (value) {
                setState(() => _selectedCategoryId = value);
              },
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.folder_open_outlined,
              size: 20,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '未分类',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// 构建分类项（递归）
  Widget _buildCategoryTile(VibeLibraryCategory category, int depth) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategoryId == category.id;
    final isExpanded = _expandedCategories.contains(category.id);

    // 如果被排除（不能移动到自己）
    final isExcluded = widget.excludeCategoryId == category.id;

    // 获取子分类
    final childCategories = widget.categories
        .where((c) => c.parentId == category.id)
        .sortedByOrder()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isExcluded
              ? null
              : () {
                  setState(() => _selectedCategoryId = category.id);
                },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.only(left: depth * 16.0),
            child: Opacity(
              opacity: isExcluded ? 0.5 : 1.0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary)
                      : null,
                ),
                child: Row(
                  children: [
                    // 展开/折叠按钮
                    if (childCategories.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 20,
                          color: theme.colorScheme.outline,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedCategories.remove(category.id);
                            } else {
                              _expandedCategories.add(category.id);
                            }
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      )
                    else
                      const SizedBox(width: 32),

                    // 单选按钮
                    Radio<String?>(
                      value: category.id,
                      groupValue: _selectedCategoryId,
                      onChanged: isExcluded
                          ? null
                          : (value) {
                              setState(() => _selectedCategoryId = value);
                            },
                    ),

                    const SizedBox(width: 8),

                    // 文件夹图标
                    Icon(
                      isExpanded ? Icons.folder_open : Icons.folder,
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withOpacity(0.7),
                    ),

                    const SizedBox(width: 12),

                    // 分类名称
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : isExcluded
                                      ? theme.colorScheme.outline
                                      : null,
                            ),
                          ),
                          if (isExcluded)
                            Text(
                              '不能移动到当前所在分类',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 选中标记
                    if (isSelected)
                      Icon(
                        Icons.check,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 子分类
        if (isExpanded)
          ...childCategories.map(
            (child) => _buildCategoryTile(child, depth + 1),
          ),
      ],
    );
  }
}

/// 便捷方法：显示批量移动分类选择对话框
///
/// 返回选中的分类 ID：
/// - null: 用户取消
/// - '': 未分类
/// - 其他字符串: 具体分类 ID
Future<String?> showVibeBulkCategoryDialog({
  required BuildContext context,
  required List<VibeLibraryCategory> categories,
  String? excludeCategoryId,
  required int entryCount,
}) {
  return VibeBulkCategoryDialog.show(
    context: context,
    categories: categories,
    excludeCategoryId: excludeCategoryId,
    entryCount: entryCount,
  );
}
