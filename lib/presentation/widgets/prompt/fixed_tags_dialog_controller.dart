import 'package:flutter/material.dart';

import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../providers/fixed_tags_viewport_memory_provider.dart';
import '../common/owned_scroll_controller.dart';

class FixedTagsDialogController extends ChangeNotifier {
  FixedTagsDialogController({FixedTagsViewportMemory? viewportMemory})
    : _viewportMemory = viewportMemory ?? FixedTagsViewportMemory() {
    for (final promptType in FixedTagPromptType.values) {
      _browseListControllers[promptType] = OwnedScrollController(
        viewport: _viewportMemory.browseViewport(
          FixedTagsSurface.dialog,
          promptType,
        ),
      )..addListener(_handleScroll);
      _filteredListControllers[promptType] = ScrollController()
        ..addListener(_handleScroll);
    }
  }

  final FixedTagsViewportMemory _viewportMemory;
  final positiveSearchController = TextEditingController();
  final negativeSearchController = TextEditingController();
  final _browseListControllers = <FixedTagPromptType, OwnedScrollController>{};
  // Filtered results start at the top and never overwrite the browse memory.
  final _filteredListControllers = <FixedTagPromptType, ScrollController>{};
  final _compactHeaderKeys = {
    for (final promptType in FixedTagPromptType.values) promptType: GlobalKey(),
  };

  final _positiveAnchors = <String, RenderBox>{};
  final _negativeAnchors = <String, RenderBox>{};
  RenderBox? _linkLayer;
  String positiveSearchQuery = '';
  String negativeSearchQuery = '';
  bool enabledOnly = false;
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

  FixedTagPromptType get mobilePromptType =>
      _viewportMemory.dialogMobilePromptType;

  GlobalKey compactHeaderKeyFor(FixedTagPromptType promptType) =>
      _compactHeaderKeys[promptType]!;

  ScrollController listControllerFor(
    FixedTagPromptType promptType, {
    required bool filtered,
  }) => filtered
      ? _filteredListControllers[promptType]!
      : _browseListControllers[promptType]!;

  double scrollOffsetFor(
    FixedTagPromptType promptType, {
    required bool filtered,
  }) {
    final positions = listControllerFor(
      promptType,
      filtered: filtered,
    ).positions;
    if (positions.isEmpty) return 0;
    // A responsive rebuild can briefly keep the outgoing list attached while
    // mounting its replacement. The newest position belongs to the incoming
    // layout; reading ScrollController.offset would assert during that frame.
    return positions.last.pixels;
  }

  void setSearchQuery(
    FixedTagPromptType promptType,
    String value, {
    bool searchInList = false,
  }) {
    final leavingSearch =
        searchQueryFor(promptType).trim().isNotEmpty && value.trim().isEmpty;
    if (promptType == FixedTagPromptType.positive) {
      positiveSearchQuery = value;
    } else {
      negativeSearchQuery = value;
    }
    // An in-list search field must stay in view: restoring a deeper offset
    // lets EditableText scroll back to the caret and overwrite the memory.
    if (searchInList && leavingSearch && !enabledOnly) {
      _returnBrowseListToTop(promptType);
    }
    notifyListeners();
  }

  void _returnBrowseListToTop(FixedTagPromptType promptType) {
    _viewportMemory
        .browseViewport(FixedTagsSurface.dialog, promptType)
        .replace(0);
    // Entering and leaving search within one frame keeps the browse list
    // mounted, so its live position must move as well as the memory.
    final browse = _browseListControllers[promptType]!;
    if (browse.hasClients) browse.jumpTo(0);
  }

  void clearSearch(FixedTagPromptType promptType, {bool searchInList = false}) {
    searchControllerFor(promptType).clear();
    setSearchQuery(promptType, '', searchInList: searchInList);
  }

  void toggleEnabledOnly() {
    enabledOnly = !enabledOnly;
    notifyListeners();
  }

  void selectMobilePromptType(FixedTagPromptType promptType) {
    if (mobilePromptType == promptType) return;
    _viewportMemory.dialogMobilePromptType = promptType;
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
    for (final listController in [
      ..._browseListControllers.values,
      ..._filteredListControllers.values,
    ]) {
      listController
        ..removeListener(_handleScroll)
        ..dispose();
    }
    positiveSearchController.dispose();
    negativeSearchController.dispose();
    _positiveAnchors.clear();
    _negativeAnchors.clear();
    _linkLayer = null;
    super.dispose();
  }
}
