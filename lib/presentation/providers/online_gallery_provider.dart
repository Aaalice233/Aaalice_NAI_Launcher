import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/online_gallery_detail_coordinator.dart';
import '../../core/online_gallery/online_gallery_load_coordinator.dart';
import '../../core/online_gallery/online_gallery_session_repository.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/repositories/online_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/online_gallery_auth_scope_coordinator.dart';
import '../../data/services/online_gallery/online_gallery_blacklist_filter_service.dart';
import '../../data/services/online_gallery/online_gallery_error_mapper.dart';
import '../../data/services/online_gallery/online_gallery_query.dart';
import '../../data/services/online_gallery/online_gallery_search_service.dart';
import 'online_gallery_command_service.dart';
import 'online_gallery_dependencies.dart';
import 'online_gallery_detail_favorite_service.dart';
import 'online_gallery_favorites_loader_service.dart';
import 'online_gallery_feed_helpers.dart';
import 'online_gallery_lifecycle_service.dart';
import 'online_gallery_pagination_service.dart';
import 'online_gallery_random_loader_service.dart';
import 'online_gallery_state.dart';

export '../../core/online_gallery/online_gallery_load_coordinator.dart'
    show OnlineGalleryLoadCoordinator, OnlineGalleryRequestHandle;
export '../../data/repositories/online_gallery_repository.dart'
    show OnlineGalleryRemoteFavoritesPage, OnlineGalleryRepository;
export '../../data/services/online_gallery/online_gallery_query.dart'
    show OnlineGalleryQuery;
export 'online_gallery_dependencies.dart'
    show
        GalleryTagMetadataLoader,
        OnlineGalleryHttpClientRef,
        OnlineGallerySourceAdaptersRef,
        onlineGalleryHttpClient,
        onlineGalleryHttpClientProvider,
        onlineGalleryQueryProvider,
        onlineGalleryRepositoryProvider,
        onlineGallerySourceAdapters,
        onlineGallerySourceAdaptersProvider,
        onlineGalleryTagCatalogProvider,
        onlineGalleryTagMetadataLoaderProvider,
        quickTagCloudCatalogProvider,
        quickTagCloudCodexProvider,
        quickTagCloudGallerySourceAdapterProvider;
export 'online_gallery_feed_helpers.dart'
    show GalleryPageJumpTarget, onlineGalleryPageSize;
export 'online_gallery_state.dart'
    show
        GalleryPageBoundary,
        GallerySourceIdCapabilities,
        GalleryViewMode,
        ModeCache,
        OnlineGalleryErrorCode,
        OnlineGalleryNotice,
        OnlineGalleryState,
        RandomGallerySession,
        buildOnlineGallerySearchQuery,
        decodeOnlineGalleryBrowsingSession,
        encodeOnlineGalleryBrowsingSession,
        kAllRatings,
        onlineGalleryPostKey,
        parsePostsInIsolate;

part 'online_gallery_provider.g.dart';

@riverpod
class OnlineGalleryNotifier extends _$OnlineGalleryNotifier {
  final OnlineGalleryLoadCoordinator _loadCoordinator =
      OnlineGalleryLoadCoordinator();
  final OnlineGalleryAuthScopeCoordinator _authScopes =
      const OnlineGalleryAuthScopeCoordinator();
  final OnlineGalleryBlacklistFilterService _blacklistFilter =
      const OnlineGalleryBlacklistFilterService(OnlineGalleryQuery());
  final OnlineGalleryErrorMapper _errorMapper =
      const OnlineGalleryErrorMapper();
  OnlineGalleryCommandService? _commandService;
  OnlineGalleryDetailCoordinator? _detailCoordinator;
  OnlineGalleryDetailFavoriteService? _detailFavorites;
  OnlineGalleryFavoritesLoaderService? _favoritesLoaderService;
  OnlineGalleryLifecycleService? _lifecycleService;
  OnlineGalleryPaginationService? _paginationService;
  OnlineGalleryRandomLoaderService? _randomLoaderService;
  Set<String> _localFavoriteKeys = const {};
  final Set<String> _remoteFavoriteKeys = <String>{};
  final OnlineGallerySearchService _search = OnlineGallerySearchService();
  int _detailRequestScopeRevision = 0;
  bool _loadMoreClaimed = false;
  int _loadMoreClaimRevision = 0;
  int _pageJumpRevision = 0;
  bool _backgroundNetworkPaused = false;
  int _explicitNetworkAccessCount = 0;
  int _deferredLoadCount = 0;
  bool _resumeInitialLoadAfterBackgroundPause = false;
  bool _resumeAppendAfterBackgroundPause = false;

