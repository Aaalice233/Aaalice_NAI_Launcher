import 'package:flutter/widgets.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../../data/models/online_gallery/gallery_item.dart';

@immutable
class OnlineGalleryViewportVisibilityEvent {
  const OnlineGalleryViewportVisibilityEvent({
    required this.index,
    required this.item,
    required this.itemWidth,
    required this.columnCount,
    required this.visible,
    required this.leadingScrollOffset,
    required this.viewportGeneration,
    required this.tokenSequence,
  });

  final int index;
  final GalleryItem item;
  final double itemWidth;
  final int columnCount;
  final bool visible;
  final double leadingScrollOffset;
  final int viewportGeneration;
  final int tokenSequence;
}

@immutable
class OnlineGalleryViewportItem {
  const OnlineGalleryViewportItem({
    required this.index,
    required this.item,
    required this.itemWidth,
    required this.leadingScrollOffset,
    required this.tokenSequence,
    required this.thumbnailRequest,
  });

  final int index;
  final GalleryItem item;
  final double itemWidth;
  final double leadingScrollOffset;
  final int tokenSequence;
  final GalleryImageRequest? thumbnailRequest;
}

/// Tracks viewport geometry by stable item identity.
///
/// Item indices are resolved against the latest post collection, so a sparse
/// page insertion cannot leave pagination or prefetching attached to an old
/// index. Provider pagination state never writes into this ephemeral model.
class OnlineGalleryViewportTracker {
  static const int viewedItemCapacity = 4096;

  final ValueNotifier<bool> scrolling = ValueNotifier<bool>(false);
  final Map<String, OnlineGalleryViewportItem> _visibleByStableKey = {};
  final Set<String> _viewedItemKeys = <String>{};
  int _generation = 0;

  bool get isScrolling => scrolling.value;
  int get generation => _generation;
  Set<String> get viewedItemKeys => Set.unmodifiable(_viewedItemKeys);
  bool get hasVisibleItems => _visibleByStableKey.isNotEmpty;
  int get visibleItemCount => _visibleByStableKey.length;
  bool hasViewedItem(String stableKey) => _viewedItemKeys.contains(stableKey);

  void setScrolling(bool value) {
    if (scrolling.value != value) scrolling.value = value;
  }

  bool recordVisibleItem({
    required int index,
    required GalleryItem item,
    required double itemWidth,
    required double leadingScrollOffset,
    required int viewportGeneration,
    required int tokenSequence,
    GalleryImageRequest? thumbnailRequest,
  }) {
    if (viewportGeneration != _generation) return false;
    final stableKey = item.stableKey;
    _viewedItemKeys
      ..remove(stableKey)
      ..add(stableKey);
    while (_viewedItemKeys.length > viewedItemCapacity) {
      _viewedItemKeys.remove(_viewedItemKeys.first);
    }
    final previous = _visibleByStableKey[stableKey];
    if (previous != null && previous.tokenSequence > tokenSequence) {
      return false;
    }
    final enteredViewport = previous?.tokenSequence != tokenSequence;
    final unchanged =
        !enteredViewport &&
        previous!.index == index &&
        previous.itemWidth == itemWidth &&
        (previous.leadingScrollOffset - leadingScrollOffset).abs() < 1 &&
        previous.thumbnailRequest?.stableRequestKey ==
            thumbnailRequest?.stableRequestKey;
    if (unchanged) return false;
    _visibleByStableKey[stableKey] = OnlineGalleryViewportItem(
      index: index,
      item: item,
      itemWidth: itemWidth,
      leadingScrollOffset: leadingScrollOffset,
      tokenSequence: tokenSequence,
      thumbnailRequest: thumbnailRequest,
    );
    return enteredViewport;
  }

  OnlineGalleryViewportItem? removeVisibleItem(
    GalleryItem item, {
    required int viewportGeneration,
    required int tokenSequence,
  }) {
    if (viewportGeneration != _generation) return null;
    final current = _visibleByStableKey[item.stableKey];
    if (current == null || current.tokenSequence != tokenSequence) {
      return null;
    }
    return _visibleByStableKey.remove(item.stableKey);
  }

  void resetVisibleItems() {
    _generation++;
    _visibleByStableKey.clear();
  }

  List<OnlineGalleryViewportItem> resolveVisibleItems(List<GalleryItem> posts) {
    final resolved = <OnlineGalleryViewportItem>[];
    final staleKeys = <String>[];
    for (final entry in _visibleByStableKey.entries) {
      final index = _indexOfStableKey(posts, entry.key);
      if (index == null) {
        staleKeys.add(entry.key);
        continue;
      }
      final snapshot = entry.value;
      resolved.add(
        OnlineGalleryViewportItem(
          index: index,
          item: posts[index],
          itemWidth: snapshot.itemWidth,
          leadingScrollOffset: snapshot.leadingScrollOffset,
          tokenSequence: snapshot.tokenSequence,
          thumbnailRequest: snapshot.thumbnailRequest,
        ),
      );
    }
    for (final key in staleKeys) {
      _visibleByStableKey.remove(key);
    }
    resolved.sort((left, right) => left.index.compareTo(right.index));
    return resolved;
  }

  OnlineGalleryViewportItem? resolveLeadingAnchor({
    required List<GalleryItem> posts,
    required ScrollMetrics metrics,
  }) {
    final candidates = resolveVisibleItems(posts)
        .where(
          (item) =>
              (item.leadingScrollOffset - metrics.pixels).abs() <=
              metrics.viewportDimension * 2,
        )
        .toList(growable: false);
    if (candidates.isEmpty) return null;

    OnlineGalleryViewportItem? leading;
    for (final candidate in candidates) {
      if (candidate.leadingScrollOffset > metrics.pixels + 1) continue;
      if (leading == null ||
          candidate.leadingScrollOffset > leading.leadingScrollOffset ||
          (candidate.leadingScrollOffset == leading.leadingScrollOffset &&
              candidate.index < leading.index)) {
        leading = candidate;
      }
    }
    if (leading != null) return leading;

    return candidates.reduce(
      (left, right) =>
          left.leadingScrollOffset <= right.leadingScrollOffset ? left : right,
    );
  }

  int? indexOfStableKey(List<GalleryItem> posts, String stableKey) {
    if (posts is ChunkedGalleryItems) {
      return posts.indexOfStableKey(stableKey);
    }
    final index = posts.indexWhere((item) => item.stableKey == stableKey);
    return index < 0 ? null : index;
  }

  int? _indexOfStableKey(List<GalleryItem> posts, String stableKey) =>
      indexOfStableKey(posts, stableKey);

  void dispose() {
    _visibleByStableKey.clear();
    _viewedItemKeys.clear();
    scrolling.dispose();
  }
}
