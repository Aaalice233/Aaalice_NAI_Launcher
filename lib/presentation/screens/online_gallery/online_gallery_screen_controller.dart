import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../providers/online_gallery_provider.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import '../../widgets/online_gallery/online_gallery_hover_controller.dart';
import 'online_gallery_masonry_layout.dart';
import 'online_gallery_pagination_demand.dart';
import 'online_gallery_viewport_tracker.dart';

/// Owns the ephemeral input, focus, scrolling, anchor and prefetch lifecycle for
/// [OnlineGalleryScreen]. Provider state remains the source of truth for the
/// current gallery query and loaded items.
class OnlineGalleryScreenController extends ChangeNotifier {
  OnlineGalleryScreenController({required this.prefetchCoordinator}) {
    scrollController = OwnedScrollController(viewport: _viewportOffset);
    _frameTimingsCallback = _recordFrameTimings;
    if (kDebugMode) {
      SchedulerBinding.instance.addTimingsCallback(_frameTimingsCallback);
    }
  }

  final searchController = TextEditingController();
  final promptSearchController = TextEditingController();
  final popularSearchController = TextEditingController();
  final popularPromptSearchController = TextEditingController();
  final favoriteSearchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final promptSearchFocusNode = FocusNode();
  final popularSearchFocusNode = FocusNode();
  final popularPromptSearchFocusNode = FocusNode();
  final favoriteSearchFocusNode = FocusNode();
  final OwnedViewportOffset _viewportOffset = OwnedViewportOffset();
  late final OwnedScrollController scrollController;
  final pageController = TextEditingController();
  final pageFocusNode = FocusNode();
  final hoverController = OnlineGalleryHoverController();
  final OnlineGalleryPrefetchCoordinator prefetchCoordinator;
  final dateRangeLayerLink = LayerLink();
  final primarySearchRevealKey = GlobalKey();
  final viewportTracker = OnlineGalleryViewportTracker();
  final paginationDemand = OnlineGalleryPaginationDemand();
  final Map<String, GlobalKey> _pageAnchorKeys = <String, GlobalKey>{};
  final Set<String> pendingGalleryDetails = <String>{};
  final ListQueue<VoidCallback> _cardRevealQueue = ListQueue<VoidCallback>();
  bool _cardRevealScheduled = false;
  bool _disposed = false;

  Timer? searchDebounceTimer;
  Timer? scrollStopTimer;
  Timer? prefetchResumeTimer;
  Timer? idlePrefetchTimer;
  Timer? _pageFocusNotificationTimer;
  OverlayEntry? dateRangeOverlayEntry;
  double lastScrollOffset = 0;
  int scrollDirection = 1;
  int lookaheadItemCount = 12;
  double? _lookaheadViewportHeight;
  double? _lookaheadItemWidth;
  int? _lookaheadColumnCount;
  ValueListenable<bool> get scrolling => viewportTracker.scrolling;
  bool get isScrolling => viewportTracker.isScrolling;
  bool hasViewedItem(String stableKey) =>
      viewportTracker.hasViewedItem(stableKey);
  double? get currentItemWidth => _lookaheadItemWidth;
  int? get currentColumnCount => _lookaheadColumnCount;
  GlobalKey pageAnchorKey(String stableKey) =>
      _pageAnchorKeys.putIfAbsent(stableKey, () => GlobalKey());

