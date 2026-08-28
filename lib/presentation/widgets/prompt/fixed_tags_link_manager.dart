import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../providers/fixed_tags_provider.dart';
import '../common/app_toast.dart';

void showFixedTagLinkManager({
  required BuildContext context,
  required WidgetRef ref,
  required FixedTagEntry entry,
}) {
  if (MediaQuery.sizeOf(context).width < 600) {
    _showCompactLinkManager(context: context, ref: ref, entry: entry);
  } else {
    _showDesktopLinkManager(context: context, ref: ref, entry: entry);
  }
}

void _showDesktopLinkManager({
  required BuildContext context,
  required WidgetRef ref,
  required FixedTagEntry entry,
}) {
  final state = ref.read(fixedTagsNotifierProvider);
  final linkedEntries = entry.promptType == FixedTagPromptType.positive
      ? state.linkedNegativesOf(entry.id)
      : state.linkedPositivesOf(entry.id);
  if (linkedEntries.isEmpty) {
    AppToast.info(context, context.l10n.fixedTags_linkInstruction);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(dialogContext.l10n.fixedTags_manageLinks),
      children: [
        for (final linkedEntry in linkedEntries)
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final notifier = ref.read(fixedTagsNotifierProvider.notifier);
              if (entry.promptType == FixedTagPromptType.positive) {
                await notifier.removeLinkByPair(
                  positiveEntryId: entry.id,
                  negativeEntryId: linkedEntry.id,
                );
              } else {
                await notifier.removeLinkByPair(
                  positiveEntryId: linkedEntry.id,
                  negativeEntryId: entry.id,
                );
              }
            },
            child: Row(
              children: [
                const Icon(Icons.link_off_rounded, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dialogContext.l10n.fixedTags_removeLink(
                      linkedEntry.displayName,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

void _showCompactLinkManager({
  required BuildContext context,
  required WidgetRef ref,
  required FixedTagEntry entry,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(fixedTagsNotifierProvider);
        final oppositeType = entry.promptType == FixedTagPromptType.positive
            ? FixedTagPromptType.negative
            : FixedTagPromptType.positive;
        final oppositeTitle = oppositeType == FixedTagPromptType.positive
            ? context.l10n.fixedTags_positiveTitle
            : context.l10n.fixedTags_negativeTitle;
        final candidates = state.entries
            .where((candidate) => candidate.promptType == oppositeType)
            .toList()
            .sortedByOrder();
        final linkedIds = entry.promptType == FixedTagPromptType.positive
            ? state.linkedNegativesOf(entry.id).map((item) => item.id).toSet()
            : state.linkedPositivesOf(entry.id).map((item) => item.id).toSet();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.fixedTags_manageLinks,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${entry.displayName} · $oppositeTitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: Text(
                      context.l10n.fixedTags_emptyTarget(oppositeTitle),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        final linked = linkedIds.contains(candidate.id);
                        return CheckboxListTile(
                          key: ValueKey(
                            'fixed-tag-link-option-${candidate.id}',
                          ),
                          value: linked,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(candidate.displayName),
                          subtitle: candidate.content.isEmpty
                              ? null
                              : Text(
                                  candidate.content.replaceAll('\n', ' '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onChanged: (selected) async {
                            final notifier = ref.read(
                              fixedTagsNotifierProvider.notifier,
                            );
                            final positiveId =
                                entry.promptType == FixedTagPromptType.positive
                                ? entry.id
                                : candidate.id;
                            final negativeId =
                                entry.promptType == FixedTagPromptType.negative
                                ? entry.id
                                : candidate.id;
                            if (selected ?? false) {
                              await notifier.createLink(
                                positiveEntryId: positiveId,
                                negativeEntryId: negativeId,
                              );
                            } else {
                              await notifier.removeLinkByPair(
                                positiveEntryId: positiveId,
                                negativeEntryId: negativeId,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
