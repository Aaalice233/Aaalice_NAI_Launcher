import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/online_gallery_detail_coordinator.dart';
import '../../core/online_gallery/gallery_tag_query.dart';
import '../../core/online_gallery/online_gallery_load_coordinator.dart';
import '../../core/online_gallery/online_gallery_session_repository.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/gelbooru_api_service.dart';
import '../../data/datasources/remote/online_gallery/gallery_random_sampler.dart';
import '../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/repositories/online_gallery_local_favorites_repository.dart';
import '../../data/repositories/online_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/artist_chain_parser.dart';
import '../../data/services/online_gallery/online_gallery_artist_hunt_service.dart';
import '../../data/services/online_gallery/online_gallery_auth_scope_coordinator.dart';
import '../../data/services/online_gallery/online_gallery_blacklist_filter_service.dart';
import '../../data/services/online_gallery/online_gallery_error_mapper.dart';
import '../../data/services/online_gallery/online_gallery_favorites_service.dart';
import '../../data/services/online_gallery/online_gallery_query.dart';
import '../../data/services/online_gallery/online_gallery_random_service.dart';
import '../../data/services/online_gallery/online_gallery_search_service.dart';
import 'online_gallery_blacklist_provider.dart';
import 'online_gallery_command_service.dart';
import 'online_gallery_dependencies.dart';
import 'online_gallery_detail_favorite_service.dart';
import 'online_gallery_lifecycle_service.dart';
import 'online_gallery_local_favorites_provider.dart';
import 'online_gallery_pagination_service.dart';
import 'online_gallery_state.dart';
import 'quick_tag_cloud_gallery_provider.dart';

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

const int onlineGalleryPageSize = 60;

class GalleryPageJumpTarget {
  const GalleryPageJumpTarget({
    required this.page,
    required this.itemIndex,
    required this.stableKey,
  });

  final int page;
  final int itemIndex;
  final String stableKey;
}

@riverpod
class OnlineGalleryNotifier extends _$OnlineGalleryNotifier {
  static const int _pageSize = onlineGalleryPageSize;
  final OnlineGalleryLoadCoordinator _loadCoordinator =
      OnlineGalleryLoadCoordinator();
  final OnlineGalleryArtistHuntService _artistHunt =
      const OnlineGalleryArtistHuntService();
  final OnlineGalleryAuthScopeCoordinator _authScopes =
      const OnlineGalleryAuthScopeCoordinator();
  final OnlineGalleryBlacklistFilterService _blacklistFilter =
      const OnlineGalleryBlacklistFilterService(OnlineGalleryQuery());
  final OnlineGalleryErrorMapper _errorMapper =
      const OnlineGalleryErrorMapper();
  final OnlineGalleryFavoritesService _favorites =
      const OnlineGalleryFavoritesService();
  final OnlineGalleryRandomService _random = const OnlineGalleryRandomService();
  OnlineGalleryCommandService? _commandService;
  OnlineGalleryDetailCoordinator? _detailCoordinator;
  OnlineGalleryDetailFavoriteService? _detailFavorites;
  OnlineGalleryLifecycleService? _lifecycleService;
  OnlineGalleryPaginationService? _paginationService;
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
      state = state.copyWith();
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

  Future<void> _loadRandom({
    required bool replace,
    bool restart = false,
  }) async {
    if (_networkRequestsPaused ||
        _deferredLoadCount > 0 ||
        !state.randomEnabled ||
        !state.supportsRandom) {
      return;
    }
    if (!replace &&
        (state.isLoading ||
            state.isLoadingMore ||
            state.randomSession.exhausted)) {
      return;
    }

    // Claim generation before initialization so older setup cannot win.
    final sourceId = state.activeSourceId;
    final requestHandle = _beginRequest();
    final requestCancelToken = requestHandle.cancelToken;
    var cacheKey = state.currentCacheKey;
    state = state.copyWith(
      isLoading: replace,
      isLoadingMore: !replace,
      clearError: true,
    );
    try {
      await Future.wait([
        _ensureQuickTagCloudFilterInitialized(),
        _ensureAuthenticationReady(sourceId),
      ]);
      if (!_loadCoordinator.isCurrent(requestHandle) ||
          !state.randomEnabled ||
          !state.supportsRandom ||
          state.activeSourceId != sourceId) {
        return;
      }
      cacheKey = state.currentCacheKey;
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (!_loadCoordinator.isCurrent(requestHandle) || !state.randomEnabled) {
        return;
      }
      final blacklist = ref.read(onlineGalleryBlacklistNotifierProvider).tags;
      if (state.viewMode == GalleryViewMode.favorites &&
          !_canLoadRemoteFavorites(state.favoritesSourceId)) {
        await _loadRandomLocalFavorites(
          requestHandle: requestHandle,
          cacheKey: cacheKey,
          blacklist: blacklist,
          replace: replace,
          restart: restart,
        );
        return;
      }
      final scopeKey = _randomScopeKey(blacklist);
      var session = state.randomSession;
      if (restart || session.scopeKey != scopeKey) {
        final restoredPosition = !restart && session.cache.posts.isEmpty
            ? session.cache
            : const ModeCache();
        session = RandomGallerySession(
          scopeKey: scopeKey,
          cache: restoredPosition,
        );
      }
      if (_random.isExhausted(session.seenStableKeys)) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          randomSession: session.copyWith(exhausted: true),
        );
        return;
      }

