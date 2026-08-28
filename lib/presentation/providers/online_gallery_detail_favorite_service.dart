import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/online_gallery_detail_coordinator.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_query.dart';
import '../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/repositories/online_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import 'online_gallery_dependencies.dart';
import 'online_gallery_local_favorites_provider.dart';
import 'online_gallery_state.dart';
import 'quick_tag_cloud_gallery_provider.dart';

class OnlineGalleryDetailFavoriteService {
  OnlineGalleryDetailFavoriteService({
    required Ref ref,
    required OnlineGalleryState Function() readState,
    required void Function(OnlineGalleryState next) reduce,
    required OnlineGalleryDetailCoordinator Function() details,
    required OnlineGalleryRepository Function() repository,
    required DanbooruAuthState Function() danbooruAuth,
    required Set<String> Function() localFavoriteKeys,
    required Set<String> Function() remoteFavoriteKeys,
    required Future<void> Function({bool refresh}) loadPosts,
  }) : _ref = ref,
       _readState = readState,
       _reduce = reduce,
       _details = details,
       _repository = repository,
       _danbooruAuth = danbooruAuth,
       _localFavoriteKeys = localFavoriteKeys,
       _remoteFavoriteKeys = remoteFavoriteKeys,
       _loadPosts = loadPosts;

  final Ref _ref;
  final OnlineGalleryState Function() _readState;
  final void Function(OnlineGalleryState next) _reduce;
  final OnlineGalleryDetailCoordinator Function() _details;
  final OnlineGalleryRepository Function() _repository;
  final DanbooruAuthState Function() _danbooruAuth;
  final Set<String> Function() _localFavoriteKeys;
  final Set<String> Function() _remoteFavoriteKeys;
  final Future<void> Function({bool refresh}) _loadPosts;

  OnlineGalleryState get state => _readState();
  set state(OnlineGalleryState next) => _reduce(next);

  Future<GalleryDetail> loadDetail(
    GalleryItem item, {
    bool forceRefresh = false,
    GalleryDetailPriority priority = GalleryDetailPriority.interactive,
  }) {
    if (!forceRefresh && state.viewMode == GalleryViewMode.favorites) {
      final record = _ref
          .read(onlineGalleryLocalFavoritesProvider.notifier)
          .getByStableKey(item.stableKey);
      if (record != null) return Future.value(record.detail);
    }
    return _details().request(
      item,
      forceRefresh: forceRefresh,
      priority: priority,
    );
  }

  void cancelDetail(GalleryItem item) => _details().cancel(item);

