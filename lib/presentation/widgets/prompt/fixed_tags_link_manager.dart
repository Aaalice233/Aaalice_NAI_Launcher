import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import '../../providers/fixed_tags_provider.dart';
import '../common/adaptive_dialog_frame.dart';
import '../common/app_toast.dart';

void showFixedTagLinkManager({
  required BuildContext context,
  required WidgetRef ref,
  required FixedTagEntry entry,
}) {
  final isCompact = AdaptiveWindowMetrics.of(context).isCompact;
  final state = ref.read(fixedTagsNotifierProvider);
  final linkedEntries = entry.promptType == FixedTagPromptType.positive
      ? state.linkedNegativesOf(entry.id)
      : state.linkedPositivesOf(entry.id);
  if (!isCompact && linkedEntries.isEmpty) {
    AppToast.info(context, context.l10n.fixedTags_linkInstruction);
    return;
  }

  final oppositeType = entry.promptType == FixedTagPromptType.positive
      ? FixedTagPromptType.negative
      : FixedTagPromptType.positive;
  AdaptivePresenter.showPanel<void>(
    context: context,
    titleBuilder: (panelContext) =>
        _LinkManagerTitle(entry: entry, oppositeType: oppositeType),
    initialChildSize: 0.72,
    minChildSize: 0.38,
    maxChildSize: 0.94,
    dialogWidth: 420,
    builder: (panelContext, scrollController) => Align(
      alignment: Alignment.topCenter,
      child: AdaptiveDialogFrame(
        maxWidth: 420,
        maxHeight: 480,
        reservedVerticalSpace: 104,
        horizontalMargin: isCompact ? 12 : 24,
        child: _FixedTagLinkManagerBody(
          entry: entry,
          showAllCandidates: isCompact,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class _LinkManagerTitle extends StatelessWidget {
  const _LinkManagerTitle({required this.entry, required this.oppositeType});

  final FixedTagEntry entry;
  final FixedTagPromptType oppositeType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oppositeTitle = oppositeType == FixedTagPromptType.positive
        ? context.l10n.fixedTags_positiveTitle
        : context.l10n.fixedTags_negativeTitle;
    return Row(
      children: [
        Icon(Icons.link_rounded, color: theme.colorScheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.fixedTags_manageLinks,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${entry.displayName} · $oppositeTitle',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FixedTagLinkManagerBody extends ConsumerWidget {
  const _FixedTagLinkManagerBody({
    required this.entry,
    required this.showAllCandidates,
    required this.scrollController,
  });

  final FixedTagEntry entry;
  final bool showAllCandidates;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fixedTagsNotifierProvider);
    final oppositeType = entry.promptType == FixedTagPromptType.positive
        ? FixedTagPromptType.negative
        : FixedTagPromptType.positive;
    final oppositeTitle = oppositeType == FixedTagPromptType.positive
        ? context.l10n.fixedTags_positiveTitle
        : context.l10n.fixedTags_negativeTitle;
    final linkedEntries = entry.promptType == FixedTagPromptType.positive
        ? state.linkedNegativesOf(entry.id)
        : state.linkedPositivesOf(entry.id);

    if (!showAllCandidates) {
      return ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: linkedEntries.length,
        itemBuilder: (context, index) {
          final linkedEntry = linkedEntries[index];
          return SimpleDialogOption(
            key: ValueKey('fixed-tag-linked-entry-${linkedEntry.id}'),
            onPressed: () async {
              Navigator.of(context).pop();
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
                    context.l10n.fixedTags_removeLink(linkedEntry.displayName),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final candidates = state.entries
        .where((candidate) => candidate.promptType == oppositeType)
        .toList()
        .sortedByOrder();
    final linkedIds = linkedEntries.map((item) => item.id).toSet();
    if (candidates.isEmpty) {
      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Text(
          context.l10n.fixedTags_emptyTarget(oppositeTitle),
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        final linked = linkedIds.contains(candidate.id);
        return CheckboxListTile(
          key: ValueKey('fixed-tag-link-option-${candidate.id}'),
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
            final notifier = ref.read(fixedTagsNotifierProvider.notifier);
            final positiveId = entry.promptType == FixedTagPromptType.positive
                ? entry.id
                : candidate.id;
            final negativeId = entry.promptType == FixedTagPromptType.negative
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
    );
  }
}