  int get detailRequestScopeRevision => _detailRequestScopeRevision;
  bool get _networkRequestsPaused =>
      _backgroundNetworkPaused && _explicitNetworkAccessCount == 0;

  OnlineGalleryDetailCoordinator get _details =>
      _detailCoordinator ??= OnlineGalleryDetailCoordinator(
        loader: (item, cancelToken) =>
            _repository.detail(item, cancelToken: cancelToken),
      )..setBackgroundPaused(_networkRequestsPaused);

  Future<T> runWithExplicitNetworkAccess<T>(Future<T> Function() action) async {
    _explicitNetworkAccessCount++;
    _detailCoordinator?.setBackgroundPaused(false);
    try {
      return await action();
    } finally {
      _explicitNetworkAccessCount--;
      if (_explicitNetworkAccessCount == 0) {
        _detailCoordinator?.setBackgroundPaused(_backgroundNetworkPaused);
      }
    }
  }

  Future<T> runWithDeferredLoading<T>(Future<T> Function() action) async {
    _deferredLoadCount++;
    try {
      return await action();
    } finally {
      _deferredLoadCount--;
    }
  }

  void cancelActiveRequests({
    String reason = 'Gallery request cancelled',
    bool cancelDetails = false,
  }) {
    _loadCoordinator.cancel(reason);
    _loadMoreClaimRevision++;
    _loadMoreClaimed = false;
    _detailRequestScopeRevision++;
    if (cancelDetails) {
      _detailCoordinator?.cancelVisible(reason: reason);
    }
    if (state.isLoading || state.isLoadingMore) {
      state = state.copyWith(isLoading: false, isLoadingMore: false);
    }
  }

  void setBackgroundNetworkPaused(bool paused) {
    if (_backgroundNetworkPaused == paused) return;
    _backgroundNetworkPaused = paused;
    if (paused && _explicitNetworkAccessCount == 0) {
      _resumeInitialLoadAfterBackgroundPause = state.isLoading;
      _resumeAppendAfterBackgroundPause = state.isLoadingMore;
      _cancelCurrentRequest();
    }
    _details.setBackgroundPaused(_networkRequestsPaused);
    if (!paused) {
      _detailRequestScopeRevision++;
      ref.notifyListeners();
      final resumeInitial = _resumeInitialLoadAfterBackgroundPause;
      final resumeAppend = _resumeAppendAfterBackgroundPause;
      _resumeInitialLoadAfterBackgroundPause = false;
      _resumeAppendAfterBackgroundPause = false;
      if (resumeInitial || resumeAppend) {
        unawaited(
          Future<void>(() async {
            if (_networkRequestsPaused) return;
            if (resumeAppend) {
              await loadMore();
            } else {
              await loadPosts();
            }
          }),
        );
      }
    }
  }

  void cancelLookaheadDetailRequests() {
    _detailCoordinator?.cancelLookahead();
  }

  OnlineGalleryPaginationService get _pagination =>
      _paginationService ??= OnlineGalleryPaginationService(
        ref: ref,
        readState: () => state,
        reduce: (next) => state = next,
        beginRequest: _beginRequest,
        isCurrent: _isCurrentRequest,
        isActive: _loadCoordinator.isCurrent,
        ensureQuickFilter: _ensureQuickTagCloudFilterInitialized,
        ensureAuth: _ensureAuthenticationReady,
        repository: () => _repository,
        details: () => _details,
        filterBlacklist: _filterByBlacklistCompletingDetails,
        serverTagLimit: _serverOrdinaryTagLimit,
        effectivePrompt: _effectivePromptQuery,
        errorCode: _errorCode,
      );