      final rawTagQuery = switch (state.viewMode) {
        GalleryViewMode.search => state.searchQuery,
        GalleryViewMode.popular => state.popularQuery,
        GalleryViewMode.favorites => '',
      };
      final tagPlan = await _search.buildPlan(
        sourceId: sourceId,
        feedKind: state.activeFeedKind,
        serverTagLimit: _serverOrdinaryTagLimit(sourceId),
        fuzzySearchEnabled: state.fuzzySearchEnabled,
        rawQuery: rawTagQuery,
        metadataLoader: ref.read(onlineGalleryTagMetadataLoaderProvider),
      );
      if (!_loadCoordinator.isCurrent(requestHandle) || !state.randomEnabled) {
        return;
      }
      final randomRequest = _randomRequest(session, blacklist, tagPlan);
      final page = await _repository.random(
        sourceId,
        randomRequest,
        cancelToken: requestCancelToken,
      );
      if (!_loadCoordinator.isCurrent(requestHandle) ||
          !state.randomEnabled ||
          state.currentCacheKey != cacheKey) {
        return;
      }

      final tagFiltered = await _search.filterByPlan(
        candidates: page.items,
        plan: tagPlan,
        capabilities: sourceId.capabilities.tagSearch,
        feedKind: state.activeFeedKind,
        cancelToken: requestCancelToken,
        detailLoader: (item, cancelToken) =>
            _repository.detail(item, cancelToken: cancelToken),
      );
      if (!_loadCoordinator.isCurrent(requestHandle) ||
          !state.randomEnabled ||
          state.currentCacheKey != cacheKey) {
        return;
      }
      final blacklistFiltered = await _filterByBlacklistCompletingDetails(
        tagFiltered.items,
        blacklist,
      );
      if (!_loadCoordinator.isCurrent(requestHandle) ||
          !state.randomEnabled ||
          state.currentCacheKey != cacheKey) {
        return;
      }
      final detailFailures =
          tagFiltered.detailFailures + blacklistFiltered.detailFailures;
      final artistHuntActive = state.isArtistHuntActive;
      final seen = Set<String>.of(session.seenStableKeys);
      final seenCandidates = Set<String>.of(session.seenCandidateStableKeys);
      final candidates = <GalleryItem>[];
      for (var index = 0; index < blacklistFiltered.items.length; index++) {
        if (index > 0 && index % 256 == 0) {
          await Future<void>.delayed(Duration.zero);
          if (!_loadCoordinator.isCurrent(requestHandle) ||
              !state.randomEnabled) {
            return;
          }
        }
        final item = blacklistFiltered.items[index];
        final identity = artistHuntActive
            ? item.detailStableKey
            : item.stableKey;
        final alreadySeen = artistHuntActive
            ? seenCandidates.contains(identity)
            : seen.contains(identity);
        if (alreadySeen || _random.isExhausted(seen)) continue;
        candidates.add(item);
      }

      var posts = replace
          ? ChunkedGalleryItems()
          : session.cache.posts is ChunkedGalleryItems
          ? session.cache.posts as ChunkedGalleryItems
          : ChunkedGalleryItems.from(session.cache.posts);
      final unique = <GalleryItem>[];
      final candidateCount = replace
          ? candidates.length
          : session.cache.artistHuntCandidateCount + candidates.length;
      var resolvedCount = replace ? 0 : session.cache.artistHuntResolvedCount;
      var failureCount = replace ? 0 : session.cache.artistHuntFailureCount;

