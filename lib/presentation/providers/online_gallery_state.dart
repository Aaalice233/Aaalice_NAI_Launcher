import 'dart:collection';
import 'dart:convert';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_query.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/models/online_gallery/gelbooru_post_parser.dart';
import '../../data/services/online_gallery/online_gallery_query.dart';

const Set<String> kAllRatings = {'g', 's', 'q', 'e'};

String buildOnlineGallerySearchQuery(String query, {required bool fuzzyMatch}) {
  return const OnlineGalleryQuery().buildSearchQuery(
    query,
    fuzzyMatch: fuzzyMatch,
  );
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
  tooManySearchTags,
  tagDetailsIncomplete,
  unsupportedMetatag,
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
  artistHuntDetailFailed,
}

enum OnlineGalleryNotice {
  gelbooruCredentialsInvalid,
  tagDetailsIncomplete,
  randomDrawNoMatch,
}

String onlineGalleryPostKey(GalleryItem item) => item.stableKey;

/// Maps one upstream response to the exact records it contributed after
/// filtering and stable-key deduplication.
class GalleryPageBoundary {
  const GalleryPageBoundary({
    required this.page,
    required this.cursor,
    required this.startIndex,
    required this.endIndex,
    required this.rawItemCount,
    this.nextCursor,
  });

  final int page;
  final String cursor;
  final int startIndex;
  final int endIndex;
  final int rawItemCount;
  final String? nextCursor;

  bool containsItem(int index) => startIndex <= index && index < endIndex;
}

class RandomGallerySession {
  const RandomGallerySession({
    this.scopeKey = '',
    this.cache = const ModeCache(),
    this.seenStableKeys = const <String>{},
    this.seenCandidateStableKeys = const <String>{},
    this.nextCursor,
    this.consecutiveMisses = 0,
    this.drawRevision = 0,
    this.exhausted = false,
  });

  final String scopeKey;
  final ModeCache cache;
  final Set<String> seenStableKeys;
  final Set<String> seenCandidateStableKeys;
  final String? nextCursor;
  final int consecutiveMisses;
  final int drawRevision;
  final bool exhausted;

  RandomGallerySession copyWith({
    String? scopeKey,
    ModeCache? cache,
    Set<String>? seenStableKeys,
    Set<String>? seenCandidateStableKeys,
    String? nextCursor,
    bool clearNextCursor = false,
    int? consecutiveMisses,
    int? drawRevision,
    bool? exhausted,
  }) {
    return RandomGallerySession(
      scopeKey: scopeKey ?? this.scopeKey,
      cache: cache ?? this.cache,
      seenStableKeys: seenStableKeys ?? this.seenStableKeys,
      seenCandidateStableKeys:
          seenCandidateStableKeys ?? this.seenCandidateStableKeys,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      consecutiveMisses: consecutiveMisses ?? this.consecutiveMisses,
      drawRevision: drawRevision ?? this.drawRevision,
      exhausted: exhausted ?? this.exhausted,
    );
  }
}

class ModeCache {
  const ModeCache({
    this.posts = const [],
    this.page = 1,
    this.pageBoundaries = const [],
    this.nextCursor = '1',
    this.hasMore = true,
    this.total,
    this.scrollOffset = 0,
    this.anchorStableKey,
    this.anchorLocalOffset = 0,
    this.appendErrorCode,
    this.localFavoritesOffset = 0,
    this.remoteFavoritesPage = 1,
    this.localFavoritesHasMore = true,
    this.remoteFavoritesHasMore = true,
    this.localFavoritesErrorCode,
    this.remoteFavoritesErrorCode,
    this.localFavoriteItemKeys = const {},
    this.remoteFavoriteItemKeys = const {},
    this.endedByDuplicatePage = false,
    this.artistHuntCandidateCount = 0,
    this.artistHuntResolvedCount = 0,
    this.artistHuntFailureCount = 0,
    this.queryRequestCount = 0,
    this.queryCandidateCount = 0,
    this.queryFilterMicros = 0,
    this.queryDetailFailureCount = 0,
    this.lastRawPageIdentity,
    this.queryScanPaused = false,
  });

  final List<GalleryItem> posts;

  /// Page containing the first visible record, not the last fetched page.
  final int page;
  final List<GalleryPageBoundary> pageBoundaries;
  final String? nextCursor;

  int get lastLoadedPage => pageBoundaries.isEmpty
      ? (posts.isEmpty ? 0 : page)
      : pageBoundaries.last.page;

