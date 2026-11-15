import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/online_gallery/online_gallery_load_coordinator.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/gelbooru_api_service.dart';
import '../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/repositories/online_gallery_local_favorites_repository.dart';
import '../../data/repositories/online_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/online_gallery_favorites_service.dart';
import '../../data/services/online_gallery/online_gallery_query.dart';
import 'online_gallery_blacklist_provider.dart';
import 'online_gallery_feed_helpers.dart';
import 'online_gallery_local_favorites_provider.dart';
import 'online_gallery_state.dart';
import 'quick_tag_cloud_gallery_provider.dart';

class OnlineGalleryFavoritesLoaderService {
  OnlineGalleryFavoritesLoaderService({
    required Ref ref,
    required OnlineGalleryState Function() readState,
    required void Function(OnlineGalleryState next) reduce,
    required bool Function() isDisposed,
    required OnlineGalleryRequestHandle Function() beginRequest,
    required bool Function(OnlineGalleryRequestHandle request, String cacheKey)
    isCurrent,
    required Future<void> Function(GallerySourceId sourceId) ensureAuth,
    required OnlineGalleryRepository Function() repository,
    required OnlineGalleryQuery Function() query,
    required DanbooruAuthState Function() danbooruAuth,
    required GelbooruAuthState Function() gelbooruAuth,
    required Set<String> Function() localFavoriteKeys,
    required Set<String> Function() remoteFavoriteKeys,
    required bool Function(GallerySourceId sourceId) canLoadRemoteFavorites,
    required Future<({List<GalleryItem> items, int detailFailures})> Function(
      List<GalleryItem> items,
      Set<String> blacklist,
    )
    filterBlacklist,
    required OnlineGalleryErrorCode Function(Object error) errorCode,
  }) : _ref = ref,
       _readState = readState,
       _reduce = reduce,
       _isDisposed = isDisposed,
       _beginRequest = beginRequest,
       _isCurrent = isCurrent,
       _ensureAuth = ensureAuth,
       _repository = repository,
       _query = query,
       _danbooruAuth = danbooruAuth,
       _gelbooruAuth = gelbooruAuth,
       _localFavoriteKeys = localFavoriteKeys,
       _remoteFavoriteKeys = remoteFavoriteKeys,
       _canLoadRemoteFavorites = canLoadRemoteFavorites,
       _filterBlacklist = filterBlacklist,
       _errorCode = errorCode;

  static const int _pageSize = onlineGalleryPageSize;
  final Ref _ref;
  final OnlineGalleryState Function() _readState;
  final void Function(OnlineGalleryState next) _reduce;
  final bool Function() _isDisposed;
  final OnlineGalleryRequestHandle Function() _beginRequest;
  final bool Function(OnlineGalleryRequestHandle request, String cacheKey)
  _isCurrent;
  final Future<void> Function(GallerySourceId sourceId) _ensureAuth;
  final OnlineGalleryRepository Function() _repository;
  final OnlineGalleryQuery Function() _query;
  final DanbooruAuthState Function() _danbooruAuth;
  final GelbooruAuthState Function() _gelbooruAuth;
  final Set<String> Function() _localFavoriteKeys;
  final Set<String> Function() _remoteFavoriteKeys;
  final bool Function(GallerySourceId sourceId) _canLoadRemoteFavorites;
  final Future<({List<GalleryItem> items, int detailFailures})> Function(
    List<GalleryItem> items,
    Set<String> blacklist,
  )
  _filterBlacklist;
  final OnlineGalleryErrorCode Function(Object error) _errorCode;
  final OnlineGalleryFavoritesService _favorites =
      const OnlineGalleryFavoritesService();

  OnlineGalleryState get state => _readState();
  set state(OnlineGalleryState next) => _reduce(next);

