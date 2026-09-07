import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/tag_library/import_models.dart';
import '../../../../data/models/tag_library/import_plan.dart';
import '../../../../data/services/tag_library_import_planner.dart';
import '../../../../data/services/tag_library_io_service.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/translated_tag_text.dart';

/// 导入对话框
class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog._();

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.file_download_outlined,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              panelContext.l10n.tagLibrary_import,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                panelContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      dialogWidth: 700,
      builder: (context, _) => const ImportDialog._(),
    );
  }

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

    if (_isImporting) {
      return Padding(
        key: const Key('tag-library-import-content'),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 12),
            Text(
              _progressMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    if (_preview == null) {
      return SingleChildScrollView(
        key: const Key('tag-library-import-content'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: _buildFileSelection(theme),
      );
    }

    return Padding(
      key: const Key('tag-library-import-content'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildPreview(theme)),

          const SizedBox(height: 16),

          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFile = null;
                    _preview = null;
                    _conflicts = [];
                    _conflictResolutions.clear();
                  });
                },
                child: Text(context.l10n.tagLibrary_reselect),
              ),
              FilledButton.icon(
                onPressed:
                    _selectedEntryIds.isNotEmpty ||
                        _selectedCategoryIds.isNotEmpty
                    ? _import
                    : null,
                icon: const Icon(Icons.file_download),
                label: Text(
                  context.l10n.tagLibrary_selectedImportCount(
                    _selectedEntryIds.length + _selectedCategoryIds.length,
                  ),
                ),
              ),
            ],
          ),
        ],
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
            ),
            child: Column(
              children: [
                if (_isLoading)
                  CircularProgressIndicator(
                    value: MediaQuery.disableAnimationsOf(context)
                        ? 0.72
                        : null,
                  )
                else ...[
                  Icon(
                    Icons.upload_file,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.tagLibrary_selectZipFile,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.tagLibrary_zipFileHint,
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
                  context.l10n.tagLibrary_fileInfo,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: context.l10n.tagLibrary_entryCountLabel,
                  value: preview.entryCount.toString(),
                ),
                _InfoRow(
                  label: context.l10n.tagLibrary_categoryCountLabel,
                  value: preview.categoryCount.toString(),
                ),
                _InfoRow(
                  label: context.l10n.tagLibrary_exportDateLabel,
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
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.5,
                ),
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
                      context.l10n.tagLibrary_importConflictsHint(
                        _conflicts.length,
                      ),
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
              Text(
                context.l10n.tagLibrary_selectImportContent,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedEntryIds.addAll(preview.entries.map((e) => e.id));
                    _selectedCategoryIds.addAll(
                      preview.categories.map((c) => c.id),
                    );
                  });
                },
                child: Text(context.l10n.common_selectAll),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedEntryIds.clear();
                    _selectedCategoryIds.clear();
                  });
                },
                child: Text(context.l10n.common_deselectAll),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 分类列表
          if (preview.categories.isNotEmpty) ...[
            Text(
              context.l10n.tagLibrary_categoriesSection(
                preview.categories.length,
              ),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...preview.categories.map((category) {
              final conflict = _conflicts.firstWhere(
                (c) => c.importId == category.id,
                orElse: () => const ImportConflict(
                  type: ConflictType.category,
                  importName: '',
                  importId: '',
                  existingId: '',
                ),
              );
              final isConflict = conflict.importId.isNotEmpty;
              final resolution =
                  _conflictResolutions[category.id] ?? ConflictResolution.skip;

              return _buildConflictItem(
                theme: theme,
                title: category.displayName,
                subtitle: isConflict ? _getConflictSubtitle(resolution) : null,
                isSelected: _selectedCategoryIds.contains(category.id),
                isConflict: isConflict,
                resolution: resolution,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedCategoryIds.add(category.id);
                    } else {
                      _selectedCategoryIds.remove(category.id);
                    }
                  });
                },
                onResolutionChanged: isConflict
                    ? (newResolution) {
                        setState(() {
                          _conflictResolutions[category.id] = newResolution;
                        });
                      }
                    : null,
              );
            }),
            const SizedBox(height: 16),
          ],

          // 条目列表
          if (preview.entries.isNotEmpty) ...[
            Text(
              context.l10n.tagLibrary_entriesSection(preview.entries.length),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...preview.entries.map((entry) {
              final conflict = _conflicts.firstWhere(
                (c) => c.importId == entry.id,
                orElse: () => const ImportConflict(
                  type: ConflictType.entry,
                  importName: '',
                  importId: '',
                  existingId: '',
                ),
              );
              final isConflict = conflict.importId.isNotEmpty;
              final resolution =
                  _conflictResolutions[entry.id] ?? ConflictResolution.skip;

              return _buildConflictItem(
                theme: theme,
                title: entry.displayName,
                subtitle: isConflict
                    ? _getConflictSubtitle(resolution)
                    : entry.contentPreview,
                translateSubtitle: !isConflict,
                isSelected: _selectedEntryIds.contains(entry.id),
                isConflict: isConflict,
                resolution: resolution,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedEntryIds.add(entry.id);
                    } else {
                      _selectedEntryIds.remove(entry.id);
                    }
                  });
                },
                onResolutionChanged: isConflict
                    ? (newResolution) {
                        setState(() {
                          _conflictResolutions[entry.id] = newResolution;
                        });
                      }
                    : null,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildConflictItem({
    required ThemeData theme,
    required String title,
    required String? subtitle,
    bool translateSubtitle = false,
    required bool isSelected,
    required bool isConflict,
    required ConflictResolution resolution,
    required ValueChanged<bool?> onChanged,
    required ValueChanged<ConflictResolution>? onResolutionChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isConflict
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Checkbox(value: isSelected, onChanged: onChanged),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  if (translateSubtitle)
                    TranslatedPromptText(
                      subtitle,
                      selectable: false,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                    )
                  else
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isConflict
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ),
          ),
          if (isConflict && onResolutionChanged != null)
            _buildResolutionSwitch(theme, resolution, onResolutionChanged)
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildResolutionSwitch(
    ThemeData theme,
    ConflictResolution currentResolution,
    ValueChanged<ConflictResolution> onChanged,
  ) {
    return PopupMenuButton<ConflictResolution>(
      tooltip: context.l10n.tagLibrary_conflictResolutionTooltip,
      initialValue: currentResolution,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ConflictResolution.skip,
          child: Row(
            children: [
              Icon(
                Icons.skip_next,
                size: 18,
                color: currentResolution == ConflictResolution.skip
                    ? theme.colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.common_skip,
                style: TextStyle(
                  color: currentResolution == ConflictResolution.skip
                      ? theme.colorScheme.primary
                      : null,
                  fontWeight: currentResolution == ConflictResolution.skip
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: ConflictResolution.rename,
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: 18,
                color: currentResolution == ConflictResolution.rename
                    ? theme.colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.common_rename,
                style: TextStyle(
                  color: currentResolution == ConflictResolution.rename
                      ? theme.colorScheme.primary
                      : null,
                  fontWeight: currentResolution == ConflictResolution.rename
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: ConflictResolution.overwrite,
          child: Row(
            children: [
              Icon(
                Icons.sync,
                size: 18,
                color: currentResolution == ConflictResolution.overwrite
                    ? theme.colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.common_replace,
                style: TextStyle(
                  color: currentResolution == ConflictResolution.overwrite
                      ? theme.colorScheme.primary
                      : null,
                  fontWeight: currentResolution == ConflictResolution.overwrite
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        constraints: BoxConstraints(
          minHeight: context.interactionPolicy.shouldExposeTouchAlternatives
              ? 48
              : 0,
        ),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getResolutionIcon(currentResolution),
              size: 14,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 4),
            Text(
              _getResolutionLabel(currentResolution),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _getConflictSubtitle(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.skip:
        return context.l10n.tagLibrary_conflictSkip;
      case ConflictResolution.rename:
        return context.l10n.tagLibrary_conflictRename;
      case ConflictResolution.overwrite:
        return context.l10n.tagLibrary_conflictOverwrite;
    }
  }

  String _getResolutionLabel(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.skip:
        return context.l10n.common_skip;
      case ConflictResolution.rename:
        return context.l10n.common_rename;
      case ConflictResolution.overwrite:
        return context.l10n.common_replace;
    }
  }

  IconData _getResolutionIcon(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.skip:
        return Icons.skip_next;
      case ConflictResolution.rename:
        return Icons.edit;
      case ConflictResolution.overwrite:
        return Icons.sync;
    }
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
        _errorMessage = context.l10n.tagLibrary_parseFileFailed('$e');
      });
    }
  }

  Future<void> _import() async {
    final file = _selectedFile;
    final preview = _preview;
    if (file == null || preview == null) return;

    final l10n = context.l10n;
    final state = ref.read(tagLibraryPageNotifierProvider);
    final notifier = ref.read(tagLibraryPageNotifierProvider.notifier);

    setState(() {
      _isImporting = true;
      _progress = 0;
      _progressMessage = l10n.tagLibrary_preparingImport;
    });

    try {
      final plan = const TagLibraryImportPlanner().plan(
        preview: preview,
        selectedEntryIds: _selectedEntryIds,
        selectedCategoryIds: _selectedCategoryIds,
        conflicts: _conflicts,
        conflictResolutions: _conflictResolutions,
        existingEntries: state.entries,
        existingCategories: state.categories,
        renameSuffix: ' (${l10n.common_import})',
      );

      final result = await TagLibraryIOService().executeImport(
        zipFile: file,
        plan: plan,
        onProgress: (progress, message) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _progressMessage = message;
          });
        },
      );

      final applied = await notifier.applyImportPlan(
        plan,
        importedEntries: result.updatedEntries,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.info(context, _importSummary(result, applied));
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        AppToast.info(
          context,
          context.l10n.tagLibrary_importFailedWithError('$e'),
        );
      }
    }
  }

  String _importSummary(
    ImportResult result,
    TagLibraryImportApplyResult applied,
  ) {
    final l10n = context.l10n;
    final messages = <String>[
      if (result.importedEntries > 0)
        l10n.tagLibrary_importedEntriesCount(result.importedEntries),
      if (result.importedCategories > 0)
        l10n.tagLibrary_importedCategoriesCount(result.importedCategories),
      if (result.renamedCount > 0)
        l10n.tagLibrary_renamedCount(result.renamedCount),
      if (result.overwrittenCount > 0)
        l10n.tagLibrary_overwrittenCount(result.overwrittenCount),
      if (result.skippedConflicts > 0)
        l10n.tagLibrary_skippedCount(result.skippedConflicts),
      if (applied.rejected.isNotEmpty)
        l10n.tagLibrary_importRejectedCount(applied.rejected.length),
    ];
    return messages.isEmpty
        ? l10n.tagLibrary_importCompleted
        : l10n.tagLibrary_importSuccessSummary(messages.join(', '));
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