  GalleryPageBoundary? boundaryForPage(int targetPage) {
    for (final boundary in pageBoundaries) {
      if (boundary.page == targetPage &&
          boundary.endIndex > boundary.startIndex) {
        return boundary;
      }
    }
    return null;
  }

  int? pageForItemIndex(int index) {
    for (final boundary in pageBoundaries.reversed) {
      if (boundary.containsItem(index)) return boundary.page;
    }
    return null;
  }

  bool isPageBoundaryStart(int index) => pageBoundaries.any(
    (boundary) =>
        boundary.startIndex == index && boundary.endIndex > boundary.startIndex,
  );
  final bool hasMore;
  final int? total;
  final double scrollOffset;
  final String? anchorStableKey;
  final double anchorLocalOffset;
  final OnlineGalleryErrorCode? appendErrorCode;
  final int localFavoritesOffset;
  final int remoteFavoritesPage;
  final bool localFavoritesHasMore;
  final bool remoteFavoritesHasMore;
  final OnlineGalleryErrorCode? localFavoritesErrorCode;
  final OnlineGalleryErrorCode? remoteFavoritesErrorCode;
  final Set<String> localFavoriteItemKeys;
  final Set<String> remoteFavoriteItemKeys;
  final bool endedByDuplicatePage;

  bool get hasFavoritesPartialFailure =>
      localFavoritesErrorCode != null || remoteFavoritesErrorCode != null;
  final int artistHuntCandidateCount;
  final int artistHuntResolvedCount;
  final int artistHuntFailureCount;
  final int queryRequestCount;
  final int queryCandidateCount;
  final int queryFilterMicros;
  final int queryDetailFailureCount;
  final String? lastRawPageIdentity;
  final bool queryScanPaused;

