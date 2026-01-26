import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../data/repositories/local_gallery_repository.dart';
import '../providers/bulk_operation_provider.dart';
import '../providers/selection_mode_provider.dart';
import 'bulk_progress_dialog.dart';

/// Bulk Export Dialog Widget
/// 批量导出对话框组件
///
/// Provides export options for selected images including format selection
/// and metadata inclusion toggle
/// 为选中的图片提供导出选项，包括格式选择和元数据包含切换
class BulkExportDialog extends ConsumerStatefulWidget {
  const BulkExportDialog({super.key});

  @override
  ConsumerState<BulkExportDialog> createState() => _BulkExportDialogState();
}

class _BulkExportDialogState extends ConsumerState<BulkExportDialog> {
  String _selectedFormat = 'json';
  bool _includeMetadata = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    // Get selected images
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final selectedCount = selectionState.selectedIds.length;

    return Container(
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: theme.dividerColor.withOpacity(isDark ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.download,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.bulkExport_title(selectedCount),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: l10n.common_close,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Export options
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format selection
                  _buildOptionSection(
                    theme,
                    l10n.bulkExport_format,
                    Icons.description,
                    Column(
                      children: [
                        _buildFormatOption(
                          theme,
                          l10n.bulkExport_jsonFormat,
                          'json',
                          Icons.code,
                        ),
                        const SizedBox(height: 8),
                        _buildFormatOption(
                          theme,
                          l10n.bulkExport_csvFormat,
                          'csv',
                          Icons.table_chart,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata inclusion
                  _buildOptionSection(
                    theme,
                    l10n.bulkExport_metadataOptions,
                    Icons.info,
                    CheckboxListTile(
                      value: _includeMetadata,
                      onChanged: (value) {
                        setState(() {
                          _includeMetadata = value ?? true;
                        });
                      },
                      title: Text(
                        l10n.bulkExport_includeMetadata,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        l10n.bulkExport_includeMetadataHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.common_cancel),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: selectedCount > 0 ? _handleExport : null,
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(l10n.common_export),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build an option section with label and content
  Widget _buildOptionSection(
    ThemeData theme,
    String label,
    IconData icon,
    Widget content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  /// Build a format option radio button
  Widget _buildFormatOption(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    final isSelected = _selectedFormat == value;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = value;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.5)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.3 : 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withOpacity(isDark ? 0.2 : 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  /// Handle export action
  void _handleExport() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final selectedPaths = selectionState.selectedIds.toList();

    if (selectedPaths.isEmpty) {
      return;
    }

    // Convert paths to File objects
    final selectedFiles = selectedPaths.map((path) => File(path)).toList();

    // Load records from files
    final repository = LocalGalleryRepository.instance;
    final records = await repository.loadRecords(selectedFiles);

    if (!mounted) return;

    if (records.isEmpty) {
      return;
    }

    // Close the export dialog
    Navigator.of(context).pop();

    if (!mounted) return;

    // Show progress dialog first (it will watch the operation state)
    // 首先显示进度对话框（它将监听操作状态）
    unawaited(BulkProgressDialog.show(context));

    // Perform export operation (the progress dialog will show the progress)
    // 执行导出操作（进度对话框将显示进度）
    final notifier = ref.read(bulkOperationNotifierProvider.notifier);
    await notifier.bulkExport(
      records,
      outputFormat: _selectedFormat,
      includeMetadata: _includeMetadata,
    );
  }
}

/// Show bulk export dialog
/// 显示批量导出对话框
void showBulkExportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const AlertDialog(
      backgroundColor: Colors.transparent,
      content: BulkExportDialog(),
      insetPadding: EdgeInsets.all(16),
    ),
  );
}
