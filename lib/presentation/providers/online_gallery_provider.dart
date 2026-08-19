import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/gelbooru_api_service.dart';
import '../../data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/donmai_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/gelbooru_gallery_source_adapter.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/models/online_gallery/gelbooru_post_parser.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import 'online_gallery_blacklist_provider.dart';

part 'online_gallery_provider.g.dart';

const Set<String> kAllRatings = {'g', 's', 'q', 'e'};

String buildOnlineGallerySearchQuery(String query, {required bool fuzzyMatch}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return '';
  final tags = trimmed
      .split(RegExp(r'[,，\s]+'))
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toList(growable: false);
  return tags
      .map((tag) {
        if (!fuzzyMatch || _isOnlineGallerySpecialTag(tag)) return tag;
        return '*$tag*';
      })
      .join(' ');
}

bool _isOnlineGallerySpecialTag(String tag) {
  return tag.contains('*') || tag.contains(':') || tag.startsWith('-');
}

/// Kept as a top-level parser for callers that process large booru responses in
/// an isolate. New source adapters return the same common model.
List<GalleryItem> parsePostsInIsolate(Map<String, dynamic> data) {
  final rawList = data['rawList'] as List;
  final sourceId = GallerySourceId.fromKey(data['source']?.toString() ?? '');
  return rawList
      .whereType<Map>()
      .map((raw) {
        final json = Map<String, dynamic>.from(raw);
        return sourceId == GallerySourceId.gelbooru
            ? parseGelbooruPostJson(json)
            : GalleryItem.fromDanbooruJson(json, sourceId: sourceId);
      })
      .where((item) => item.hasValidPreview)
      .toList(growable: false);
}

enum GalleryViewMode { search, popular, favorites }

enum OnlineGalleryErrorCode {
  credentialsRequired,
  credentialsInvalid,
  rateLimited,
  timeout,
  server,
  network,
  malformedResponse,
  detailNotFound,
  imageUnavailable,
  rankingProcessing,
  configurationUnavailable,
  requestFailed,
  gelbooruCredentialsRequired,
  gelbooruCredentialsInvalid,
  gelbooruRateLimited,
  gelbooruTimeout,
  gelbooruServer,
  gelbooruNetwork,
  gelbooruMalformedResponse,
  gelbooruRequestFailed,
}

enum OnlineGalleryNotice { gelbooruCredentialsInvalid }

String onlineGalleryPostKey(GalleryItem item) => item.stableKey;

@Riverpod(keepAlive: true)
Dio onlineGalleryHttpClient(Ref ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
}

@Riverpod(keepAlive: true)
Map<GallerySourceId, GallerySourceAdapter> onlineGallerySourceAdapters(
  Ref ref,
) {
  final dio = ref.watch(onlineGalleryHttpClientProvider);
  return {
    GallerySourceId.danbooru: DonmaiGallerySourceAdapter(
      sourceId: GallerySourceId.danbooru,
      dio: dio,
    ),
    GallerySourceId.safebooru: DonmaiGallerySourceAdapter(
      sourceId: GallerySourceId.safebooru,
      dio: dio,
    ),
    GallerySourceId.gelbooru: GelbooruGallerySourceAdapter(
      dio: dio,
      apiService: ref.watch(gelbooruApiServiceProvider),
      credentials: () async {
        await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
        return ref.read(gelbooruAuthProvider).credentials;
      },
      markCredentialsInvalid: () {
        ref.read(gelbooruAuthProvider.notifier).markInvalid();
      },
    ),
    GallerySourceId.aiTag: AiTagGallerySourceAdapter(dio: dio),
  };
}

class ModeCache {
  const ModeCache({
    this.posts = const [],
    this.page = 1,
    this.nextCursor = '1',
    this.hasMore = true,
    this.total,
    this.scrollOffset = 0,
    this.appendErrorCode,
    this.endedByDuplicatePage = false,
  });

  final List<GalleryItem> posts;
  final int page;
  final String? nextCursor;
  final bool hasMore;
  final int? total;
  final double scrollOffset;
  final OnlineGalleryErrorCode? appendErrorCode;
  final bool endedByDuplicatePage;

  ModeCache copyWith({
    List<GalleryItem>? posts,
    int? page,
    String? nextCursor,
    bool? hasMore,
    int? total,
    double? scrollOffset,
    OnlineGalleryErrorCode? appendErrorCode,
    bool clearAppendError = false,
    bool? endedByDuplicatePage,
  }) {
    return ModeCache(
      posts: posts ?? this.posts,
      page: page ?? this.page,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      appendErrorCode: clearAppendError
          ? null
          : (appendErrorCode ?? this.appendErrorCode),
      endedByDuplicatePage: endedByDuplicatePage ?? this.endedByDuplicatePage,
    );
  }
}

