import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../../providers/fixed_tags_provider.dart';
import '../sidebar_entry_tile.dart';
import 'fixed_tags_sidebar_models.dart';

typedef FixedTagsDragStartCallback =
    void Function(
      String positiveEntryId, {
      String? negativeEntryId,
      bool isDetaching,
    });

typedef FixedTagsDragUpdateCallback =
    void Function({
      required String positiveEntryId,
      required Offset globalPosition,
      bool isDetaching,
    });

typedef FixedTagsDetachCompleteCallback =
    void Function({
      required String positiveEntryId,
      required String negativeEntryId,
      Offset? globalPosition,
    });

class FixedTagsLinkAnchor extends ConsumerWidget {
  const FixedTagsLinkAnchor({
    super.key,
    required this.entry,
    required this.anchorKey,
    required this.onHighlightChanged,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragClear,
    required this.onDetachComplete,
  });

  final FixedTagEntry entry;
  final GlobalKey anchorKey;
  final void Function(String entryId, bool highlighted) onHighlightChanged;
  final FixedTagsDragStartCallback onDragStart;
  final FixedTagsDragUpdateCallback onDragUpdate;
  final VoidCallback onDragClear;
  final FixedTagsDetachCompleteCallback onDetachComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final anchorExtent = SidebarEntryTile.linkAnchorExtentOf(context);
    final state = ref.watch(fixedTagsNotifierProvider);
    final linkedPositiveIds = entry.promptType == FixedTagPromptType.negative
        ? state.linkedPositivesOf(entry.id).map((linked) => linked.id).toList()
        : const <String>[];
    final linkCount = entry.promptType == FixedTagPromptType.positive
        ? state.linkedNegativesOf(entry.id).length
        : linkedPositiveIds.length;

    final visual = Semantics(
      label: linkCount > 0 ? 'Linked $linkCount' : 'Not linked',
      child: SizedBox.square(
        dimension: anchorExtent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.link_rounded,
                size: 16,
                color: linkCount > 0
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outline,
              ),
            ),
            if (linkCount > 1)
              Positioned(
                right: -2,
                top: -2,
                child: Text(
                  '$linkCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    Widget revealRelatedLinks(Widget child) {
      return MouseRegion(
        onEnter: (_) => onHighlightChanged(entry.id, true),
        onExit: (_) => onHighlightChanged(entry.id, false),
        child: Focus(
          onFocusChange: (focused) => onHighlightChanged(entry.id, focused),
          child: child,
        ),
      );
    }

    if (entry.promptType == FixedTagPromptType.positive) {
      return KeyedSubtree(
        key: anchorKey,
        child: revealRelatedLinks(
          Draggable<FixedTagLinkDragPayload>(
            data: FixedTagLinkDragPayload(entry.id),
            onDragStarted: () => onDragStart(entry.id),
            onDragUpdate: (details) => onDragUpdate(
              positiveEntryId: entry.id,
              globalPosition: details.globalPosition,
            ),
            onDragEnd: (_) => onDragClear(),
            onDragCompleted: onDragClear,
            onDraggableCanceled: (_, __) => onDragClear(),
            feedback: Material(
              color: Colors.transparent,
              child: Icon(
                Icons.link_rounded,
                color: theme.colorScheme.secondary,
                size: 22,
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: visual),
            child: visual,
          ),
        ),
      );
    }

    final negativeAnchor = linkedPositiveIds.isEmpty
        ? visual
        : Draggable<String>(
            data: entry.id,
            feedback: const SizedBox(width: 1, height: 1),
            childWhenDragging: Opacity(opacity: 0.35, child: visual),
            onDragStarted: () => onDragStart(
              linkedPositiveIds.first,
              negativeEntryId: entry.id,
              isDetaching: true,
            ),
            onDragUpdate: (details) => onDragUpdate(
              positiveEntryId: linkedPositiveIds.first,
              globalPosition: details.globalPosition,
              isDetaching: true,
            ),
            onDragEnd: (details) => onDetachComplete(
              positiveEntryId: linkedPositiveIds.first,
              negativeEntryId: entry.id,
              globalPosition: details.offset,
            ),
            onDraggableCanceled: (_, offset) => onDetachComplete(
              positiveEntryId: linkedPositiveIds.first,
              negativeEntryId: entry.id,
              globalPosition: offset,
            ),
            child: visual,
          );
    return KeyedSubtree(
      key: anchorKey,
      child: revealRelatedLinks(negativeAnchor),
    );
  }
}

class FixedTagsNegativeLinkTarget extends ConsumerWidget {
  const FixedTagsNegativeLinkTarget({
    super.key,
    required this.entry,
    required this.child,
    required this.onLinkChanged,
  });

  final FixedTagEntry entry;
  final Widget child;
  final VoidCallback onLinkChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(fixedTagsNotifierProvider);
    return DragTarget<FixedTagLinkDragPayload>(
      onWillAcceptWithDetails: (details) {
        return state.entries.any(
          (candidate) =>
              candidate.id == details.data.positiveEntryId &&
              candidate.promptType == FixedTagPromptType.positive,
        );
      },
      onAcceptWithDetails: (details) {
        final positiveEntryId = details.data.positiveEntryId;
        final currentState = ref.read(fixedTagsNotifierProvider);
        final notifier = ref.read(fixedTagsNotifierProvider.notifier);
        final linkExists = currentState.links.any(
          (link) =>
              link.positiveEntryId == positiveEntryId &&
              link.negativeEntryId == entry.id,
        );
        if (linkExists) {
          notifier.removeLinkByPair(
            positiveEntryId: positiveEntryId,
            negativeEntryId: entry.id,
          );
        } else {
          notifier.createLink(
            positiveEntryId: positiveEntryId,
            negativeEntryId: entry.id,
          );
        }
        onLinkChanged();
      },
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: theme.colorScheme.secondary, width: 1.5)
                : null,
          ),
          child: child,
        );
      },
    );
  }
}