  Future<bool> addFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_danbooruAuth().isLoggedIn) return false;
    final key = 'danbooru:$postId';
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    try {
      final success = await _repository().addDanbooruFavorite(postId);
      if (success) _remoteFavoriteKeys().add(key);
      if (success) _syncMembership();
      return success;
    } catch (error, stack) {
      AppLogger.e(
        'Failed to add remote favorite',
        error,
        stack,
        'OnlineGallery',
      );
      return false;
    } finally {
      _removeLoadingKey(key);
    }
  }

  Future<bool> removeFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_danbooruAuth().isLoggedIn) return false;
    final key = 'danbooru:$postId';
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    try {
      final success = await _repository().removeDanbooruFavorite(postId);
      if (!success) return false;
      _remoteFavoriteKeys().remove(key);
      _syncMembership();
      if (state.viewMode == GalleryViewMode.favorites &&
          state.favoritesSourceId == GallerySourceId.danbooru &&
          !_localFavoriteKeys().contains(key)) {
        final posts = state.currentCache.posts is ChunkedGalleryItems
            ? state.currentCache.posts as ChunkedGalleryItems
            : ChunkedGalleryItems.from(state.currentCache.posts);
        state = state.updateCurrentCache(
          state.currentCache.copyWith(
            posts: posts.removeStableKeys({'danbooru:$postId'}),
          ),
        );
      }
      return true;
    } catch (error, stack) {
      AppLogger.e(
        'Failed to remove remote favorite',
        error,
        stack,
        'OnlineGallery',
      );
      return false;
    } finally {
      _removeLoadingKey(key);
    }
  }

  Future<void> recordQuickTagCloudViewed(GalleryItem item) async {
    if (item.sourceId != GallerySourceId.quickTagCloud) return;
    await _ref
        .read(quickTagCloudGallerySourceAdapterProvider)
        .recordViewed(item);
    final recentKeyFragment = '|${QuickTagCloudBrowseScope.recent.name}|';
    final activeRecent =
        state.viewMode == GalleryViewMode.search &&
        state.sourceId == GallerySourceId.quickTagCloud &&
        _ref.read(quickTagCloudFilterProvider).scope ==
            QuickTagCloudBrowseScope.recent;
    state = state.copyWith(
      caches: {
        for (final entry in state.caches.entries)
          if (!(entry.key.startsWith('search:quick_tag_cloud:') &&
              entry.key.contains(recentKeyFragment)))
            entry.key: entry.value,
      },
    );
    if (activeRecent) await _loadPosts(refresh: true);
  }

  Future<int> saveVisiblePostsToLocalFavorites() async {
    final candidates = state.posts
        .where((item) => item.sourceId == state.favoritesSourceId)
        .where((item) => !_localFavoriteKeys().contains(item.stableKey))
        .toList(growable: false);
    if (candidates.isEmpty) return 0;
    final details = <GalleryDetail>[];
    const batchSize = 6;
    for (var offset = 0; offset < candidates.length; offset += batchSize) {
      final end = min(offset + batchSize, candidates.length);
      details.addAll(
        await Future.wait(
          candidates
              .sublist(offset, end)
              .map(
                (item) => _details().request(
                  item,
                  priority: GalleryDetailPriority.interactive,
                ),
              ),
        ),
      );
    }
    await _ref
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsertAll(details);
    return details.length;
  }

  Future<bool> toggleFavorite(Object postOrId) async {
    if (postOrId is! GalleryItem) {
      final postId = _danbooruFavoritePostId(postOrId);
      if (postId == null) return false;
      return _remoteFavoriteKeys().contains('danbooru:$postId')
          ? removeFavorite(postOrId)
          : addFavorite(postOrId);
    }
    if (postOrId.sourceId == GallerySourceId.danbooru &&
        _danbooruAuth().isLoggedIn) {
      return _remoteFavoriteKeys().contains(postOrId.stableKey)
          ? removeFavorite(postOrId)
          : addFavorite(postOrId);
    }
    final key = postOrId.stableKey;
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    try {
      final localFavorites = _ref.read(
        onlineGalleryLocalFavoritesProvider.notifier,
      );
      if (_localFavoriteKeys().contains(key)) {
        await localFavorites.remove(key);
      } else {
        await localFavorites.upsert(
          await _details().request(
            postOrId,
            priority: GalleryDetailPriority.interactive,
          ),
        );
      }
      return true;
    } catch (error, stack) {
      AppLogger.e(
        'Failed to toggle local online gallery favorite',
        error,
        stack,
        'OnlineGallery',
      );
      return false;
    } finally {
      _removeLoadingKey(key);
    }
  }

  bool isFavorited(Object postOrId) {
    if (postOrId is GalleryItem) {
      return postOrId.sourceId == GallerySourceId.danbooru &&
              _danbooruAuth().isLoggedIn
          ? _remoteFavoriteKeys().contains(postOrId.stableKey)
          : _localFavoriteKeys().contains(postOrId.stableKey);
    }
    if (postOrId is! int) return false;
    final key = 'danbooru:$postOrId';
    return _danbooruAuth().isLoggedIn
        ? _remoteFavoriteKeys().contains(key)
        : _localFavoriteKeys().contains(key);
  }

  bool isLocallyFavorited(GalleryItem item) =>
      _localFavoriteKeys().contains(item.stableKey);

  bool isRemotelyFavorited(GalleryItem item) =>
      _remoteFavoriteKeys().contains(item.stableKey);

  void clearNotice() => state = state.copyWith(clearNotice: true);

  void invalidateGelbooruFavorites() {
    _remoteFavoriteKeys().removeWhere((key) => key.startsWith('gelbooru:'));
    state = state.copyWith(
      caches: {
        for (final entry in state.caches.entries)
          if (!entry.key.startsWith('favorites:gelbooru'))
            entry.key: entry.value,
      },
      favoritedPostKeys: {..._localFavoriteKeys(), ..._remoteFavoriteKeys()},
      localFavoritedPostKeys: _localFavoriteKeys(),
      remoteFavoritedPostKeys: _remoteFavoriteKeys(),
      favoriteLoadingPostKeys: state.favoriteLoadingPostKeys
          .where((key) => !key.startsWith('gelbooru:'))
          .toSet(),
    );
  }

  int? _danbooruFavoritePostId(Object postOrId) {
    if (postOrId is GalleryItem) {
      return postOrId.sourceId == GallerySourceId.danbooru ? postOrId.id : null;
    }
    return postOrId is int ? postOrId : null;
  }

  void _syncMembership() {
    state = state.copyWith(
      favoritedPostKeys: {..._localFavoriteKeys(), ..._remoteFavoriteKeys()},
      localFavoritedPostKeys: _localFavoriteKeys(),
      remoteFavoritedPostKeys: _remoteFavoriteKeys(),
    );
  }

  void _removeLoadingKey(String key) {
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys}..remove(key),
    );
  }
}
