import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';

/// 条目选择对话框
///
/// 用于选择要更新预览图的词条
class EntrySelectorDialog extends ConsumerStatefulWidget {
  /// 所有条目
  final List<TagLibraryEntry> entries;

  /// 所有分类（用于显示分类名称）
  final List<TagLibraryCategory> categories;

  const EntrySelectorDialog({
    super.key,
    required this.entries,
    required this.categories,
  });

  /// 显示对话框
  static Future<TagLibraryEntry?> show(
    BuildContext context, {
    required List<TagLibraryEntry> entries,
    required List<TagLibraryCategory> categories,
  }) {
    return showDialog<TagLibraryEntry?>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => EntrySelectorDialog(
        entries: entries,
        categories: categories,
      ),
    );
  }

  @override
  ConsumerState<EntrySelectorDialog> createState() =>
      _EntrySelectorDialogState();
}

class _EntrySelectorDialogState extends ConsumerState<EntrySelectorDialog> {
  String _searchQuery = '';
  String? _selectedEntryId;

  List<TagLibraryEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return widget.entries;

    final query = _searchQuery.toLowerCase();
    return widget.entries.where((entry) {
      return entry.name.toLowerCase().contains(query) ||
          entry.content.toLowerCase().contains(query) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return '根分类';
    final category = widget.categories.cast<TagLibraryCategory?>().firstWhere(
          (c) => c?.id == categoryId,
          orElse: () => null,
        );
    return category?.displayName ?? '未知分类';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final filteredEntries = _filteredEntries;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    Icons.image_search_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '选择要更新的词条',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: l10n.common_close,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 搜索框
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索词条...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              // 条目列表
              Expanded(
                child: filteredEntries.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        itemCount: filteredEntries.length,
                        itemBuilder: (context, index) {
                          final entry = filteredEntries[index];
                          return _EntryListTile(
                            entry: entry,
                            categoryName: _getCategoryName(entry.categoryId),
                            isSelected: _selectedEntryId == entry.id,
                            onTap: () {
                              setState(() {
                                _selectedEntryId = entry.id;
                              });
                            },
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // 底部按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.common_cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _selectedEntryId == null
                        ? null
                        : () {
                            final selectedEntry = widget.entries.firstWhere(
                              (e) => e.id == _selectedEntryId,
                            );
                            Navigator.of(context).pop(selectedEntry);
                          },
                    icon: const Icon(Icons.update, size: 18),
                    label: const Text('更新预览图'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 48,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '没有找到匹配的词条',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 条目列表项
class _EntryListTile extends StatelessWidget {
  final TagLibraryEntry entry;
  final String categoryName;
  final bool isSelected;
  final VoidCallback onTap;

  const _EntryListTile({
    required this.entry,
    required this.categoryName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color:
          isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              // 选择指示器
              Radio<String>(
                value: entry.id,
                groupValue: isSelected ? entry.id : null,
                onChanged: (_) => onTap(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),

              const SizedBox(width: 8),

              // 预览图
              _buildThumbnail(theme),

              const SizedBox(width: 12),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            categoryName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 是否有预览图标记
              if (entry.thumbnail != null)
                Tooltip(
                  message: '将替换现有预览图',
                  child: Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final hasThumbnail = entry.thumbnail != null;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: hasThumbnail
            ? null
            : Border.all(
                color: theme.colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
      ),
      child: hasThumbnail
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(entry.thumbnail!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: theme.colorScheme.outline,
                  );
                },
              ),
            )
          : Icon(
              Icons.image_not_supported_outlined,
              size: 24,
              color: theme.colorScheme.outline,
            ),
    );
  }
}
