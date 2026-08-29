import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_detail_coordinator.dart';
import '../../../core/cache/online_gallery_preload_policy.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';
import '../../providers/online_gallery_provider.dart';
import 'online_gallery_screen_controller.dart';
import 'online_gallery_utils.dart';

/// Coordinates scroll restoration, pagination and image/detail prefetching.
/// All scheduling starts from lifecycle, scroll, or visibility events; build is
/// deliberately side-effect free.
class OnlineGalleryScrollPrefetchCoordinator {
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

  bool isWithinLoadAhead(ScrollMetrics metrics) =>
      metrics.extentAfter <=
      OnlineGalleryPreloadPolicy.loadAheadDistance(metrics.viewportDimension);

  Future<bool> prepareVisibleMedia(GalleryItem item, double itemWidth) {
    if (!item.mediaCapability.canPrefetchPreview) {
      return Future<bool>.value(true);
    }
    return controller.prefetchCoordinator.submit(
      imageRequest(
        item,
        item.previewUrl,
        GalleryImageTier.thumbnail,
        itemWidth,
      ),
      priority: GalleryImagePriority.visible,
    );
  }

  void onScroll() {
    controller.hoverController.dismiss();
    if (!controller.branchVisible) return;
    final offset = controller.scrollController.offset;
    if (offset != controller.lastScrollOffset) {
      final startedScrolling = !controller.isScrolling;
      controller.scrollDirection = offset >= controller.lastScrollOffset
          ? 1
          : -1;
      controller.lastScrollOffset = offset;
      controller.setScrolling(true);
      controller.prefetchCoordinator.setScrolling(true);
      if (startedScrolling) _retainVisibleThumbnailWindow();
      notifier.cancelLookaheadDetailRequests();
      controller.scrollStopTimer?.cancel();
      controller.scrollStopTimer = Timer(const Duration(milliseconds: 150), () {
        if (!isMounted() || !controller.branchVisible) return;
        controller.setScrolling(false);
        controller.prefetchCoordinator.setScrolling(false);
        saveScrollOffset();
        scheduleVisiblePrefetch();
      });
    }
    final state = readState();
    final cache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    if (!cache.queryScanPaused &&
        isWithinLoadAhead(controller.scrollController.position)) {
      unawaited(notifier.loadMore());
    }
  }