  bool isEditingPage = false;
  GalleryViewMode? lastViewMode;
  GallerySourceId? lastFavoritesSource;
  String? lastCacheKey;
  bool? lastRandomEnabled;
  bool restoreInitialPositionPending = false;
  bool randomReplacePending = false;
  bool branchVisible = true;
  int _scrollRestoreRevision = 0;
  String? _viewportScope;
  String? _viewportAnchorStableKey;
  double _viewportAnchorLocalOffset = 0;
  int? _viewportColumnCount;
  double? _viewportItemWidth;
  bool _viewportUnavailable = false;
  bool _viewportRestoreRequested = false;
  late final TimingsCallback _frameTimingsCallback;
  bool _scrollTraceActive = false;
  int _scrollTraceSequence = 0;
  final Stopwatch _scrollTraceElapsed = Stopwatch();
  double _scrollTraceStartOffset = 0;
  int _scrollCallbackCount = 0;
  int _visibilityCallbackCount = 0;
  int _geometryReadCount = 0;
  int _slotBuildCount = 0;
  int _loadedSlotBuildCount = 0;
  int _pendingSlotBuildCount = 0;
  int _tileBuildCount = 0;
  int _visibilityTransitionCount = 0;
  int _visibilityDrivenRebuildCount = 0;
  int _frameCount = 0;
  int _slowBuildFrameCount = 0;
  int _slowRasterFrameCount = 0;
  int _maxScrollCallbackMicros = 0;
  int _maxVisibilityCallbackMicros = 0;
  int _maxGeometryReadMicros = 0;
  int _maxBuildMicros = 0;
  int _maxRasterMicros = 0;
  String? _lastGridLayoutSignature;
  String? _lastMasonrySnapshotSignature;

  void traceGridLayout({
    required BoxConstraints constraints,
    required int columnCount,
    required double itemWidth,
    required int postCount,
    required int placeholderCount,
    required String cacheKey,
  }) {
    if (!kDebugMode) return;
    final signature = <Object>[
      constraints.maxWidth.toStringAsFixed(1),
      constraints.maxHeight.toStringAsFixed(1),
      columnCount,
      itemWidth.toStringAsFixed(1),
      postCount,
      placeholderCount,
      cacheKey,
    ].join('|');
    if (_lastGridLayoutSignature == signature) return;
    _lastGridLayoutSignature = signature;
    AppLogger.d(
      'layout width=${constraints.maxWidth.toStringAsFixed(1)} '
          'height=${constraints.maxHeight.toStringAsFixed(1)} '
          'columns=$columnCount itemWidth=${itemWidth.toStringAsFixed(1)} '
          'posts=$postCount placeholders=$placeholderCount '
          'cache=${cacheKey.hashCode}',
      'GalleryPerf',
    );
  }

  void traceMasonrySnapshot({
    required int childCount,
    required double maxScrollExtent,
    required Duration elapsed,
  }) {
    if (!kDebugMode) return;
    final signature = '$childCount|${maxScrollExtent.toStringAsFixed(1)}';
    if (_lastMasonrySnapshotSignature == signature) return;
    _lastMasonrySnapshotSignature = signature;
    AppLogger.d(
      'masonrySnapshot children=$childCount '
          'extent=${maxScrollExtent.toStringAsFixed(1)} '
          'computeMs=${_milliseconds(elapsed.inMicroseconds)}',
      'GalleryPerf',
    );
  }

  void beginScrollTrace(ScrollMetrics metrics) {
    if (!kDebugMode || _scrollTraceActive) return;
    _scrollTraceActive = true;
    _scrollTraceSequence++;
    _scrollTraceStartOffset = metrics.pixels;
    _scrollCallbackCount = 0;
    _visibilityCallbackCount = 0;
    _geometryReadCount = 0;
    _slotBuildCount = 0;
    _loadedSlotBuildCount = 0;
    _pendingSlotBuildCount = 0;
    _tileBuildCount = 0;
    _visibilityTransitionCount = 0;
    _visibilityDrivenRebuildCount = 0;
    _frameCount = 0;
    _slowBuildFrameCount = 0;
    _slowRasterFrameCount = 0;
    _maxScrollCallbackMicros = 0;
    _maxVisibilityCallbackMicros = 0;
    _maxGeometryReadMicros = 0;
    _maxBuildMicros = 0;
    _maxRasterMicros = 0;
    _scrollTraceElapsed
      ..reset()
      ..start();
  }

