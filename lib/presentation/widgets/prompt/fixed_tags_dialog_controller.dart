import 'package:flutter/material.dart';

import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';

class FixedTagsDialogController extends ChangeNotifier {
  FixedTagsDialogController() {
    positiveListController.addListener(_handleScroll);
    negativeListController.addListener(_handleScroll);
  }

  final positiveSearchController = TextEditingController();
  final negativeSearchController = TextEditingController();
  final positiveListController = ScrollController();
  final negativeListController = ScrollController();

  final _positiveAnchors = <String, RenderBox>{};
  final _negativeAnchors = <String, RenderBox>{};
  RenderBox? _linkLayer;
  String positiveSearchQuery = '';
  String negativeSearchQuery = '';
  FixedTagPromptType mobilePromptType = FixedTagPromptType.positive;
  int? _scheduledGeometryHash;
  bool _scrollRepaintScheduled = false;
  bool _disposed = false;

  String searchQueryFor(FixedTagPromptType promptType) =>
      promptType == FixedTagPromptType.positive
      ? positiveSearchQuery
      : negativeSearchQuery;

  TextEditingController searchControllerFor(FixedTagPromptType promptType) =>
      promptType == FixedTagPromptType.positive
      ? positiveSearchController
      : negativeSearchController;

  ScrollController listControllerFor(FixedTagPromptType promptType) =>
      promptType == FixedTagPromptType.positive
      ? positiveListController
      : negativeListController;

  double scrollOffsetFor(FixedTagPromptType promptType) {
    final positions = listControllerFor(promptType).positions;
    if (positions.isEmpty) return 0;
    // A responsive rebuild can briefly keep the outgoing list attached while
    // mounting its replacement. The newest position belongs to the incoming
    // layout; reading ScrollController.offset would assert during that frame.
    return positions.last.pixels;
  }

  void setSearchQuery(FixedTagPromptType promptType, String value) {
    if (promptType == FixedTagPromptType.positive) {
      positiveSearchQuery = value;
    } else {
      negativeSearchQuery = value;
    }
    notifyListeners();
  }

  void clearSearch(FixedTagPromptType promptType) {
    searchControllerFor(promptType).clear();
    setSearchQuery(promptType, '');
  }

  void selectMobilePromptType(FixedTagPromptType promptType) {
    if (mobilePromptType == promptType) return;
    mobilePromptType = promptType;
    notifyListeners();
  }

  void registerLinkLayer(RenderBox layer) => _linkLayer = layer;

  void unregisterLinkLayer(RenderBox layer) {
    if (identical(_linkLayer, layer)) _linkLayer = null;
  }

  void registerAnchor(
    FixedTagPromptType promptType,
    String entryId,
    RenderBox anchor,
  ) {
    _anchorsFor(promptType)[entryId] = anchor;
  }

  void unregisterAnchor(
    FixedTagPromptType promptType,
    String entryId,
    RenderBox anchor,
  ) {
    final anchors = _anchorsFor(promptType);
    if (identical(anchors[entryId], anchor)) anchors.remove(entryId);
  }

  Map<String, Offset> collectAnchorCenters(FixedTagPromptType promptType) {
    final layer = _linkLayer;
    if (layer == null || !layer.attached || !layer.hasSize) return const {};
    final centers = <String, Offset>{};
    for (final item in _anchorsFor(promptType).entries) {
      final anchor = item.value;
      if (!anchor.attached || !anchor.hasSize) continue;
      centers[item.key] = layer.globalToLocal(
        anchor.localToGlobal(anchor.size.center(Offset.zero)),
      );
    }
    return centers;
  }

  Map<String, RenderBox> _anchorsFor(FixedTagPromptType promptType) =>
      promptType == FixedTagPromptType.positive
      ? _positiveAnchors
      : _negativeAnchors;

  void scheduleGeometryRefresh({
    required List<FixedTagEntry> positives,
    required List<FixedTagEntry> negatives,
  }) {
    final hash = Object.hashAll([
      for (final entry in positives) entry.id,
      '|',
      for (final entry in negatives) entry.id,
    ]);
    if (_scheduledGeometryHash == hash) return;
    _scheduledGeometryHash = hash;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && _scheduledGeometryHash == hash) notifyListeners();
    });
  }

  void resetGeometryTracking() => _scheduledGeometryHash = null;

  void _handleScroll() {
    if (_disposed) return;
    notifyListeners();
    if (_scrollRepaintScheduled) return;
    _scrollRepaintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollRepaintScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    positiveListController.removeListener(_handleScroll);
    negativeListController.removeListener(_handleScroll);
    positiveSearchController.dispose();
    negativeSearchController.dispose();
    positiveListController.dispose();
    negativeListController.dispose();
    _positiveAnchors.clear();
    _negativeAnchors.clear();
    _linkLayer = null;
    super.dispose();
  }
}