      if (artistHuntActive) {
        final artistHuntDeduplicationKeys = _artistHunt.deduplicationKeys(
          posts,
        );
        final resolution = await _artistHunt.resolve(
          candidates: candidates,
          details: _details,
          isCurrent: () =>
              _isCurrentRequest(requestHandle, cacheKey) && state.randomEnabled,
          deduplicationKeys: artistHuntDeduplicationKeys,
          onProgress: (items, resolvedDelta, failureDelta) {
            if (!_loadCoordinator.isCurrent(requestHandle) ||
                !state.randomEnabled) {
              return;
            }
            resolvedCount += resolvedDelta;
            failureCount += failureDelta;
            final freshItems = items
                .where((item) {
                  if (_random.isExhausted(seen) || !seen.add(item.stableKey)) {
                    return false;
                  }
                  return true;
                })
                .toList(growable: false);
            unique.addAll(freshItems);
            if (freshItems.isNotEmpty) posts = posts.appendPage(freshItems);
            state = state.copyWith(
              randomSession: session.copyWith(
                cache: session.cache.copyWith(
                  posts: posts,
                  artistHuntCandidateCount: candidateCount,
                  artistHuntResolvedCount: resolvedCount,
                  artistHuntFailureCount: failureCount,
                ),
                seenStableKeys: Set.unmodifiable(seen),
              ),
            );
          },
        );
        if (resolution == null) return;
        if (candidates.isNotEmpty &&
            resolution.resolvedCount == 0 &&
            resolution.failureCount > 0) {
          throw OnlineGalleryArtistHuntDetailException(resolution.failureCount);
        }
        seenCandidates.addAll(resolution.successfulCandidateKeys);
      } else {
        final selection = _random.accept(
          candidates: candidates,
          seenStableKeys: seen,
        );
        seen
          ..clear()
          ..addAll(selection.seenStableKeys);
        unique.addAll(selection.items);
        posts = posts.appendPage(unique);
      }