  ModeCache copyWith({
    List<GalleryItem>? posts,
    int? page,
    List<GalleryPageBoundary>? pageBoundaries,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    int? total,
    bool clearTotal = false,
    double? scrollOffset,
    String? anchorStableKey,
    bool clearAnchorStableKey = false,
    double? anchorLocalOffset,
    OnlineGalleryErrorCode? appendErrorCode,
    bool clearAppendError = false,
    int? localFavoritesOffset,
    int? remoteFavoritesPage,
    bool? localFavoritesHasMore,
    bool? remoteFavoritesHasMore,
    OnlineGalleryErrorCode? localFavoritesErrorCode,
    OnlineGalleryErrorCode? remoteFavoritesErrorCode,
    bool clearLocalFavoritesError = false,
    bool clearRemoteFavoritesError = false,
    Set<String>? localFavoriteItemKeys,
    Set<String>? remoteFavoriteItemKeys,
    bool? endedByDuplicatePage,
    int? artistHuntCandidateCount,
    int? artistHuntResolvedCount,
    int? artistHuntFailureCount,
    int? queryRequestCount,
    int? queryCandidateCount,
    int? queryFilterMicros,
    int? queryDetailFailureCount,
    String? lastRawPageIdentity,
    bool clearLastRawPageIdentity = false,
    bool? queryScanPaused,
  }) {
    return ModeCache(
      posts: posts ?? this.posts,
      page: page ?? this.page,
      pageBoundaries: List.unmodifiable(pageBoundaries ?? this.pageBoundaries),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      total: clearTotal ? null : (total ?? this.total),
      scrollOffset: scrollOffset ?? this.scrollOffset,
      anchorStableKey: clearAnchorStableKey
          ? null
          : (anchorStableKey ?? this.anchorStableKey),
      anchorLocalOffset: anchorLocalOffset ?? this.anchorLocalOffset,
      appendErrorCode: clearAppendError
          ? null
          : (appendErrorCode ?? this.appendErrorCode),
      localFavoritesOffset: localFavoritesOffset ?? this.localFavoritesOffset,
      remoteFavoritesPage: remoteFavoritesPage ?? this.remoteFavoritesPage,
      localFavoritesHasMore:
          localFavoritesHasMore ?? this.localFavoritesHasMore,
      remoteFavoritesHasMore:
          remoteFavoritesHasMore ?? this.remoteFavoritesHasMore,
      localFavoritesErrorCode: clearLocalFavoritesError
          ? null
          : (localFavoritesErrorCode ?? this.localFavoritesErrorCode),
      remoteFavoritesErrorCode: clearRemoteFavoritesError
          ? null
          : (remoteFavoritesErrorCode ?? this.remoteFavoritesErrorCode),
      localFavoriteItemKeys: Set.unmodifiable(
        localFavoriteItemKeys ?? this.localFavoriteItemKeys,
      ),
      remoteFavoriteItemKeys: Set.unmodifiable(
        remoteFavoriteItemKeys ?? this.remoteFavoriteItemKeys,
      ),
      endedByDuplicatePage: endedByDuplicatePage ?? this.endedByDuplicatePage,
      artistHuntCandidateCount:
          artistHuntCandidateCount ?? this.artistHuntCandidateCount,
      artistHuntResolvedCount:
          artistHuntResolvedCount ?? this.artistHuntResolvedCount,
      artistHuntFailureCount:
          artistHuntFailureCount ?? this.artistHuntFailureCount,
      queryRequestCount: queryRequestCount ?? this.queryRequestCount,
      queryCandidateCount: queryCandidateCount ?? this.queryCandidateCount,
      queryFilterMicros: queryFilterMicros ?? this.queryFilterMicros,
      queryDetailFailureCount:
          queryDetailFailureCount ?? this.queryDetailFailureCount,
      lastRawPageIdentity: clearLastRawPageIdentity
          ? null
          : (lastRawPageIdentity ?? this.lastRawPageIdentity),
      queryScanPaused: queryScanPaused ?? this.queryScanPaused,
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
    this.favoriteSearchQuery = '',
    this.selectedRatings = kAllRatings,
    this.viewMode = GalleryViewMode.search,
    this.searchCache = const ModeCache(),
    this.popularCache = const ModeCache(),
    this.caches = const {},
    this.popularScale = PopularScale.day,
    this.popularDate,
    this.aiTagTimeRange = 'all',
    this.aiTagPopularPeriod = 'current',
    this.quickTagCloudFilterKey = QuickTagCloudGalleryQuery.defaultStableKey,
    this.aiTagConfig,
    this.favoritedPostKeys = const {},
    this.localFavoritedPostKeys = const {},
    this.remoteFavoritedPostKeys = const {},
    this.favoriteLoadingPostKeys = const {},
    this.dateRangeStart,
    this.dateRangeEnd,
    this.randomEnabled = false,
    this.randomSession = const RandomGallerySession(),
    this.artistHuntEnabled = false,
    this.blacklistRevision = 0,
    this.danbooruAuthScope = 'anonymous',
    this.gelbooruAuthScope = 'anonymous',
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
  final String favoriteSearchQuery;
  final Set<String> selectedRatings;
  final GalleryViewMode viewMode;
  final ModeCache searchCache;
  final ModeCache popularCache;
  final Map<String, ModeCache> caches;
  final PopularScale popularScale;
  final DateTime? popularDate;
  final String aiTagTimeRange;
  final String aiTagPopularPeriod;
  final String quickTagCloudFilterKey;
  final AiTagSourceConfig? aiTagConfig;
  final Set<String> favoritedPostKeys;
  final Set<String> localFavoritedPostKeys;
  final Set<String> remoteFavoritedPostKeys;
  final Set<String> favoriteLoadingPostKeys;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final bool randomEnabled;
  final RandomGallerySession randomSession;
  final bool artistHuntEnabled;
  final int blacklistRevision;
  final String danbooruAuthScope;
  final String gelbooruAuthScope;

  GallerySourceId get activeSourceId => switch (viewMode) {
    GalleryViewMode.search => sourceId,
    GalleryViewMode.popular => popularSourceId,
    GalleryViewMode.favorites => favoritesSourceId,
  };

  GalleryFeedKind get activeFeedKind => switch (viewMode) {
    GalleryViewMode.search => GalleryFeedKind.search,
    GalleryViewMode.popular => GalleryFeedKind.ranking,
    GalleryViewMode.favorites => GalleryFeedKind.favorites,
  };

  GallerySourceCapabilities get activeCapabilities =>
      gallerySourceCapabilities[activeSourceId]!;

  bool get supportsRandom =>
      activeCapabilities.supportsRandomFeed(activeFeedKind);

  bool get isArtistHuntActive =>
      artistHuntEnabled &&
      activeSourceId == GallerySourceId.aiTag &&
      viewMode != GalleryViewMode.favorites;

  String get currentCacheKey {
    switch (viewMode) {
      case GalleryViewMode.search:
        return 'search:${sourceId.key}:${searchQuery.trim()}|${promptQuery.trim()}|$fuzzySearchEnabled|${_ratingsKey(selectedRatings)}|${dateRangeStart?.toIso8601String() ?? ''}|${dateRangeEnd?.toIso8601String() ?? ''}|$aiTagTimeRange|artistHunt:${sourceId == GallerySourceId.aiTag && artistHuntEnabled}|codex:${sourceId == GallerySourceId.quickTagCloud ? quickTagCloudFilterKey : ''}|blacklist:$blacklistRevision|auth:${_authScopeFor(sourceId)}';
      case GalleryViewMode.popular:
        return 'popular:${popularSourceId.key}:${popularScale.name}|${popularDate?.toIso8601String() ?? ''}|$aiTagPopularPeriod|${popularQuery.trim()}|${popularPromptQuery.trim()}|${_ratingsKey(selectedRatings)}|artistHunt:${popularSourceId == GallerySourceId.aiTag && artistHuntEnabled}|blacklist:$blacklistRevision|auth:${_authScopeFor(popularSourceId)}';
      case GalleryViewMode.favorites:
        return 'favorites:${favoritesSourceId.key}|${favoriteSearchQuery.trim()}|${_ratingsKey(selectedRatings)}|codex:${favoritesSourceId == GallerySourceId.quickTagCloud ? quickTagCloudFilterKey : ''}|blacklist:$blacklistRevision';
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
    final key =
        'favorites:${sourceId.key}|${favoriteSearchQuery.trim()}|${_ratingsKey(selectedRatings)}|codex:${sourceId == GallerySourceId.quickTagCloud ? quickTagCloudFilterKey : ''}|blacklist:$blacklistRevision';
    return caches[key] ?? const ModeCache();
  }

  bool get hasError => error != null || errorCode != null;
  List<GalleryItem> get posts =>
      randomEnabled ? randomSession.cache.posts : currentCache.posts;
  int get page => randomEnabled ? 1 : currentCache.page;
  bool get hasMore =>
      randomEnabled ? !randomSession.exhausted : currentCache.hasMore;
  double get scrollOffset => randomEnabled
      ? randomSession.cache.scrollOffset
      : currentCache.scrollOffset;

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
    String? favoriteSearchQuery,
    Set<String>? selectedRatings,
    GalleryViewMode? viewMode,
    ModeCache? searchCache,
    ModeCache? popularCache,
    Map<String, ModeCache>? caches,
    PopularScale? popularScale,
    DateTime? popularDate,
    String? aiTagTimeRange,
    String? aiTagPopularPeriod,
    String? quickTagCloudFilterKey,
    AiTagSourceConfig? aiTagConfig,
    bool clearAiTagConfig = false,
    Set<String>? favoritedPostKeys,
    Set<String>? localFavoritedPostKeys,
    Set<String>? remoteFavoritedPostKeys,
    Set<String>? favoriteLoadingPostKeys,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool clearError = false,
    bool clearNotice = false,
    bool clearPopularDate = false,
    bool clearDateRange = false,
    bool clearDateRangeStart = false,
    bool clearDateRangeEnd = false,
    bool? randomEnabled,
    RandomGallerySession? randomSession,
    bool? artistHuntEnabled,
    int? blacklistRevision,
    String? danbooruAuthScope,
    String? gelbooruAuthScope,
  }) {
    return OnlineGalleryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      errorCode: errorCode ?? (clearError ? null : this.errorCode),
      notice: clearNotice ? null : (notice ?? this.notice),
      searchQuery: searchQuery ?? this.searchQuery,
      promptQuery: promptQuery ?? this.promptQuery,
      popularQuery: popularQuery ?? this.popularQuery,
      popularPromptQuery: popularPromptQuery ?? this.popularPromptQuery,
      fuzzySearchEnabled: fuzzySearchEnabled ?? this.fuzzySearchEnabled,
      sourceId: sourceId ?? this.sourceId,
      popularSourceId: popularSourceId ?? this.popularSourceId,
      favoritesSourceId: favoritesSourceId ?? this.favoritesSourceId,
      favoriteSearchQuery: favoriteSearchQuery ?? this.favoriteSearchQuery,
      selectedRatings: Set.unmodifiable(
        selectedRatings ?? this.selectedRatings,
      ),
      viewMode: viewMode ?? this.viewMode,
      searchCache: searchCache ?? this.searchCache,
      popularCache: popularCache ?? this.popularCache,
      caches: Map.unmodifiable(caches ?? this.caches),
      popularScale: popularScale ?? this.popularScale,
      popularDate: clearPopularDate ? null : (popularDate ?? this.popularDate),
      aiTagTimeRange: aiTagTimeRange ?? this.aiTagTimeRange,
      aiTagPopularPeriod: aiTagPopularPeriod ?? this.aiTagPopularPeriod,
      quickTagCloudFilterKey:
          quickTagCloudFilterKey ?? this.quickTagCloudFilterKey,
      aiTagConfig: clearAiTagConfig ? null : (aiTagConfig ?? this.aiTagConfig),
      favoritedPostKeys: Set.unmodifiable(
        favoritedPostKeys ?? this.favoritedPostKeys,
      ),
      localFavoritedPostKeys: Set.unmodifiable(
        localFavoritedPostKeys ?? this.localFavoritedPostKeys,
      ),
      remoteFavoritedPostKeys: Set.unmodifiable(
        remoteFavoritedPostKeys ?? this.remoteFavoritedPostKeys,
      ),
      favoriteLoadingPostKeys: Set.unmodifiable(
        favoriteLoadingPostKeys ?? this.favoriteLoadingPostKeys,
      ),
      dateRangeStart: clearDateRange || clearDateRangeStart
          ? null
          : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRange || clearDateRangeEnd
          ? null
          : (dateRangeEnd ?? this.dateRangeEnd),
      randomEnabled: randomEnabled ?? this.randomEnabled,
      randomSession: randomSession ?? this.randomSession,
      artistHuntEnabled: artistHuntEnabled ?? this.artistHuntEnabled,
      blacklistRevision: blacklistRevision ?? this.blacklistRevision,
      danbooruAuthScope: danbooruAuthScope ?? this.danbooruAuthScope,
      gelbooruAuthScope: gelbooruAuthScope ?? this.gelbooruAuthScope,
    );
  }

