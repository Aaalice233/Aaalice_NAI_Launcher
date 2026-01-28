import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../providers/bulk_operation_provider.dart';
import '../providers/selection_mode_provider.dart';
import 'bulk_progress_dialog.dart';
import '../widgets/common/themed_divider.dart';
import '../widgets/common/app_toast.dart';

/// Bulk Metadata Edit Dialog Widget
/// 批量元数据编辑对话框组件
///
/// Provides bulk metadata editing options for selected images
/// 为选中的图片提供批量元数据编辑选项
class BulkMetadataEditDialog extends ConsumerStatefulWidget {
  const BulkMetadataEditDialog({super.key});

  @override
  ConsumerState<BulkMetadataEditDialog> createState() =>
      _BulkMetadataEditDialogState();
}

class _BulkMetadataEditDialogState
    extends ConsumerState<BulkMetadataEditDialog> {
  final TextEditingController _tagsToAddController = TextEditingController();
  final TextEditingController _tagsToRemoveController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _negativePromptController =
      TextEditingController();

  final FocusNode _tagsToAddFocus = FocusNode();
  final FocusNode _tagsToRemoveFocus = FocusNode();

  final List<String> _chipsToAdd = [];
  final List<String> _chipsToRemove = [];

  @override
  void dispose() {
    _tagsToAddController.dispose();
    _tagsToRemoveController.dispose();
    _promptController.dispose();
    _negativePromptController.dispose();
    _tagsToAddFocus.dispose();
    _tagsToRemoveFocus.dispose();
    super.dispose();
  }

  /// Apply bulk metadata edit
  void _applyEdit() async {
    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds;

    if (selectedIds.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    // Parse tags to add (comma or newline separated)
    final tagsToAdd = _parseTagInput(_chipsToAdd);
    final tagsToRemove = _parseTagInput(_chipsToRemove);

    if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
      // Show error dialog if no changes
      AppToast.warning(context, 'Please add tags to add or remove');
      return;
    }

    // Close dialog
    Navigator.of(context).pop();

    if (!mounted) return;

    // Show progress dialog first (it will watch the operation state)
    // 首先显示进度对话框（它将监听操作状态）
    unawaited(BulkProgressDialog.show(context));

    // Start bulk edit operation (the progress dialog will show the progress)
    // 执行批量编辑操作（进度对话框将显示进度）
    final notifier = ref.read(bulkOperationNotifierProvider.notifier);
    await notifier.bulkEditMetadata(
      selectedIds.toList(),
      tagsToAdd: tagsToAdd,
      tagsToRemove: tagsToRemove,
    );
  }

  /// Parse tag input from list of strings
  List<String> _parseTagInput(List<String> input) {
    final result = <String>[];
    for (final item in input) {
      // Split by comma or newline
      final parts = item.split(RegExp(r'[,,\n]'));
      for (final part in parts) {
        final tag = part.trim();
        if (tag.isNotEmpty && !result.contains(tag)) {
          result.add(tag);
        }
      }
    }
    return result;
  }

  /// Add tag to "add" list
  void _addTagToAdd() {
    final text = _tagsToAddController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      // Split by comma or newline and add all tags
      final tags = text.split(RegExp(r'[,,\n]'));
      for (final tag in tags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty && !_chipsToAdd.contains(trimmed)) {
          _chipsToAdd.add(trimmed);
        }
      }
      _tagsToAddController.clear();
    });
  }

  /// Add tag to "remove" list
  void _addTagToRemove() {
    final text = _tagsToRemoveController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      // Split by comma or newline and add all tags
      final tags = text.split(RegExp(r'[,,\n]'));
      for (final tag in tags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty && !_chipsToRemove.contains(trimmed)) {
          _chipsToRemove.add(trimmed);
        }
      }
      _tagsToRemoveController.clear();
    });
  }

  /// Remove tag from "add" list
  void _removeTagToAdd(String tag) {
    setState(() {
      _chipsToAdd.remove(tag);
    });
  }

  /// Remove tag from "remove" list
  void _removeTagToRemove(String tag) {
    setState(() {
      _chipsToRemove.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final selectionState = ref.watch(localGallerySelectionNotifierProvider);
    final selectedCount = selectionState.selectedIds.length;

    return AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
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
                  Icons.edit_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bulk Edit Metadata ($selectedCount images)',
                    style: theme.textTheme.titleLarge?.copyWith(
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
            const ThemedDivider(),
            const SizedBox(height: 16),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags to Add section
                    _buildEditSection(
                      theme,
                      'Tags to Add',
                      Icons.add_circle_outline,
                      [
                        _buildTagInputField(
                          theme,
                          _tagsToAddController,
                          _tagsToAddFocus,
                          'Enter tags to add...',
                          _addTagToAdd,
                        ),
                        const SizedBox(height: 8),
                        _buildChipsList(
                          theme,
                          _chipsToAdd,
                          Colors.green,
                          _removeTagToAdd,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tags to Remove section
                    _buildEditSection(
                      theme,
                      'Tags to Remove',
                      Icons.remove_circle_outline,
                      [
                        _buildTagInputField(
                          theme,
                          _tagsToRemoveController,
                          _tagsToRemoveFocus,
                          'Enter tags to remove...',
                          _addTagToRemove,
                        ),
                        const SizedBox(height: 8),
                        _buildChipsList(
                          theme,
                          _chipsToRemove,
                          Colors.red,
                          _removeTagToRemove,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Prompt section (disabled for now)
                    _buildEditSection(
                      theme,
                      'Prompt (Not Implemented)',
                      Icons.edit_note_outlined,
                      [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bulk prompt editing will be available in a future update',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const ThemedDivider(),
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
                    onPressed: _applyEdit,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Apply Changes'),
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
      ),
    );
  }

  /// Build an edit section with label and content
  Widget _buildEditSection(
    ThemeData theme,
    String label,
    IconData icon,
    List<Widget> children,
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
        ...children,
      ],
    );
  }

  /// Build tag input field with add button
  Widget _buildTagInputField(
    ThemeData theme,
    TextEditingController controller,
    FocusNode focusNode,
    String hintText,
    VoidCallback onAdd,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.6)
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.1),
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(
                    isDark ? 0.6 : 0.5,
                  ),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 20),
          tooltip: 'Add tag',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            foregroundColor: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  /// Build chips list with remove buttons
  Widget _buildChipsList(
    ThemeData theme,
    List<String> chips,
    Color color,
    Function(String) onRemove,
  ) {
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips.map((tag) {
        return Chip(
          label: Text(
            tag,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.9),
            ),
          ),
          deleteIconColor: color,
          onDeleted: () => onRemove(tag),
          backgroundColor: color.withOpacity(0.1),
          side: BorderSide(
            color: color.withOpacity(0.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }).toList(),
    );
  }
}

/// Show bulk metadata edit dialog
/// 显示批量元数据编辑对话框
void showBulkMetadataEditDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const BulkMetadataEditDialog(),
  );
}
