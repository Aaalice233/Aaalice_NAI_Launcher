import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../data/services/tag_library_io_service.dart';

import '../../../widgets/common/app_toast.dart';

/// 导出对话框
class ExportDialog extends ConsumerStatefulWidget {
  final List<TagLibraryEntry> entries;
  final List<TagLibraryCategory> categories;

  const ExportDialog({
    super.key,
    required this.entries,
    required this.categories,
  });

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  bool _includeThumbnails = true;
  bool _isExporting = false;
  double _progress = 0;
  String _progressMessage = '';

  // 选中的条目和分类
  final Set<String> _selectedEntryIds = {};
  final Set<String> _selectedCategoryIds = {};

  // 展开的分类
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // 默认全选所有条目和分类
    _selectedEntryIds.addAll(widget.entries.map((e) => e.id));
    _selectedCategoryIds.addAll(widget.categories.map((c) => c.id));
    // 默认展开所有有子项的分类
    for (final category in widget.categories) {
      if (category.parentId == null) {
        _expandedCategories.add(category.id);
      }
    }
    // 如果有未分类的条目，默认展开未分类
    final hasUncategorized = widget.entries.any((e) => e.categoryId == null);
    if (hasUncategorized) {
      _expandedCategories.add('__uncategorized__');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
                    Icons.file_upload_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.tagLibrary_export,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (!_isExporting)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              if (_isExporting) ...[
                // 导出进度
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
                Text(
                  _progressMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ] else ...[
                // 统计信息
                _buildStatsBar(theme),

                const SizedBox(height: 16),

                // 全选/全不选按钮
                _buildSelectionActions(theme),

                const SizedBox(height: 8),

                // 可滚动的选择列表
                Expanded(child: _buildSelectionList(theme)),

                const Divider(height: 24),

                // 选项
                CheckboxListTile(
                  title: const Text('包含预览图'),
                  subtitle: const Text('将增加文件大小'),
                  value: _includeThumbnails,
                  onChanged: (value) {
                    setState(() => _includeThumbnails = value ?? true);
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),

                const SizedBox(height: 16),

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.common_cancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _selectedEntryIds.isNotEmpty ||
                              _selectedCategoryIds.isNotEmpty
                          ? _export
                          : null,
                      icon: const Icon(Icons.file_download),
                      label: Text(
                        '导出 (${_selectedEntryIds.length + _selectedCategoryIds.length} 项)',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建统计信息栏
  Widget _buildStatsBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _StatItem(
            label: '条目',
            value: '${_selectedEntryIds.length}/${widget.entries.length}',
            icon: Icons.article_outlined,
          ),
          const SizedBox(width: 24),
          _StatItem(
            label: '分类',
            value: '${_selectedCategoryIds.length}/${widget.categories.length}',
            icon: Icons.folder_outlined,
          ),
        ],
      ),
    );
  }

  /// 构建选择操作按钮
  Widget _buildSelectionActions(ThemeData theme) {
    final allEntriesSelected =
        _selectedEntryIds.length == widget.entries.length;
    final allCategoriesSelected =
        _selectedCategoryIds.length == widget.categories.length;
    final allSelected = allEntriesSelected && allCategoriesSelected;

    return Row(
      children: [
        Text('选择要导出的内容', style: theme.textTheme.titleSmall),
        const Spacer(),
        TextButton.icon(
          onPressed: allSelected ? null : _selectAll,
          icon: const Icon(Icons.select_all, size: 18),
          label: const Text('全选'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        TextButton.icon(
          onPressed: _selectedEntryIds.isEmpty && _selectedCategoryIds.isEmpty
              ? null
              : _selectNone,
          icon: const Icon(Icons.deselect, size: 18),
          label: const Text('全不选'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  /// 构建选择列表
  Widget _buildSelectionList(ThemeData theme) {
    // 构建分类树结构
    final rootCategories =
        widget.categories.where((c) => c.parentId == null).toList();

    // 获取无分类的条目
    final uncategorizedEntries =
        widget.entries.where((e) => e.categoryId == null).toList();

    return ListView.builder(
      itemCount:
          rootCategories.length + (uncategorizedEntries.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        // 先显示有分类的
        if (index < rootCategories.length) {
          final category = rootCategories[index];
          return _buildCategoryTile(category, 0);
        }

        // 最后显示未分类
        return _buildUncategorizedSection(theme, uncategorizedEntries);
      },
    );
  }

  /// 构建未分类部分
  Widget _buildUncategorizedSection(
    ThemeData theme,
    List<TagLibraryEntry> entries,
  ) {
    final isExpanded = _expandedCategories.contains('__uncategorized__');
    final selectedCount =
        entries.where((e) => _selectedEntryIds.contains(e.id)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (selectedCount == entries.length) {
                for (final entry in entries) {
                  _selectedEntryIds.remove(entry.id);
                }
              } else {
                for (final entry in entries) {
                  _selectedEntryIds.add(entry.id);
                }
              }
            });
          },
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedCategories.remove('__uncategorized__');
                    } else {
                      _expandedCategories.add('__uncategorized__');
                    }
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: selectedCount == 0
                      ? false
                      : selectedCount == entries.length
                          ? true
                          : null,
                  tristate: true,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        for (final entry in entries) {
                          _selectedEntryIds.add(entry.id);
                        }
                      } else {
                        for (final entry in entries) {
                          _selectedEntryIds.remove(entry.id);
                        }
                      }
                    });
                  },
                ),
              ),
              Icon(
                Icons.folder_open_outlined,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '未分类',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              Text(
                '$selectedCount/${entries.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (isExpanded) ...entries.map((entry) => _buildEntryTile(entry, 1)),
      ],
    );
  }

  /// 构建分类项（递归）
  Widget _buildCategoryTile(TagLibraryCategory category, int depth) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategoryIds.contains(category.id);
    final isExpanded = _expandedCategories.contains(category.id);

    // 获取子分类
    final childCategories =
        widget.categories.where((c) => c.parentId == category.id).toList();

    // 获取该分类下的条目
    final categoryEntries =
        widget.entries.where((e) => e.categoryId == category.id).toList();

    // 计算选中状态（用于indeterminate状态）
    final childSelectedCount = childCategories
        .where((c) => _selectedCategoryIds.contains(c.id))
        .length;
    final entrySelectedCount =
        categoryEntries.where((e) => _selectedEntryIds.contains(e.id)).length;
    final totalChildren = childCategories.length + categoryEntries.length;
    final totalSelected = childSelectedCount + entrySelectedCount;

    final bool? checkboxValue = totalSelected == 0
        ? false
        : totalSelected == totalChildren && isSelected
            ? true
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedCategoryIds.remove(category.id);
                // 取消选择时同时取消子分类和条目
                for (final child in childCategories) {
                  _selectedCategoryIds.remove(child.id);
                }
                for (final entry in categoryEntries) {
                  _selectedEntryIds.remove(entry.id);
                }
              } else {
                _selectedCategoryIds.add(category.id);
                // 选择时同时选择子分类和条目
                for (final child in childCategories) {
                  _selectedCategoryIds.add(child.id);
                }
                for (final entry in categoryEntries) {
                  _selectedEntryIds.add(entry.id);
                }
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.only(left: depth * 16.0),
            child: Row(
              children: [
                // 展开/折叠按钮
                if (childCategories.isNotEmpty || categoryEntries.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
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

                // 复选框
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: checkboxValue,
                    tristate: true,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedCategoryIds.add(category.id);
                          for (final child in childCategories) {
                            _selectedCategoryIds.add(child.id);
                          }
                          for (final entry in categoryEntries) {
                            _selectedEntryIds.add(entry.id);
                          }
                        } else {
                          _selectedCategoryIds.remove(category.id);
                          for (final child in childCategories) {
                            _selectedCategoryIds.remove(child.id);
                          }
                          for (final entry in categoryEntries) {
                            _selectedEntryIds.remove(entry.id);
                          }
                        }
                      });
                    },
                  ),
                ),

                // 图标
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),

                // 名称
                Expanded(
                  child: Text(
                    category.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // 数量
                if (totalChildren > 0)
                  Text(
                    '$totalSelected/$totalChildren',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 子项
        if (isExpanded) ...[
          // 子分类
          ...childCategories
              .map((child) => _buildCategoryTile(child, depth + 1)),

          // 条目
          ...categoryEntries.map((entry) => _buildEntryTile(entry, depth + 1)),
        ],
      ],
    );
  }

  /// 构建条目项
  Widget _buildEntryTile(TagLibraryEntry entry, int depth) {
    final theme = Theme.of(context);
    final isSelected = _selectedEntryIds.contains(entry.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedEntryIds.remove(entry.id);
          } else {
            _selectedEntryIds.add(entry.id);
          }
        });
      },
      child: Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: Row(
          children: [
            const SizedBox(width: 32),
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedEntryIds.add(entry.id);
                    } else {
                      _selectedEntryIds.remove(entry.id);
                    }
                  });
                },
              ),
            ),
            Icon(
              entry.isFavorite ? Icons.favorite : Icons.article_outlined,
              size: 18,
              color: entry.isFavorite ? Colors.pink : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    entry.contentPreview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAll() {
    setState(() {
      _selectedEntryIds.addAll(widget.entries.map((e) => e.id));
      _selectedCategoryIds.addAll(widget.categories.map((c) => c.id));
    });
  }

  void _selectNone() {
    setState(() {
      _selectedEntryIds.clear();
      _selectedCategoryIds.clear();
    });
  }

  Future<void> _export() async {
    // 过滤选中的条目和分类
    final selectedEntries =
        widget.entries.where((e) => _selectedEntryIds.contains(e.id)).toList();
    final selectedCategories = widget.categories
        .where((c) => _selectedCategoryIds.contains(c.id))
        .toList();

    // 选择保存位置
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '选择保存位置',
      fileName: TagLibraryIOService().generateExportFileName(),
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null) return;

    setState(() {
      _isExporting = true;
      _progress = 0;
      _progressMessage = '准备导出...';
    });

    try {
      final service = TagLibraryIOService();
      await service.exportLibrary(
        entries: selectedEntries,
        categories: selectedCategories,
        includeThumbnails: _includeThumbnails,
        outputPath: result,
        onProgress: (progress, message) {
          setState(() {
            _progress = progress;
            _progressMessage = message;
          });
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.info(context, '导出成功');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        AppToast.info(context, '导出失败: $e');
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
