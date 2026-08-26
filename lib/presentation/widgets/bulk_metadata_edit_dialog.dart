import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/bulk_tag_edit_utils.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../providers/bulk_operation_provider.dart';
import '../providers/local_gallery_provider.dart';
import '../providers/selection_mode_provider.dart';
import 'bulk_progress_dialog.dart';
import '../widgets/common/themed_divider.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/autocomplete/autocomplete_config.dart';
import '../widgets/autocomplete/autocomplete_wrapper.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

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

  final FocusNode _tagsToAddFocus = FocusNode();
  final FocusNode _tagsToRemoveFocus = FocusNode();

  final List<String> _chipsToAdd = [];
  final List<String> _chipsToRemove = [];

  @override
  void dispose() {
    _tagsToAddController.dispose();
    _tagsToRemoveController.dispose();
    _tagsToAddFocus.dispose();
    _tagsToRemoveFocus.dispose();
    super.dispose();
  }

  Future<void> _applyEdit() async {
    _addTagToAdd();
    _addTagToRemove();

    final selectionState = ref.read(localGallerySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds;
    if (selectedIds.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final operationState = ref.read(bulkOperationNotifierProvider);
    if (operationState.isOperationInProgress) {
      AppToast.warning(
        context,
        context.l10n.bulkProgress_operationAlreadyInProgress,
      );
      return;
    }

    final tagsToAdd = parseBulkTagInput(_chipsToAdd);
    final tagsToRemove = parseBulkTagInput(_chipsToRemove);
    if (tagsToAdd.isEmpty && tagsToRemove.isEmpty) {
      AppToast.warning(context, context.l10n.bulkMetadataEdit_noChanges);
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    final progressContext = navigator.context;
    navigator.pop();

    final notifier = ref.read(bulkOperationNotifierProvider.notifier);
    final operation = notifier.bulkEditMetadata(
      selectedIds.toList(),
      tagsToAdd: tagsToAdd,
      tagsToRemove: tagsToRemove,
    );
    unawaited(BulkProgressDialog.show(progressContext));

    try {
      final result = await operation;
      if (result.success > 0) {
        await ref
            .read(localGalleryNotifierProvider.notifier)
            .refresh(scan: false);
      }
    } on Object {
      // BulkOperationNotifier exposes the localized failure in progress state.
    }
  }

  void _addTagToAdd() {
    _commitTags(
      controller: _tagsToAddController,
      target: _chipsToAdd,
      opposite: _chipsToRemove,
    );
  }

  void _addTagToRemove() {
    _commitTags(
      controller: _tagsToRemoveController,
      target: _chipsToRemove,
      opposite: _chipsToAdd,
    );
  }

  void _commitTags({
    required TextEditingController controller,
    required List<String> target,
    required List<String> opposite,
  }) {
    final tags = parseBulkTagInput([controller.text]);
    if (tags.isEmpty) return;

    setState(() {
      for (final tag in tags) {
        final key = canonicalBulkTagKey(tag);
        opposite.removeWhere((item) => canonicalBulkTagKey(item) == key);
        if (!target.any((item) => canonicalBulkTagKey(item) == key)) {
          target.add(tag);
        }
      }
      controller.clear();
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
                    l10n.bulkMetadataEdit_title(selectedCount),
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
                    _buildEditSection(
                      theme,
                      l10n.bulkMetadataEdit_tagsToAdd,
                      Icons.add_circle_outline,
                      [
                        _buildTagInputField(
                          theme,
                          _tagsToAddController,
                          _tagsToAddFocus,
                          l10n.bulkMetadataEdit_tagsToAddHint,
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
                    _buildEditSection(
                      theme,
                      l10n.bulkMetadataEdit_tagsToRemove,
                      Icons.remove_circle_outline,
                      [
                        _buildTagInputField(
                          theme,
                          _tagsToRemoveController,
                          _tagsToRemoveFocus,
                          l10n.bulkMetadataEdit_tagsToRemoveHint,
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
                    label: Text(context.l10n.common_apply),
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
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
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
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    )
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.1),
              ),
            ),
            child: AutocompleteWrapper(
              controller: controller,
              focusNode: focusNode,
              config: const AutocompleteConfig(
                showTranslation: true,
                showCategory: true,
                autoInsertComma: false,
              ),
              child: ThemedInput(
                controller: controller,
                focusNode: focusNode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: isDark ? 0.6 : 0.5,
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
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 20),
          tooltip: context.l10n.tag_addTag,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
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
              color: color.withValues(alpha: 0.9),
            ),
          ),
          deleteIconColor: color,
          onDeleted: () => onRemove(tag),
          backgroundColor: color.withValues(alpha: 0.1),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
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
