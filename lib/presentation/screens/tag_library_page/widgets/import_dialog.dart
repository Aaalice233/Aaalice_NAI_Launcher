import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/import_models.dart';
import '../../../../data/services/tag_library_io_service.dart';
import '../../../providers/tag_library_page_provider.dart';

import '../../../widgets/common/app_toast.dart';

/// 导入对话框
class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  File? _selectedFile;
  ImportPreview? _preview;
  List<ImportConflict> _conflicts = [];
  bool _isLoading = false;
  bool _isImporting = false;
  double _progress = 0;
  String _progressMessage = '';
  String? _errorMessage;

  // 选中的条目和分类
  final Set<String> _selectedEntryIds = {};
  final Set<String> _selectedCategoryIds = {};
  final Map<String, ConflictResolution> _conflictResolutions = {};

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
                    Icons.file_download_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.tagLibrary_import,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (!_isImporting)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              if (_isImporting) ...[
                // 导入进度
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
                Text(
                  _progressMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ] else if (_preview == null) ...[
                // 选择文件
                _buildFileSelection(theme),
              ] else ...[
                // 预览和选择
                Expanded(child: _buildPreview(theme)),

                const SizedBox(height: 16),

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedFile = null;
                          _preview = null;
                          _conflicts = [];
                        });
                      },
                      child: const Text('重新选择'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _selectedEntryIds.isNotEmpty ||
                              _selectedCategoryIds.isNotEmpty
                          ? _import
                          : null,
                      icon: const Icon(Icons.file_download),
                      label: Text(
                        '导入 (${_selectedEntryIds.length + _selectedCategoryIds.length} 项)',
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

  Widget _buildFileSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择文件按钮
        InkWell(
          onTap: _isLoading ? null : _selectFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  Icon(
                    Icons.upload_file,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '点击选择 ZIP 文件',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持从本应用导出的词库文件',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // 取消按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_cancel),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final preview = _preview!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '文件信息',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: '条目数', value: preview.entryCount.toString()),
                _InfoRow(label: '分类数', value: preview.categoryCount.toString()),
                _InfoRow(
                  label: '导出时间',
                  value:
                      '${preview.exportDate.year}-${preview.exportDate.month.toString().padLeft(2, '0')}-${preview.exportDate.day.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 冲突提示
          if (_conflicts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '发现 ${_conflicts.length} 个冲突项，已自动设置为跳过',
                      style: TextStyle(color: theme.colorScheme.tertiary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 选择全部
          Row(
            children: [
              Text('选择要导入的内容', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedEntryIds.addAll(preview.entries.map((e) => e.id));
                    _selectedCategoryIds
                        .addAll(preview.categories.map((c) => c.id));
                  });
                },
                child: const Text('全选'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedEntryIds.clear();
                    _selectedCategoryIds.clear();
                  });
                },
                child: const Text('全不选'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 分类列表
          if (preview.categories.isNotEmpty) ...[
            Text(
              '分类 (${preview.categories.length})',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...preview.categories.map((category) {
              final isConflict =
                  _conflicts.any((c) => c.importId == category.id);
              return CheckboxListTile(
                title: Text(category.displayName),
                subtitle: isConflict ? const Text('冲突 - 将跳过') : null,
                value: _selectedCategoryIds.contains(category.id),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedCategoryIds.add(category.id);
                    } else {
                      _selectedCategoryIds.remove(category.id);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),
            const SizedBox(height: 16),
          ],

          // 条目列表
          if (preview.entries.isNotEmpty) ...[
            Text(
              '条目 (${preview.entries.length})',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...preview.entries.map((entry) {
              final isConflict = _conflicts.any((c) => c.importId == entry.id);
              return CheckboxListTile(
                title: Text(entry.displayName),
                subtitle: Text(
                  isConflict ? '冲突 - 将跳过' : entry.contentPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: _selectedEntryIds.contains(entry.id),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedEntryIds.add(entry.id);
                    } else {
                      _selectedEntryIds.remove(entry.id);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(result.files.single.path!);
      final service = TagLibraryIOService();
      final preview = await service.parseImportFile(file);

      // 获取现有数据进行冲突检测
      final state = ref.read(tagLibraryPageNotifierProvider);
      final conflicts = await service.detectConflicts(
        preview,
        state.entries,
        state.categories,
      );

      // 默认选中所有项
      _selectedEntryIds.addAll(preview.entries.map((e) => e.id));
      _selectedCategoryIds.addAll(preview.categories.map((c) => c.id));

      // 冲突项默认跳过
      for (final conflict in conflicts) {
        _conflictResolutions[conflict.importId] = ConflictResolution.skip;
      }

      setState(() {
        _selectedFile = file;
        _preview = preview;
        _conflicts = conflicts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '无法解析文件: $e';
      });
    }
  }

  Future<void> _import() async {
    if (_selectedFile == null || _preview == null) return;

    setState(() {
      _isImporting = true;
      _progress = 0;
      _progressMessage = '准备导入...';
    });

    try {
      final state = ref.read(tagLibraryPageNotifierProvider);
      final service = TagLibraryIOService();

      final result = await service.executeImport(
        zipFile: _selectedFile!,
        preview: _preview!,
        selectedEntryIds: _selectedEntryIds,
        selectedCategoryIds: _selectedCategoryIds,
        conflictResolutions: _conflictResolutions,
        existingEntries: state.entries,
        existingCategories: state.categories,
        onProgress: (progress, message) {
          setState(() {
            _progress = progress;
            _progressMessage = message;
          });
        },
      );

      // 导入到 provider
      final notifier = ref.read(tagLibraryPageNotifierProvider.notifier);

      // 筛选要导入的分类（排除冲突跳过的）
      final categoriesToImport = _preview!.categories.where((c) {
        if (!_selectedCategoryIds.contains(c.id)) return false;
        final resolution = _conflictResolutions[c.id];
        return resolution != ConflictResolution.skip;
      }).toList();

      // 导入分类并获取 ID 映射
      final categoryIdMapping =
          await notifier.importCategories(categoriesToImport);

      // 筛选要导入的条目（排除冲突跳过的）
      final entriesToImport = _preview!.entries.where((e) {
        if (!_selectedEntryIds.contains(e.id)) return false;
        final resolution = _conflictResolutions[e.id];
        return resolution != ConflictResolution.skip;
      }).toList();

      // 导入条目
      await notifier.importEntries(
        entriesToImport,
        categoryIdMapping: categoryIdMapping,
      );

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.info(context,
            '导入成功: ${result.importedEntries} 条目, ${result.skippedConflicts} 跳过',);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        AppToast.info(context, '导入失败: $e');
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.outline)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
