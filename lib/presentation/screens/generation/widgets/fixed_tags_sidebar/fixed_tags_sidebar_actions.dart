import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../../providers/fixed_tags_provider.dart';
import '../../../../widgets/common/app_toast.dart';
import '../../../../widgets/common/themed_confirm_dialog.dart';
import '../../../../widgets/prompt/fixed_tag_edit_dialog.dart';
import '../../../../widgets/tag_library/tag_library_picker_dialog.dart';

Future<void> showEditFixedTagEntryDialog(
  BuildContext context,
  WidgetRef ref,
  FixedTagEntry entry,
) async {
  final result = await FixedTagEditDialog.show(context: context, entry: entry);
  if (result == null || !context.mounted) return;
  await ref.read(fixedTagsNotifierProvider.notifier).updateEntry(result);
}

Future<void> showAddFixedTagEntryDialog(
  BuildContext context,
  WidgetRef ref, {
  FixedTagPromptType promptType = FixedTagPromptType.positive,
}) async {
  final result = await FixedTagEditDialog.show(
    context: context,
    initialPromptType: promptType,
  );
  if (result == null || !context.mounted) return;
  await ref
      .read(fixedTagsNotifierProvider.notifier)
      .addEntry(
        name: result.name,
        content: result.content,
        weight: result.weight,
        position: result.position,
        enabled: result.enabled,
        promptType: result.promptType,
        sourceEntryId: result.sourceEntryId,
        categoryId: result.categoryId,
      );
}

Future<void> showAddFixedTagFromLibraryDialog(
  BuildContext context,
  WidgetRef ref,
  FixedTagPromptType promptType,
) async {
  final entry = await TagLibraryPickerDialog.show(context);
  if (entry == null || !context.mounted) return;
  await ref
      .read(fixedTagsNotifierProvider.notifier)
      .addEntry(
        name: entry.name,
        content: entry.content,
        promptType: promptType,
        sourceEntryId: entry.id,
        categoryId: entry.categoryId,
      );
  if (!context.mounted) return;
  AppToast.success(context, context.l10n.fixedTags_addedToSidebar);
}

Future<void> confirmDeleteFixedTagEntry(
  BuildContext context,
  WidgetRef ref,
  FixedTagEntry entry,
) async {
  final confirmed = await ThemedConfirmDialog.show(
    context: context,
    title: context.l10n.fixedTags_deleteTitle,
    content: context.l10n.fixedTags_deleteConfirm(entry.displayName),
    confirmText: context.l10n.common_delete,
    type: ThemedConfirmDialogType.danger,
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(fixedTagsNotifierProvider.notifier).deleteEntry(entry.id);
}