  OnlineGalleryRandomLoaderService get _randomLoader =>
      _randomLoaderService ??= OnlineGalleryRandomLoaderService(
        ref: ref,
        readState: () => state,
        reduce: (next) => state = next,
        isNetworkBlocked: () =>
            _networkRequestsPaused || _deferredLoadCount > 0,
        beginRequest: _beginRequest,
        isActive: _loadCoordinator.isCurrent,
        isCurrent: _isCurrentRequest,
        ensureQuickFilter: _ensureQuickTagCloudFilterInitialized,
        ensureAuth: _ensureAuthenticationReady,
        repository: () => _repository,
        details: () => _details,
        search: _search,
        danbooruAuth: () => _danbooruAuth,
        gelbooruAuth: () => _gelbooruAuth,
        canLoadRemoteFavorites: _canLoadRemoteFavorites,
        filterBlacklist: _filterByBlacklistCompletingDetails,
        serverTagLimit: _serverOrdinaryTagLimit,
        effectivePrompt: _effectivePromptQuery,
        errorCode: _errorCode,
      );

  OnlineGalleryFavoritesLoaderService get _favoritesLoader =>
      _favoritesLoaderService ??= OnlineGalleryFavoritesLoaderService(
        ref: ref,
        readState: () => state,
        reduce: (next) => state = next,
        isDisposed: () => _lifecycle.disposed,
        beginRequest: _beginRequest,
        isCurrent: _isCurrentRequest,
        ensureAuth: _ensureAuthenticationReady,
        repository: () => _repository,
        query: () => _query,
        danbooruAuth: () => _danbooruAuth,
        gelbooruAuth: () => _gelbooruAuth,
        localFavoriteKeys: () => _localFavoriteKeys,
        remoteFavoriteKeys: () => _remoteFavoriteKeys,
        canLoadRemoteFavorites: _canLoadRemoteFavorites,
        filterBlacklist: _filterByBlacklistCompletingDetails,
        errorCode: _errorCode,
      );

  OnlineGalleryLifecycleService get _lifecycle =>
      _lifecycleService ??= OnlineGalleryLifecycleService(
        ref: ref,
        readState: () => state,
        reduce: (next) => state = next,
        cancelCurrentRequest: _cancelCurrentRequest,
        loadPosts: loadPosts,
        loadRandom: _loadRandom,
        search: _search,
        clearDetails: () => _detailCoordinator?.clear(),
        invalidateRandomSnapshot: _commands.invalidateRandomSnapshot,
        localFavoriteKeys: () => _localFavoriteKeys,
        setLocalFavoriteKeys: (keys) => _localFavoriteKeys = keys,
        remoteFavoriteKeys: () => _remoteFavoriteKeys,
      );

  OnlineGalleryDetailFavoriteService get _favoriteActions =>
      _detailFavorites ??= OnlineGalleryDetailFavoriteService(
        ref: ref,
        readState: () => state,
        reduce: (next) => state = next,
        details: () => _details,
        repository: () => _repository,
        danbooruAuth: () => _danbooruAuth,
        localFavoriteKeys: () => _localFavoriteKeys,
        remoteFavoriteKeys: () => _remoteFavoriteKeys,
        loadPosts: loadPosts,
      );

  OnlineGalleryCommandService get _commands =>
      _commandService ??= OnlineGalleryCommandService(
        ref: ref,
        readState: () => state,
        reduce: (next) => state = next,
        cancelCurrentRequest: _cancelCurrentRequest,
        loadPosts: loadPosts,
        loadRandom: _loadRandom,
        clearDetailCache: () => _detailCoordinator?.clear(),
      );

