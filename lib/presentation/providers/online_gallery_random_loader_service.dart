import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/online_gallery_detail_coordinator.dart';
import '../../core/online_gallery/gallery_tag_query.dart';
import '../../core/online_gallery/online_gallery_load_coordinator.dart';
import '../../data/datasources/remote/online_gallery/gallery_random_sampler.dart';
import '../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/repositories/online_gallery_local_favorites_repository.dart';
import '../../data/repositories/online_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/online_gallery_artist_hunt_service.dart';
import '../../data/services/online_gallery/online_gallery_random_service.dart';
import '../../data/services/online_gallery/online_gallery_search_service.dart';
import 'online_gallery_blacklist_provider.dart';
import 'online_gallery_dependencies.dart';
import 'online_gallery_feed_helpers.dart';
import 'online_gallery_local_favorites_provider.dart';
import 'online_gallery_state.dart';
import 'quick_tag_cloud_gallery_provider.dart';

class OnlineGalleryRandomLoaderService {
  OnlineGalleryRandomLoaderService({
    required Ref ref,
    required OnlineGalleryState Function() readState,
    required void Function(OnlineGalleryState next) reduce,
    required bool Function() isNetworkBlocked,
    required OnlineGalleryRequestHandle Function() beginRequest,
    required bool Function(OnlineGalleryRequestHandle request) isActive,
    required bool Function(OnlineGalleryRequestHandle request, String cacheKey)
    isCurrent,
    required Future<void> Function() ensureQuickFilter,
    required Future<void> Function(GallerySourceId sourceId) ensureAuth,
    required OnlineGalleryRepository Function() repository,
    required OnlineGalleryDetailCoordinator Function() details,
    required OnlineGallerySearchService search,
    required DanbooruAuthState Function() danbooruAuth,
    required GelbooruAuthState Function() gelbooruAuth,
    required bool Function(GallerySourceId sourceId) canLoadRemoteFavorites,
    required Future<({List<GalleryItem> items, int detailFailures})> Function(
      List<GalleryItem> items,
      Set<String> blacklist,
    )
    filterBlacklist,
    required int Function(GallerySourceId sourceId) serverTagLimit,
    required String Function(String prompt) effectivePrompt,
    required OnlineGalleryErrorCode Function(Object error) errorCode,
  }) : _ref = ref,
       _readState = readState,
       _reduce = reduce,
       _isNetworkBlocked = isNetworkBlocked,
       _beginRequest = beginRequest,
       _isActive = isActive,
       _isCurrent = isCurrent,
       _ensureQuickFilter = ensureQuickFilter,
       _ensureAuth = ensureAuth,
       _repository = repository,
       _details = details,
       _search = search,
       _danbooruAuth = danbooruAuth,
       _gelbooruAuth = gelbooruAuth,
       _canLoadRemoteFavorites = canLoadRemoteFavorites,
       _filterBlacklist = filterBlacklist,
       _serverTagLimit = serverTagLimit,
       _effectivePrompt = effectivePrompt,
       _errorCode = errorCode;

  static const int _pageSize = onlineGalleryPageSize;
  final Ref _ref;
  final OnlineGalleryState Function() _readState;
  final void Function(OnlineGalleryState next) _reduce;
  final bool Function() _isNetworkBlocked;
  final OnlineGalleryRequestHandle Function() _beginRequest;
  final bool Function(OnlineGalleryRequestHandle request) _isActive;
  final bool Function(OnlineGalleryRequestHandle request, String cacheKey)
  _isCurrent;
  final Future<void> Function() _ensureQuickFilter;
  final Future<void> Function(GallerySourceId sourceId) _ensureAuth;
  final OnlineGalleryRepository Function() _repository;
  final OnlineGalleryDetailCoordinator Function() _details;
  final OnlineGallerySearchService _search;
  final DanbooruAuthState Function() _danbooruAuth;
  final GelbooruAuthState Function() _gelbooruAuth;
  final bool Function(GallerySourceId sourceId) _canLoadRemoteFavorites;
  final Future<({List<GalleryItem> items, int detailFailures})> Function(
    List<GalleryItem> items,
    Set<String> blacklist,
  )
  _filterBlacklist;
  final int Function(GallerySourceId sourceId) _serverTagLimit;
  final String Function(String prompt) _effectivePrompt;
  final OnlineGalleryErrorCode Function(Object error) _errorCode;
  final OnlineGalleryArtistHuntService _artistHunt =
      const OnlineGalleryArtistHuntService();
  final OnlineGalleryRandomService _random = const OnlineGalleryRandomService();

