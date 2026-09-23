import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/file_export_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../data/services/tag_library_io_service.dart';

import '../../../adaptive/adaptive_presenter.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/translated_tag_text.dart';
import '../../../widgets/library_export/library_export_controls.dart';
import '../../../widgets/library_export/library_export_panel.dart';
import '../../../widgets/library_export/library_selection_controller.dart';

/// 导出对话框
class ExportDialog extends ConsumerStatefulWidget {
  final List<TagLibraryEntry> entries;
  final List<TagLibraryCategory> categories;

  const ExportDialog._({required this.entries, required this.categories});

  static Future<void> show(
    BuildContext context, {
    required List<TagLibraryEntry> entries,
    required List<TagLibraryCategory> categories,
  }) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.file_upload_outlined,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              panelContext.l10n.tagLibrary_export,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                panelContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      dialogWidth: 600,
      builder: (context, _) =>
          ExportDialog._(entries: entries, categories: categories),
    );
  }

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late final LibrarySelectionTree<TagLibraryEntry> _tree;
  late final LibrarySelectionController _selection;

  bool _includeThumbnails = true;
  bool _isExporting = false;
  double _progress = 0;
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
    _tree = LibrarySelectionTree<TagLibraryEntry>(
      categories: widget.categories
          .map(
            (category) => LibraryCategoryNode(
              id: category.id,
              displayName: category.displayName,
              parentId: category.parentId,
            ),
          )
          .toList(growable: false),
      entries: widget.entries
          .map(
            (entry) => LibraryEntryNode<TagLibraryEntry>(
              id: entry.id,
              value: entry,
              categoryId: entry.categoryId,
            ),
          )
          .toList(growable: false),
    );
    _selection = LibrarySelectionController(tree: _tree)
      ..addListener(_handleSelectionChanged);
  }

  @override
  void dispose() {
    _selection
      ..removeListener(_handleSelectionChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSelectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      key: const Key('tag-library-export-content'),
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isExporting)
            LibraryExportProgressView(
              progress: _progress,
              message: _progressMessage,
            )
          else ...[
            _buildSelectionHeader(theme),

            const SizedBox(height: 8),

            LibraryExportPanel<TagLibraryEntry>(
              tree: _tree,
              selection: _selection,
              uncategorizedLabel: context.l10n.tagLibrary_uncategorized,
              entryContentBuilder: _buildEntryContent,
            ),

            const Divider(height: 24),

            LibraryExportThumbnailOption(
              title: context.l10n.tagLibrary_includeThumbnails,
              subtitle: context.l10n.tagLibrary_includeThumbnailsSubtitle,
              value: _includeThumbnails,
              onChanged: (value) => setState(() => _includeThumbnails = value),
            ),

            const SizedBox(height: 16),

            _buildDialogActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(ThemeData theme) {
    return HorizontalActionStrip(
      scrollKey: const Key('tag-library-export-selection-header-scroll'),

      child: Row(
        key: const Key('tag-library-export-selection-header'),
        children: [
          _buildStatsBar(theme),
          const SizedBox(width: 16),
          _buildSelectionActions(theme),
        ],
      ),
    );
  }

  /// 构建统计信息栏
  Widget _buildStatsBar(ThemeData theme) {
    return Container(
      key: const Key('tag-library-export-stats'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          LibraryExportStatItem(
            label: context.l10n.tagLibrary_entriesLabel,
            value:
                '${_selection.selectedEntryIds.length}/${widget.entries.length}',
            icon: Icons.article_outlined,
          ),
          const SizedBox(width: 24),
          LibraryExportStatItem(
            label: context.l10n.tagLibrary_categoriesLabel,
            value:
                '${_selection.selectedCategoryIds.length}/${widget.categories.length}',
            icon: Icons.folder_outlined,
          ),
        ],
      ),
    );
  }

  /// 构建选择操作按钮
  Widget _buildSelectionActions(ThemeData theme) {
    return Row(
      key: const Key('tag-library-export-selection-actions'),
      children: [
        Text(
          context.l10n.tagLibrary_selectExportContent,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _selection.isEverythingSelected
              ? null
              : _selection.selectAll,
          icon: const Icon(Icons.select_all, size: 18),
          label: Text(context.l10n.common_selectAll),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: _selection.isNothingSelected
              ? null
              : _selection.selectNone,
          icon: const Icon(Icons.deselect, size: 18),
          label: Text(context.l10n.common_deselectAll),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogActions() {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        key: const Key('tag-library-export-dialog-actions'),
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton.icon(
            onPressed: _selection.isNothingSelected ? null : _export,
            icon: const Icon(Icons.file_download),
            label: Text(
              context.l10n.tagLibrary_selectedExportCount(
                _selection.selectedCount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建条目行内容
  Widget _buildEntryContent(
    BuildContext context,
    LibraryEntryNode<TagLibraryEntry> node,
  ) {
    final theme = Theme.of(context);
    final entry = node.value;

    return Row(
      children: [
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
              TranslatedPromptText(
                entry.contentPreview,
                selectable: false,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    // 过滤选中的条目和分类
    final selectedEntries = widget.entries
        .where((e) => _selection.isEntrySelected(e.id))
        .toList();
    final selectedCategories = widget.categories
        .where((c) => _selection.isCategorySelected(c.id))
        .toList();

    final service = TagLibraryIOService();
    final fileName = service.generateExportFileName();

    setState(() {
      _isExporting = true;
      _progress = 0;
      _progressMessage = context.l10n.tagLibrary_preparingExport;
    });

    try {
      final savedLocation = await FileExportService.withTemporaryOutput(
        fileName: fileName,
        action: (path) async {
          await service.exportLibrary(
            entries: selectedEntries,
            categories: selectedCategories,
            includeThumbnails: _includeThumbnails,
            outputPath: path,
            onProgress: (progress, message) {
              if (!mounted) return;
              setState(() {
                _progress = progress;
                _progressMessage = message;
              });
            },
          );
          if (!mounted) return null;
          return FileExportService.saveFileFromPath(
            sourcePath: path,
            fileName: fileName,
            dialogTitle: context.l10n.tagLibrary_selectSaveLocation,
            mimeType: 'application/zip',
            allowedExtensions: const ['zip'],
          );
        },
      );
      if (savedLocation == null) {
        if (mounted) setState(() => _isExporting = false);
        return;
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.info(context, context.l10n.tagLibrary_exportSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        AppToast.info(
          context,
          context.l10n.tagLibrary_exportFailedWithError('$e'),
        );
      }
    }
  }
}