  @override
  OnlineGalleryState build() {
    ref.keepAlive();
    ref.onDispose(() {
      _commandService?.dispose();
      _lifecycle.dispose();
      _loadCoordinator.dispose();
      _detailCoordinator?.clear();
      _paginationService?.dispose();
      _search.clear();
    });
    final sessionRepository = OnlineGallerySessionRepository(
      ref.read(localStorageServiceProvider),
    );
    final persistedSession = sessionRepository.read();
    var restored = decodeOnlineGalleryBrowsingSession(persistedSession);
    restored = restored.copyWith(
      danbooruAuthScope: _lifecycle.currentDanbooruAuthScope,
      gelbooruAuthScope: _lifecycle.currentGelbooruAuthScope,
    );
    sessionRepository.seed(encodeOnlineGalleryBrowsingSession(restored));
    _commands.restoreRandomSnapshot(restored);
    listenSelf((previous, next) {
      sessionRepository.save(encodeOnlineGalleryBrowsingSession(next));
      final wasLoading =
          previous?.isLoading == true || previous?.isLoadingMore == true;
      if (wasLoading && !next.isLoading && !next.isLoadingMore) {
        Future.microtask(_lifecycle.flushAuthenticationChanges);
      }
    });
    _lifecycle.attach();
    return restored;
  }

  Future<void> _ensureAuthenticationReady(GallerySourceId sourceId) =>
      _lifecycle.ensureAuthenticationReady(sourceId);

  OnlineGalleryRepository get _repository =>
      ref.read(onlineGalleryRepositoryProvider);
  OnlineGalleryQuery get _query => ref.read(onlineGalleryQueryProvider);
  DanbooruAuthState get _danbooruAuth => ref.read(danbooruAuthProvider);
  GelbooruAuthState get _gelbooruAuth => ref.read(gelbooruAuthProvider);
  OnlineGalleryRequestHandle _beginRequest({String? cacheKey}) =>
      _loadCoordinator.begin(cacheKey: cacheKey);

  void _cancelCurrentRequest() {
    _loadCoordinator.cancel('Superseded by a gallery state change');
    _loadMoreClaimRevision++;
    _pageJumpRevision++;
    _loadMoreClaimed = false;
    _detailRequestScopeRevision++;
    _detailCoordinator?.cancelQueuedVisible();
    _detailCoordinator?.cancelLookahead();
    if (state.isLoading || state.isLoadingMore) {
      state = state.copyWith(isLoading: false, isLoadingMore: false);
    }
  }

  bool _isCurrentRequest(OnlineGalleryRequestHandle request, String cacheKey) {
    return _loadCoordinator.isCurrent(request, cacheKey: cacheKey) &&
        state.currentCacheKey == cacheKey;
  }

  void updateVisibleItemIndex(int index, {String? expectedStableKey}) {
    if (state.randomEnabled) return;
    final cache = state.currentCache;
    if (index < 0 || index >= cache.posts.length) return;
    if (expectedStableKey != null &&
        cache.posts[index].stableKey != expectedStableKey) {
      return;
    }
    final visiblePage = cache.pageForItemIndex(index);
    if (visiblePage == null || visiblePage == cache.page) return;
    state = state.updateCurrentCache(cache.copyWith(page: visiblePage));
  }

  void saveScrollOffset(
    double offset, {
    String? anchorStableKey,
    double anchorLocalOffset = 0,
  }) => _commands.saveScrollOffset(
    offset,
    anchorStableKey: anchorStableKey,
    anchorLocalOffset: anchorLocalOffset,
  );

  Future<void> switchToSearch() => _commands.switchToSearch();

  Future<void> switchToPopular() => _commands.switchToPopular();

  Future<void> switchToFavorites() => _commands.switchToFavorites();

  Future<void> setSource(
    Object source, {
    String? draftQuery,
    String? draftPrompt,
  }) => _commands.setSource(
    source,
    draftQuery: draftQuery,
    draftPrompt: draftPrompt,
  );

  Future<void> setPopularSource(
    Object source, {
    String? draftQuery,
    String? draftPrompt,
  }) => _commands.setPopularSource(
    source,
    draftQuery: draftQuery,
    draftPrompt: draftPrompt,
  );

  Future<void> setFavoritesSource(Object source, {String? draftQuery}) =>
      _commands.setFavoritesSource(source, draftQuery: draftQuery);

  Future<void> searchFavorites(String query) =>
      _commands.searchFavorites(query);

  void syncQuickTagCloudFilterKey() => _commands.syncQuickTagCloudFilterKey();

  Future<void> _ensureQuickTagCloudFilterInitialized() =>
      _commands.ensureQuickTagCloudFilterInitialized();

