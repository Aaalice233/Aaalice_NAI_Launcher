import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../../../data/models/fixed_tag/fixed_tag_link.dart';
import '../../../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../../../providers/fixed_tags_provider.dart';
import '../sidebar_link_painter.dart';
import 'fixed_tags_sidebar_layout.dart';
import 'fixed_tags_sidebar_models.dart';

class FixedTagsLinkController {
  FixedTagsLinkController({
    required this.isMounted,
    required this.onStateChanged,
    required this.onRemoveLinkByPair,
  });

  final bool Function() isMounted;
  final VoidCallback onStateChanged;
  final Future<void> Function({
    required String positiveEntryId,
    required String negativeEntryId,
  })
  onRemoveLinkByPair;

  final linkLayerKey = GlobalKey();
  final _positiveAnchorKeys = <String, GlobalKey>{};
  final _negativeAnchorKeys = <String, GlobalKey>{};

  var positiveAnchorCenters = <String, Offset>{};
  var negativeAnchorCenters = <String, Offset>{};
  FixedTagLinkDragPreview? linkDragPreview;
  String? _highlightedLinkEntryId;
  bool _linkRepaintScheduled = false;

  void setHighlightedLinkEntry(String entryId, bool highlighted) {
    if (highlighted) {
      if (_highlightedLinkEntryId == entryId) return;
      _highlightedLinkEntryId = entryId;
      onStateChanged();
      return;
    }
    if (_highlightedLinkEntryId != entryId || linkDragPreview != null) return;
    _highlightedLinkEntryId = null;
    onStateChanged();
  }

  void startLinkDragPreview(
    String positiveEntryId, {
    String? negativeEntryId,
    bool isDetaching = false,
  }) {
    final start = positiveAnchorCenters[positiveEntryId];
    if (start == null) return;
    final end = negativeEntryId == null
        ? start
        : negativeAnchorCenters[negativeEntryId] ?? start;
    linkDragPreview = FixedTagLinkDragPreview(
      start: start,
      end: end,
      isDetaching: isDetaching,
    );
    onStateChanged();
  }

  void updateLinkDragPreview({
    required String positiveEntryId,
    required Offset globalPosition,
    bool isDetaching = false,
  }) {
    final start = positiveAnchorCenters[positiveEntryId];
    final end = _globalToLinkLayer(globalPosition);
    if (start == null || end == null) return;
    linkDragPreview = FixedTagLinkDragPreview(
      start: start,
      end: end,
      isDetaching: isDetaching,
    );
    onStateChanged();
  }

  void completeLinkDetachDrag({
    required String positiveEntryId,
    required String negativeEntryId,
    Offset? globalPosition,
  }) {
    final dragEnd = globalPosition == null
        ? linkDragPreview?.end
        : _globalToLinkLayer(globalPosition);
    final endpoint = negativeAnchorCenters[negativeEntryId];
    if (dragEnd != null &&
        endpoint != null &&
        (dragEnd - endpoint).distance >= linkDetachDistance) {
      onRemoveLinkByPair(
        positiveEntryId: positiveEntryId,
        negativeEntryId: negativeEntryId,
      );
      scheduleLinkRepaint();
    }
    clearLinkDragPreview();
  }

  void clearLinkDragPreview() {
    if (linkDragPreview == null) return;
    linkDragPreview = null;
    onStateChanged();
  }

  Offset? _globalToLinkLayer(Offset globalPosition) {
    final renderObject = linkLayerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.globalToLocal(globalPosition);
  }

  List<FixedTagLink> visibleLinks(FixedTagsState state) {
    final highlightedEntryId = _highlightedLinkEntryId;
    if (highlightedEntryId == null) return const [];
    return state.links
        .where(
          (link) =>
              link.positiveEntryId == highlightedEntryId ||
              link.negativeEntryId == highlightedEntryId,
        )
        .toList();
  }

  GlobalKey anchorKeyFor(FixedTagEntry entry) {
    final keys = entry.promptType == FixedTagPromptType.positive
        ? _positiveAnchorKeys
        : _negativeAnchorKeys;
    return keys.putIfAbsent(entry.id, () => GlobalKey());
  }

  void pruneAnchorKeys(FixedTagsState state) {
    final positiveIds = state.positiveEntries.map((e) => e.id).toSet();
    final negativeIds = state.negativeEntries.map((e) => e.id).toSet();
    _positiveAnchorKeys.removeWhere((id, _) => !positiveIds.contains(id));
    _negativeAnchorKeys.removeWhere((id, _) => !negativeIds.contains(id));
  }

  void scheduleLinkRepaint() {
    if (_linkRepaintScheduled) return;
    _linkRepaintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linkRepaintScheduled = false;
      if (!isMounted()) return;
      final positiveCenters = collectAnchorCenters(
        _positiveAnchorKeys,
        linkLayerKey,
      );
      final negativeCenters = collectAnchorCenters(
        _negativeAnchorKeys,
        linkLayerKey,
      );
      if (mapEquals(positiveAnchorCenters, positiveCenters) &&
          mapEquals(negativeAnchorCenters, negativeCenters)) {
        return;
      }
      positiveAnchorCenters = positiveCenters;
      negativeAnchorCenters = negativeCenters;
      onStateChanged();
    });
  }
}