  void recordScrollCallback(Duration elapsed) {
    if (!_scrollTraceActive) return;
    _scrollCallbackCount++;
    _maxScrollCallbackMicros = _max(
      _maxScrollCallbackMicros,
      elapsed.inMicroseconds,
    );
  }

  void recordVisibilityCallback(Duration elapsed) {
    if (!_scrollTraceActive) return;
    _visibilityCallbackCount++;
    _maxVisibilityCallbackMicros = _max(
      _maxVisibilityCallbackMicros,
      elapsed.inMicroseconds,
    );
  }

  void recordGeometryRead(Duration elapsed) {
    if (!_scrollTraceActive) return;
    _geometryReadCount++;
    _maxGeometryReadMicros = _max(
      _maxGeometryReadMicros,
      elapsed.inMicroseconds,
    );
  }

  void recordGridSlotBuild({required bool pending}) {
    if (!_scrollTraceActive) return;
    _slotBuildCount++;
    if (pending) {
      _pendingSlotBuildCount++;
    } else {
      _loadedSlotBuildCount++;
    }
  }

  void recordTileBuild() {
    if (_scrollTraceActive) _tileBuildCount++;
  }

  void recordVisibilityTransition() {
    if (_scrollTraceActive) _visibilityTransitionCount++;
  }

  void recordVisibilityDrivenRebuild() {
    if (_scrollTraceActive) _visibilityDrivenRebuildCount++;
  }

  void finishScrollTrace({
    required ScrollMetrics metrics,
    required int visibleCount,
    required int prefetchQueueDepth,
    required int prefetchActiveCount,
  }) {
    if (!kDebugMode || !_scrollTraceActive) return;
    _scrollTraceElapsed.stop();
    _scrollTraceActive = false;
    AppLogger.i(
      'scroll#$_scrollTraceSequence '
          'elapsedMs=${_scrollTraceElapsed.elapsedMilliseconds} '
          'offset=${_scrollTraceStartOffset.toStringAsFixed(1)}->'
          '${metrics.pixels.toStringAsFixed(1)} '
          'viewport=${metrics.viewportDimension.toStringAsFixed(1)} '
          'maxExtent=${metrics.maxScrollExtent.toStringAsFixed(1)} '
          'events=$_scrollCallbackCount '
          'maxScrollCallbackMs=${_milliseconds(_maxScrollCallbackMicros)} '
          'visibility=$_visibilityCallbackCount '
          'maxVisibilityMs=${_milliseconds(_maxVisibilityCallbackMicros)} '
          'geometryReads=$_geometryReadCount '
          'maxGeometryMs=${_milliseconds(_maxGeometryReadMicros)} '
          'slotBuilds=$_slotBuildCount loadedSlots=$_loadedSlotBuildCount '
          'pendingSlots=$_pendingSlotBuildCount tileBuilds=$_tileBuildCount '
          'visibilityTransitions=$_visibilityTransitionCount '
          'visibilityRebuilds=$_visibilityDrivenRebuildCount '
          'frames=$_frameCount slowBuild=$_slowBuildFrameCount '
          'slowRaster=$_slowRasterFrameCount '
          'maxBuildMs=${_milliseconds(_maxBuildMicros)} '
          'maxRasterMs=${_milliseconds(_maxRasterMicros)} '
          'visible=$visibleCount queue=$prefetchQueueDepth '
          'active=$prefetchActiveCount',
      'GalleryPerf',
    );
  }

  void _recordFrameTimings(List<FrameTiming> timings) {
    if (!_scrollTraceActive) return;
    for (final timing in timings) {
      final buildMicros = timing.buildDuration.inMicroseconds;
      final rasterMicros = timing.rasterDuration.inMicroseconds;
      _frameCount++;
      if (buildMicros > 16667) _slowBuildFrameCount++;
      if (rasterMicros > 16667) _slowRasterFrameCount++;
      _maxBuildMicros = _max(_maxBuildMicros, buildMicros);
      _maxRasterMicros = _max(_maxRasterMicros, rasterMicros);
    }
  }