  void clearDetailCache() => _commands.clearDetailCache();

  Future<void> setPopularScale(PopularScale scale) =>
      _commands.setPopularScale(scale);

  Future<void> setPopularDate(DateTime? date) => _commands.setPopularDate(date);

  Future<void> setAiTagTimeRange(String range) =>
      _commands.setAiTagTimeRange(range);

  Future<void> setAiTagPopularPeriod(String period) =>
      _commands.setAiTagPopularPeriod(period);

  Future<void> setArtistHuntEnabled(bool enabled) =>
      _commands.setArtistHuntEnabled(enabled);

  Future<void> refreshWithDraft({
    required String query,
    required String prompt,
  }) => _commands.refreshWithDraft(query: query, prompt: prompt);

  Future<void> search(String query) => _commands.search(query);

  Future<void> searchWithPrompt(String query, {required String prompt}) =>
      _commands.searchWithPrompt(query, prompt: prompt);

  Future<void> searchPopular({required String query, required String prompt}) =>
      _commands.searchPopular(query: query, prompt: prompt);

  Future<void> setFuzzySearchEnabled(bool enabled) =>
      _commands.setFuzzySearchEnabled(enabled);

  Future<void> setRatings(Set<String> selectedRatings) =>
      _commands.setRatings(selectedRatings);

  Future<void> toggleRating(String rating) => _commands.toggleRating(rating);

  Future<void> setDateRange(DateTime? start, DateTime? end) =>
      _commands.setDateRange(start, end);

  Future<void> clearDateRange() => _commands.clearDateRange();

  Future<void> setRandomEnabled(bool enabled) =>
      _commands.setRandomEnabled(enabled);

  Future<void> restartRandom() => _commands.restartRandom();

  Future<void> _loadRandom({required bool replace, bool restart = false}) =>
      _randomLoader.load(replace: replace, restart: restart);

  String _effectivePromptQuery(String prompt) =>
      resolveOnlineGalleryEffectivePrompt(
        prompt,
        isArtistHuntActive: state.isArtistHuntActive,
      );

  int _serverOrdinaryTagLimit(GallerySourceId sourceId) =>
      resolveOnlineGalleryServerOrdinaryTagLimit(
        sourceId: sourceId,
        danbooruAuth: _danbooruAuth,
        gelbooruAuth: _gelbooruAuth,
      );

  Future<void> loadPosts({bool refresh = false}) async {
    if (_networkRequestsPaused || _deferredLoadCount > 0) return;
    if (state.randomEnabled) {
      await _loadRandom(replace: refresh);
      return;
    }
    if (!refresh && (state.isLoading || state.isLoadingMore)) return;
    switch (state.viewMode) {
      case GalleryViewMode.search:
      case GalleryViewMode.popular:
        await _loadAdapterPage(refresh: refresh);
        break;
      case GalleryViewMode.favorites:
        await _loadFavorites(refresh: refresh);
        break;
    }
  }

  Future<void> loadMore() async {
    final activeCache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    if (state.isLoading ||
        state.isLoadingMore ||
        state.hasError ||
        activeCache.appendErrorCode != null ||
        !state.hasMore ||
        _loadMoreClaimed) {
      return;
    }
    _loadMoreClaimed = true;
    final claimRevision = ++_loadMoreClaimRevision;
    try {
      await loadPosts();
    } finally {
      if (claimRevision == _loadMoreClaimRevision) {
        _loadMoreClaimed = false;
      }
    }
  }

  Future<void> refresh() async {
    if (_networkRequestsPaused) return;
    _cancelCurrentRequest();
    await loadPosts(refresh: true);
  }

  Future<void> retryAppend() async {
    if (_networkRequestsPaused ||
        state.randomEnabled ||
        state.isLoading ||
        state.isLoadingMore ||
        state.currentCache.appendErrorCode == null) {
      return;
    }
    await loadPosts();
  }

