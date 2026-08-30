import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/online_gallery_detail_coordinator.dart';
import '../../core/online_gallery/online_gallery_load_coordinator.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/repositories/online_gallery_repository.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/online_gallery_artist_hunt_service.dart';
import '../../data/services/online_gallery/online_gallery_query.dart';
import '../../data/services/online_gallery/online_gallery_search_service.dart';
import 'online_gallery_blacklist_provider.dart';
import 'online_gallery_dependencies.dart';
import 'online_gallery_state.dart';

class OnlineGalleryPaginationService {
  OnlineGalleryPaginationService({
    required Ref ref,
    required OnlineGalleryState Function() readState,
    required void Function(OnlineGalleryState next) reduce,
    required OnlineGalleryRequestHandle Function() beginRequest,
    required bool Function(OnlineGalleryRequestHandle request, String cacheKey)
    isCurrent,
    required bool Function(OnlineGalleryRequestHandle request) isActive,
    required Future<void> Function() ensureQuickFilter,
    required Future<void> Function(GallerySourceId sourceId) ensureAuth,
    required OnlineGalleryRepository Function() repository,
    required OnlineGalleryDetailCoordinator Function() details,
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
       _beginRequest = beginRequest,
       _isCurrent = isCurrent,
       _isActive = isActive,
       _ensureQuickFilter = ensureQuickFilter,
       _ensureAuth = ensureAuth,
       _repository = repository,
       _details = details,
       _filterBlacklist = filterBlacklist,
       _serverTagLimit = serverTagLimit,
       _effectivePrompt = effectivePrompt,
       _errorCode = errorCode;

  static const int _pageSize = 60;
  static const int _residualScanPageBudget = 8;
  final Ref _ref;
  final OnlineGalleryState Function() _readState;
  final void Function(OnlineGalleryState next) _reduce;
  final OnlineGalleryRequestHandle Function() _beginRequest;
  final bool Function(OnlineGalleryRequestHandle request, String cacheKey)
  _isCurrent;
  final bool Function(OnlineGalleryRequestHandle request) _isActive;
  final Future<void> Function() _ensureQuickFilter;
  final Future<void> Function(GallerySourceId sourceId) _ensureAuth;
  final OnlineGalleryRepository Function() _repository;
  final OnlineGalleryDetailCoordinator Function() _details;
  final Future<({List<GalleryItem> items, int detailFailures})> Function(
    List<GalleryItem> items,
    Set<String> blacklist,
  )
  _filterBlacklist;
  final int Function(GallerySourceId sourceId) _serverTagLimit;
  final String Function(String prompt) _effectivePrompt;
  final OnlineGalleryErrorCode Function(Object error) _errorCode;
  final OnlineGallerySearchService _search = OnlineGallerySearchService();
  final OnlineGalleryQuery _query = const OnlineGalleryQuery();
  final OnlineGalleryArtistHuntService _artistHunt =
      const OnlineGalleryArtistHuntService();

  OnlineGalleryState get state => _readState();
  set state(OnlineGalleryState next) => _reduce(next);

  void clearSource(GallerySourceId sourceId) => _search.clearSource(sourceId);
  void dispose() => _search.clear();

  Future<void> load({required bool refresh, String? initialCursor}) async {
    final sourceId = state.viewMode == GalleryViewMode.popular
        ? state.popularSourceId
        : state.sourceId;
    final generation = _beginRequest();
    final requestCancelToken = generation.cancelToken;
    var cache = state.currentCache;
    var cacheKey = state.currentCacheKey;
    var isAppend = !refresh && cache.posts.isNotEmpty;

    // Claim the append synchronously. Scroll and underfill callbacks can fire
    // in the same frame; publishing this state before authentication/setup
    // makes them converge on one request and exposes the runway immediately.
    state = state.copyWith(
      isLoading: !isAppend,
      isLoadingMore: isAppend,
      clearError: true,
    );
    if (isAppend) {
      state = state.updateCurrentCache(cache.copyWith(clearAppendError: true));
    }

    try {
      await Future.wait([_ensureQuickFilter(), _ensureAuth(sourceId)]);
      if (!_isActive(generation) ||
          state.randomEnabled ||
          state.activeSourceId != sourceId) {
        return;
      }
      cache = state.currentCache;
      cacheKey = state.currentCacheKey;
      isAppend = !refresh && cache.posts.isNotEmpty;
      final cursor = initialCursor ?? (refresh ? '1' : cache.nextCursor);
      if (cursor == null) {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
        return;
      }
      state = state.copyWith(isLoading: !isAppend, isLoadingMore: isAppend);
      final adapter = _repository().adapter(sourceId);
      await _ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (!_isCurrent(generation, cacheKey)) return;
      final blacklist = _ref.read(onlineGalleryBlacklistNotifierProvider).tags;
      final rawTagQuery = state.viewMode == GalleryViewMode.popular
          ? state.popularQuery
          : state.searchQuery;
      final tagPlan = await _search.buildPlan(
        sourceId: sourceId,
        feedKind: state.activeFeedKind,
        serverTagLimit: _serverTagLimit(sourceId),
        fuzzySearchEnabled: state.fuzzySearchEnabled,
        rawQuery: rawTagQuery,
        metadataLoader: _ref.read(onlineGalleryTagMetadataLoaderProvider),
      );
      if (!_isCurrent(generation, cacheKey)) return;
      final tagCapabilities = sourceId.capabilities.tagSearch;
      final requiresLocalQueryValidation =
          tagPlan.query.ordinaryClauses.isNotEmpty &&
          (!tagCapabilities.appliesOrdinaryQuery(state.activeFeedKind) ||
              tagPlan.requiresLocalFiltering ||
              tagCapabilities.validatesPushdownLocally);
      AiTagSourceConfig? aiTagConfig;
      if (adapter is AiTagGallerySourceAdapter) {
        aiTagConfig = await adapter.getConfig(cancelToken: requestCancelToken);
        if (!_isCurrent(generation, cacheKey)) return;
      }
      final artistHuntActive = state.isArtistHuntActive;
      final resetsQuery = refresh || cache.pageBoundaries.isEmpty;
      final baseItems = resetsQuery
          ? ChunkedGalleryItems()
          : cache.posts is ChunkedGalleryItems
          ? cache.posts as ChunkedGalleryItems
          : ChunkedGalleryItems.from(cache.posts);
      final pageBoundaries = <GalleryPageBoundary>[
        if (!resetsQuery) ...cache.pageBoundaries,
      ];
      final huntKeys = artistHuntActive
          ? _artistHunt.deduplicationKeys(baseItems)
          : null;
      var merged = baseItems;
      var candidateCount = refresh ? 0 : cache.artistHuntCandidateCount;
      var resolvedCount = refresh ? 0 : cache.artistHuntResolvedCount;
      var failureCount = refresh ? 0 : cache.artistHuntFailureCount;
      var matchedItemCount = 0;
      var queryRequestCount = refresh ? 0 : cache.queryRequestCount;
      var queryCandidateCount = refresh ? 0 : cache.queryCandidateCount;
      var queryFilterMicros = refresh ? 0 : cache.queryFilterMicros;
      var detailFailureCount = refresh ? 0 : cache.queryDetailFailureCount;
      var requestCursor = cursor;
      var pagesFetched = 0;
      var stalledCursor = false;
      var repeatedRawPage = false;
      var duplicateResponsePage = false;
      var scanBudgetReached = false;
      var previousRawIdentity = refresh ? null : cache.lastRawPageIdentity;
      final visitedCursors = <String>{};
      late GalleryPage page;
      while (true) {
        pagesFetched++;
        queryRequestCount++;
        visitedCursors.add(requestCursor);
        page = state.viewMode == GalleryViewMode.popular
            ? await _repository().ranking(
                sourceId,
                GalleryRankingRequest(
                  cursor: requestCursor,
                  pageSize: sourceId == GallerySourceId.aiTag
                      ? (aiTagConfig?.pageSize ?? 60)
                      : _pageSize,
                  kind: sourceId == GallerySourceId.aiTag
                      ? GalleryRankingKind.aiTagMonthly
                      : _rankingKind(state.popularScale),
                  date: state.popularDate,
                  period: state.aiTagPopularPeriod,
                  query: tagPlan.serverQuery,
                  prompt: _effectivePrompt(state.popularPromptQuery),
                  ratings: state.selectedRatings,
                  blacklistTags: blacklist,
                ),
                cancelToken: requestCancelToken,
              )
            : await _repository().search(
                sourceId,
                GallerySearchRequest(
                  cursor: requestCursor,
                  pageSize: sourceId == GallerySourceId.aiTag
                      ? (aiTagConfig?.pageSize ?? 60)
                      : _pageSize,
                  query: tagPlan.serverQuery,
                  prompt: _effectivePrompt(state.promptQuery),
                  timeRange: state.aiTagTimeRange,
                  ratings: state.selectedRatings,
                  dateStart: state.dateRangeStart,
                  dateEnd: state.dateRangeEnd,
                  blacklistTags: blacklist,
                ),
                cancelToken: requestCancelToken,
              );
        if (!_isCurrent(generation, cacheKey)) return;
        final rawIdentity =
            page.rawPageIdentity ??
            (page.items.isNotEmpty ? _query.rawPageIdentity(page.items) : null);
        if (rawIdentity != null && rawIdentity.isNotEmpty) {
          if (rawIdentity == previousRawIdentity) {
            repeatedRawPage = true;
            break;
          }
          previousRawIdentity = rawIdentity;
        }
        queryCandidateCount += page.items.length;
        final predecessor = pageBoundaries
            .where((boundary) => boundary.nextCursor == page.cursor)
            .firstOrNull;
        final boundaryPage = galleryCursorPage(
          page.cursor,
          fallback: predecessor?.page == null ? 1 : predecessor!.page + 1,
        );
        final laterBoundaryIndex = pageBoundaries.indexWhere(
          (boundary) => boundary.page > boundaryPage,
        );
        final insertionIndex = laterBoundaryIndex < 0
            ? merged.length
            : pageBoundaries[laterBoundaryIndex].startIndex;
        final itemCountBeforePage = merged.length;
        final tagFiltered = await _search.filterByPlan(
          candidates: page.items,
          plan: tagPlan,
          capabilities: sourceId.capabilities.tagSearch,
          feedKind: state.activeFeedKind,
          cancelToken: requestCancelToken,
          detailLoader: (item, _) {
            return _details().request(
              item,
              priority: GalleryDetailPriority.visible,
            );
          },
        );
        queryFilterMicros += tagFiltered.filterMicros;
        detailFailureCount += tagFiltered.detailFailures;
        if (!_isCurrent(generation, cacheKey)) return;
        final blacklistFiltered = await _filterBlacklist(
          tagFiltered.items,
          blacklist,
        );
        detailFailureCount += blacklistFiltered.detailFailures;
        List<GalleryItem> visibleItems = blacklistFiltered.items;
        if (!_isCurrent(generation, cacheKey)) return;
        if (artistHuntActive) {
          candidateCount += visibleItems.length;
          final resolution = await _artistHunt.resolve(
            candidates: visibleItems,
            details: _details(),
            isCurrent: () => _isCurrent(generation, cacheKey),
            deduplicationKeys: huntKeys!,
            onProgress: (items, resolvedDelta, failureDelta) {
              if (!_isCurrent(generation, cacheKey)) return;
              resolvedCount += resolvedDelta;
              failureCount += failureDelta;
              if (items.isNotEmpty) {
                final insertAt =
                    insertionIndex + (merged.length - itemCountBeforePage);
                merged = insertAt == merged.length
                    ? merged.appendPage(items)
                    : merged.insertPage(insertAt, items);
              }
              state = state.updateCurrentCache(
                cache.copyWith(
                  posts: merged,
                  scrollOffset: refresh ? 0 : cache.scrollOffset,
                  artistHuntCandidateCount: candidateCount,
                  artistHuntResolvedCount: resolvedCount,
                  artistHuntFailureCount: failureCount,
                  clearAppendError: true,
                ),
              );
            },
          );
          if (resolution == null) return;
          if (visibleItems.isNotEmpty &&
              resolution.resolvedCount == 0 &&
              resolution.failureCount > 0) {
            throw OnlineGalleryArtistHuntDetailException(
              resolution.failureCount,
            );
          }
          visibleItems = resolution.items;
        } else {
          merged = insertionIndex == merged.length
              ? merged.appendPage(visibleItems)
              : merged.insertPage(insertionIndex, visibleItems);
        }
        final uniqueItemCount = merged.length - itemCountBeforePage;
        matchedItemCount += uniqueItemCount;
        if (uniqueItemCount > 0 && laterBoundaryIndex >= 0) {
          for (
            var boundaryIndex = laterBoundaryIndex;
            boundaryIndex < pageBoundaries.length;
            boundaryIndex++
          ) {
            final boundary = pageBoundaries[boundaryIndex];
            pageBoundaries[boundaryIndex] = GalleryPageBoundary(
              page: boundary.page,
              cursor: boundary.cursor,
              startIndex: boundary.startIndex + uniqueItemCount,
              endIndex: boundary.endIndex + uniqueItemCount,
              rawItemCount: boundary.rawItemCount,
              nextCursor: boundary.nextCursor,
            );
          }
        }
        final boundary = GalleryPageBoundary(
          page: boundaryPage,
          cursor: page.cursor,
          startIndex: insertionIndex,
          endIndex: insertionIndex + uniqueItemCount,
          rawItemCount: page.rawItemCount,
          nextCursor: page.nextCursor,
        );
        if (laterBoundaryIndex < 0) {
          pageBoundaries.add(boundary);
        } else {
          pageBoundaries.insert(laterBoundaryIndex, boundary);
        }
        duplicateResponsePage = visibleItems.isNotEmpty && uniqueItemCount == 0;
        final nextCursor = page.nextCursor;
        final needsMore =
            (page.rawItemCount > 0 &&
                visibleItems.length < page.rawItemCount) ||
            requiresLocalQueryValidation;
        stalledCursor =
            needsMore &&
            nextCursor != null &&
            visitedCursors.contains(nextCursor);
        final shouldContinue =
            !duplicateResponsePage &&
            needsMore &&
            matchedItemCount < _pageSize &&
            page.hasMore &&
            nextCursor != null &&
            !stalledCursor;
        scanBudgetReached =
            shouldContinue &&
            requiresLocalQueryValidation &&
            pagesFetched >= _residualScanPageBudget;
        if (!shouldContinue || scanBudgetReached) break;
        requestCursor = nextCursor;
        state = state.updateCurrentCache(
          cache.copyWith(
            posts: merged,
            pageBoundaries: pageBoundaries,
            nextCursor: nextCursor,
            hasMore: true,
            scrollOffset: refresh ? 0 : cache.scrollOffset,
            queryRequestCount: queryRequestCount,
            queryCandidateCount: queryCandidateCount,
            queryFilterMicros: queryFilterMicros,
            queryDetailFailureCount: detailFailureCount,
            lastRawPageIdentity: previousRawIdentity,
            queryScanPaused: false,
            clearAppendError: true,
          ),
        );
        if (queryRequestCount.isEven) await Future<void>.delayed(Duration.zero);
      }
      final endedByDuplicate =
          duplicateResponsePage || stalledCursor || repeatedRawPage;
      final firstVisibleBoundary = pageBoundaries.firstWhere(
        (boundary) => boundary.endIndex > boundary.startIndex,
        orElse: () => pageBoundaries.first,
      );
      final visiblePage = resetsQuery ? firstVisibleBoundary.page : cache.page;
      final tailBoundary = pageBoundaries.last;
      final responsePredecessor = pageBoundaries
          .where((boundary) => boundary.nextCursor == page.cursor)
          .firstOrNull;
      final responsePage = galleryCursorPage(
        page.cursor,
        fallback: responsePredecessor == null
            ? 1
            : responsePredecessor.page + 1,
      );
      final loadedTail = tailBoundary.page <= responsePage;
      final tailNextCursor = loadedTail && endedByDuplicate
          ? null
          : tailBoundary.nextCursor;
      final nextCache = ModeCache(
        posts: merged,
        page: visiblePage,
        pageBoundaries: pageBoundaries,
        nextCursor: tailNextCursor,
        total: artistHuntActive
            ? null
            : loadedTail
            ? page.total
            : cache.total,
        hasMore: loadedTail
            ? !endedByDuplicate && page.hasMore && tailNextCursor != null
            : cache.hasMore && tailNextCursor != null,
        scrollOffset: refresh ? 0 : cache.scrollOffset,
        endedByDuplicatePage: loadedTail
            ? endedByDuplicate
            : cache.endedByDuplicatePage,
        artistHuntCandidateCount: candidateCount,
        artistHuntResolvedCount: resolvedCount,
        artistHuntFailureCount: failureCount,
        queryRequestCount: queryRequestCount,
        queryCandidateCount: queryCandidateCount,
        queryFilterMicros: queryFilterMicros,
        queryDetailFailureCount: detailFailureCount,
        lastRawPageIdentity: loadedTail
            ? previousRawIdentity
            : cache.lastRawPageIdentity,
        queryScanPaused: scanBudgetReached,
      );
      final invalidGelbooru =
          sourceId == GallerySourceId.gelbooru &&
          _ref.read(gelbooruAuthProvider).status == GelbooruAuthStatus.invalid;
      state = state
          .copyWith(
            isLoading: false,
            isLoadingMore: false,
            aiTagConfig: aiTagConfig,
            notice: invalidGelbooru
                ? OnlineGalleryNotice.gelbooruCredentialsInvalid
                : detailFailureCount > 0
                ? OnlineGalleryNotice.tagDetailsIncomplete
                : null,
            clearNotice: !invalidGelbooru && detailFailureCount == 0,
            clearError: true,
          )
          .updateCurrentCache(nextCache);
    } on DioException catch (error) {
      if (error.type != DioExceptionType.cancel) {
        _finishError(error, generation, cacheKey, isAppend);
      }
    } catch (error, stack) {
      AppLogger.e(
        'Failed to load online gallery page',
        error,
        stack,
        'OnlineGallery',
      );
      _finishError(error, generation, cacheKey, isAppend);
    }
  }

  GalleryRankingKind _rankingKind(PopularScale scale) => switch (scale) {
    PopularScale.day => GalleryRankingKind.day,
    PopularScale.week => GalleryRankingKind.week,
    PopularScale.month => GalleryRankingKind.month,
  };

  void _finishError(
    Object error,
    OnlineGalleryRequestHandle request,
    String cacheKey,
    bool isAppend,
  ) {
    if (!_isCurrent(request, cacheKey)) return;
    final code = _errorCode(error);
    state = state.copyWith(isLoading: false, isLoadingMore: false);
    state = isAppend
        ? state.updateCurrentCache(
            state.currentCache.copyWith(appendErrorCode: code),
          )
        : state.copyWith(errorCode: code);
  }
}