  int _max(int left, int right) => left >= right ? left : right;

  String _milliseconds(int microseconds) =>
      (microseconds / 1000).toStringAsFixed(2);

  void synchronizeQueries(OnlineGalleryState state) {
    _setText(searchController, state.searchQuery);
    _setText(promptSearchController, state.promptQuery);
    _setText(popularSearchController, state.popularQuery);
    _setText(popularPromptSearchController, state.popularPromptQuery);
    _setText(favoriteSearchController, state.favoriteSearchQuery);
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text != value) controller.text = value;
  }

  void setScrolling(bool value) => viewportTracker.setScrolling(value);

  int get viewportGeneration => viewportTracker.generation;

  void resetViewportTracking() => viewportTracker.resetVisibleItems();

  int beginScrollRestore() => ++_scrollRestoreRevision;
  void invalidateScrollRestore() {
    _scrollRestoreRevision++;
    _viewportRestoreRequested = false;
    scrollController.clearLayoutRestore();
  }

  bool isCurrentScrollRestore(int revision) =>
      revision == _scrollRestoreRevision;

  void stageViewportRestore({required String scope, required ModeCache cache}) {
    beginScrollRestore();
    _viewportScope = scope;
    _viewportOffset.replace(cache.scrollOffset);
    _viewportAnchorStableKey = cache.anchorStableKey;
    _viewportAnchorLocalOffset = cache.anchorLocalOffset;
    _viewportRestoreRequested = true;
  }

  bool get viewportAvailable => !_viewportUnavailable;

  void markViewportUnavailable({
    required String scope,
    required List<GalleryItem> posts,
  }) {
    if (_viewportUnavailable) return;
    if (!_viewportRestoreRequested && _viewportScope == scope) {
      captureViewport(scope: scope, posts: posts);
    }
    _viewportUnavailable = true;
    idlePrefetchTimer?.cancel();
    scrollStopTimer?.cancel();
    prefetchResumeTimer?.cancel();
    paginationDemand.settleScroll();
    setScrolling(false);
    hoverController.dismiss();
    prefetchCoordinator.setPageVisible(false);
  }

  void captureViewport({
    required String scope,
    required List<GalleryItem> posts,
  }) {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (!OwnedViewportOffset.hasUsableViewport(position)) return;
    _viewportScope = scope;
    _viewportOffset.record(position);
    final anchor = viewportTracker.resolveLeadingAnchor(
      posts: posts,
      metrics: position,
    );
    if (anchor == null) return;
    _viewportAnchorStableKey = anchor.item.stableKey;
    _viewportAnchorLocalOffset = position.pixels - anchor.leadingScrollOffset;
  }

  void prepareGridViewport({
    required String scope,
    required ModeCache cache,
    required List<GalleryItem> posts,
    required OnlineGalleryMasonryLayoutSnapshot layout,
    required int columnCount,
    required double itemWidth,
  }) {
    final scopeChanged = _viewportScope != scope;
    if (scopeChanged) {
      _viewportScope = scope;
      _viewportOffset.replace(cache.scrollOffset);
      _viewportAnchorStableKey = cache.anchorStableKey;
      _viewportAnchorLocalOffset = cache.anchorLocalOffset;
    }
    final geometryChanged =
        _viewportColumnCount != null &&
        (_viewportColumnCount != columnCount ||
            (_viewportItemWidth! - itemWidth).abs() >= 0.5);
    if (geometryChanged && !scopeChanged) {
      captureViewport(scope: scope, posts: posts);
    }
    final shouldRestore =
        scopeChanged ||
        geometryChanged ||
        _viewportUnavailable ||
        _viewportRestoreRequested;
    _viewportColumnCount = columnCount;
    _viewportItemWidth = itemWidth;
    _viewportUnavailable = false;
    prefetchCoordinator.setPageVisible(branchVisible);
    _viewportRestoreRequested = false;
    if (!shouldRestore) return;

    var target = _viewportOffset.pixels;
    final stableKey = _viewportAnchorStableKey;
    if (stableKey != null) {
      final index = viewportTracker.indexOfStableKey(posts, stableKey);
      if (index != null && index < layout.childCount) {
        target =
            12 +
            layout.placementFor(index).scrollOffset +
            _viewportAnchorLocalOffset;
      }
    }
    scrollController.restoreDuringLayout(target);
  }

  bool updateLookaheadMetrics({
    required double viewportHeight,
    required double itemWidth,
    required int columnCount,
  }) {
    if (_lookaheadViewportHeight == viewportHeight &&
        _lookaheadItemWidth == itemWidth &&
        _lookaheadColumnCount == columnCount) {
      return false;
    }
    _lookaheadViewportHeight = viewportHeight;
    _lookaheadItemWidth = itemWidth;
    _lookaheadColumnCount = columnCount;
    return true;
  }

  void beginPageEditing(int currentPage) {
    AppLogger.d('pageEdit begin current=$currentPage', 'GalleryPerf');
    isEditingPage = true;
    pageController.text = currentPage.toString();
    pageController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: pageController.text.length,
    );
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pageFocusNode.requestFocus();
    });
  }

  int? finishPageEditing() {
    final raw = pageController.text.trim();
    final parsed = int.tryParse(raw);
    AppLogger.d('pageEdit submit raw=$raw parsed=$parsed', 'GalleryPerf');
    isEditingPage = false;
    notifyListeners();
    return parsed != null && parsed >= 1 ? parsed : null;
  }

  void cancelPageEditingWhenUnfocused() {
    if (pageFocusNode.hasFocus || !isEditingPage) return;
    // Focus changes can occur while a route is being finalized. Deferring the
    // notification avoids rebuilding pagination during the focus dispatch.
    _pageFocusNotificationTimer?.cancel();
    _pageFocusNotificationTimer = Timer(Duration.zero, () {
      if (pageFocusNode.hasFocus || !isEditingPage) return;
      isEditingPage = false;
      notifyListeners();
    });
  }

  void scheduleCardReveal(VoidCallback reveal) {
    if (_disposed) return;
    _cardRevealQueue.addLast(reveal);
    _scheduleCardRevealFrame();
  }

  void _scheduleCardRevealFrame() {
    if (_cardRevealScheduled || _cardRevealQueue.isEmpty || _disposed) return;
    _cardRevealScheduled = true;
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _cardRevealScheduled = false;
      if (_disposed) return;
      for (var index = 0; index < 2 && _cardRevealQueue.isNotEmpty; index++) {
        _cardRevealQueue.removeFirst()();
      }
      if (_cardRevealQueue.isNotEmpty) {
        SchedulerBinding.instance.scheduleFrame();
        _scheduleCardRevealFrame();
      }
    });
  }

  void cancelTimers() {
    searchDebounceTimer?.cancel();
    scrollStopTimer?.cancel();
    prefetchResumeTimer?.cancel();
    idlePrefetchTimer?.cancel();
    _pageFocusNotificationTimer?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _cardRevealQueue.clear();
    if (kDebugMode) {
      SchedulerBinding.instance.removeTimingsCallback(_frameTimingsCallback);
    }
    cancelTimers();
    dateRangeOverlayEntry?.remove();
    dateRangeOverlayEntry = null;
    hoverController.dispose();
    prefetchCoordinator.dispose();
    searchController.dispose();
    promptSearchController.dispose();
    popularSearchController.dispose();
    popularPromptSearchController.dispose();
    favoriteSearchController.dispose();
    searchFocusNode.dispose();
    promptSearchFocusNode.dispose();
    popularSearchFocusNode.dispose();
    popularPromptSearchFocusNode.dispose();
    favoriteSearchFocusNode.dispose();
    scrollController.dispose();
    pageController.dispose();
    pageFocusNode.dispose();
    viewportTracker.dispose();
    _pageAnchorKeys.clear();
    super.dispose();
  }
}