class OnlineGalleryState {
  const OnlineGalleryState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.errorCode,
    this.notice,
    this.searchQuery = '',
    this.promptQuery = '',
    this.popularQuery = '',
    this.popularPromptQuery = '',
    this.fuzzySearchEnabled = false,
    this.sourceId = GallerySourceId.danbooru,
    this.popularSourceId = GallerySourceId.danbooru,
    this.favoritesSourceId = GallerySourceId.danbooru,
    this.selectedRatings = kAllRatings,
    this.viewMode = GalleryViewMode.search,
    this.searchCache = const ModeCache(),
    this.popularCache = const ModeCache(),
    this.danbooruFavoritesCache = const ModeCache(),
    this.gelbooruFavoritesCache = const ModeCache(),
    this.caches = const {},
    this.popularScale = PopularScale.day,
    this.popularDate,
    this.aiTagTimeRange = 'all',
    this.aiTagPopularPeriod = 'current',
    this.aiTagConfig,
    this.favoritedPostKeys = const {},
    this.favoriteLoadingPostKeys = const {},
    this.dateRangeStart,
    this.dateRangeEnd,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final OnlineGalleryErrorCode? errorCode;
  final OnlineGalleryNotice? notice;
  final String searchQuery;
  final String promptQuery;
  final String popularQuery;
  final String popularPromptQuery;
  final bool fuzzySearchEnabled;
  final GallerySourceId sourceId;
  final GallerySourceId popularSourceId;
  final GallerySourceId favoritesSourceId;
  final Set<String> selectedRatings;
  final GalleryViewMode viewMode;
  final ModeCache searchCache;
  final ModeCache popularCache;
  final ModeCache danbooruFavoritesCache;
  final ModeCache gelbooruFavoritesCache;
  final Map<String, ModeCache> caches;
  final PopularScale popularScale;
  final DateTime? popularDate;
  final String aiTagTimeRange;
  final String aiTagPopularPeriod;
  final AiTagSourceConfig? aiTagConfig;
  final Set<String> favoritedPostKeys;
  final Set<String> favoriteLoadingPostKeys;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;

  GallerySourceCapabilities get activeCapabilities =>
      gallerySourceCapabilities[viewMode == GalleryViewMode.popular
          ? popularSourceId
          : sourceId]!;

  String get currentCacheKey {
    switch (viewMode) {
      case GalleryViewMode.search:
        return 'search:${sourceId.key}:${searchQuery.trim()}|${promptQuery.trim()}|$fuzzySearchEnabled|${_ratingsKey(selectedRatings)}|${dateRangeStart?.toIso8601String() ?? ''}|${dateRangeEnd?.toIso8601String() ?? ''}|$aiTagTimeRange';
      case GalleryViewMode.popular:
        return 'popular:${popularSourceId.key}:${popularScale.name}|${popularDate?.toIso8601String() ?? ''}|$aiTagPopularPeriod|${popularQuery.trim()}|${popularPromptQuery.trim()}|${_ratingsKey(selectedRatings)}';
      case GalleryViewMode.favorites:
        return 'favorites:${favoritesSourceId.key}|${_ratingsKey(selectedRatings)}';
    }
  }

  ModeCache get currentCache {
    final cached = caches[currentCacheKey];
    if (cached != null) return cached;
    // Legacy fields are only a constructor compatibility path. Once keyed
    // caches exist, a missing key must be empty rather than leaking the
    // previous source/filter result into the newly selected query.
    if (caches.isEmpty) {
      switch (viewMode) {
        case GalleryViewMode.search:
          return searchCache;
        case GalleryViewMode.popular:
          return popularCache;
        case GalleryViewMode.favorites:
          return favoritesCacheFor(favoritesSourceId);
      }
    }
    return const ModeCache();
  }

  ModeCache favoritesCacheFor(GallerySourceId sourceId) {
    final key = 'favorites:${sourceId.key}|${_ratingsKey(selectedRatings)}';
    return caches[key] ??
        (sourceId == GallerySourceId.gelbooru
            ? gelbooruFavoritesCache
            : danbooruFavoritesCache);
  }

  bool get hasError => error != null || errorCode != null;
  List<GalleryItem> get posts => currentCache.posts;
  int get page => currentCache.page;
  bool get hasMore => currentCache.hasMore;
  double get scrollOffset => currentCache.scrollOffset;