  OnlineGalleryState updateCurrentCache(ModeCache cache) {
    final updated = LinkedHashMap<String, ModeCache>.of(caches)
      ..remove(currentCacheKey)
      ..[currentCacheKey] = cache;
    switch (viewMode) {
      case GalleryViewMode.search:
        return copyWith(caches: updated, searchCache: cache);
      case GalleryViewMode.popular:
        return copyWith(caches: updated, popularCache: cache);
      case GalleryViewMode.favorites:
        return copyWith(caches: updated);
    }
  }

  OnlineGalleryState updateFavoritesCache(
    GallerySourceId sourceId,
    ModeCache cache,
  ) {
    final key =
        'favorites:${sourceId.key}|${favoriteSearchQuery.trim()}|${_ratingsKey(selectedRatings)}|codex:${sourceId == GallerySourceId.quickTagCloud ? quickTagCloudFilterKey : ''}|blacklist:$blacklistRevision';
    final updated = LinkedHashMap<String, ModeCache>.of(caches)
      ..remove(key)
      ..[key] = cache;
    return copyWith(caches: updated);
  }

  String _authScopeFor(GallerySourceId sourceId) => switch (sourceId) {
    GallerySourceId.danbooru => danbooruAuthScope,
    GallerySourceId.gelbooru => gelbooruAuthScope,
    _ => 'public',
  };

