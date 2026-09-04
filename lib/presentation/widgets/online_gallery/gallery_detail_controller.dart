import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../adaptive/window_size_class.dart';

class GalleryDetailController extends ChangeNotifier {
  GalleryDetailController({
    required GalleryItem item,
    required GalleryDetail detail,
    required bool isFavorited,
    OnlineGalleryPrefetchCoordinator? prefetchCoordinator,
  }) : _item = item,
       _detail = detail,
       _isFavorited = isFavorited,
       _prefetchCoordinator = prefetchCoordinator,
       mediaIndex = _resolveInitialMediaIndex(item, detail) {
    pageController = PageController(initialPage: mediaIndex);
  }

  late final PageController pageController;
  final FocusNode keyboardFocusNode = FocusNode();

  GalleryItem _item;
  GalleryDetail _detail;
  int mediaIndex;
  int imageRevision = 0;
  bool _isFavorited;
  bool favoriteActionPending = false;
  bool queueActionPending = false;
  bool downloadActionPending = false;
  bool reverseActionPending = false;
  bool _disposed = false;
  final OnlineGalleryPrefetchCoordinator? _prefetchCoordinator;

  bool get isFavorited => _isFavorited;
  List<GalleryMedia> get media => _detail.media;
  GalleryMedia? get currentMedia =>
      media.isEmpty ? null : media[mediaIndex.clamp(0, media.length - 1)];

  void update({
    required GalleryItem item,
    required GalleryDetail detail,
    required bool isFavorited,
  }) {
    if (_isFavorited != isFavorited) _isFavorited = isFavorited;
    final sameItem = _item.stableKey == item.stableKey;
    final sameMedia = _hasSameMediaIdentity(_detail.media, detail.media);
    final sameFocus =
        _item.focusedMediaId == item.focusedMediaId &&
        _item.focusedMediaIndex == item.focusedMediaIndex;
    _item = item;
    _detail = detail;
    if (sameItem && sameMedia && sameFocus) return;
    mediaIndex = _resolveInitialMediaIndex(item, detail);
    imageRevision++;
    _notifyChanged();
  }

  void syncPageAndPrefetch(BuildContext context) {
    if (pageController.hasClients && media.isNotEmpty) {
      pageController.jumpToPage(mediaIndex);
    }
    prefetchAdjacent(context, mediaIndex);
  }

  void onPageChanged(BuildContext context, int index) {
    if (mediaIndex == index) return;
    mediaIndex = index;
    _notifyChanged();
    prefetchAdjacent(context, index);
  }

  void moveTo(BuildContext context, int index) {
    if (index < 0 || index >= media.length || !pageController.hasClients) {
      return;
    }
    pageController.animateToPage(
      index,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
    );
  }

  void prefetchAdjacent(BuildContext context, int index) {
    for (final targetIndex in [index - 1, index + 1]) {
      if (targetIndex < 0 || targetIndex >= media.length) continue;
      final target = media[targetIndex];
      final capability = target.capability;
      final url = capability.isVideo
          ? (capability.hasStaticThumbnail ? capability.previewUrl : '')
          : capability.imageDisplayUrl;
      if (url.isEmpty) continue;
      final request = GalleryImageRequest.forUrl(
        sourceId: _item.sourceId,
        url: url,
        tier: GalleryImageTier.sample,
        targetDecodeWidth: GalleryImageSizing.detailViewportTargetWidth(
          MediaQuery.devicePixelRatioOf(context),
          context.adaptiveWindow.safeUsableSize.width,
        ),
      );
      _prefetchCoordinator?.submit(
        request,
        priority: GalleryImagePriority.interactiveDetail,
      );
    }
  }

  Future<void> retryMedia(GalleryMedia media) async {
    final urls = <String>{media.previewUrl, media.displayUrl, media.downloadUrl}
      ..removeWhere((url) => url.isEmpty);
    for (final url in urls) {
      await CachedNetworkImage.evictFromCache(
        url,
        cacheManager: OnlineGalleryImageCacheManager.instance,
        cacheKey: onlineGalleryImageCacheKeyForUrl(url),
      );
    }
    imageRevision++;
    _notifyChanged();
  }

  Future<void> toggleFavorite(Future<bool> Function() action) async {
    favoriteActionPending = true;
    _notifyChanged();
    try {
      final changed = await action();
      if (changed) _isFavorited = !_isFavorited;
    } finally {
      favoriteActionPending = false;
      _notifyChanged();
    }
  }

  Future<void> addToQueue(Future<void> Function() action) async {
    queueActionPending = true;
    _notifyChanged();
    try {
      await action();
    } finally {
      queueActionPending = false;
      _notifyChanged();
    }
  }

  Future<void> download(Future<void> Function() action) async {
    downloadActionPending = true;
    _notifyChanged();
    try {
      await action();
    } finally {
      downloadActionPending = false;
      _notifyChanged();
    }
  }

  Future<void> sendToReverse(Future<void> Function() action) async {
    reverseActionPending = true;
    _notifyChanged();
    try {
      await action();
    } finally {
      reverseActionPending = false;
      _notifyChanged();
    }
  }

  void _notifyChanged() {
    if (!_disposed) notifyListeners();
  }

  static bool _hasSameMediaIdentity(
    List<GalleryMedia> previous,
    List<GalleryMedia> next,
  ) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].id != next[index].id) return false;
    }
    return true;
  }

  static int _resolveInitialMediaIndex(GalleryItem item, GalleryDetail detail) {
    if (detail.media.isEmpty) return 0;
    final focusedId = item.focusedMediaId;
    if (focusedId != null) {
      final matchingIndex = detail.media.indexWhere(
        (media) => media.id == focusedId,
      );
      if (matchingIndex >= 0) return matchingIndex;
    }
    return (item.focusedMediaIndex ?? 0).clamp(0, detail.media.length - 1);
  }

  @override
  void dispose() {
    _disposed = true;
    pageController.dispose();
    keyboardFocusNode.dispose();
    super.dispose();
  }
}