  OnlineGalleryState get state => _readState();
  set state(OnlineGalleryState next) => _reduce(next);

  Future<void> load({required bool replace, bool restart = false}) async {
    if (_isNetworkBlocked() || !state.randomEnabled || !state.supportsRandom) {
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
      await Future.wait([_ensureQuickFilter(), _ensureAuth(sourceId)]);
      if (!_isActive(requestHandle) ||
          !state.randomEnabled ||
          !state.supportsRandom ||
          state.activeSourceId != sourceId) {
        return;
      }
      cacheKey = state.currentCacheKey;
      await _ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (!_isActive(requestHandle) || !state.randomEnabled) {
        return;
      }
      final blacklist = _ref.read(onlineGalleryBlacklistNotifierProvider).tags;
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
        serverTagLimit: _serverTagLimit(sourceId),
        fuzzySearchEnabled: state.fuzzySearchEnabled,
        rawQuery: rawTagQuery,
        metadataLoader: _ref.read(onlineGalleryTagMetadataLoaderProvider),
      );
      if (!_isActive(requestHandle) || !state.randomEnabled) {
        return;
      }
      final randomRequest = _randomRequest(session, blacklist, tagPlan);
      final page = await _repository().random(
        sourceId,
        randomRequest,
        cancelToken: requestCancelToken,
      );
      if (!_isActive(requestHandle) ||
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
            _repository().detail(item, cancelToken: cancelToken),
      );
      if (!_isActive(requestHandle) ||
          !state.randomEnabled ||
          state.currentCacheKey != cacheKey) {
        return;
      }
      final blacklistFiltered = await _filterBlacklist(
        tagFiltered.items,
        blacklist,
      );
      if (!_isActive(requestHandle) ||
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
          if (!_isActive(requestHandle) || !state.randomEnabled) {
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
          details: _details(),
          isCurrent: () =>
              _isCurrent(requestHandle, cacheKey) && state.randomEnabled,
          deduplicationKeys: artistHuntDeduplicationKeys,
          onProgress: (items, resolvedDelta, failureDelta) {
            if (!_isActive(requestHandle) || !state.randomEnabled) {
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
      if (!_isActive(requestHandle) || !state.randomEnabled) {
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
    await _ref.read(onlineGalleryLocalFavoritesProvider.notifier).initialize();
    if (!_isCurrent(requestHandle, cacheKey) || !state.randomEnabled) {
      return;
    }
    final scopeKey = _randomScopeKey(blacklist);
    var session = state.randomSession;
    if (restart || session.scopeKey != scopeKey) {
      session = RandomGallerySession(scopeKey: scopeKey);
    }
    final localState = _ref.read(onlineGalleryLocalFavoritesProvider);
    final quickTagFilter =
        state.favoritesSourceId == GallerySourceId.quickTagCloud
        ? _ref.read(quickTagCloudFilterProvider)
        : null;
    final page = _ref
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
      GallerySourceId.danbooru => _danbooruAuth().user?.name ?? 'anonymous',
      GallerySourceId.gelbooru =>
        _gelbooruAuth().credentials?.userId.toString() ?? 'anonymous',
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
          prompt: _effectivePrompt(state.promptQuery),
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
          prompt: _effectivePrompt(state.popularPromptQuery),
          ratings: state.selectedRatings,
          blacklistTags: blacklist,
          cursor: session.nextCursor,
        );
      case GalleryViewMode.favorites:
        final identity = switch (state.favoritesSourceId) {
          GallerySourceId.danbooru => _danbooruAuth().user?.name,
          GallerySourceId.gelbooru =>
            _gelbooruAuth().credentials?.userId.toString(),
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
}