  OnlineGalleryState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    OnlineGalleryErrorCode? errorCode,
    OnlineGalleryNotice? notice,
    String? searchQuery,
    String? promptQuery,
    String? popularQuery,
    String? popularPromptQuery,
    bool? fuzzySearchEnabled,
    GallerySourceId? sourceId,
    GallerySourceId? popularSourceId,
    GallerySourceId? favoritesSourceId,
    Set<String>? selectedRatings,
    GalleryViewMode? viewMode,
    ModeCache? searchCache,
    ModeCache? popularCache,
    ModeCache? danbooruFavoritesCache,
    ModeCache? gelbooruFavoritesCache,
    Map<String, ModeCache>? caches,
    PopularScale? popularScale,
    DateTime? popularDate,
    String? aiTagTimeRange,
    String? aiTagPopularPeriod,
    AiTagSourceConfig? aiTagConfig,
    Set<String>? favoritedPostKeys,
    Set<String>? favoriteLoadingPostKeys,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool clearError = false,
    bool clearNotice = false,
    bool clearPopularDate = false,
    bool clearDateRange = false,
  }) {
    return OnlineGalleryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      notice: clearNotice ? null : (notice ?? this.notice),
      searchQuery: searchQuery ?? this.searchQuery,
      promptQuery: promptQuery ?? this.promptQuery,
      popularQuery: popularQuery ?? this.popularQuery,
      popularPromptQuery: popularPromptQuery ?? this.popularPromptQuery,
      fuzzySearchEnabled: fuzzySearchEnabled ?? this.fuzzySearchEnabled,
      sourceId: sourceId ?? this.sourceId,
      popularSourceId: popularSourceId ?? this.popularSourceId,
      favoritesSourceId: favoritesSourceId ?? this.favoritesSourceId,
      selectedRatings: Set.unmodifiable(
        selectedRatings ?? this.selectedRatings,
      ),
      viewMode: viewMode ?? this.viewMode,
      searchCache: searchCache ?? this.searchCache,
      popularCache: popularCache ?? this.popularCache,
      danbooruFavoritesCache:
          danbooruFavoritesCache ?? this.danbooruFavoritesCache,
      gelbooruFavoritesCache:
          gelbooruFavoritesCache ?? this.gelbooruFavoritesCache,
      caches: Map.unmodifiable(caches ?? this.caches),
      popularScale: popularScale ?? this.popularScale,
      popularDate: clearPopularDate ? null : (popularDate ?? this.popularDate),
      aiTagTimeRange: aiTagTimeRange ?? this.aiTagTimeRange,
      aiTagPopularPeriod: aiTagPopularPeriod ?? this.aiTagPopularPeriod,
      aiTagConfig: aiTagConfig ?? this.aiTagConfig,
      favoritedPostKeys: Set.unmodifiable(
        favoritedPostKeys ?? this.favoritedPostKeys,
      ),
      favoriteLoadingPostKeys: Set.unmodifiable(
        favoriteLoadingPostKeys ?? this.favoriteLoadingPostKeys,
      ),
      dateRangeStart: clearDateRange
          ? null
          : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRange ? null : (dateRangeEnd ?? this.dateRangeEnd),
    );
  }

  OnlineGalleryState updateCurrentCache(ModeCache cache) {
    final updated = {...caches, currentCacheKey: cache};
    switch (viewMode) {
      case GalleryViewMode.search:
        return copyWith(caches: updated, searchCache: cache);
      case GalleryViewMode.popular:
        return copyWith(caches: updated, popularCache: cache);
      case GalleryViewMode.favorites:
        return favoritesSourceId == GallerySourceId.gelbooru
            ? copyWith(caches: updated, gelbooruFavoritesCache: cache)
            : copyWith(caches: updated, danbooruFavoritesCache: cache);
    }
  }

  OnlineGalleryState updateFavoritesCache(
    GallerySourceId sourceId,
    ModeCache cache,
  ) {
    final key = 'favorites:${sourceId.key}|${_ratingsKey(selectedRatings)}';
    return sourceId == GallerySourceId.gelbooru
        ? copyWith(
            caches: {...caches, key: cache},
            gelbooruFavoritesCache: cache,
          )
        : copyWith(
            caches: {...caches, key: cache},
            danbooruFavoritesCache: cache,
          );
  }

  static String _ratingsKey(Set<String> ratings) {
    final sorted = ratings.toList()..sort();
    return sorted.join();
  }
}

@riverpod
class OnlineGalleryNotifier extends _$OnlineGalleryNotifier {
  static const int _pageSize = 40;
  static const int _maxConcurrentDetailRequests = 6;
  static const int _maxFilteredEmptyPagesPerLoad = 5;

  CancelToken? _cancelToken;
  int _requestGeneration = 0;
  int _activeDetailRequests = 0;
  final List<Completer<void>> _detailRequestQueue = [];
  final Map<String, Future<GalleryDetail>> _detailRequests = {};

  @override
  OnlineGalleryState build() {
    ref.keepAlive();
    return const OnlineGalleryState();
  }

  Map<GallerySourceId, GallerySourceAdapter> get _adapters =>
      ref.read(onlineGallerySourceAdaptersProvider);
  DanbooruApiService get _danbooruApi => ref.read(danbooruApiServiceProvider);
  DanbooruAuthState get _danbooruAuth => ref.read(danbooruAuthProvider);
  GelbooruApiService get _gelbooruApi => ref.read(gelbooruApiServiceProvider);
  GelbooruAuthState get _gelbooruAuth => ref.read(gelbooruAuthProvider);

