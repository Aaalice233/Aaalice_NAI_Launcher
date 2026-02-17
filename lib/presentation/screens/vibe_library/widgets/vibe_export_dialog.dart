import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/vibe_export_utils.dart';
import '../../../../data/models/vibe/vibe_library_category.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/models/vibe/vibe_export_format.dart';

import '../../../widgets/common/app_toast.dart';

/// VibeExportFormat 本地化扩展
extension VibeExportFormatUiExtension on VibeExportFormat {
  /// 获取显示名称（中文）
  String get uiDisplayName {
    switch (this) {
      case VibeExportFormat.bundle:
        return '打包文件 (.naiv4vibebundle)';
      case VibeExportFormat.encoding:
        return '单独文件 (.naiv4vibe)';
      case VibeExportFormat.embeddedImage:
        return '嵌入图片 (PNG)';
    }
  }

  /// 获取描述（中文）
  String get uiDescription {
    switch (this) {
      case VibeExportFormat.bundle:
        return '多个 Vibe 打包为一个文件，适合批量备份';
      case VibeExportFormat.encoding:
        return '每个 Vibe 导出为独立文件，适合分享单个 Vibe';
      case VibeExportFormat.embeddedImage:
        return '将 Vibe 数据嵌入到 PNG 图片元数据中';
    }
  }
}

/// Vibe 导出对话框
class VibeExportDialog extends ConsumerStatefulWidget {
  final List<VibeLibraryEntry> entries;
  final List<VibeLibraryCategory> categories;

  const VibeExportDialog({
    super.key,
    required this.entries,
    required this.categories,
  });

  @override
  ConsumerState<VibeExportDialog> createState() => _VibeExportDialogState();
}

