import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../../core/cache/online_gallery_preload_policy.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../providers/online_gallery_provider.dart';
import 'online_gallery_masonry_layout.dart';
import 'online_gallery_screen_controller.dart';
import 'online_gallery_utils.dart';
import 'online_gallery_viewport_tracker.dart';

/// Coordinates scroll restoration, pagination and image/detail prefetching.
/// All scheduling starts from lifecycle, scroll, or visibility events; build is
/// deliberately side-effect free.
class OnlineGalleryScrollPrefetchCoordinator {
  static const scrollIdleDelay = Duration(milliseconds: 150);
  static const prefetchResumeDelay = Duration(milliseconds: 500);

  OnlineGalleryScrollPrefetchCoordinator({
    required this.context,
    required this.ref,
    required this.controller,
    required this.notifier,
  });

  final BuildContext context;
  final WidgetRef ref;
  final OnlineGalleryScreenController controller;
  final OnlineGalleryNotifier notifier;
  bool _visiblePageUpdateScheduled = false;
  bool _pageJumpInProgress = false;
  int _visiblePageUpdateRevision = 0;

  OnlineGalleryState readState() => ref.read(onlineGalleryNotifierProvider);
  bool isMounted() => context.mounted;
  GalleryImageRequest imageRequest(
    GalleryItem item,
    String url,
    GalleryImageTier tier,
    double logicalWidth,
  ) => createGalleryImageRequest(
    context: context,
    item: item,
    url: url,
    tier: tier,
    logicalWidth: logicalWidth,
  );

  bool isWithinLoadAhead(ScrollMetrics metrics) {
    final itemWidth = controller.currentItemWidth;
    final columnCount = controller.currentColumnCount;
    final reservedPlaceholderExtent = itemWidth == null || columnCount == null
        ? 0.0
        : controller.paginationDemand.placeholderExtent(
            viewportDimension: metrics.viewportDimension,
            itemWidth: itemWidth,
            columnCount: columnCount,
            spacing: 6,
            pageSize: onlineGalleryPageSize,
          );
    return controller.paginationDemand.isWithinDemandWindow(
      metrics,
      reservedPlaceholderExtent: reservedPlaceholderExtent,
    );
  }

  String _paginationScope(OnlineGalleryState state) => state.randomEnabled
      ? 'random:${state.randomSession.scopeKey}'
      : state.currentCacheKey;

  (String, String?, int, bool, bool, int) _paginationProgress(
    OnlineGalleryState state,
  ) {
    final cache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    return (
      _paginationScope(state),
      cache.nextCursor,
      cache.posts.length,
      cache.hasMore,
      cache.queryScanPaused,
      state.randomSession.drawRevision,
    );
  }

  void onScroll() {
    if (!controller.branchVisible) return;
    final callbackStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final offset = controller.scrollController.offset;
    if (offset != controller.lastScrollOffset) {
      controller.paginationDemand.recordScroll(offset);
      final startedScrolling = !controller.isScrolling;
      final startedPrefetchPause =
          !controller.prefetchCoordinator.isScrollingPaused;
      controller.scrollDirection = offset >= controller.lastScrollOffset
          ? 1
          : -1;
      controller.lastScrollOffset = offset;
      controller.setScrolling(true);
      if (startedScrolling) {
        controller.beginScrollTrace(controller.scrollController.position);
        controller.hoverController.dismiss();
      }
      if (startedPrefetchPause) {
        controller.prefetchCoordinator.setScrolling(true);
        _retainVisibleThumbnailWindow();
        notifier.cancelLookaheadDetailRequests();
      }
      controller.scrollStopTimer?.cancel();
      controller.scrollStopTimer = Timer(scrollIdleDelay, () {
        if (!isMounted() || !controller.branchVisible) return;
        controller.paginationDemand.settleScroll();
        controller.setScrolling(false);
        _scheduleVisiblePageUpdate();
      });
      controller.prefetchResumeTimer?.cancel();
      controller.prefetchResumeTimer = Timer(prefetchResumeDelay, () {
        if (!isMounted() || !controller.branchVisible) return;
        controller.prefetchCoordinator.setScrolling(false);
        scheduleVisiblePrefetch();
        if (controller.scrollController.hasClients) {
          controller.finishScrollTrace(
            metrics: controller.scrollController.position,
            visibleCount: controller.viewportTracker.visibleItemCount,
            prefetchQueueDepth: controller.prefetchCoordinator.queueDepth,
            prefetchActiveCount: controller.prefetchCoordinator.activeCount,
          );
        }
      });
    }
    _requestNextIfNeeded();
    if (callbackStopwatch != null) {
      callbackStopwatch.stop();
      controller.recordScrollCallback(callbackStopwatch.elapsed);
    }
  }