      final misses = unique.isEmpty ? session.consecutiveMisses + 1 : 0;
      final sourceExhausted =
          sourceId == GallerySourceId.quickTagCloud && !page.hasMore;
      final exhausted = sourceExhausted || _random.isExhausted(seen);
      final nextSession = RandomGallerySession(
        scopeKey: scopeKey,
        cache: session.cache.copyWith(
          posts: posts,
          page: 1,
          nextCursor: page.nextCursor ?? session.nextCursor ?? 'random',
          hasMore: !exhausted,
          total: artistHuntActive ? null : page.total,
          endedByDuplicatePage: exhausted,
          queryScanPaused: unique.isEmpty && !exhausted,
          queryDetailFailureCount: detailFailures,
          artistHuntCandidateCount: candidateCount,
          artistHuntResolvedCount: resolvedCount,
          artistHuntFailureCount: failureCount,
        ),
        seenStableKeys: Set.unmodifiable(seen),
        seenCandidateStableKeys: Set.unmodifiable(seenCandidates),
        nextCursor: page.nextCursor,
        consecutiveMisses: misses,
        drawRevision: session.drawRevision + 1,
        exhausted: exhausted,
      );
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        randomSession: nextSession,
        notice: detailFailures > 0
            ? OnlineGalleryNotice.tagDetailsIncomplete
            : unique.isEmpty && !exhausted
            ? OnlineGalleryNotice.randomDrawNoMatch
            : null,
        clearNotice: detailFailures == 0 && (unique.isNotEmpty || exhausted),
        clearError: true,
      );
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) return;
      if (!_loadCoordinator.isCurrent(requestHandle) || !state.randomEnabled) {
        return;
      }
      final isArtistHuntDetailFailure =
          error is OnlineGalleryArtistHuntDetailException;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: isArtistHuntDetailFailure ? null : error.toString(),
        errorCode: _errorCode(error),
        clearError: isArtistHuntDetailFailure,
      );
    }
  }

  Future<void> _loadRandomLocalFavorites({
    required OnlineGalleryRequestHandle requestHandle,
    required String cacheKey,
    required Set<String> blacklist,
    required bool replace,
    required bool restart,
  }) async {
    await ref.read(onlineGalleryLocalFavoritesProvider.notifier).initialize();
    if (!_isCurrentRequest(requestHandle, cacheKey) || !state.randomEnabled) {
      return;
    }
    final scopeKey = _randomScopeKey(blacklist);
    var session = state.randomSession;
    if (restart || session.scopeKey != scopeKey) {
      session = RandomGallerySession(scopeKey: scopeKey);
    }
    final localState = ref.read(onlineGalleryLocalFavoritesProvider);
    final quickTagFilter =
        state.favoritesSourceId == GallerySourceId.quickTagCloud
        ? ref.read(quickTagCloudFilterProvider)
        : null;
    final page = ref
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .query(
          OnlineGalleryFavoriteQuery(
            sourceId: state.favoritesSourceId,
            searchText: state.favoriteSearchQuery,
            ratings: state.activeCapabilities.supportsRatings
                ? state.selectedRatings
                : const {},
            blacklistTags: blacklist,
            codexId: quickTagFilter?.codexId,
            categoryPath: quickTagFilter?.categoryPath ?? const [],
            mediaFilter: quickTagFilter?.mediaFilter.name ?? 'all',
            limit: max(1, localState.count),
          ),
        );
    final available =
        page.items
            .where((item) => !session.seenStableKeys.contains(item.stableKey))
            .toList(growable: true)
          ..shuffle(Random());
    final selected = available.take(min(_pageSize, available.length)).toList();
    final seen = {...session.seenStableKeys}
      ..addAll(selected.map((item) => item.stableKey));
    final base = replace
        ? ChunkedGalleryItems()
        : session.cache.posts is ChunkedGalleryItems
        ? session.cache.posts as ChunkedGalleryItems
        : ChunkedGalleryItems.from(session.cache.posts);
    final posts = base.appendPage(selected);
    final exhausted = seen.length >= page.total || selected.isEmpty;
    state = state.copyWith(
      isLoading: false,
      isLoadingMore: false,
      randomSession: RandomGallerySession(
        scopeKey: scopeKey,
        cache: session.cache.copyWith(
          posts: posts,
          page: 1,
          nextCursor: exhausted ? null : 'local-random',
          hasMore: !exhausted,
          total: page.total,
          endedByDuplicatePage: exhausted,
        ),
        seenStableKeys: Set.unmodifiable(seen),
        consecutiveMisses: selected.isEmpty ? 1 : 0,
        drawRevision: session.drawRevision + 1,
        exhausted: exhausted,
      ),
      clearError: true,
    );
  }

  String _randomScopeKey(Set<String> blacklist) {
    final sortedBlacklist = blacklist.toList()..sort();
    final accountIdentity = switch (state.activeSourceId) {
      GallerySourceId.danbooru => _danbooruAuth.user?.name ?? 'anonymous',
      GallerySourceId.gelbooru =>
        _gelbooruAuth.credentials?.userId.toString() ?? 'anonymous',
      _ => 'anonymous',
    };
    final feedKind = switch (state.viewMode) {
      GalleryViewMode.search => GalleryFeedKind.search,
      GalleryViewMode.popular => GalleryFeedKind.ranking,
      GalleryViewMode.favorites => GalleryFeedKind.favorites,
    };
    return GalleryRandomScope(
      sourceId: state.activeSourceId,
      feedKind: feedKind,
      fields: {
        'query': state.currentCacheKey,
        'blacklist': sortedBlacklist.join(','),
        'account': accountIdentity,
      },
    ).stableKey;
  }

  GalleryRandomRequest _randomRequest(
    RandomGallerySession session,
    Set<String> blacklist,
    GalleryTagQueryPlan tagPlan,
  ) {
    switch (state.viewMode) {
      case GalleryViewMode.search:
        return GalleryRandomSearchRequest(
          pageSize: _pageSize,
          query: tagPlan.serverQuery,
          prompt: _effectivePromptQuery(state.promptQuery),
          timeRange: state.aiTagTimeRange,
          ratings: state.selectedRatings,
          dateStart: state.dateRangeStart,
          dateEnd: state.dateRangeEnd,
          cursor: session.nextCursor,
          blacklistTags: blacklist,
        );
      case GalleryViewMode.popular:
        return GalleryRandomRankingRequest(
          pageSize: _pageSize,
          kind: state.popularSourceId == GallerySourceId.aiTag
              ? GalleryRankingKind.aiTagMonthly
              : _random.rankingKind(state.popularScale),
          date: state.popularDate,
          period: state.aiTagPopularPeriod,
          query: tagPlan.serverQuery,
          prompt: _effectivePromptQuery(state.popularPromptQuery),
          ratings: state.selectedRatings,
          blacklistTags: blacklist,
          cursor: session.nextCursor,
        );
      case GalleryViewMode.favorites:
        final identity = switch (state.favoritesSourceId) {
          GallerySourceId.danbooru => _danbooruAuth.user?.name,
          GallerySourceId.gelbooru =>
            _gelbooruAuth.credentials?.userId.toString(),
          GallerySourceId.quickTagCloud => '',
          _ => null,
        };
        if (identity == null ||
            (identity.isEmpty &&
                state.favoritesSourceId != GallerySourceId.quickTagCloud)) {
          throw GallerySourceException(
            GallerySourceErrorCode.credentialsRequired,
            source: state.favoritesSourceId,
          );
        }
        return GalleryRandomFavoritesRequest(
          pageSize: _pageSize,
          username: identity,
          cursor: session.nextCursor,
          ratings: state.selectedRatings,
          blacklistTags: blacklist,
        );
    }
  }

  String _effectivePromptQuery(String prompt) {
    return state.isArtistHuntActive
        ? ArtistChainParser.withArtistConstraint(prompt)
        : prompt;
  }

  int _serverOrdinaryTagLimit(GallerySourceId sourceId) {
    final capability = sourceId.capabilities.tagSearch;
    final authenticated = switch (sourceId) {
      GallerySourceId.danbooru => _danbooruAuth.isLoggedIn,
      GallerySourceId.gelbooru => _gelbooruAuth.isAuthenticated,
      _ => false,
    };
    final accountLevel = sourceId == GallerySourceId.danbooru
        ? _danbooruAuth.user?.level
        : null;
    return capability.serverLimit(
      authenticated: authenticated,
      accountLevel: accountLevel,
    );
  }

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

  void _finishRequestError(
    Object error,
    OnlineGalleryRequestHandle request,
    String cacheKey,
    bool isAppend,
    ModeCache cache,
  ) {
    if (!_isCurrentRequest(request, cacheKey)) return;
    final code = _errorCode(error);
    state = state.copyWith(isLoading: false, isLoadingMore: false);
    state = isAppend
        ? state.updateCurrentCache(cache.copyWith(appendErrorCode: code))
        : state.copyWith(errorCode: code);
  }

  Future<void> _loadFavorites({required bool refresh, int? targetPage}) async {
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
      await _ensureAuthenticationReady(sourceId);
      if (_lifecycle.disposed ||
          !_isCurrentRequest(generation, cacheKey) ||
          state.viewMode != GalleryViewMode.favorites ||
          state.favoritesSourceId != sourceId) {
        return;
      }
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (!_isCurrentRequest(generation, cacheKey)) return;
      final blacklist = ref.read(onlineGalleryBlacklistNotifierProvider).tags;
      final quickTagFilter = sourceId == GallerySourceId.quickTagCloud
          ? ref.read(quickTagCloudFilterProvider)
          : null;

      if (cache.localFavoritesHasMore) {
        try {
          final localFavorites = ref.read(
            onlineGalleryLocalFavoritesProvider.notifier,
          );
          await localFavorites.initialize();
          if (!_isCurrentRequest(generation, cacheKey)) return;
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
            remotePage = await _repository.danbooruFavorites(
              username: _danbooruAuth.user!.name,
              page: requestPage,
              limit: _pageSize,
            );
          } else {
            remotePage = await _repository.gelbooruFavorites(
              credentials: _gelbooruAuth.credentials!,
              page: requestPage,
              limit: _pageSize,
              cancelToken: generation.cancelToken,
            );
          }
          if (!_isCurrentRequest(generation, cacheKey)) return;
          rawItemCount += remotePage.rawCount;
          final matching = _query
              .filterLocal(
                items: remotePage.items,
                ratings: state.selectedRatings,
                blacklist: const {},
              )
              .where(
                (item) => _query.matchesFavoriteSearch(
                  item,
                  state.favoriteSearchQuery,
                ),
              )
              .toList(growable: false);
          final remoteResult = await _filterByBlacklistCompletingDetails(
            matching,
            blacklist,
          );
          if (!_isCurrentRequest(generation, cacheKey)) return;
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
            _remoteFavoriteKeys.removeAll(cache.remoteFavoriteItemKeys);
          }
          mergePageItems(remoteItems);
          final remoteItemKeys = resetBranches
              ? loadedRemoteItemKeys
              : {
                  ...cache.remoteFavoriteItemKeys,
                  ...remoteItems.map(onlineGalleryPostKey),
                };
          _remoteFavoriteKeys.addAll(remoteItemKeys);
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
            ref.read(gelbooruAuthProvider.notifier).markInvalid();
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
          _remoteFavoriteKeys.removeAll(cache.remoteFavoriteItemKeys);
        }
        cache = cache.copyWith(
          posts: posts,
          remoteFavoritesHasMore: false,
          remoteFavoriteItemKeys: const {},
          clearRemoteFavoritesError: true,
        );
      }

      if (!_isCurrentRequest(generation, cacheKey)) return;
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
            favoritedPostKeys: {..._localFavoriteKeys, ..._remoteFavoriteKeys},
            localFavoritedPostKeys: _localFavoriteKeys,
            remoteFavoritedPostKeys: _remoteFavoriteKeys,
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

  OnlineGalleryErrorCode _errorCode(Object error) => switch (_errorMapper.map(
    error,
    state.activeSourceId,
  )) {
    OnlineGalleryFailureCode.tooManySearchTags =>
      OnlineGalleryErrorCode.tooManySearchTags,
    OnlineGalleryFailureCode.unsupportedMetatag =>
      OnlineGalleryErrorCode.unsupportedMetatag,
    OnlineGalleryFailureCode.credentialsRequired =>
      OnlineGalleryErrorCode.credentialsRequired,
    OnlineGalleryFailureCode.credentialsInvalid =>
      OnlineGalleryErrorCode.credentialsInvalid,
    OnlineGalleryFailureCode.rateLimited => OnlineGalleryErrorCode.rateLimited,
    OnlineGalleryFailureCode.timeout => OnlineGalleryErrorCode.timeout,
    OnlineGalleryFailureCode.server => OnlineGalleryErrorCode.server,
    OnlineGalleryFailureCode.network => OnlineGalleryErrorCode.network,
    OnlineGalleryFailureCode.malformedResponse =>
      OnlineGalleryErrorCode.malformedResponse,
    OnlineGalleryFailureCode.detailNotFound =>
      OnlineGalleryErrorCode.detailNotFound,
    OnlineGalleryFailureCode.imageUnavailable =>
      OnlineGalleryErrorCode.imageUnavailable,
    OnlineGalleryFailureCode.rankingProcessing =>
      OnlineGalleryErrorCode.rankingProcessing,
    OnlineGalleryFailureCode.configurationUnavailable =>
      OnlineGalleryErrorCode.configurationUnavailable,
    OnlineGalleryFailureCode.requestFailed =>
      OnlineGalleryErrorCode.requestFailed,
    OnlineGalleryFailureCode.gelbooruCredentialsRequired =>
      OnlineGalleryErrorCode.gelbooruCredentialsRequired,
    OnlineGalleryFailureCode.gelbooruCredentialsInvalid =>
      OnlineGalleryErrorCode.gelbooruCredentialsInvalid,
    OnlineGalleryFailureCode.gelbooruRateLimited =>
      OnlineGalleryErrorCode.gelbooruRateLimited,
    OnlineGalleryFailureCode.gelbooruTimeout =>
      OnlineGalleryErrorCode.gelbooruTimeout,
    OnlineGalleryFailureCode.gelbooruServer =>
      OnlineGalleryErrorCode.gelbooruServer,
    OnlineGalleryFailureCode.gelbooruNetwork =>
      OnlineGalleryErrorCode.gelbooruNetwork,
    OnlineGalleryFailureCode.gelbooruMalformedResponse =>
      OnlineGalleryErrorCode.gelbooruMalformedResponse,
    OnlineGalleryFailureCode.gelbooruRequestFailed =>
      OnlineGalleryErrorCode.gelbooruRequestFailed,
    OnlineGalleryFailureCode.artistHuntDetailFailed =>
      OnlineGalleryErrorCode.artistHuntDetailFailed,
  };
}