  Future<void> load({required bool refresh, int? targetPage}) async {
    final sourceId = state.favoritesSourceId;
    final previousCache = state.currentCache;
    final pageNumber =
        targetPage ?? (refresh ? 1 : previousCache.lastLoadedPage + 1);
    final generation = _beginRequest();
    final cacheKey = state.currentCacheKey;
    final resetBranches = refresh;
    final isAppend = !resetBranches && previousCache.posts.isNotEmpty;
    var cache = resetBranches
        ? ModeCache(
            posts: previousCache.posts,
            page: 1,
            localFavoritesOffset: 0,
            remoteFavoritesPage: 1,
            localFavoriteItemKeys: previousCache.localFavoriteItemKeys,
            remoteFavoriteItemKeys: previousCache.remoteFavoriteItemKeys,
          )
        : targetPage != null
        ? previousCache.copyWith(
            localFavoritesOffset: (targetPage - 1) * _pageSize,
            remoteFavoritesPage: targetPage,
            localFavoritesHasMore: true,
            remoteFavoritesHasMore: true,
          )
        : previousCache;
    var posts = cache.posts is ChunkedGalleryItems
        ? cache.posts as ChunkedGalleryItems
        : ChunkedGalleryItems.from(cache.posts);
    final laterBoundaryIndex = resetBranches
        ? -1
        : previousCache.pageBoundaries.indexWhere(
            (boundary) => boundary.page > pageNumber,
          );
    final pageStartIndex = resetBranches
        ? 0
        : laterBoundaryIndex < 0
        ? posts.length
        : previousCache.pageBoundaries[laterBoundaryIndex].startIndex;
    final itemCountBeforePage = posts.length;
    void mergePageItems(Iterable<GalleryItem> items) {
      if (resetBranches) {
        posts = posts.mergePage(items, mergeDuplicate: _favorites.mergeItem);
        return;
      }
      final insertAt = pageStartIndex + (posts.length - itemCountBeforePage);
      posts = insertAt == posts.length
          ? posts.mergePage(items, mergeDuplicate: _favorites.mergeItem)
          : posts.insertPage(
              insertAt,
              items,
              mergeDuplicate: _favorites.mergeItem,
            );
    }

    var rawItemCount = 0;
    state = state.copyWith(
      isLoading: !isAppend,
      isLoadingMore: isAppend,
      clearError: true,
    );

    Object? localError;
    Object? remoteError;
    var blacklistDetailFailures = 0;
    try {
      await _ensureAuth(sourceId);
      if (_isDisposed() ||
          !_isCurrent(generation, cacheKey) ||
          state.viewMode != GalleryViewMode.favorites ||
          state.favoritesSourceId != sourceId) {
        return;
      }
      await _ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (!_isCurrent(generation, cacheKey)) return;
      final blacklist = _ref.read(onlineGalleryBlacklistNotifierProvider).tags;
      final quickTagFilter = sourceId == GallerySourceId.quickTagCloud
          ? _ref.read(quickTagCloudFilterProvider)
          : null;

      if (cache.localFavoritesHasMore) {
        try {
          final localFavorites = _ref.read(
            onlineGalleryLocalFavoritesProvider.notifier,
          );
          await localFavorites.initialize();
          if (!_isCurrent(generation, cacheKey)) return;
          final localPage = localFavorites.query(
            OnlineGalleryFavoriteQuery(
              sourceId: sourceId,
              searchText: state.favoriteSearchQuery,
              ratings: sourceId.capabilities.supportsRatings
                  ? state.selectedRatings
                  : const {},
              blacklistTags: blacklist,
              codexId: quickTagFilter?.codexId,
              categoryPath: quickTagFilter?.categoryPath ?? const [],
              mediaFilter: quickTagFilter?.mediaFilter.name ?? 'all',
              offset: cache.localFavoritesOffset,
              limit: _pageSize,
            ),
          );
          rawItemCount += localPage.records.length;
          final loadedLocalItemKeys = localPage.items
              .map(onlineGalleryPostKey)
              .toSet();
          if (resetBranches) {
            posts = _favorites.removeBranch(
              posts,
              branchKeys: cache.localFavoriteItemKeys.difference(
                loadedLocalItemKeys,
              ),
              retainedByOtherBranch: cache.remoteFavoriteItemKeys,
            );
          }
          mergePageItems(localPage.items);
          final localItemKeys = resetBranches
              ? loadedLocalItemKeys
              : {
                  ...cache.localFavoriteItemKeys,
                  ...localPage.items.map(onlineGalleryPostKey),
                };
          final latestViewCache = state.currentCache;
          cache = cache.copyWith(
            posts: posts,
            page: latestViewCache.page,
            scrollOffset: latestViewCache.scrollOffset,
            anchorStableKey: latestViewCache.anchorStableKey,
            anchorLocalOffset: latestViewCache.anchorLocalOffset,
            localFavoritesOffset:
                cache.localFavoritesOffset + localPage.records.length,
            localFavoritesHasMore: localPage.hasMore,
            localFavoriteItemKeys: localItemKeys,
            clearLocalFavoritesError: true,
          );
          state = state.updateCurrentCache(cache);
        } catch (error, stack) {
          localError = error;
          AppLogger.e(
            'Failed to load local favorites',
            error,
            stack,
            'OnlineGallery',
          );
          cache = cache.copyWith(
            localFavoritesHasMore: false,
            localFavoritesErrorCode: _errorCode(error),
          );
        }
      }

      if (_canLoadRemoteFavorites(sourceId) && cache.remoteFavoritesHasMore) {
        try {
          final requestPage = cache.remoteFavoritesPage;
          final OnlineGalleryRemoteFavoritesPage remotePage;
          if (sourceId == GallerySourceId.danbooru) {
            remotePage = await _repository().danbooruFavorites(
              username: _danbooruAuth().user!.name,
              page: requestPage,
              limit: _pageSize,
            );
          } else {
            remotePage = await _repository().gelbooruFavorites(
              credentials: _gelbooruAuth().credentials!,
              page: requestPage,
              limit: _pageSize,
              cancelToken: generation.cancelToken,
            );
          }
          if (!_isCurrent(generation, cacheKey)) return;
          rawItemCount += remotePage.rawCount;
          final query = _query();
          final matching = query
              .filterLocal(
                items: remotePage.items,
                ratings: state.selectedRatings,
                blacklist: const {},
              )
              .where(
                (item) => query.matchesFavoriteSearch(
                  item,
                  state.favoriteSearchQuery,
                ),
              )
              .toList(growable: false);
          final remoteResult = await _filterBlacklist(matching, blacklist);
          if (!_isCurrent(generation, cacheKey)) return;
          blacklistDetailFailures += remoteResult.detailFailures;
          final remoteItems = remoteResult.items;
          final upstreamEnded = remotePage.rawCount < _pageSize;
          final nextRequestPage = requestPage + 1;
          final loadedRemoteItemKeys = remoteItems
              .map(onlineGalleryPostKey)
              .toSet();
          if (resetBranches) {
            posts = _favorites.removeBranch(
              posts,
              branchKeys: cache.remoteFavoriteItemKeys.difference(
                loadedRemoteItemKeys,
              ),
              retainedByOtherBranch: cache.localFavoriteItemKeys,
            );
            _remoteFavoriteKeys().removeAll(cache.remoteFavoriteItemKeys);
          }
          mergePageItems(remoteItems);
          final remoteItemKeys = resetBranches
              ? loadedRemoteItemKeys
              : {
                  ...cache.remoteFavoriteItemKeys,
                  ...remoteItems.map(onlineGalleryPostKey),
                };
          _remoteFavoriteKeys().addAll(remoteItemKeys);
          cache = cache.copyWith(
            posts: posts,
            remoteFavoritesPage: nextRequestPage,
            remoteFavoritesHasMore: !upstreamEnded,
            remoteFavoriteItemKeys: remoteItemKeys,
            clearRemoteFavoritesError: true,
          );
        } on GelbooruApiException catch (error, stack) {
          if (error.type == GelbooruApiErrorType.cancelled) return;
          remoteError = error;
          if (error.type == GelbooruApiErrorType.invalidCredentials) {
            _ref.read(gelbooruAuthProvider.notifier).markInvalid();
          }
          AppLogger.e(
            'Failed to load remote favorites',
            error,
            stack,
            'OnlineGallery',
          );
          cache = cache.copyWith(
            remoteFavoritesHasMore: false,
            remoteFavoritesErrorCode: _errorCode(error),
          );
        } catch (error, stack) {
          remoteError = error;
          AppLogger.e(
            'Failed to load remote favorites',
            error,
            stack,
            'OnlineGallery',
          );
          cache = cache.copyWith(
            remoteFavoritesHasMore: false,
            remoteFavoritesErrorCode: _errorCode(error),
          );
        }
      } else if (!_canLoadRemoteFavorites(sourceId)) {
        if (resetBranches) {
          posts = _favorites.removeBranch(
            posts,
            branchKeys: cache.remoteFavoriteItemKeys,
            retainedByOtherBranch: cache.localFavoriteItemKeys,
          );
          _remoteFavoriteKeys().removeAll(cache.remoteFavoriteItemKeys);
        }
        cache = cache.copyWith(
          posts: posts,
          remoteFavoritesHasMore: false,
          remoteFavoriteItemKeys: const {},
          clearRemoteFavoritesError: true,
        );
      }

      if (!_isCurrent(generation, cacheKey)) return;
      final remoteAvailable = _canLoadRemoteFavorites(sourceId);
      final allAvailableBranchesFailed =
          localError != null && (!remoteAvailable || remoteError != null);
      if (allAvailableBranchesFailed) {
        cache = cache.copyWith(
          clearLocalFavoritesError: true,
          clearRemoteFavoritesError: true,
        );
      }
      // A filtered page can contribute no visible favorites while either
      // branch still has later records. Only each branch's real cursor/EOF
      // result may end it; deduplication is not an upstream end signal.
      final duplicatePage =
          isAppend &&
          posts.length == previousCache.posts.length &&
          !cache.localFavoritesHasMore &&
          !cache.remoteFavoritesHasMore;
      final hasMore =
          cache.localFavoritesHasMore || cache.remoteFavoritesHasMore;
      final insertedItemCount = resetBranches
          ? posts.length
          : posts.length - itemCountBeforePage;
      final boundaries = <GalleryPageBoundary>[
        if (!refresh) ...previousCache.pageBoundaries,
      ];
      if (!refresh && insertedItemCount > 0 && laterBoundaryIndex >= 0) {
        for (
          var boundaryIndex = laterBoundaryIndex;
          boundaryIndex < boundaries.length;
          boundaryIndex++
        ) {
          final boundary = boundaries[boundaryIndex];
          boundaries[boundaryIndex] = GalleryPageBoundary(
            page: boundary.page,
            cursor: boundary.cursor,
            startIndex: boundary.startIndex + insertedItemCount,
            endIndex: boundary.endIndex + insertedItemCount,
            rawItemCount: boundary.rawItemCount,
            nextCursor: boundary.nextCursor,
          );
        }
      }
      final pageBoundary = GalleryPageBoundary(
        page: pageNumber,
        cursor: '$pageNumber',
        startIndex: pageStartIndex,
        endIndex: pageStartIndex + insertedItemCount,
        rawItemCount: rawItemCount,
        nextCursor: hasMore ? '${pageNumber + 1}' : null,
      );
      if (refresh || laterBoundaryIndex < 0) {
        boundaries.add(pageBoundary);
      } else {
        boundaries.insert(laterBoundaryIndex, pageBoundary);
      }
      final loadedTail = boundaries.last.page == pageNumber;
      final tailHasMore = loadedTail ? hasMore : previousCache.hasMore;
      final tailNextCursor = loadedTail
          ? hasMore
                ? '${pageNumber + 1}'
                : null
          : boundaries.last.nextCursor;
      final latestViewCache = state.currentCache;
      cache = cache.copyWith(
        posts: posts,
        page: refresh ? pageNumber : latestViewCache.page,
        pageBoundaries: boundaries,
        nextCursor: tailNextCursor,
        clearNextCursor: tailNextCursor == null,
        hasMore: tailHasMore && tailNextCursor != null,
        scrollOffset: refresh ? 0 : latestViewCache.scrollOffset,
        anchorStableKey: refresh ? null : latestViewCache.anchorStableKey,
        clearAnchorStableKey: refresh,
        anchorLocalOffset: refresh ? 0 : latestViewCache.anchorLocalOffset,
        endedByDuplicatePage: loadedTail
            ? duplicatePage
            : previousCache.endedByDuplicatePage,
        localFavoritesOffset: loadedTail
            ? cache.localFavoritesOffset
            : previousCache.localFavoritesOffset,
        remoteFavoritesPage: loadedTail
            ? cache.remoteFavoritesPage
            : previousCache.remoteFavoritesPage,
        localFavoritesHasMore: loadedTail
            ? cache.localFavoritesHasMore
            : previousCache.localFavoritesHasMore,
        remoteFavoritesHasMore: loadedTail
            ? cache.remoteFavoritesHasMore
            : previousCache.remoteFavoritesHasMore,
        appendErrorCode: allAvailableBranchesFailed && isAppend
            ? _errorCode(remoteError ?? localError)
            : null,
        clearAppendError: !allAvailableBranchesFailed || !isAppend,
        queryDetailFailureCount: blacklistDetailFailures,
      );
      state = state
          .copyWith(
            isLoading: false,
            isLoadingMore: false,
            errorCode: allAvailableBranchesFailed && !isAppend
                ? _errorCode(remoteError ?? localError)
                : null,
            favoritedPostKeys: {
              ..._localFavoriteKeys(),
              ..._remoteFavoriteKeys(),
            },
            localFavoritedPostKeys: _localFavoriteKeys(),
            remoteFavoritedPostKeys: _remoteFavoriteKeys(),
            notice: blacklistDetailFailures > 0
                ? OnlineGalleryNotice.tagDetailsIncomplete
                : null,
            clearNotice: blacklistDetailFailures == 0,
            clearError: !allAvailableBranchesFailed || isAppend,
          )
          .updateCurrentCache(cache);
    } catch (error, stack) {
      AppLogger.e('Failed to load favorites', error, stack, 'OnlineGallery');
      _finishRequestError(error, generation, cacheKey, isAppend, previousCache);
    }
  }

  void _finishRequestError(
    Object error,
    OnlineGalleryRequestHandle request,
    String cacheKey,
    bool isAppend,
    ModeCache cache,
  ) {
    if (!_isCurrent(request, cacheKey)) return;
    final code = _errorCode(error);
    state = state.copyWith(isLoading: false, isLoadingMore: false);
    state = isAppend
        ? state.updateCurrentCache(cache.copyWith(appendErrorCode: code))
        : state.copyWith(errorCode: code);
  }
}