  static String _ratingsKey(Set<String> ratings) {
    final sorted = ratings.toList()..sort();
    return sorted.join();
  }
}

/// Encodes browsing intent only. Page, scroll and remote rows deliberately
/// restart from page one so stale layout state cannot corrupt a new viewport.
String encodeOnlineGalleryBrowsingSession(OnlineGalleryState state) {
  return jsonEncode({
    'version': 2,
    'viewMode': state.viewMode.name,
    'sourceId': state.sourceId.key,
    'popularSourceId': state.popularSourceId.key,
    'favoritesSourceId': state.favoritesSourceId.key,
    'favoriteSearchQuery': state.favoriteSearchQuery,
    'searchQuery': state.searchQuery,
    'promptQuery': state.promptQuery,
    'popularQuery': state.popularQuery,
    'popularPromptQuery': state.popularPromptQuery,
    'fuzzySearchEnabled': state.fuzzySearchEnabled,
    'selectedRatings': (state.selectedRatings.toList()..sort()),
    'popularScale': state.popularScale.name,
    'popularDate': state.popularDate?.toIso8601String(),
    'aiTagTimeRange': state.aiTagTimeRange,
    'aiTagPopularPeriod': state.aiTagPopularPeriod,
    'quickTagCloudFilterKey': state.quickTagCloudFilterKey,
    'dateRangeStart': state.dateRangeStart?.toIso8601String(),
    'dateRangeEnd': state.dateRangeEnd?.toIso8601String(),
    'randomEnabled': state.randomEnabled,
    'artistHuntEnabled': state.artistHuntEnabled,
  });
}

