import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import '../../router/app_routes.dart';
import '../common/app_toast.dart';
import '../common/themed_confirm_dialog.dart';
import 'fixed_tag_edit_dialog.dart';
import 'fixed_tag_library_picker_dialog.dart';
import 'fixed_tags_dialog_models.dart';
import 'fixed_tags_link_manager.dart';

class FixedTagsDialogCoordinator {
  const FixedTagsDialogCoordinator(this.ref);

  final WidgetRef ref;

  FixedTagsDialogCommands commands(BuildContext context) {
    final notifier = ref.read(fixedTagsNotifierProvider.notifier);
    return FixedTagsDialogCommands(
      close: () => Navigator.of(context).pop(),
      openLibraryPage: () {
        Navigator.of(context).pop();
        context.go(AppRoutes.tagLibraryPage);
      },
      toggleNegativePanel: () {
        final expanded = ref.read(
          fixedTagsNotifierProvider.select(
            (state) => state.negativePanelExpanded,
          ),
        );
        notifier.setNegativePanelExpanded(!expanded);
      },
      undo: notifier.undo,
      redo: notifier.redo,
      setAllEnabled: notifier.setAllEnabled,
      setPromptTypeEnabled: (promptType, enabled) {
        if (promptType == FixedTagPromptType.positive) {
          notifier.setAllPositiveEnabled(enabled);
        } else {
          notifier.setAllNegativeEnabled(enabled);
        }
      },
      toggleEntry: (entry) => notifier.toggleEnabled(entry.id),
      reorder: notifier.reorderWithinPromptType,
      editEntry: (entry, initialPromptType) =>
          _editEntry(context, entry, initialPromptType),
      deleteEntry: (entry) => _deleteEntry(context, entry),
      clearAll: () => _clearAll(context),
      pickFromLibrary: (promptType) => _showLibraryPicker(context, promptType),
      showLinkManager: (entry) =>
          showFixedTagLinkManager(context: context, ref: ref, entry: entry),
      createLink: (positiveEntryId, negativeEntryId) {
        notifier.createLink(
          positiveEntryId: positiveEntryId,
          negativeEntryId: negativeEntryId,
        );
      },
    );
  }

  Future<void> _showLibraryPicker(
    BuildContext context,
    FixedTagPromptType promptType,
  ) async {
    final libraryEntries = ref.read(tagLibraryPageNotifierProvider).entries;
    if (libraryEntries.isEmpty) {
      AppToast.info(context, context.l10n.fixedTags_libraryEmpty);
      return;
    }
    final entries = filterUnlinkedLibraryEntries(
      libraryEntries: libraryEntries,
      fixedEntries: ref.read(fixedTagsNotifierProvider).entries,
    );
    await showDialog<void>(
      context: context,
      builder: (_) => FixedTagLibraryPickerDialog(
        entries: entries,
        onSelect: (entry) => _addFromLibrary(entry, promptType),
      ),
    );
  }

  Future<void> _addFromLibrary(
    TagLibraryEntry entry,
    FixedTagPromptType promptType,
  ) {
    return ref
        .read(fixedTagsNotifierProvider.notifier)
        .addEntry(
          name: entry.name,
          content: entry.content,
          weight: 1,
          position: FixedTagPosition.prefix,
          enabled: true,
          promptType: promptType,
          sourceEntryId: entry.id,
          categoryId: entry.categoryId,
        );
  }

  Future<void> _editEntry(
    BuildContext context,
    FixedTagEntry? entry,
    FixedTagPromptType initialPromptType,
  ) async {
    final result = await showDialog<FixedTagEntry>(
      context: context,
      builder: (_) => FixedTagEditDialog(
        entry: entry,
        initialPromptType: initialPromptType,
      ),
    );
    if (result == null) return;
    final notifier = ref.read(fixedTagsNotifierProvider.notifier);
    if (entry == null) {
      await notifier.addEntry(
        name: result.name,
        content: result.content,
        weight: result.weight,
        position: result.position,
        promptType: result.promptType,
        enabled: result.enabled,
      );
    } else {
      await notifier.updateEntry(result);
    }
  }

  Future<void> _deleteEntry(BuildContext context, FixedTagEntry entry) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.fixedTags_deleteTitle,
      content: context.l10n.fixedTags_deleteConfirm(entry.displayName),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_outline,
    );
    if (confirmed) {
      await ref.read(fixedTagsNotifierProvider.notifier).deleteEntry(entry.id);
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final count = ref.read(fixedTagsNotifierProvider).entries.length;
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.fixedTags_clearAllTitle,
      content: context.l10n.fixedTags_clearAllConfirm(count),
      confirmText: context.l10n.fixedTags_clearAll,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(fixedTagsNotifierProvider.notifier).clearAll();
    if (context.mounted) {
      AppToast.success(context, context.l10n.fixedTags_clearedSuccess);
    }
  }
}