  void scheduleAutoLoadIfUnderfilled(OnlineGalleryState state) {
    final cache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    if (!controller.branchVisible ||
        state.isLoading ||
        state.isLoadingMore ||
        state.hasError ||
        !state.hasMore ||
        cache.queryScanPaused ||
        cache.appendErrorCode != null ||
        controller.scheduledAutoLoadCacheKey == state.currentCacheKey) {
      return;
    }
    final cacheKey = state.currentCacheKey;
    controller.scheduledAutoLoadCacheKey = cacheKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted() || !controller.branchVisible) return;
      if (controller.scheduledAutoLoadCacheKey == cacheKey) {
        controller.scheduledAutoLoadCacheKey = null;
      }
      final latest = readState();
      final latestCache = latest.randomEnabled
          ? latest.randomSession.cache
          : latest.currentCache;
      if (latest.currentCacheKey != cacheKey ||
          latest.isLoading ||
          latest.isLoadingMore ||
          latest.hasError ||
          !latest.hasMore ||
          latestCache.queryScanPaused ||
          latestCache.appendErrorCode != null) {
        return;
      }
      final needsMore =
          latest.posts.isEmpty ||
          (controller.scrollController.hasClients &&
              isWithinLoadAhead(controller.scrollController.position));
      if (needsMore) unawaited(notifier.loadMore());
    });
  }

  void saveScrollOffset() {
    if (!controller.scrollController.hasClients) return;
    final visible = controller.visibleItems.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final anchor = visible.isEmpty ? null : visible.first.value;
    notifier.saveScrollOffset(
      controller.scrollController.offset,
      anchorStableKey: anchor?.item.stableKey,
      anchorLocalOffset: anchor?.visibleTop ?? 0,
    );
  }

  void restoreScrollOffset(ModeCache cache) {
    controller.pendingAnchorStableKey = cache.anchorStableKey;
    controller.pendingAnchorLocalOffset = cache.anchorLocalOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted() || !controller.scrollController.hasClients) return;
      final position = controller.scrollController.position;
      controller.scrollController.jumpTo(
        cache.scrollOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final anchorContext = controller.anchorRestoreKey.currentContext;
        if (!isMounted() || anchorContext == null) return;
        await Scrollable.ensureVisible(anchorContext, duration: Duration.zero);
        if (!isMounted() || !controller.scrollController.hasClients) return;
        final current = controller.scrollController.offset;
        controller.scrollController.jumpTo(
          (current + controller.pendingAnchorLocalOffset).clamp(
            controller.scrollController.position.minScrollExtent,
            controller.scrollController.position.maxScrollExtent,
          ),
        );
      });
    });
  }

  void handleCardVisibility(
    int index,
    GalleryItem item,
    double itemWidth,
    int columnCount,
    bool visible,
    double visibleTop,
  ) {
    if (!isMounted() || !controller.branchVisible) return;
    if (!visible) {
      final current = controller.visibleItems[index];
      if (current?.item.stableKey == item.stableKey) {
        controller.visibleItems.remove(index);
        final request = current!.thumbnailRequest;
        if (request != null) {
          controller.prefetchCoordinator.cancelPending(request);
        }
      }
      return;
    }
    final thumbnailRequest = !item.mediaCapability.canPrefetchPreview
        ? null
        : imageRequest(
            item,
            item.previewUrl,
            GalleryImageTier.thumbnail,
            itemWidth,
          );
    final enteredViewport = controller.recordVisibleItem(
      index: index,
      item: item,
      itemWidth: itemWidth,
      visibleTop: visibleTop,
      thumbnailRequest: thumbnailRequest,
    );
    if (controller.scrollController.hasClients) {
      final position = controller.scrollController.position;
      controller.lookaheadItemCount =
          OnlineGalleryPreloadPolicy.lookaheadItemCount(
            viewportHeight: position.viewportDimension,
            itemWidth: itemWidth,
            columnCount: columnCount,
          );
    }
    // VisibilityDetector also reports position changes for cards that remain
    // visible. Keep the anchor and viewport sizing current, but do not repeat
    // image queue and idle-prefetch work until a card actually enters.
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

  void scheduleVisiblePrefetch() {
    if (controller.visibleItems.isEmpty || !controller.branchVisible) return;
    final state = readState();
    final visible = controller.visibleItems.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final itemWidth = visible.first.value.itemWidth;
    final edge = controller.scrollDirection >= 0
        ? visible.last.key
        : visible.first.key;
    final thumbnailWindow = <String>{};
    for (final entry in visible) {
      final request = entry.value.thumbnailRequest;
      if (request != null) thumbnailWindow.add(request.stableRequestKey);
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
        thumbnailWindow.add(request.stableRequestKey);
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
      final item = entry.value.item;
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
      unawaited(
        controller.prefetchCoordinator.submit(
          imageRequest(
            item,
            sampleUrl,
            GalleryImageTier.sample,
            entry.value.itemWidth,
          ),
          priority: GalleryImagePriority.lookahead,
        ),
      );
    }
    controller.prefetchCoordinator.retainThumbnailWindow(thumbnailWindow);
  }

  void _retainVisibleThumbnailWindow() {
    final keys = <String>{};
    for (final entry in controller.visibleItems.values) {
      final request = entry.thumbnailRequest;
      if (request != null) keys.add(request.stableRequestKey);
    }
    controller.prefetchCoordinator.retainThumbnailWindow(keys);
  }
}