OnlineGalleryState decodeOnlineGalleryBrowsingSession(String? encoded) {
  if (encoded == null || encoded.trim().isEmpty) {
    return const OnlineGalleryState();
  }
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map ||
        (decoded['version'] != 1 && decoded['version'] != 2)) {
      return const OnlineGalleryState();
    }
    final json = Map<String, dynamic>.from(decoded);
    final sourceId = _decodeGallerySource(json['sourceId']);
    final popularSourceCandidate = _decodeGallerySource(
      json['popularSourceId'],
    );
    final popularSourceId = popularSourceCandidate.capabilities.supportsRanking
        ? popularSourceCandidate
        : GallerySourceId.danbooru;
    final favoritesSourceId = _decodeGallerySource(json['favoritesSourceId']);
    final viewMode = _decodeEnumByName(
      GalleryViewMode.values,
      json['viewMode'],
      GalleryViewMode.search,
    );
    final selectedRatings = _decodeRatings(json['selectedRatings']);
    final quickTagCloudQuery = QuickTagCloudGalleryQuery.tryParseStableKey(
      json['quickTagCloudFilterKey'] is String
          ? json['quickTagCloudFilterKey'] as String
          : null,
    );
    final base = OnlineGalleryState(
      searchQuery: _decodeBoundedString(json['searchQuery']),
      promptQuery: _decodeBoundedString(json['promptQuery']),
      popularQuery: _decodeBoundedString(json['popularQuery']),
      popularPromptQuery: _decodeBoundedString(json['popularPromptQuery']),
      fuzzySearchEnabled: json['fuzzySearchEnabled'] == true,
      sourceId: sourceId,
      popularSourceId: popularSourceId,
      favoritesSourceId: favoritesSourceId,
      favoriteSearchQuery: _decodeBoundedString(
        json['favoriteSearchQuery'],
        maxLength: 500,
      ),
      selectedRatings: selectedRatings,
      viewMode: viewMode,
      popularScale: _decodeEnumByName(
        PopularScale.values,
        json['popularScale'],
        PopularScale.day,
      ),
      popularDate: _decodeDate(json['popularDate']),
      aiTagTimeRange: _decodeBoundedString(
        json['aiTagTimeRange'],
        fallback: 'all',
        maxLength: 100,
      ),
      aiTagPopularPeriod: _decodeBoundedString(
        json['aiTagPopularPeriod'],
        fallback: 'current',
        maxLength: 100,
      ),
      quickTagCloudFilterKey:
          quickTagCloudQuery?.stableKey ??
          QuickTagCloudGalleryQuery.defaultStableKey,
      dateRangeStart: _decodeDate(json['dateRangeStart']),
      dateRangeEnd: _decodeDate(json['dateRangeEnd']),
      artistHuntEnabled: json['artistHuntEnabled'] == true,
    );

    final randomEnabled = json['randomEnabled'] == true && base.supportsRandom;
    return base.copyWith(randomEnabled: randomEnabled);
  } catch (error, stack) {
    AppLogger.w(
      'Ignored invalid online gallery browsing session',
      'OnlineGallery',
    );
    AppLogger.d('$error\n$stack', 'OnlineGallery');
    return const OnlineGalleryState();
  }
}

GallerySourceId _decodeGallerySource(Object? value) {
  if (value is! String) return GallerySourceId.danbooru;
  return GallerySourceId.fromKey(value);
}

T _decodeEnumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is! String) return fallback;
  return values.firstWhere(
    (candidate) => candidate.name == value,
    orElse: () => fallback,
  );
}

Set<String> _decodeRatings(Object? value) {
  if (value is! List) return kAllRatings;
  final ratings = value.whereType<String>().where(kAllRatings.contains).toSet();
  return ratings.isEmpty ? kAllRatings : ratings;
}

String _decodeBoundedString(
  Object? value, {
  String fallback = '',
  int maxLength = 10000,
}) {
  if (value is! String || value.length > maxLength) return fallback;
  return value;
}

DateTime? _decodeDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

extension GallerySourceIdCapabilities on GallerySourceId {
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[this]!;
}