class _VibeExportDialogState extends ConsumerState<VibeExportDialog> {
  VibeExportFormat _exportFormat = VibeExportFormat.encoding;
  bool _includeThumbnails = true;
  bool _includeFullData = true;
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
    _selectedEntryIds.addAll(
      widget.entries.where((e) => _canExportEntry(e)).map((e) => e.id),
    );
    _selectedCategoryIds.addAll(widget.categories.map((c) => c.id));
    // 默认展开所有有子项的分类
    for (final category in widget.categories) {
      if (category.parentId == null) {
        _expandedCategories.add(category.id);
      }
    }
    // 如果有未分类的条目，默认展开未分类
    final hasUncategorized = widget.entries.any(
      (e) => e.categoryId == null && _canExportEntry(e),
    );
    if (hasUncategorized) {
      _expandedCategories.add('__uncategorized__');
    }
  }

  /// 检查条目是否可以导出（是否有可导出的数据）
  bool _canExportEntry(VibeLibraryEntry entry) {
    return entry.vibeEncoding.isNotEmpty ||
        (entry.rawImageData != null && entry.rawImageData!.isNotEmpty) ||
        (entry.vibeThumbnail != null && entry.vibeThumbnail!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
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
                    Icons.waves_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '导出 Vibe',
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

                // 导出格式选择
                _buildFormatSelection(theme),

                const SizedBox(height: 16),

                // 全选/全不选按钮
                _buildSelectionActions(theme),

                const SizedBox(height: 8),

                // 可滚动的选择列表
                Expanded(child: _buildSelectionList(theme)),

                const Divider(height: 24),

                // 选项
                CheckboxListTile(
                  title: const Text('包含完整数据'),
                  subtitle: const Text('包含原始图片数据和完整的 Vibe 编码'),
                  value: _includeFullData,
                  onChanged: (value) {
                    setState(() => _includeFullData = value ?? true);
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  title: Text(context.l10n.vibe_export_include_thumbnails),
                  subtitle: Text(
                    context.l10n.vibe_export_include_thumbnails_subtitle,
                  ),
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
                      onPressed: _selectedEntryIds.isEmpty ? null : _export,
                      icon: const Icon(Icons.file_download),
                      label: Text(
                        '导出 (${_selectedEntryIds.length} 个)',
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
    final exportableCount =
        widget.entries.where((e) => _canExportEntry(e)).length;
    final unexportableCount = widget.entries.length - exportableCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _StatItem(
            label: '可导出',
            value: '${_selectedEntryIds.length}/$exportableCount',
            icon: Icons.check_circle_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 24),
          if (unexportableCount > 0)
            _StatItem(
              label: '不可导出',
              value: '$unexportableCount',
              icon: Icons.error_outline,
              color: theme.colorScheme.error,
            ),
          const Spacer(),
          _StatItem(
            label: '分类',
            value: '${_selectedCategoryIds.length}/${widget.categories.length}',
            icon: Icons.folder_outlined,
            color: theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }

  /// 构建格式选择区域
  Widget _buildFormatSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('导出格式', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...VibeExportFormat.values.map((format) {
          final isSelected = _exportFormat == format;
          return InkWell(
            onTap: () => setState(() => _exportFormat = format),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected
                    ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                    : null,
              ),
              child: Row(
                children: [
                  Radio<VibeExportFormat>(
                    value: format,
                    groupValue: _exportFormat,
                    onChanged: (value) {
                      setState(() => _exportFormat = value!);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          format.uiDisplayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          format.uiDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 构建选择操作按钮
  Widget _buildSelectionActions(ThemeData theme) {
    final exportableEntries =
        widget.entries.where((e) => _canExportEntry(e)).toList();
    final allEntriesSelected =
        _selectedEntryIds.length == exportableEntries.length;
    final allCategoriesSelected =
        _selectedCategoryIds.length == widget.categories.length;
    final allSelected = allEntriesSelected && allCategoriesSelected;

    return Row(
      children: [
        Text('选择要导出的 Vibe', style: theme.textTheme.titleSmall),
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

    // 获取无分类的条目（且可导出）
    final uncategorizedEntries = widget.entries
        .where((e) => e.categoryId == null && _canExportEntry(e))
        .toList();

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
    List<VibeLibraryEntry> entries,
  ) {
    final isExpanded = _expandedCategories.contains('__uncategorized__');
    final selectedCount =
        entries.where((e) => _selectedEntryIds.contains(e.id)).length;

    if (entries.isEmpty) return const SizedBox.shrink();

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
  Widget _buildCategoryTile(VibeLibraryCategory category, int depth) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategoryIds.contains(category.id);
    final isExpanded = _expandedCategories.contains(category.id);

    // 获取子分类
    final childCategories =
        widget.categories.where((c) => c.parentId == category.id).toList();

    // 获取该分类下的条目（且可导出）
    final categoryEntries = widget.entries
        .where((e) => e.categoryId == category.id && _canExportEntry(e))
        .toList();

    if (categoryEntries.isEmpty && childCategories.isEmpty) {
      return const SizedBox.shrink();
    }

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
  Widget _buildEntryTile(VibeLibraryEntry entry, int depth) {
    final theme = Theme.of(context);
    final isSelected = _selectedEntryIds.contains(entry.id);

    // 获取缩略图数据
    final Uint8List? thumbnailData =
        entry.vibeThumbnail ?? entry.thumbnail ?? entry.rawImageData;

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

            // 缩略图
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: thumbnailData != null
                  ? Image.memory(
                      thumbnailData,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          size: 20,
                          color: theme.colorScheme.outline,
                        );
                      },
                    )
                  : Icon(
                      Icons.image,
                      size: 20,
                      color: theme.colorScheme.outline,
                    ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.displayName,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isFavorite)
                        const Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.pink,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _SourceTypeBadge(sourceType: entry.sourceType),
                      const SizedBox(width: 8),
                      Text(
                        '强度: ${(entry.strength * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
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
      _selectedEntryIds.addAll(
        widget.entries.where((e) => _canExportEntry(e)).map((e) => e.id),
      );
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
    // 过滤选中的条目
    final selectedEntries =
        widget.entries.where((e) => _selectedEntryIds.contains(e.id)).toList();

    if (selectedEntries.isEmpty) {
      AppToast.warning(context, '请先选择要导出的 Vibe');
      return;
    }

    setState(() {
      _isExporting = true;
      _progress = 0;
      _progressMessage = '准备导出...';
    });

    try {
      if (_exportFormat == VibeExportFormat.bundle) {
        // 导出为 bundle 格式
        await _exportAsBundle(selectedEntries);
      } else if (_exportFormat == VibeExportFormat.encoding) {
        // 导出为单独文件 (使用 encoding 格式)
        await _exportAsSingleFiles(selectedEntries);
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.success(context, '导出成功');
      }
    } catch (e, stack) {
      AppLogger.e('导出 Vibe 失败', e, stack, 'VibeExportDialog');
      if (mounted) {
        setState(() => _isExporting = false);
        AppToast.error(context, '导出失败: $e');
      }
    }
  }

  /// 创建用于导出的 VibeReference，根据选项决定是否包含完整数据
  VibeReference _createExportReference(VibeLibraryEntry entry) {
    final baseRef = entry.toVibeReference();

    if (_includeFullData) {
      // 完整导出：保留所有数据
      return baseRef;
    }

    // 非完整导出：移除原始图片数据，仅保留编码
    return baseRef.copyWith(
      rawImageData: null,
    );
  }

  /// 导出为单独文件
  Future<void> _exportAsSingleFiles(List<VibeLibraryEntry> entries) async {
    // 选择保存目录
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择保存目录',
    );

    if (result == null) {
      setState(() => _isExporting = false);
      return;
    }

    final total = entries.length;
    int successCount = 0;
    int failCount = 0;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      setState(() {
        _progress = i / total;
        _progressMessage = '正在导出: ${entry.displayName}';
      });

      // 根据选项创建导出用的 VibeReference
      final vibeRef = _createExportReference(entry);

      // 导出单个 vibe
      final exportedPath = await VibeExportUtils.exportToNaiv4Vibe(
        vibeRef,
        name: entry.displayName,
      );

      if (exportedPath != null) {
        successCount++;
      } else {
        failCount++;
        AppLogger.w('导出失败: ${entry.displayName}', 'VibeExportDialog');
      }
    }

    setState(() {
      _progress = 1.0;
      _progressMessage = '导出完成: $successCount 成功, $failCount 失败';
    });
  }

  /// 导出为 bundle 文件
  Future<void> _exportAsBundle(List<VibeLibraryEntry> entries) async {
    setState(() {
      _progress = 0.3;
      _progressMessage = '正在打包 ${entries.length} 个 Vibe...';
    });

    // 根据选项创建导出用的 VibeReference 列表
    final vibes = entries.map((e) => _createExportReference(e)).toList();

    setState(() {
      _progress = 0.6;
      _progressMessage = '正在生成 bundle 文件...';
    });

    // 导出 bundle
    final bundleName = 'vibe_bundle_${entries.length}';
    final exportedPath = await VibeExportUtils.exportToNaiv4VibeBundle(
      vibes,
      bundleName,
    );

    if (exportedPath == null) {
      throw Exception('导出 bundle 失败');
    }

    setState(() {
      _progress = 1.0;
      _progressMessage = '导出完成: $exportedPath';
    });
  }
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
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

/// 数据来源类型标签
class _SourceTypeBadge extends StatelessWidget {
  final VibeSourceType sourceType;

  const _SourceTypeBadge({required this.sourceType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    String label;

    switch (sourceType) {
      case VibeSourceType.png:
        backgroundColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green;
        label = 'PNG';
      case VibeSourceType.naiv4vibe:
        backgroundColor = Colors.blue.withOpacity(0.15);
        textColor = Colors.blue;
        label = 'V4';
      case VibeSourceType.naiv4vibebundle:
        backgroundColor = Colors.purple.withOpacity(0.15);
        textColor = Colors.purple;
        label = 'Bundle';
      case VibeSourceType.rawImage:
        backgroundColor = Colors.orange.withOpacity(0.15);
        textColor = Colors.orange;
        label = 'Image';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