  void scheduleAutoLoadIfUnderfilled(OnlineGalleryState state) {
    if (!controller.branchVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted() && controller.branchVisible) _requestNextIfNeeded();
    });
  }

  bool _isNearLoadedEdge(OnlineGalleryState state) {
    if (state.posts.isEmpty || controller.scrollDirection < 0) return false;
    final visible = controller.viewportTracker.resolveVisibleItems(state.posts);
    if (visible.isEmpty) return false;
    final remaining = state.posts.length - 1 - visible.last.index;
    final itemThreshold = controller.lookaheadItemCount > onlineGalleryPageSize
        ? controller.lookaheadItemCount
        : onlineGalleryPageSize;
    return remaining <= itemThreshold;
  }

  void _requestNextIfNeeded() {
    if (!isMounted() || !controller.branchVisible) return;
    final state = readState();
    final cache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    final position = controller.scrollController.hasClients
        ? controller.scrollController.position
        : null;
    final needsMore =
        state.posts.isEmpty ||
        _isNearLoadedEdge(state) ||
        (position != null && isWithinLoadAhead(position));
    if (!needsMore ||
        state.hasError ||
        !state.hasMore ||
        cache.queryScanPaused ||
        cache.appendErrorCode != null) {
      return;
    }
    if (state.isLoading ||
        state.isLoadingMore ||
        controller.paginationDemand.requestInFlight) {
      controller.paginationDemand.queueDemand();
      return;
    }
    final scope = _paginationScope(state);
    final requestToken = controller.paginationDemand.beginRequest(
      scopeKey: scope,
      cursor: cache.nextCursor,
      viewportDimension:
          position?.viewportDimension ?? MediaQuery.sizeOf(context).height,
    );
    if (requestToken == null) return;
    if (kDebugMode) {
      AppLogger.d(
        'pagination start token=$requestToken posts=${state.posts.length} '
            'cursor=${cache.nextCursor} offset=${position?.pixels.toStringAsFixed(1)} '
            'extentAfter=${position?.extentAfter.toStringAsFixed(1)} '
            'viewport=${position?.viewportDimension.toStringAsFixed(1)}',
        'GalleryPerf',
      );
    }
    unawaited(_loadNextForDemand(scope, requestToken));
  }

  Future<void> _loadNextForDemand(String scope, int requestToken) async {
    final progressBefore = _paginationProgress(readState());
    try {
      await notifier.loadMore();
    } finally {
      final completion = controller.paginationDemand.completeRequest(
        requestToken,
      );
      final progressed =
          isMounted() && _paginationProgress(readState()) != progressBefore;
      if (kDebugMode) {
        final state = isMounted() ? readState() : null;
        AppLogger.d(
          'pagination complete token=$requestToken accepted=${completion.accepted} '
              'progressed=$progressed queued=${completion.hadQueuedDemand} '
              'posts=${state?.posts.length} loadingMore=${state?.isLoadingMore}',
          'GalleryPerf',
        );
      }
      if (completion.accepted && progressed && controller.branchVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isMounted() || _paginationScope(readState()) != scope) return;
          if (completion.hadQueuedDemand ||
              controller.scrollController.hasClients ||
              readState().posts.isEmpty) {
            _requestNextIfNeeded();
          }
        });
      }
    }
  }

  void saveScrollOffset() {
    if (!controller.scrollController.hasClients) return;
    final state = readState();
    final position = controller.scrollController.position;
    final anchor = controller.viewportTracker.resolveLeadingAnchor(
      posts: state.posts,
      metrics: position,
    );
    notifier.saveScrollOffset(
      position.pixels,
      anchorStableKey: anchor?.item.stableKey,
      anchorLocalOffset: anchor == null
          ? 0
          : position.pixels - anchor.leadingScrollOffset,
    );
  }

  void restoreScrollOffset(ModeCache cache) {
    final revision = controller.beginScrollRestore();
    final scope = _paginationScope(readState());
    final anchorStableKey = cache.anchorStableKey;
    final anchorLocalOffset = cache.anchorLocalOffset;
    controller.pendingAnchorStableKey = anchorStableKey;
    controller.pendingAnchorLocalOffset = anchorLocalOffset;

    bool isCurrent() =>
        isMounted() &&
        controller.isCurrentScrollRestore(revision) &&
        _paginationScope(readState()) == scope;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isCurrent() || !controller.scrollController.hasClients) return;
      final position = controller.scrollController.position;
      controller.scrollController.jumpTo(
        cache.scrollOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!isCurrent() ||
            controller.pendingAnchorStableKey != anchorStableKey) {
          return;
        }
        final anchorContext = controller.anchorRestoreKey.currentContext;
        if (anchorContext == null) return;
        await Scrollable.ensureVisible(anchorContext, duration: Duration.zero);
        if (!isCurrent() || !controller.scrollController.hasClients) return;
        final current = controller.scrollController.offset;
        controller.scrollController.jumpTo(
          (current + anchorLocalOffset).clamp(
            controller.scrollController.position.minScrollExtent,
            controller.scrollController.position.maxScrollExtent,
          ),
        );
      });
    });
  }

  void beginPageJump() {
    controller.invalidateScrollRestore();
    _pageJumpInProgress = true;
    _visiblePageUpdateRevision++;
    controller.resetViewportTracking();
  }

  void endPageJump() {
    final wasInProgress = _pageJumpInProgress;
    _pageJumpInProgress = false;
    _visiblePageUpdateRevision++;
    if (wasInProgress) {
      _scheduleVisiblePageUpdate();
      if (controller.viewportTracker.hasVisibleItems) scheduleVisiblePrefetch();
    }
  }

  Future<void> jumpToPageTarget(
    GalleryPageJumpTarget target, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent() || !controller.scrollController.hasClients) return;
    final state = readState();
    final cache = state.currentCache;
    if (target.itemIndex >= cache.posts.length ||
        cache.posts[target.itemIndex].stableKey != target.stableKey) {
      return;
    }

    final viewportWidth =
        context.size?.width ?? MediaQuery.sizeOf(context).width;
    const horizontalPadding = 24.0;
    const spacing = 6.0;
    final availableWidth = (viewportWidth - horizontalPadding).clamp(
      0.0,
      double.infinity,
    );
    final columnCount =
        controller.currentColumnCount ??
        ((availableWidth + spacing) / (160 + spacing)).floor().clamp(1, 8);
    final itemWidth =
        controller.currentItemWidth ??
        (availableWidth - (columnCount - 1) * spacing) / columnCount;
    final estimateStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final masonryLayout = OnlineGalleryMasonryLayoutSnapshot(
      aspectRatios: [
        for (final item in cache.posts)
          item.width > 0 && item.height > 0 ? item.width / item.height : 1.0,
      ],
      placeholderCount: 0,
      columnCount: columnCount,
      itemWidth: itemWidth,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
    );
    final estimatedOffset =
        12 + masonryLayout.placementFor(target.itemIndex).scrollOffset;
    estimateStopwatch?.stop();
    final position = controller.scrollController.position;
    final clampedOffset = estimatedOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (kDebugMode) {
      AppLogger.i(
        'pageJump estimate targetIndex=${target.itemIndex} '
            'columns=$columnCount itemWidth=${itemWidth.toStringAsFixed(1)} '
            'estimateMs=${estimateStopwatch?.elapsedMicroseconds == null ? null : (estimateStopwatch!.elapsedMicroseconds / 1000).toStringAsFixed(2)} '
            'requestedOffset=${estimatedOffset.toStringAsFixed(1)} '
            'clampedOffset=${clampedOffset.toStringAsFixed(1)} '
            'maxExtent=${position.maxScrollExtent.toStringAsFixed(1)}',
        'GalleryPerf',
      );
    }
    controller.scrollController.jumpTo(clampedOffset);

    final layoutStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    await WidgetsBinding.instance.endOfFrame;
    layoutStopwatch?.stop();
    if (!isMounted() || !isCurrent()) return;
    final latestCache = readState().currentCache;
    if (target.itemIndex >= latestCache.posts.length ||
        latestCache.posts[target.itemIndex].stableKey != target.stableKey) {
      return;
    }
    final anchorContext = controller
        .pageAnchorKey(target.stableKey)
        .currentContext;
    if (anchorContext == null || !anchorContext.mounted || !isCurrent()) {
      if (kDebugMode) {
        AppLogger.w(
          'pageJump anchor missing targetIndex=${target.itemIndex} '
              'frameMs=${layoutStopwatch?.elapsedMilliseconds}',
          'GalleryPerf',
        );
      }
      return;
    }
    final ensureStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    await Scrollable.ensureVisible(
      anchorContext,
      alignment: 0,
      duration: Duration.zero,
    );
    ensureStopwatch?.stop();
    if (kDebugMode) {
      AppLogger.i(
        'pageJump anchor targetIndex=${target.itemIndex} '
            'frameMs=${layoutStopwatch?.elapsedMilliseconds} '
            'ensureMs=${ensureStopwatch?.elapsedMilliseconds} '
            'finalOffset=${controller.scrollController.offset.toStringAsFixed(1)}',
        'GalleryPerf',
      );
    }
  }

  void handleCardVisibility(OnlineGalleryViewportVisibilityEvent event) {
    if (!isMounted() || !controller.branchVisible) return;
    final callbackStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    try {
      _handleCardVisibility(event);
    } finally {
      if (callbackStopwatch != null) {
        callbackStopwatch.stop();
        controller.recordVisibilityCallback(callbackStopwatch.elapsed);
      }
    }
  }

  void _handleCardVisibility(OnlineGalleryViewportVisibilityEvent event) {
    final item = event.item;
    if (!event.visible) {
      final removed = controller.viewportTracker.removeVisibleItem(
        item,
        viewportGeneration: event.viewportGeneration,
        tokenSequence: event.tokenSequence,
      );
      final request = removed?.thumbnailRequest;
      if (request != null) {
        controller.prefetchCoordinator.cancelPending(request);
      }
      _scheduleVisiblePageUpdate();
      return;
    }
    final thumbnailRequest = !item.mediaCapability.canPrefetchPreview
        ? null
        : imageRequest(
            item,
            item.previewUrl,
            GalleryImageTier.thumbnail,
            event.itemWidth,
          );
    final enteredViewport = controller.viewportTracker.recordVisibleItem(
      index: event.index,
      item: item,
      itemWidth: event.itemWidth,
      leadingScrollOffset: event.leadingScrollOffset,
      viewportGeneration: event.viewportGeneration,
      tokenSequence: event.tokenSequence,
      thumbnailRequest: thumbnailRequest,
    );
    _scheduleVisiblePageUpdate();
    _requestNextIfNeeded();
    if (controller.scrollController.hasClients) {
      final position = controller.scrollController.position;
      if (controller.updateLookaheadMetrics(
        viewportHeight: position.viewportDimension,
        itemWidth: event.itemWidth,
        columnCount: event.columnCount,
      )) {
        controller.lookaheadItemCount =
            OnlineGalleryPreloadPolicy.lookaheadItemCount(
              viewportHeight: position.viewportDimension,
              itemWidth: event.itemWidth,
              columnCount: event.columnCount,
            );
      }
    }
    if (!enteredViewport) return;
    if (!controller.isScrolling) {
      controller.idlePrefetchTimer?.cancel();
      controller.idlePrefetchTimer = Timer(
        const Duration(milliseconds: 150),
        () {
          if (isMounted() &&
              controller.branchVisible &&
              !controller.isScrolling) {
            scheduleVisiblePrefetch();
          }
        },
      );
    }
  }

  void _scheduleVisiblePageUpdate() {
    if (_visiblePageUpdateScheduled ||
        _pageJumpInProgress ||
        controller.isScrolling ||
        !controller.scrollController.hasClients) {
      return;
    }
    _visiblePageUpdateScheduled = true;
    final revision = _visiblePageUpdateRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visiblePageUpdateScheduled = false;
      if (!isMounted() ||
          _pageJumpInProgress ||
          controller.isScrolling ||
          revision != _visiblePageUpdateRevision ||
          !controller.scrollController.hasClients) {
        return;
      }
      final state = readState();
      if (state.randomEnabled) return;
      final anchor = controller.viewportTracker.resolveLeadingAnchor(
        posts: state.posts,
        metrics: controller.scrollController.position,
      );
      if (anchor == null) return;
      final visiblePage = state.currentCache.pageForItemIndex(anchor.index);
      if (kDebugMode && visiblePage != null && visiblePage != state.page) {
        AppLogger.d(
          'visiblePage ${state.page}->$visiblePage index=${anchor.index} '
              'offset=${controller.scrollController.offset.toStringAsFixed(1)} '
              'leading=${anchor.leadingScrollOffset.toStringAsFixed(1)}',
          'GalleryPerf',
        );
      }
      notifier.updateVisibleItemIndex(
        anchor.index,
        expectedStableKey: anchor.item.stableKey,
      );
    });
  }

  void scheduleVisiblePrefetch() {
    if (!controller.viewportTracker.hasVisibleItems ||
        !controller.branchVisible) {
      return;
    }
    final state = readState();
    final visible = controller.viewportTracker.resolveVisibleItems(state.posts);
    if (visible.isEmpty) return;
    final itemWidth = visible.first.itemWidth;
    final edge = controller.scrollDirection >= 0
        ? visible.last.index
        : visible.first.index;
    final thumbnailWindow = <String>{};
    var thumbnailCount = 0;
    var sampleCount = 0;
    for (final entry in visible) {
      final request = entry.thumbnailRequest;
      if (request != null) {
        thumbnailWindow.add(
          controller.prefetchCoordinator.retentionKeyFor(request),
        );
      }
    }
    var detailCount = 0;
    for (var step = 1; step <= controller.lookaheadItemCount; step++) {
      final index = edge + step * controller.scrollDirection;
      if (index < 0 || index >= state.posts.length) continue;
      final item = state.posts[index];
      if (item.mediaCapability.canPrefetchPreview) {
        final request = imageRequest(
          item,
          item.previewUrl,
          GalleryImageTier.thumbnail,
          itemWidth,
        );
        thumbnailWindow.add(
          controller.prefetchCoordinator.retentionKeyFor(request),
        );
        thumbnailCount++;
        unawaited(
          controller.prefetchCoordinator.submit(
            request,
            priority: GalleryImagePriority.lookahead,
          ),
        );
      } else if (item.sourceId == GallerySourceId.aiTag && detailCount < 4) {
        detailCount++;
        unawaited(
          notifier
              .loadDetail(item, priority: GalleryDetailPriority.lookahead)
              .then<void>((_) {})
              .catchError((_) {}),
        );
      }
    }
    for (final entry in visible.take(12)) {
      final item = entry.item;
      if (item.isVideo ||
          item.isAnimated ||
          !item.mediaCapability.isFlutterImage ||
          item.sourceId == GallerySourceId.aiTag) {
        continue;
      }
      final sampleUrl = item.sampleUrl ?? item.largeFileUrl;
      if (sampleUrl == null ||
          sampleUrl.isEmpty ||
          sampleUrl == item.previewUrl) {
        continue;
      }
      sampleCount++;
      unawaited(
        controller.prefetchCoordinator.submit(
          imageRequest(
            item,
            sampleUrl,
            GalleryImageTier.sample,
            entry.itemWidth,
          ),
          priority: GalleryImagePriority.lookahead,
        ),
      );
    }
    controller.prefetchCoordinator.retainThumbnailWindow(thumbnailWindow);
    if (kDebugMode) {
      AppLogger.d(
        'prefetch visible=${visible.length} edge=$edge '
            'direction=${controller.scrollDirection} '
            'lookahead=${controller.lookaheadItemCount} '
            'thumbnails=$thumbnailCount samples=$sampleCount details=$detailCount '
            'retained=${thumbnailWindow.length} '
            'queue=${controller.prefetchCoordinator.queueDepth} '
            'active=${controller.prefetchCoordinator.activeCount}',
        'GalleryPerf',
      );
    }
  }

  void _retainVisibleThumbnailWindow() {
    final state = readState();
    final keys = <String>{};
    for (final entry in controller.viewportTracker.resolveVisibleItems(
      state.posts,
    )) {
      final request = entry.thumbnailRequest;
      if (request != null) {
        keys.add(controller.prefetchCoordinator.retentionKeyFor(request));
      }
    }
    controller.prefetchCoordinator.retainThumbnailWindow(keys);
  }
}