  int _beginRequest() {
    _requestGeneration++;
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('Superseded by a newer gallery request');
    }
    _cancelToken = CancelToken();
    return _requestGeneration;
  }

  void _cancelCurrentRequest() {
    _beginRequest();
    if (state.isLoading || state.isLoadingMore) {
      state = state.copyWith(isLoading: false, isLoadingMore: false);
    }
  }

  bool _isCurrentRequest(int generation, String cacheKey) {
    return generation == _requestGeneration &&
        state.currentCacheKey == cacheKey;
  }

  void saveScrollOffset(double offset) {
    state = state.updateCurrentCache(
      state.currentCache.copyWith(scrollOffset: offset),
    );
  }

  Future<void> switchToSearch() async {
    if (state.viewMode == GalleryViewMode.search) return;
    _cancelCurrentRequest();
    state = state.copyWith(viewMode: GalleryViewMode.search, clearError: true);
    if (state.currentCache.posts.isEmpty) await loadPosts(refresh: true);
  }

  Future<void> switchToPopular() async {
    if (state.viewMode == GalleryViewMode.popular) return;
    _cancelCurrentRequest();
    state = state.copyWith(viewMode: GalleryViewMode.popular, clearError: true);
    if (state.currentCache.posts.isEmpty) await loadPosts(refresh: true);
  }

  Future<void> switchToFavorites() async {
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.favorites,
      clearError: true,
    );
    if (state.currentCache.posts.isEmpty) await loadPosts(refresh: true);
  }

  Future<void> setSource(Object source) async {
    final sourceId = _normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsSearch) return;
    if (state.sourceId == sourceId) return;
    _cancelCurrentRequest();
    state = state.copyWith(sourceId: sourceId, clearError: true);
    if (state.currentCache.posts.isEmpty) await loadPosts(refresh: true);
  }

  Future<void> setPopularSource(Object source) async {
    final sourceId = _normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsRanking) return;
    if (state.popularSourceId == sourceId) return;
    _cancelCurrentRequest();
    state = state.copyWith(popularSourceId: sourceId, clearError: true);
    if (state.viewMode == GalleryViewMode.popular &&
        state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setFavoritesSource(Object source) async {
    final sourceId = _normalizeSource(source);
    if (sourceId != GallerySourceId.danbooru &&
        sourceId != GallerySourceId.gelbooru) {
      return;
    }
    if (state.favoritesSourceId == sourceId) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      favoritesSourceId: sourceId!,
      clearError: true,
      clearNotice: true,
    );
    if (state.viewMode == GalleryViewMode.favorites &&
        state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setPopularScale(PopularScale scale) async {
    if (state.popularScale == scale) return;
    _cancelCurrentRequest();
    state = state.copyWith(popularScale: scale, clearError: true);
    if (state.viewMode == GalleryViewMode.popular) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setPopularDate(DateTime? date) async {
    _cancelCurrentRequest();
    state = state.copyWith(
      popularDate: date,
      clearPopularDate: date == null,
      clearError: true,
    );
    if (state.viewMode == GalleryViewMode.popular) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setAiTagTimeRange(String range) async {
    if (state.aiTagTimeRange == range) return;
    _cancelCurrentRequest();
    state = state.copyWith(aiTagTimeRange: range, clearError: true);
    if (state.viewMode == GalleryViewMode.search &&
        state.sourceId == GallerySourceId.aiTag) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setAiTagPopularPeriod(String period) async {
    if (state.aiTagPopularPeriod == period) return;
    _cancelCurrentRequest();
    state = state.copyWith(aiTagPopularPeriod: period, clearError: true);
    if (state.viewMode == GalleryViewMode.popular &&
        state.popularSourceId == GallerySourceId.aiTag) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> search(String query) async {
    await searchWithPrompt(query, prompt: state.promptQuery);
  }

  Future<void> searchWithPrompt(String query, {required String prompt}) async {
    _cancelCurrentRequest();
    state = state.copyWith(
      searchQuery: query.trim(),
      promptQuery: prompt.trim(),
      viewMode: GalleryViewMode.search,
      clearError: true,
    );
    await loadPosts(refresh: true);
  }

  Future<void> searchPopular({
    required String query,
    required String prompt,
  }) async {
    _cancelCurrentRequest();
    state = state.copyWith(
      popularQuery: query.trim(),
      popularPromptQuery: prompt.trim(),
      viewMode: GalleryViewMode.popular,
      clearError: true,
    );
    await loadPosts(refresh: true);
  }

  Future<void> setFuzzySearchEnabled(bool enabled) async {
    if (state.fuzzySearchEnabled == enabled) return;
    _cancelCurrentRequest();
    state = state.copyWith(fuzzySearchEnabled: enabled, clearError: true);
    await loadPosts(refresh: true);
  }

  Future<void> setRatings(Set<String> selectedRatings) async {
    final normalized = _normalizeRatings(selectedRatings);
    if (_setEquals(state.selectedRatings, normalized)) return;
    _cancelCurrentRequest();
    state = state.copyWith(selectedRatings: normalized, clearError: true);
    await loadPosts(refresh: true);
  }

  Future<void> toggleRating(String rating) async {
    if (rating == 'all') return setRatings(kAllRatings);
    if (!kAllRatings.contains(rating)) return;
    final next = {...state.selectedRatings};
    if (next.contains(rating)) {
      if (next.length == 1) return;
      next.remove(rating);
    } else {
      next.add(rating);
    }
    await setRatings(next);
  }

  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    _cancelCurrentRequest();
    state = state.copyWith(
      dateRangeStart: start,
      dateRangeEnd: end,
      clearDateRange: start == null && end == null,
      clearError: true,
    );
    await loadPosts(refresh: true);
  }

  Future<void> clearDateRange() => setDateRange(null, null);

  Future<void> loadPosts({bool refresh = false}) async {
    if (!refresh && (state.isLoading || state.isLoadingMore)) return;
    switch (state.viewMode) {
      case GalleryViewMode.search:
      case GalleryViewMode.popular:
        await _loadAdapterPage(refresh: refresh);
        return;
      case GalleryViewMode.favorites:
        await _loadFavorites(refresh: refresh);
        return;
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await loadPosts();
  }

  Future<void> refresh() => loadPosts(refresh: true);

  Future<void> retryAppend() async {
    if (state.currentCache.appendErrorCode == null) return;
    await loadMore();
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || state.isLoading || state.isLoadingMore) return;
    if (state.viewMode == GalleryViewMode.favorites) {
      await _loadFavorites(refresh: true, targetPage: page);
      return;
    }
    await _loadAdapterPage(refresh: true, initialCursor: '$page');
  }

  Future<void> _loadAdapterPage({
    required bool refresh,
    String? initialCursor,
  }) async {
    final cache = state.currentCache;
    final cursor = initialCursor ?? (refresh ? '1' : cache.nextCursor);
    if (cursor == null) return;
    final sourceId = state.viewMode == GalleryViewMode.popular
        ? state.popularSourceId
        : state.sourceId;
    final adapter = _adapters[sourceId]!;
    final generation = _beginRequest();
    final cacheKey = state.currentCacheKey;
    final isAppend = !refresh && cache.posts.isNotEmpty;
    state = state.copyWith(
      isLoading: !isAppend,
      isLoadingMore: isAppend,
      clearError: true,
    );
    if (isAppend) {
      state = state.updateCurrentCache(cache.copyWith(clearAppendError: true));
    }

    try {
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (!_isCurrentRequest(generation, cacheKey)) return;
      final blacklist = ref
          .read(onlineGalleryBlacklistNotifierProvider)
          .effectiveTags;
      AiTagSourceConfig? aiTagConfig;
      if (adapter is AiTagGallerySourceAdapter) {
        aiTagConfig = await adapter.getConfig(cancelToken: _cancelToken);
        if (!_isCurrentRequest(generation, cacheKey)) return;
      }
      var requestCursor = cursor;
      var pagesFetched = 0;
      var stalledCursor = false;
      final visitedCursors = <String>{};
      late GalleryPage page;
      while (true) {
        pagesFetched++;
        visitedCursors.add(requestCursor);
        if (state.viewMode == GalleryViewMode.popular) {
          page = await adapter.ranking(
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
              query: state.popularQuery,
              prompt: state.popularPromptQuery,
              ratings: state.selectedRatings,
              blacklistTags: blacklist,
            ),
            cancelToken: _cancelToken,
          );
        } else {
          final query = sourceId == GallerySourceId.aiTag
              ? state.searchQuery.trim()
              : buildOnlineGallerySearchQuery(
                  state.searchQuery,
                  fuzzyMatch: state.fuzzySearchEnabled,
                );
          page = await adapter.search(
            GallerySearchRequest(
              cursor: requestCursor,
              pageSize: sourceId == GallerySourceId.aiTag
                  ? (aiTagConfig?.pageSize ?? 60)
                  : _pageSize,
              query: query,
              prompt: state.promptQuery,
              timeRange: state.aiTagTimeRange,
              ratings: state.selectedRatings,
              dateStart: state.dateRangeStart,
              dateEnd: state.dateRangeEnd,
              blacklistTags: blacklist,
            ),
            cancelToken: _cancelToken,
          );
        }
        if (!_isCurrentRequest(generation, cacheKey)) return;
        final nextCursor = page.nextCursor;
        final filteredEmptyPage = page.rawItemCount > 0 && page.items.isEmpty;
        stalledCursor =
            filteredEmptyPage &&
            nextCursor != null &&
            visitedCursors.contains(nextCursor);
        final shouldContinue =
            filteredEmptyPage &&
            page.hasMore &&
            nextCursor != null &&
            !stalledCursor &&
            pagesFetched < _maxFilteredEmptyPagesPerLoad;
        if (!shouldContinue) break;
        requestCursor = nextCursor;
      }
      final baseItems = refresh ? const <GalleryItem>[] : cache.posts;
      final existingKeys = baseItems.map(onlineGalleryPostKey).toSet();
      final uniqueNew = <GalleryItem>[];
      for (final item in page.items) {
        if (existingKeys.add(onlineGalleryPostKey(item))) uniqueNew.add(item);
      }
      final duplicatePage =
          !refresh && page.items.isNotEmpty && uniqueNew.isEmpty;
      final endedByDuplicatePage = duplicatePage || stalledCursor;
      final merged = [...baseItems, ...uniqueNew];
      final isInitialLoad =
          !refresh && cache.posts.isEmpty && cache.page == 1 && cursor == '1';
      final firstRequestedPage = refresh || isInitialLoad
          ? galleryCursorPage(cursor)
          : cache.page + 1;
      final parsedPage = galleryCursorPage(
        page.cursor,
        fallback: firstRequestedPage + pagesFetched - 1,
      );
      final nextCache = ModeCache(
        posts: List.unmodifiable(merged),
        page: parsedPage,
        nextCursor: endedByDuplicatePage ? null : page.nextCursor,
        total: page.total,
        hasMore:
            !endedByDuplicatePage && page.hasMore && page.nextCursor != null,
        scrollOffset: refresh ? 0 : cache.scrollOffset,
        endedByDuplicatePage: endedByDuplicatePage,
      );
      final gelbooruCredentialsBecameInvalid =
          sourceId == GallerySourceId.gelbooru &&
          ref.read(gelbooruAuthProvider).status == GelbooruAuthStatus.invalid;
      state = state
          .copyWith(
            isLoading: false,
            isLoadingMore: false,
            aiTagConfig: aiTagConfig,
            notice: gelbooruCredentialsBecameInvalid
                ? OnlineGalleryNotice.gelbooruCredentialsInvalid
                : null,
            clearError: true,
          )
          .updateCurrentCache(nextCache);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) return;
      _finishRequestError(error, generation, cacheKey, isAppend, cache);
    } catch (error, stack) {
      AppLogger.e(
        'Failed to load online gallery page',
        error,
        stack,
        'OnlineGallery',
      );
      _finishRequestError(error, generation, cacheKey, isAppend, cache);
    }
  }

  void _finishRequestError(
    Object error,
    int generation,
    String cacheKey,
    bool isAppend,
    ModeCache cache,
  ) {
    if (!_isCurrentRequest(generation, cacheKey)) return;
    final code = _errorCode(error);
    state = state.copyWith(isLoading: false, isLoadingMore: false);
    if (isAppend) {
      state = state.updateCurrentCache(cache.copyWith(appendErrorCode: code));
    } else {
      state = state.copyWith(errorCode: code);
    }
  }

  Future<void> _loadFavorites({required bool refresh, int? targetPage}) async {
    final sourceId = state.favoritesSourceId;
    final authMissing = sourceId == GallerySourceId.danbooru
        ? !_danbooruAuth.isLoggedIn || _danbooruAuth.user == null
        : false;
    if (authMissing) {
      state = state.copyWith(
        isLoading: false,
        errorCode: OnlineGalleryErrorCode.credentialsRequired,
      );
      return;
    }
    if (sourceId == GallerySourceId.gelbooru) {
      await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
      if (!_gelbooruAuth.isAuthenticated || _gelbooruAuth.credentials == null) {
        state = state.copyWith(
          isLoading: false,
          errorCode: _gelbooruAuth.status == GelbooruAuthStatus.invalid
              ? OnlineGalleryErrorCode.gelbooruCredentialsInvalid
              : OnlineGalleryErrorCode.gelbooruCredentialsRequired,
        );
        return;
      }
    }
    final cache = state.currentCache;
    final pageNumber = targetPage ?? (refresh ? 1 : cache.page + 1);
    final generation = _beginRequest();
    final cacheKey = state.currentCacheKey;
    final isAppend = !refresh && cache.posts.isNotEmpty;
    state = state.copyWith(
      isLoading: !isAppend,
      isLoadingMore: isAppend,
      clearError: true,
    );
    try {
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      final blacklist = ref
          .read(onlineGalleryBlacklistNotifierProvider)
          .effectiveTags;
      final List<GalleryItem> raw;
      final int rawCount;
      if (sourceId == GallerySourceId.danbooru) {
        raw = await _danbooruApi.getFavorites(
          userId: _danbooruAuth.user!.id,
          page: pageNumber,
          limit: _pageSize,
        );
        rawCount = raw.length;
      } else {
        final result = await _gelbooruApi.getFavorites(
          credentials: _gelbooruAuth.credentials!,
          pid: pageNumber - 1,
          limit: _pageSize,
          cancelToken: _cancelToken,
        );
        raw = result.posts;
        rawCount = result.rawCount;
      }
      if (!_isCurrentRequest(generation, cacheKey)) return;
      final filtered = _filterLocal(raw, blacklist);
      final base = refresh ? const <GalleryItem>[] : cache.posts;
      final keys = base.map(onlineGalleryPostKey).toSet();
      final added = filtered.where((item) => keys.add(item.stableKey)).toList();
      final duplicatePage = !refresh && rawCount > 0 && added.isEmpty;
      final favorites = {...state.favoritedPostKeys}
        ..addAll(filtered.map(onlineGalleryPostKey));
      final nextCache = ModeCache(
        posts: List.unmodifiable([...base, ...added]),
        page: pageNumber,
        nextCursor: duplicatePage ? null : '${pageNumber + 1}',
        hasMore: !duplicatePage && rawCount >= _pageSize,
        scrollOffset: refresh ? 0 : cache.scrollOffset,
        endedByDuplicatePage: duplicatePage,
      );
      state = state
          .copyWith(
            isLoading: false,
            isLoadingMore: false,
            favoritedPostKeys: favorites,
            clearError: true,
          )
          .updateCurrentCache(nextCache);
    } on GelbooruApiException catch (error, stack) {
      if (error.type == GelbooruApiErrorType.cancelled) return;
      if (error.type == GelbooruApiErrorType.invalidCredentials) {
        ref.read(gelbooruAuthProvider.notifier).markInvalid();
        invalidateGelbooruFavorites();
      }
      AppLogger.e('Failed to load favorites', error, stack, 'OnlineGallery');
      _finishRequestError(error, generation, cacheKey, isAppend, cache);
    } catch (error, stack) {
      AppLogger.e('Failed to load favorites', error, stack, 'OnlineGallery');
      _finishRequestError(error, generation, cacheKey, isAppend, cache);
    }
  }

  List<GalleryItem> _filterLocal(
    List<GalleryItem> items,
    Set<String> blacklist,
  ) {
    return items
        .where((item) {
          if (state.selectedRatings.length < 4 &&
              !state.selectedRatings.contains(item.rating)) {
            return false;
          }
          return !item.tags.any(
            (tag) => blacklist.contains(
              tag.trim().toLowerCase().replaceAll(' ', '_'),
            ),
          );
        })
        .toList(growable: false);
  }

  Future<GalleryDetail> loadDetail(
    GalleryItem item, {
    bool forceRefresh = false,
  }) {
    final key = item.stableKey;
    if (forceRefresh) _detailRequests.remove(key);
    return _detailRequests.putIfAbsent(key, () async {
      await _acquireDetailRequestSlot();
      try {
        return await _adapters[item.sourceId]!.detail(item);
      } catch (_) {
        _detailRequests.remove(key);
        rethrow;
      } finally {
        _releaseDetailRequestSlot();
      }
    });
  }

  Future<void> _acquireDetailRequestSlot() async {
    if (_activeDetailRequests < _maxConcurrentDetailRequests) {
      _activeDetailRequests++;
      return;
    }
    final completer = Completer<void>();
    _detailRequestQueue.add(completer);
    await completer.future;
  }

  void _releaseDetailRequestSlot() {
    if (_detailRequestQueue.isNotEmpty) {
      _detailRequestQueue.removeAt(0).complete();
      return;
    }
    _activeDetailRequests--;
  }

  Future<bool> addFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_danbooruAuth.isLoggedIn) return false;
    final key = 'danbooru:$postId';
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    final success = await _danbooruApi.addFavorite(postId);
    final loading = {...state.favoriteLoadingPostKeys}..remove(key);
    state = success
        ? state.copyWith(
            favoritedPostKeys: {...state.favoritedPostKeys, key},
            favoriteLoadingPostKeys: loading,
          )
        : state.copyWith(favoriteLoadingPostKeys: loading);
    return success;
  }

  Future<bool> removeFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_danbooruAuth.isLoggedIn) return false;
    final key = 'danbooru:$postId';
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    final success = await _danbooruApi.removeFavorite(postId);
    final loading = {...state.favoriteLoadingPostKeys}..remove(key);
    if (success) {
      final favorites = {...state.favoritedPostKeys}..remove(key);
      state = state.copyWith(
        favoritedPostKeys: favorites,
        favoriteLoadingPostKeys: loading,
      );
      if (state.viewMode == GalleryViewMode.favorites &&
          state.favoritesSourceId == GallerySourceId.danbooru) {
        state = state.updateCurrentCache(
          state.currentCache.copyWith(
            posts: state.currentCache.posts
                .where((item) => item.id != postId)
                .toList(growable: false),
          ),
        );
      }
    } else {
      state = state.copyWith(favoriteLoadingPostKeys: loading);
    }
    return success;
  }

  Future<bool> toggleFavorite(Object postOrId) {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null) return Future.value(false);
    return state.favoritedPostKeys.contains('danbooru:$postId')
        ? removeFavorite(postOrId)
        : addFavorite(postOrId);
  }

  bool isFavorited(Object postOrId) {
    if (postOrId is GalleryItem) {
      return state.favoritedPostKeys.contains(postOrId.stableKey);
    }
    return postOrId is int &&
        state.favoritedPostKeys.contains('danbooru:$postOrId');
  }

  int? _danbooruFavoritePostId(Object postOrId) {
    if (postOrId is GalleryItem) {
      return postOrId.sourceId == GallerySourceId.danbooru ? postOrId.id : null;
    }
    return postOrId is int ? postOrId : null;
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);

  void invalidateGelbooruFavorites() {
    final filteredCaches = <String, ModeCache>{
      for (final entry in state.caches.entries)
        if (!entry.key.startsWith('favorites:gelbooru')) entry.key: entry.value,
    };
    state = state.copyWith(
      caches: filteredCaches,
      gelbooruFavoritesCache: const ModeCache(),
      favoritedPostKeys: state.favoritedPostKeys
          .where((key) => !key.startsWith('gelbooru:'))
          .toSet(),
      favoriteLoadingPostKeys: state.favoriteLoadingPostKeys
          .where((key) => !key.startsWith('gelbooru:'))
          .toSet(),
    );
  }

  OnlineGalleryErrorCode _errorCode(Object error) {
    if (error is GallerySourceException) {
      if (error.source == GallerySourceId.gelbooru) {
        return switch (error.code) {
          GallerySourceErrorCode.credentialsRequired =>
            OnlineGalleryErrorCode.gelbooruCredentialsRequired,
          GallerySourceErrorCode.credentialsInvalid =>
            OnlineGalleryErrorCode.gelbooruCredentialsInvalid,
          GallerySourceErrorCode.rateLimited =>
            OnlineGalleryErrorCode.gelbooruRateLimited,
          GallerySourceErrorCode.timeout =>
            OnlineGalleryErrorCode.gelbooruTimeout,
          GallerySourceErrorCode.server =>
            OnlineGalleryErrorCode.gelbooruServer,
          GallerySourceErrorCode.network =>
            OnlineGalleryErrorCode.gelbooruNetwork,
          GallerySourceErrorCode.malformedResponse =>
            OnlineGalleryErrorCode.gelbooruMalformedResponse,
          _ => OnlineGalleryErrorCode.gelbooruRequestFailed,
        };
      }
      return switch (error.code) {
        GallerySourceErrorCode.credentialsRequired =>
          OnlineGalleryErrorCode.credentialsRequired,
        GallerySourceErrorCode.credentialsInvalid =>
          OnlineGalleryErrorCode.credentialsInvalid,
        GallerySourceErrorCode.rateLimited =>
          OnlineGalleryErrorCode.rateLimited,
        GallerySourceErrorCode.timeout => OnlineGalleryErrorCode.timeout,
        GallerySourceErrorCode.server => OnlineGalleryErrorCode.server,
        GallerySourceErrorCode.network => OnlineGalleryErrorCode.network,
        GallerySourceErrorCode.malformedResponse =>
          OnlineGalleryErrorCode.malformedResponse,
        GallerySourceErrorCode.detailNotFound =>
          OnlineGalleryErrorCode.detailNotFound,
        GallerySourceErrorCode.imageUnavailable =>
          OnlineGalleryErrorCode.imageUnavailable,
        GallerySourceErrorCode.rankingProcessing =>
          OnlineGalleryErrorCode.rankingProcessing,
        GallerySourceErrorCode.configurationUnavailable =>
          OnlineGalleryErrorCode.configurationUnavailable,
        GallerySourceErrorCode.unknown => OnlineGalleryErrorCode.requestFailed,
      };
    }
    if (error is GelbooruApiException) {
      return switch (error.type) {
        GelbooruApiErrorType.invalidCredentials =>
          OnlineGalleryErrorCode.gelbooruCredentialsInvalid,
        GelbooruApiErrorType.rateLimited =>
          OnlineGalleryErrorCode.gelbooruRateLimited,
        GelbooruApiErrorType.timeout => OnlineGalleryErrorCode.gelbooruTimeout,
        GelbooruApiErrorType.server => OnlineGalleryErrorCode.gelbooruServer,
        GelbooruApiErrorType.network => OnlineGalleryErrorCode.gelbooruNetwork,
        GelbooruApiErrorType.malformedResponse =>
          OnlineGalleryErrorCode.gelbooruMalformedResponse,
        GelbooruApiErrorType.cancelled || GelbooruApiErrorType.unknown =>
          OnlineGalleryErrorCode.gelbooruRequestFailed,
      };
    }
    if (error is DioException) {
      return _errorCode(mapGalleryDioException(error, state.sourceId));
    }
    return OnlineGalleryErrorCode.requestFailed;
  }

  GalleryRankingKind _rankingKind(PopularScale scale) {
    return switch (scale) {
      PopularScale.day => GalleryRankingKind.day,
      PopularScale.week => GalleryRankingKind.week,
      PopularScale.month => GalleryRankingKind.month,
    };
  }

  GallerySourceId? _normalizeSource(Object source) {
    if (source is GallerySourceId) return source;
    if (source is String) {
      if (!GallerySourceId.values.any((value) => value.key == source)) {
        return null;
      }
      return GallerySourceId.fromKey(source);
    }
    return null;
  }

  Set<String> _normalizeRatings(Set<String> ratings) {
    final normalized = ratings.where(kAllRatings.contains).toSet();
    return Set.unmodifiable(normalized.isEmpty ? {...kAllRatings} : normalized);
  }

  bool _setEquals(Set<String> left, Set<String> right) {
    return identical(left, right) ||
        (left.length == right.length && left.containsAll(right));
  }
}

extension GallerySourceIdCapabilities on GallerySourceId {
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[this]!;
}
