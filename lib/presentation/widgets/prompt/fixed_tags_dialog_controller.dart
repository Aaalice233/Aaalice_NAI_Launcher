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
  final linkLayerKey = GlobalKey();

  final _positiveAnchorKeys = <String, GlobalKey>{};
  final _negativeAnchorKeys = <String, GlobalKey>{};
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

  GlobalKey anchorKeyFor(FixedTagEntry entry) {
    final keys = entry.promptType == FixedTagPromptType.positive
        ? _positiveAnchorKeys
        : _negativeAnchorKeys;
    return keys.putIfAbsent(entry.id, GlobalKey.new);
  }

  Map<String, Offset> collectAnchorCenters(FixedTagPromptType promptType) {
    final layer = linkLayerKey.currentContext?.findRenderObject();
    if (layer is! RenderBox || !layer.hasSize) return const {};
    final keys = promptType == FixedTagPromptType.positive
        ? _positiveAnchorKeys
        : _negativeAnchorKeys;
    final centers = <String, Offset>{};
    for (final item in keys.entries) {
      final anchor = item.value.currentContext?.findRenderObject();
      if (anchor is! RenderBox || !anchor.hasSize) continue;
      centers[item.key] = layer.globalToLocal(
        anchor.localToGlobal(anchor.size.center(Offset.zero)),
      );
    }
    return centers;
  }

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
    super.dispose();
  }
}