  Future<GalleryPageJumpTarget?> goToPage(int page) async {
    if (_networkRequestsPaused || page < 1 || state.randomEnabled) return null;

    _cancelCurrentRequest();
    final jumpRevision = ++_pageJumpRevision;
    var cache = state.currentCache;

    // Legacy/restored caches can contain records without response boundaries.
    // Rebuild from page 1 rather than manufacturing an index from pageSize.
    if (cache.posts.isNotEmpty && cache.pageBoundaries.isEmpty) {
      await loadPosts(refresh: true);
      if (jumpRevision != _pageJumpRevision) return null;
      cache = state.currentCache;
    }

    if (cache.boundaryForPage(page) == null &&
        page != cache.lastLoadedPage + 1) {
      if (state.viewMode == GalleryViewMode.favorites) {
        await _loadFavorites(refresh: false, targetPage: page);
      } else {
        await _loadAdapterPage(refresh: false, initialCursor: '$page');
      }
      if (jumpRevision != _pageJumpRevision) return null;
      cache = state.currentCache;
    }

    while (cache.boundaryForPage(page) == null &&
        cache.lastLoadedPage < page &&
        cache.hasMore) {
      await loadPosts();
      if (jumpRevision != _pageJumpRevision) return null;
      cache = state.currentCache;
    }

    final boundary = cache.boundaryForPage(page);
    if (boundary == null || boundary.startIndex >= cache.posts.length) {
      return null;
    }
    final item = cache.posts[boundary.startIndex];
    state = state.updateCurrentCache(cache.copyWith(page: page));
    return GalleryPageJumpTarget(
      page: page,
      itemIndex: boundary.startIndex,
      stableKey: item.stableKey,
    );
  }

  Future<void> _loadAdapterPage({
    required bool refresh,
    String? initialCursor,
  }) => _pagination.load(refresh: refresh, initialCursor: initialCursor);

  Future<void> _loadFavorites({required bool refresh, int? targetPage}) =>
      _favoritesLoader.load(refresh: refresh, targetPage: targetPage);

  bool _canLoadRemoteFavorites(GallerySourceId sourceId) =>
      _authScopes.canLoadRemoteFavorites(
        sourceId: sourceId,
        danbooru: _danbooruAuth,
        gelbooru: _gelbooruAuth,
      );

  Future<({List<GalleryItem> items, int detailFailures})>
  _filterByBlacklistCompletingDetails(
    List<GalleryItem> items,
    Set<String> blacklist,
  ) => _blacklistFilter.filter(
    items: items,
    blacklist: blacklist,
    details: _details,
  );

  GalleryDetail? peekDetail(GalleryItem item) =>
      _favoriteActions.peekDetail(item);

  Future<GalleryDetail> loadDetail(
    GalleryItem item, {
    bool forceRefresh = false,
    GalleryDetailPriority priority = GalleryDetailPriority.interactive,
  }) => _favoriteActions.loadDetail(
    item,
    forceRefresh: forceRefresh,
    priority: priority,
  );

  void cancelDetail(GalleryItem item) => _favoriteActions.cancelDetail(item);

  Future<bool> addFavorite(Object postOrId) =>
      _favoriteActions.addFavorite(postOrId);

  Future<bool> removeFavorite(Object postOrId) =>
      _favoriteActions.removeFavorite(postOrId);

  Future<void> recordQuickTagCloudViewed(GalleryItem item) =>
      _favoriteActions.recordQuickTagCloudViewed(item);

  Future<int> saveVisiblePostsToLocalFavorites() =>
      _favoriteActions.saveVisiblePostsToLocalFavorites();

  Future<bool> toggleFavorite(Object postOrId) =>
      _favoriteActions.toggleFavorite(postOrId);

  bool isFavorited(Object postOrId) => _favoriteActions.isFavorited(postOrId);

  bool isLocallyFavorited(GalleryItem item) =>
      _favoriteActions.isLocallyFavorited(item);

  bool isRemotelyFavorited(GalleryItem item) =>
      _favoriteActions.isRemotelyFavorited(item);

  void clearNotice() => _favoriteActions.clearNotice();

  void invalidateGelbooruFavorites() =>
      _favoriteActions.invalidateGelbooruFavorites();

  OnlineGalleryErrorCode _errorCode(Object error) => mapOnlineGalleryErrorCode(
    error,
    state.activeSourceId,
    errorMapper: _errorMapper,
  );
}
