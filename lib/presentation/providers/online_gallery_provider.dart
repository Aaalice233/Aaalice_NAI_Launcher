import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/online_gallery_detail_coordinator.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/network/online_gallery_retry_interceptor.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_api_service.dart';
import '../../data/datasources/remote/gelbooru_api_service.dart';
import '../../data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/donmai_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/gallery_random_sampler.dart';
import '../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/gelbooru_gallery_source_adapter.dart';
import '../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import '../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/models/online_gallery/gelbooru_post_parser.dart';
import '../../data/models/online_gallery/quick_tag_cloud_catalog.dart';
import '../../data/models/online_gallery/quick_tag_cloud_codex.dart';
import '../../data/repositories/online_gallery_local_favorites_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/artist_chain_parser.dart';
import 'online_gallery_blacklist_provider.dart';
import 'online_gallery_local_favorites_provider.dart';
import 'quick_tag_cloud_gallery_provider.dart';

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

String? _normalizeGalleryPolicyTag(String value) {
  var normalized = value.trim().toLowerCase();
  while (normalized.startsWith('-')) {
    normalized = normalized.substring(1).trimLeft();
  }
  normalized = normalized.replaceAll(RegExp(r'\s+'), '_');
  return normalized.isEmpty ? null : normalized;
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
  artistHuntDetailFailed,
}

enum OnlineGalleryNotice { gelbooruCredentialsInvalid }

String onlineGalleryPostKey(GalleryItem item) => item.stableKey;

@Riverpod(keepAlive: true)
Dio onlineGalleryHttpClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(OnlineGalleryRetryInterceptor(dio: dio));
  return dio;
}

final quickTagCloudGallerySourceAdapterProvider =
    Provider<QuickTagCloudGallerySourceAdapter>((ref) {
      return QuickTagCloudGallerySourceAdapter(
        catalogService: ref.watch(quickTagCloudCatalogServiceProvider),
        userService: ref.watch(quickTagCloudUserServiceProvider),
        queryReader: () {
          final query = ref.read(quickTagCloudFilterProvider);
          return query;
        },
      );
    });

final quickTagCloudCatalogProvider =
    FutureProvider.autoDispose<QuickTagCloudCatalog>((ref) {
      return ref.watch(quickTagCloudGallerySourceAdapterProvider).getCatalog();
    });

final quickTagCloudCodexProvider = FutureProvider.autoDispose
    .family<QuickTagCloudCodex, String>((ref, id) {
      return ref.watch(quickTagCloudGallerySourceAdapterProvider).getCodex(id);
    });

@Riverpod(keepAlive: true)
Map<GallerySourceId, GallerySourceAdapter> onlineGallerySourceAdapters(
  Ref ref,
) {
  final dio = ref.watch(onlineGalleryHttpClientProvider);
  return {
    GallerySourceId.danbooru: DonmaiGallerySourceAdapter(
      sourceId: GallerySourceId.danbooru,
      dio: dio,
      authHeader: () => ref.read(danbooruAuthProvider.notifier).getAuthHeader(),
    ),
    GallerySourceId.safebooru: DonmaiGallerySourceAdapter(
      sourceId: GallerySourceId.safebooru,
      dio: dio,
      authHeader: () => ref.read(danbooruAuthProvider.notifier).getAuthHeader(),
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
    GallerySourceId.quickTagCloud: ref.watch(
      quickTagCloudGallerySourceAdapterProvider,
    ),
  };
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
  });

  final List<GalleryItem> posts;
  final int page;
  final String? nextCursor;
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

  ModeCache copyWith({
    List<GalleryItem>? posts,
    int? page,
    String? nextCursor,
    bool? hasMore,
    int? total,
    double? scrollOffset,
    String? anchorStableKey,
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
  }) {
    return ModeCache(
      posts: posts ?? this.posts,
      page: page ?? this.page,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      anchorStableKey: anchorStableKey ?? this.anchorStableKey,
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
    );
  }
}

class _ArtistHuntResolution {
  const _ArtistHuntResolution({
    required this.items,
    required this.successfulCandidateKeys,
    required this.resolvedCount,
    required this.failureCount,
  });

  final List<GalleryItem> items;
  final Set<String> successfulCandidateKeys;
  final int resolvedCount;
  final int failureCount;
}

class _ArtistHuntCandidateOutcome {
  const _ArtistHuntCandidateOutcome.success(this.detail) : error = null;
  const _ArtistHuntCandidateOutcome.failure(this.error) : detail = null;

  final GalleryDetail? detail;
  final Object? error;
  bool get succeeded => detail != null;
}

class _ArtistHuntDetailException implements Exception {
  const _ArtistHuntDetailException(this.failureCount);

  final int failureCount;

  @override
  String toString() => 'Failed to resolve $failureCount AI TAG works';
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
        return 'search:${sourceId.key}:${searchQuery.trim()}|${promptQuery.trim()}|$fuzzySearchEnabled|${_ratingsKey(selectedRatings)}|${dateRangeStart?.toIso8601String() ?? ''}|${dateRangeEnd?.toIso8601String() ?? ''}|$aiTagTimeRange|artistHunt:${sourceId == GallerySourceId.aiTag && artistHuntEnabled}|codex:${sourceId == GallerySourceId.quickTagCloud ? quickTagCloudFilterKey : ''}|blacklist:$blacklistRevision';
      case GalleryViewMode.popular:
        return 'popular:${popularSourceId.key}:${popularScale.name}|${popularDate?.toIso8601String() ?? ''}|$aiTagPopularPeriod|${popularQuery.trim()}|${popularPromptQuery.trim()}|${_ratingsKey(selectedRatings)}|artistHunt:${popularSourceId == GallerySourceId.aiTag && artistHuntEnabled}|blacklist:$blacklistRevision';
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
    bool? randomEnabled,
    RandomGallerySession? randomSession,
    bool? artistHuntEnabled,
    int? blacklistRevision,
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
      aiTagConfig: aiTagConfig ?? this.aiTagConfig,
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
      dateRangeStart: clearDateRange
          ? null
          : (dateRangeStart ?? this.dateRangeStart),
      dateRangeEnd: clearDateRange ? null : (dateRangeEnd ?? this.dateRangeEnd),
      randomEnabled: randomEnabled ?? this.randomEnabled,
      randomSession: randomSession ?? this.randomSession,
      artistHuntEnabled: artistHuntEnabled ?? this.artistHuntEnabled,
      blacklistRevision: blacklistRevision ?? this.blacklistRevision,
    );
  }

  OnlineGalleryState updateCurrentCache(ModeCache cache) {
    final updated = LinkedHashMap<String, ModeCache>.of(caches)
      ..remove(currentCacheKey)
      ..[currentCacheKey] = cache;
    _trimCaches(updated, currentCacheKey);
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
    _trimCaches(updated, currentCacheKey);
    return copyWith(caches: updated);
  }

  static void _trimCaches(
    LinkedHashMap<String, ModeCache> caches,
    String protectedKey,
  ) {
    while (caches.length > 12) {
      final oldestEvictable = caches.keys.cast<String?>().firstWhere(
        (key) => key != protectedKey,
        orElse: () => null,
      );
      if (oldestEvictable == null) return;
      caches.remove(oldestEvictable);
    }
  }

  static String _ratingsKey(Set<String> ratings) {
    final sorted = ratings.toList()..sort();
    return sorted.join();
  }
}

/// Encodes only browsing intent and lightweight location metadata. Remote
/// gallery rows are deliberately refreshed after restart so stale URLs and
/// source-side favorite/ranking changes are not treated as durable data.
String encodeOnlineGalleryBrowsingSession(OnlineGalleryState state) {
  final positions = <String, dynamic>{};
  for (final entry in state.caches.entries) {
    positions[entry.key] = _encodeGalleryPosition(entry.value);
  }
  positions
    ..remove(state.currentCacheKey)
    ..[state.currentCacheKey] = _encodeGalleryPosition(state.currentCache);
  while (positions.length > 12) {
    positions.remove(positions.keys.first);
  }

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
    'randomPosition': _encodeGalleryPosition(state.randomSession.cache),
    'artistHuntEnabled': state.artistHuntEnabled,
    'positions': positions,
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

    final caches = <String, ModeCache>{};
    final cachePriorities = <String, int>{};
    final legacyFavoritesScope = json['favoritesScope'];
    final rawPositions = json['positions'];
    if (rawPositions is Map) {
      for (final entry in rawPositions.entries.take(12)) {
        final rawKey = entry.key;
        if (rawKey is! String || rawKey.isEmpty || rawKey.length > 4096) {
          continue;
        }
        final key = _migrateFavoritesCacheKey(rawKey);
        final position = _decodeGalleryPosition(entry.value);
        if (position == null) continue;
        final legacyMatch = _legacyFavoritesCacheKeyPattern.firstMatch(rawKey);
        final priority = legacyMatch == null
            ? 3
            : legacyMatch.group(2) == legacyFavoritesScope
            ? 2
            : 1;
        if (priority > (cachePriorities[key] ?? 0)) {
          caches[key] = position;
          cachePriorities[key] = priority;
        }
      }
    }
    var restored = base.copyWith(caches: caches);
    final randomPosition =
        _decodeGalleryPosition(json['randomPosition']) ?? const ModeCache();
    final randomEnabled =
        json['randomEnabled'] == true && restored.supportsRandom;
    restored = restored.copyWith(
      randomEnabled: randomEnabled,
      randomSession: RandomGallerySession(cache: randomPosition),
    );
    return restored;
  } catch (error, stack) {
    AppLogger.w(
      'Ignored invalid online gallery browsing session',
      'OnlineGallery',
    );
    AppLogger.d('$error\n$stack', 'OnlineGallery');
    return const OnlineGalleryState();
  }
}

Map<String, dynamic> _encodeGalleryPosition(ModeCache cache) => {
  'page': cache.page,
  'scrollOffset': cache.scrollOffset,
  if (cache.anchorStableKey != null) 'anchorStableKey': cache.anchorStableKey,
  'anchorLocalOffset': cache.anchorLocalOffset,
};

ModeCache? _decodeGalleryPosition(Object? raw) {
  if (raw is! Map) return null;
  final pageValue = raw['page'];
  final offsetValue = raw['scrollOffset'] ?? raw['offset'];
  final localOffsetValue = raw['anchorLocalOffset'];
  final page = pageValue is num
      ? pageValue.toInt().clamp(1, 1000000).toInt()
      : 1;
  final offset = offsetValue is num && offsetValue.isFinite
      ? offsetValue.toDouble().clamp(0, double.maxFinite).toDouble()
      : 0.0;
  final localOffset = localOffsetValue is num && localOffsetValue.isFinite
      ? localOffsetValue.toDouble().clamp(0, double.maxFinite).toDouble()
      : 0.0;
  final anchor = raw['anchorStableKey'];
  return ModeCache(
    page: page,
    nextCursor: '$page',
    scrollOffset: offset,
    anchorStableKey: anchor is String && anchor.length <= 256 ? anchor : null,
    anchorLocalOffset: localOffset,
  );
}

final _legacyFavoritesCacheKeyPattern = RegExp(
  r'^favorites:(danbooru|safebooru|gelbooru|ai_tag|quick_tag_cloud):(local|remote)\|',
);

String _migrateFavoritesCacheKey(String key) {
  final match = _legacyFavoritesCacheKeyPattern.firstMatch(key);
  if (match == null) return key;
  return 'favorites:${match.group(1)}|${key.substring(match.end)}';
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

@riverpod
class OnlineGalleryNotifier extends _$OnlineGalleryNotifier {
  static const int _pageSize = 60;

  CancelToken? _cancelToken;
  int _requestGeneration = 0;
  OnlineGalleryState? _normalRestorePoint;
  OnlineGalleryDetailCoordinator? _detailCoordinator;
  String? _lastPersistedBrowsingSession;
  String? _pendingRestoredCacheKey;
  int? _pendingRestoredPage;
  Future<void> _persistenceQueue = Future<void>.value();
  Timer? _blacklistRefreshDebounce;
  Set<String> _localFavoriteKeys = const {};
  final Set<String> _remoteFavoriteKeys = <String>{};

  OnlineGalleryDetailCoordinator get _details =>
      _detailCoordinator ??= OnlineGalleryDetailCoordinator(
        loader: (item, cancelToken) =>
            _adapters[item.sourceId]!.detail(item, cancelToken: cancelToken),
      );

  @override
  OnlineGalleryState build() {
    ref.keepAlive();
    ref.onDispose(() {
      _blacklistRefreshDebounce?.cancel();
      _requestGeneration++;
      if (_cancelToken != null && !_cancelToken!.isCancelled) {
        _cancelToken!.cancel('Online gallery notifier disposed');
      }
      _detailCoordinator?.clear();
    });
    final storage = ref.read(localStorageServiceProvider);
    final persistedSession = storage.getSetting<String>(
      StorageKeys.onlineGalleryBrowsingSessionV1,
    );
    final restored = decodeOnlineGalleryBrowsingSession(persistedSession);
    if (!restored.randomEnabled &&
        persistedSession != null &&
        restored.currentCache.page > 1) {
      _pendingRestoredCacheKey = restored.currentCacheKey;
      _pendingRestoredPage = restored.currentCache.page;
    }
    _lastPersistedBrowsingSession = encodeOnlineGalleryBrowsingSession(
      restored,
    );
    if (restored.randomEnabled) {
      _normalRestorePoint = restored.copyWith(randomEnabled: false);
    }
    listenSelf((_, next) => _persistBrowsingSession(storage, next));
    if (Hive.isBoxOpen(StorageKeys.localFavoritesBox)) {
      Future.microtask(() async {
        await ref
            .read(onlineGalleryLocalFavoritesProvider.notifier)
            .initialize();
        _handleLocalFavoritesChanged(reloadFavorites: false);
      });
      ref.listen<(bool, int)>(
        onlineGalleryLocalFavoritesProvider.select(
          (value) => (value.isInitialized, value.revision),
        ),
        (previous, next) => _handleLocalFavoritesChanged(
          reloadFavorites: previous?.$2 != next.$2,
        ),
      );
    }
    ref.listen<String?>(
      danbooruAuthProvider.select((value) => value.user?.name),
      (_, _) => _handleAccountIdentityChanged(GallerySourceId.danbooru),
    );
    ref.listen<String?>(
      gelbooruAuthProvider.select(
        (value) => value.credentials?.userId.toString(),
      ),
      (_, _) => _handleAccountIdentityChanged(GallerySourceId.gelbooru),
    );
    ref.listen<int>(
      onlineGalleryBlacklistNotifierProvider.select((value) => value.revision),
      (_, _) => _handleBlacklistChanged(),
    );
    return restored;
  }

  void _persistBrowsingSession(
    LocalStorageService storage,
    OnlineGalleryState next,
  ) {
    final encoded = encodeOnlineGalleryBrowsingSession(next);
    if (encoded == _lastPersistedBrowsingSession) return;
    _lastPersistedBrowsingSession = encoded;
    _persistenceQueue = _persistenceQueue.then((_) async {
      try {
        await storage.setSetting(
          StorageKeys.onlineGalleryBrowsingSessionV1,
          encoded,
        );
      } catch (error, stack) {
        AppLogger.e(
          'Failed to persist online gallery browsing session',
          error,
          stack,
          'OnlineGallery',
        );
      }
    });
  }

  void _handleLocalFavoritesChanged({bool reloadFavorites = true}) {
    final localState = ref.read(onlineGalleryLocalFavoritesProvider);
    if (!localState.isInitialized) return;
    final nextLocalKeys = ref
        .read(onlineGalleryLocalFavoritesRepositoryProvider)
        .stableKeys;
    final retainedCaches = <String, ModeCache>{
      for (final entry in state.caches.entries)
        if (!entry.key.startsWith('favorites:')) entry.key: entry.value,
    };
    _localFavoriteKeys = nextLocalKeys;
    state = state.copyWith(
      caches: retainedCaches,
      favoritedPostKeys: {..._localFavoriteKeys, ..._remoteFavoriteKeys},
      localFavoritedPostKeys: _localFavoriteKeys,
      remoteFavoritedPostKeys: _remoteFavoriteKeys,
    );
    if (reloadFavorites && state.viewMode == GalleryViewMode.favorites) {
      _cancelCurrentRequest();
      if (state.randomEnabled) {
        state = state.copyWith(randomSession: const RandomGallerySession());
      }
      unawaited(loadPosts(refresh: true));
    }
  }

  void _handleBlacklistChanged() {
    _blacklistRefreshDebounce?.cancel();
    _blacklistRefreshDebounce = Timer(const Duration(milliseconds: 150), () {
      if (state.randomEnabled) {
        _cancelCurrentRequest();
        state = state.copyWith(
          blacklistRevision: state.blacklistRevision + 1,
          randomSession: const RandomGallerySession(),
          clearError: true,
        );
        unawaited(_loadRandom(replace: true, restart: true));
        return;
      }
      _cancelCurrentRequest();
      state = state
          .copyWith(blacklistRevision: state.blacklistRevision + 1)
          .updateCurrentCache(const ModeCache());
      unawaited(loadPosts(refresh: true));
    });
  }

  void _handleAccountIdentityChanged(GallerySourceId sourceId) {
    final retainedCaches = <String, ModeCache>{
      for (final entry in state.caches.entries)
        if (!entry.key.startsWith('favorites:${sourceId.key}'))
          entry.key: entry.value,
    };
    _remoteFavoriteKeys.removeWhere(
      (key) => key.startsWith('${sourceId.key}:'),
    );
    state = state.copyWith(
      caches: retainedCaches,
      favoritedPostKeys: {..._localFavoriteKeys, ..._remoteFavoriteKeys},
      remoteFavoritedPostKeys: _remoteFavoriteKeys,
    );
    if (state.activeSourceId != sourceId ||
        (!state.randomEnabled && state.viewMode != GalleryViewMode.favorites)) {
      return;
    }
    _cancelCurrentRequest();
    if (state.randomEnabled) {
      state = state.copyWith(
        randomSession: const RandomGallerySession(),
        clearError: true,
      );
      unawaited(_loadRandom(replace: true, restart: true));
    } else if (state.viewMode == GalleryViewMode.favorites) {
      unawaited(loadPosts(refresh: true));
    }
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
    _detailCoordinator?.cancelQueuedVisible();
    if (state.isLoading || state.isLoadingMore) {
      state = state.copyWith(isLoading: false, isLoadingMore: false);
    }
  }

  bool _isCurrentRequest(int generation, String cacheKey) {
    return generation == _requestGeneration &&
        state.currentCacheKey == cacheKey;
  }

  void saveScrollOffset(
    double offset, {
    String? anchorStableKey,
    double anchorLocalOffset = 0,
  }) {
    final activeCache = state.randomEnabled
        ? state.randomSession.cache
        : state.currentCache;
    final cache = activeCache.copyWith(
      scrollOffset: offset,
      anchorStableKey: anchorStableKey,
      anchorLocalOffset: anchorLocalOffset,
    );
    if (state.randomEnabled) {
      state = state.copyWith(
        randomSession: state.randomSession.copyWith(cache: cache),
      );
      return;
    }
    state = state.updateCurrentCache(cache);
  }

  Future<void> switchToSearch() async {
    if (state.viewMode == GalleryViewMode.search) return;
    final sourceId = state.activeSourceId;
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.search,
      sourceId: sourceId,
      quickTagCloudFilterKey: sourceId == GallerySourceId.quickTagCloud
          ? ref.read(quickTagCloudFilterProvider).stableKey
          : state.quickTagCloudFilterKey,
      clearError: true,
    );
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> switchToPopular() async {
    if (state.viewMode == GalleryViewMode.popular) return;
    final sourceId = state.activeSourceId;
    if (!sourceId.capabilities.supportsRanking) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.popular,
      popularSourceId: sourceId,
      clearError: true,
    );
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> switchToFavorites() async {
    final sourceId = state.activeSourceId;
    if (!sourceId.capabilities.supportsLocalFavorites) return;
    if (sourceId == GallerySourceId.gelbooru) {
      await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
    }
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.favorites,
      favoritesSourceId: sourceId,
      clearError: true,
    );
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setSource(Object source) async {
    final sourceId = _normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsSearch) return;
    if (state.sourceId == sourceId) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      sourceId: sourceId,
      popularSourceId: sourceId.capabilities.supportsRanking
          ? sourceId
          : state.popularSourceId,
      favoritesSourceId: sourceId.capabilities.supportsLocalFavorites
          ? sourceId
          : state.favoritesSourceId,
      quickTagCloudFilterKey: sourceId == GallerySourceId.quickTagCloud
          ? ref.read(quickTagCloudFilterProvider).stableKey
          : state.quickTagCloudFilterKey,
      clearError: true,
    );
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setPopularSource(Object source) async {
    final sourceId = _normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsRanking) return;
    if (state.popularSourceId == sourceId) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      sourceId: sourceId,
      popularSourceId: sourceId,
      favoritesSourceId: sourceId.capabilities.supportsLocalFavorites
          ? sourceId
          : state.favoritesSourceId,
      clearError: true,
    );
    if (state.viewMode == GalleryViewMode.popular &&
        (state.randomEnabled || state.currentCache.posts.isEmpty)) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setFavoritesSource(Object source) async {
    final sourceId = _normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsLocalFavorites) {
      return;
    }
    if (state.favoritesSourceId == sourceId) return;
    if (sourceId == GallerySourceId.gelbooru) {
      await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
    }
    _cancelCurrentRequest();
    state = state.copyWith(
      sourceId: sourceId,
      popularSourceId: sourceId.capabilities.supportsRanking
          ? sourceId
          : state.popularSourceId,
      favoritesSourceId: sourceId,
      quickTagCloudFilterKey: sourceId == GallerySourceId.quickTagCloud
          ? ref.read(quickTagCloudFilterProvider).stableKey
          : state.quickTagCloudFilterKey,
      clearError: true,
      clearNotice: true,
    );
    if (state.viewMode == GalleryViewMode.favorites) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> searchFavorites(String query) async {
    final normalized = query.trim();
    if (state.favoriteSearchQuery == normalized &&
        state.viewMode == GalleryViewMode.favorites) {
      return;
    }
    _cancelCurrentRequest();
    state = state.copyWith(
      favoriteSearchQuery: normalized,
      viewMode: GalleryViewMode.favorites,
      clearError: true,
    );
    await loadPosts(refresh: true);
  }

  void syncQuickTagCloudFilterKey() {
    final key = ref.read(quickTagCloudFilterProvider).stableKey;
    if (state.quickTagCloudFilterKey == key) return;
    _cancelCurrentRequest();
    state = state.copyWith(quickTagCloudFilterKey: key, clearError: true);
  }

  Future<void> _ensureQuickTagCloudFilterInitialized() async {
    if (state.activeSourceId != GallerySourceId.quickTagCloud) return;
    final notifier = ref.read(quickTagCloudFilterProvider.notifier);
    final restored = QuickTagCloudGalleryQuery.tryParseStableKey(
      state.quickTagCloudFilterKey,
    );
    await notifier.initializeContentAccess();
    if (restored != null &&
        state.quickTagCloudFilterKey !=
            QuickTagCloudGalleryQuery.defaultStableKey) {
      notifier.restoreBrowsingSessionFilters(restored);
    }
    final key = ref.read(quickTagCloudFilterProvider).stableKey;
    if (state.quickTagCloudFilterKey != key) {
      state = state.copyWith(quickTagCloudFilterKey: key, clearError: true);
    }
  }

  void clearDetailCache() => _detailCoordinator?.clear();

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

  Future<void> setArtistHuntEnabled(bool enabled) async {
    if (state.artistHuntEnabled == enabled) return;
    _cancelCurrentRequest();
    final next = state.copyWith(artistHuntEnabled: enabled, clearError: true);
    if (_normalRestorePoint != null) {
      _normalRestorePoint = _normalRestorePoint!.copyWith(
        artistHuntEnabled: enabled,
        clearError: true,
      );
    }
    state = next;

    if (state.randomEnabled) {
      state = state.copyWith(randomSession: const RandomGallerySession());
      await _loadRandom(replace: true, restart: true);
      return;
    }
    if (state.currentCache.posts.isEmpty) {
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

  Future<void> setRandomEnabled(bool enabled) async {
    if (state.randomEnabled == enabled) return;
    _cancelCurrentRequest();
    if (!enabled) {
      final restore = _normalRestorePoint;
      _normalRestorePoint = null;
      state = (restore ?? state).copyWith(
        randomEnabled: false,
        randomSession: state.randomSession,
        favoritedPostKeys: state.favoritedPostKeys,
        localFavoritedPostKeys: state.localFavoritedPostKeys,
        remoteFavoritedPostKeys: state.remoteFavoritedPostKeys,
        favoriteLoadingPostKeys: state.favoriteLoadingPostKeys,
        aiTagConfig: state.aiTagConfig,
        artistHuntEnabled: state.artistHuntEnabled,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
      return;
    }
    if (!state.supportsRandom) return;
    _normalRestorePoint = state;
    state = state.copyWith(
      randomEnabled: true,
      randomSession: const RandomGallerySession(),
      clearError: true,
    );
    await _loadRandom(replace: true, restart: true);
  }

  Future<void> restartRandom() async {
    if (!state.randomEnabled) return;
    state = state.copyWith(randomSession: const RandomGallerySession());
    await _loadRandom(replace: true, restart: true);
  }

  Future<void> _loadRandom({
    required bool replace,
    bool restart = false,
  }) async {
    if (!state.randomEnabled || !state.supportsRandom) return;
    if (!replace &&
        (state.isLoading ||
            state.isLoadingMore ||
            state.randomSession.exhausted)) {
      return;
    }

    // Establish latest-call-wins before any initialization await. Otherwise an
    // earlier QuickTagCloud refresh can finish initialization later and cancel
    // the request started by a newer click.
    final generation = _beginRequest();
    await _ensureQuickTagCloudFilterInitialized();
    if (generation != _requestGeneration ||
        !state.randomEnabled ||
        !state.supportsRandom) {
      return;
    }
    final cacheKey = state.currentCacheKey;
    state = state.copyWith(
      isLoading: replace,
      isLoadingMore: !replace,
      clearError: true,
    );
    try {
      final sourceId = state.activeSourceId;
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (generation != _requestGeneration || !state.randomEnabled) return;
      final blacklist = ref.read(onlineGalleryBlacklistNotifierProvider).tags;
      if (state.viewMode == GalleryViewMode.favorites &&
          !_canLoadRemoteFavorites(state.favoritesSourceId)) {
        await _loadRandomLocalFavorites(
          generation: generation,
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
      if (session.seenStableKeys.length >= 20000) {
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          randomSession: session.copyWith(exhausted: true),
        );
        return;
      }

      final adapter = _adapters[sourceId]!;
      final request = _randomRequest(session, blacklist);
      final page = await adapter.random(request, cancelToken: _cancelToken);
      if (generation != _requestGeneration ||
          !state.randomEnabled ||
          state.currentCacheKey != cacheKey) {
        return;
      }

      final eligibleItems = await _filterByBlacklistCompletingDetails(
        page.items,
        blacklist,
      );
      if (generation != _requestGeneration ||
          !state.randomEnabled ||
          state.currentCacheKey != cacheKey) {
        return;
      }
      final artistHuntActive = state.isArtistHuntActive;
      final seen = Set<String>.of(session.seenStableKeys);
      final seenCandidates = Set<String>.of(session.seenCandidateStableKeys);
      final candidates = <GalleryItem>[];
      for (var index = 0; index < eligibleItems.length; index++) {
        if (index > 0 && index % 256 == 0) {
          await Future<void>.delayed(Duration.zero);
          if (generation != _requestGeneration || !state.randomEnabled) {
            return;
          }
        }
        final item = eligibleItems[index];
        final identity = artistHuntActive
            ? item.detailStableKey
            : item.stableKey;
        final alreadySeen = artistHuntActive
            ? seenCandidates.contains(identity)
            : seen.contains(identity);
        if (alreadySeen || seen.length >= 20000) continue;
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
        final artistHuntDeduplicationKeys = _artistHuntDeduplicationKeys(posts);
        final resolution = await _resolveArtistHuntCandidates(
          candidates,
          generation: generation,
          cacheKey: cacheKey,
          deduplicationKeys: artistHuntDeduplicationKeys,
          onProgress: (items, resolvedDelta, failureDelta) {
            if (generation != _requestGeneration || !state.randomEnabled) {
              return;
            }
            resolvedCount += resolvedDelta;
            failureCount += failureDelta;
            final freshItems = items
                .where((item) {
                  if (seen.length >= 20000 || !seen.add(item.stableKey)) {
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
          throw _ArtistHuntDetailException(resolution.failureCount);
        }
        seenCandidates.addAll(resolution.successfulCandidateKeys);
      } else {
        for (final item in candidates) {
          if (seen.length >= 20000 || !seen.add(item.stableKey)) continue;
          unique.add(item);
        }
        posts = posts.appendPage(unique);
      }

      final misses = unique.isEmpty ? session.consecutiveMisses + 1 : 0;
      final sourceExhausted =
          sourceId == GallerySourceId.quickTagCloud && !page.hasMore;
      final exhausted = sourceExhausted || misses >= 4 || seen.length >= 20000;
      final nextSession = RandomGallerySession(
        scopeKey: scopeKey,
        cache: session.cache.copyWith(
          posts: posts,
          page: 1,
          nextCursor: page.nextCursor ?? session.nextCursor ?? 'random',
          hasMore: !exhausted,
          total: artistHuntActive ? null : page.total,
          endedByDuplicatePage: exhausted,
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
        clearError: true,
      );
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) return;
      if (generation != _requestGeneration || !state.randomEnabled) return;
      final isArtistHuntDetailFailure = error is _ArtistHuntDetailException;
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
    required int generation,
    required String cacheKey,
    required Set<String> blacklist,
    required bool replace,
    required bool restart,
  }) async {
    await ref.read(onlineGalleryLocalFavoritesProvider.notifier).initialize();
    if (!_isCurrentRequest(generation, cacheKey) || !state.randomEnabled) {
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
  ) {
    switch (state.viewMode) {
      case GalleryViewMode.search:
        return GalleryRandomSearchRequest(
          pageSize: _pageSize,
          query: state.activeSourceId == GallerySourceId.aiTag
              ? state.searchQuery.trim()
              : buildOnlineGallerySearchQuery(
                  state.searchQuery,
                  fuzzyMatch:
                      state.activeSourceId != GallerySourceId.quickTagCloud &&
                      state.fuzzySearchEnabled,
                ),
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
              : _rankingKind(state.popularScale),
          date: state.popularDate,
          period: state.aiTagPopularPeriod,
          query: state.popularQuery,
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

  Future<void> loadPosts({bool refresh = false}) async {
    if (state.randomEnabled) {
      await _loadRandom(replace: refresh);
      return;
    }
    if (!refresh && (state.isLoading || state.isLoadingMore)) return;
    final restoredPage =
        !refresh && _pendingRestoredCacheKey == state.currentCacheKey
        ? _pendingRestoredPage
        : null;
    _pendingRestoredCacheKey = null;
    _pendingRestoredPage = null;
    switch (state.viewMode) {
      case GalleryViewMode.search:
      case GalleryViewMode.popular:
        await _loadAdapterPage(
          refresh: refresh,
          initialCursor: restoredPage == null ? null : '$restoredPage',
        );
        return;
      case GalleryViewMode.favorites:
        await _loadFavorites(refresh: refresh, targetPage: restoredPage);
        return;
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
        !state.hasMore) {
      return;
    }
    await loadPosts();
  }

  Future<void> refresh() => loadPosts(refresh: true);

  Future<void> retryAppend() async {
    if (state.randomEnabled ||
        state.isLoading ||
        state.isLoadingMore ||
        state.currentCache.appendErrorCode == null) {
      return;
    }
    await loadPosts();
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
    final generation = _beginRequest();
    await _ensureQuickTagCloudFilterInitialized();
    if (generation != _requestGeneration || state.randomEnabled) return;

    final cache = state.currentCache;
    final cursor = initialCursor ?? (refresh ? '1' : cache.nextCursor);
    if (cursor == null) return;
    final sourceId = state.viewMode == GalleryViewMode.popular
        ? state.popularSourceId
        : state.sourceId;
    final adapter = _adapters[sourceId]!;
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
      final blacklist = ref.read(onlineGalleryBlacklistNotifierProvider).tags;
      AiTagSourceConfig? aiTagConfig;
      if (adapter is AiTagGallerySourceAdapter) {
        aiTagConfig = await adapter.getConfig(cancelToken: _cancelToken);
        if (!_isCurrentRequest(generation, cacheKey)) return;
      }
      final artistHuntActive = state.isArtistHuntActive;
      final baseItems = refresh
          ? ChunkedGalleryItems()
          : cache.posts is ChunkedGalleryItems
          ? cache.posts as ChunkedGalleryItems
          : ChunkedGalleryItems.from(cache.posts);
      final artistHuntDeduplicationKeys = artistHuntActive
          ? _artistHuntDeduplicationKeys(baseItems)
          : null;
      var merged = baseItems;
      var candidateCount = refresh ? 0 : cache.artistHuntCandidateCount;
      var resolvedCount = refresh ? 0 : cache.artistHuntResolvedCount;
      var failureCount = refresh ? 0 : cache.artistHuntFailureCount;
      var matchedItemCount = 0;
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
              prompt: _effectivePromptQuery(state.popularPromptQuery),
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
                  fuzzyMatch:
                      sourceId != GallerySourceId.quickTagCloud &&
                      state.fuzzySearchEnabled,
                );
          page = await adapter.search(
            GallerySearchRequest(
              cursor: requestCursor,
              pageSize: sourceId == GallerySourceId.aiTag
                  ? (aiTagConfig?.pageSize ?? 60)
                  : _pageSize,
              query: query,
              prompt: _effectivePromptQuery(state.promptQuery),
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

        List<GalleryItem> visiblePageItems =
            await _filterByBlacklistCompletingDetails(page.items, blacklist);
        if (!_isCurrentRequest(generation, cacheKey)) return;
        if (artistHuntActive) {
          candidateCount += visiblePageItems.length;
          final resolution = await _resolveArtistHuntCandidates(
            visiblePageItems,
            generation: generation,
            cacheKey: cacheKey,
            deduplicationKeys: artistHuntDeduplicationKeys!,
            onProgress: (items, resolvedDelta, failureDelta) {
              if (!_isCurrentRequest(generation, cacheKey)) return;
              resolvedCount += resolvedDelta;
              failureCount += failureDelta;
              if (items.isNotEmpty) merged = merged.appendPage(items);
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
          if (visiblePageItems.isNotEmpty &&
              resolution.resolvedCount == 0 &&
              resolution.failureCount > 0) {
            throw _ArtistHuntDetailException(resolution.failureCount);
          }
          visiblePageItems = resolution.items;
          matchedItemCount += visiblePageItems.length;
        } else {
          merged = merged.appendPage(visiblePageItems);
          matchedItemCount += visiblePageItems.length;
        }

        final nextCursor = page.nextCursor;
        final filteredPage =
            page.rawItemCount > 0 &&
            visiblePageItems.length < page.rawItemCount;
        stalledCursor =
            filteredPage &&
            nextCursor != null &&
            visitedCursors.contains(nextCursor);
        final shouldContinue =
            filteredPage &&
            matchedItemCount < _pageSize &&
            page.hasMore &&
            nextCursor != null &&
            !stalledCursor;
        if (!shouldContinue) break;
        requestCursor = nextCursor;
      }
      final duplicatePage =
          !refresh && matchedItemCount > 0 && merged.length == baseItems.length;
      final endedByDuplicatePage = duplicatePage || stalledCursor;
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
        posts: merged,
        page: parsedPage,
        nextCursor: endedByDuplicatePage ? null : page.nextCursor,
        total: artistHuntActive ? null : page.total,
        hasMore:
            !endedByDuplicatePage && page.hasMore && page.nextCursor != null,
        scrollOffset: refresh ? 0 : cache.scrollOffset,
        endedByDuplicatePage: endedByDuplicatePage,
        artistHuntCandidateCount: candidateCount,
        artistHuntResolvedCount: resolvedCount,
        artistHuntFailureCount: failureCount,
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
    if (sourceId == GallerySourceId.danbooru) {
      await ref.read(danbooruAuthProvider.notifier).ensureInitialized();
    } else if (sourceId == GallerySourceId.gelbooru) {
      await ref.read(gelbooruAuthProvider.notifier).ensureInitialized();
    }
    if (state.viewMode != GalleryViewMode.favorites ||
        state.favoritesSourceId != sourceId) {
      return;
    }
    final previousCache = state.currentCache;
    final pageNumber = targetPage ?? (refresh ? 1 : previousCache.page + 1);
    final generation = _beginRequest();
    final cacheKey = state.currentCacheKey;
    final resetBranches = refresh || targetPage != null;
    final isAppend = !resetBranches && previousCache.posts.isNotEmpty;
    var cache = resetBranches
        ? ModeCache(
            posts: previousCache.posts,
            page: pageNumber,
            localFavoritesOffset: (pageNumber - 1) * _pageSize,
            remoteFavoritesPage: pageNumber,
            localFavoriteItemKeys: previousCache.localFavoriteItemKeys,
            remoteFavoriteItemKeys: previousCache.remoteFavoriteItemKeys,
            scrollOffset: refresh ? 0 : previousCache.scrollOffset,
          )
        : previousCache;
    var posts = cache.posts is ChunkedGalleryItems
        ? cache.posts as ChunkedGalleryItems
        : ChunkedGalleryItems.from(cache.posts);
    state = state.copyWith(
      isLoading: !isAppend,
      isLoadingMore: isAppend,
      clearError: true,
    );

    Object? localError;
    Object? remoteError;
    try {
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
          final loadedLocalItemKeys = localPage.items
              .map(onlineGalleryPostKey)
              .toSet();
          if (resetBranches) {
            posts = _removeFavoriteBranch(
              posts,
              branchKeys: cache.localFavoriteItemKeys.difference(
                loadedLocalItemKeys,
              ),
              retainedByOtherBranch: cache.remoteFavoriteItemKeys,
            );
          }
          posts = posts.mergePage(
            localPage.items,
            mergeDuplicate: _mergeFavoriteItem,
          );
          final localItemKeys = resetBranches
              ? loadedLocalItemKeys
              : {
                  ...cache.localFavoriteItemKeys,
                  ...localPage.items.map(onlineGalleryPostKey),
                };
          cache = cache.copyWith(
            posts: posts,
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
          final List<GalleryItem> raw;
          final int rawCount;
          if (sourceId == GallerySourceId.danbooru) {
            raw = await _danbooruApi.getFavorites(
              username: _danbooruAuth.user!.name,
              page: requestPage,
              limit: _pageSize,
            );
            rawCount = raw.length;
          } else {
            final result = await _gelbooruApi.getFavorites(
              credentials: _gelbooruAuth.credentials!,
              pid: requestPage - 1,
              limit: _pageSize,
              cancelToken: _cancelToken,
            );
            raw = result.posts;
            rawCount = result.rawCount;
          }
          if (!_isCurrentRequest(generation, cacheKey)) return;
          final matching = _filterLocal(
            raw,
            const {},
          ).where(_matchesFavoriteSearch).toList(growable: false);
          final remoteItems = await _filterByBlacklistCompletingDetails(
            matching,
            blacklist,
          );
          if (!_isCurrentRequest(generation, cacheKey)) return;
          final upstreamEnded = rawCount < _pageSize;
          final nextRequestPage = requestPage + 1;
          final loadedRemoteItemKeys = remoteItems
              .map(onlineGalleryPostKey)
              .toSet();
          if (resetBranches) {
            posts = _removeFavoriteBranch(
              posts,
              branchKeys: cache.remoteFavoriteItemKeys.difference(
                loadedRemoteItemKeys,
              ),
              retainedByOtherBranch: cache.localFavoriteItemKeys,
            );
            _remoteFavoriteKeys.removeAll(cache.remoteFavoriteItemKeys);
          }
          posts = posts.mergePage(
            remoteItems,
            mergeDuplicate: _mergeFavoriteItem,
          );
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
          posts = _removeFavoriteBranch(
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
      if (isAppend &&
          cache.localFavoritesHasMore &&
          cache.localFavoriteItemKeys.length ==
              previousCache.localFavoriteItemKeys.length) {
        cache = cache.copyWith(localFavoritesHasMore: false);
      }
      if (isAppend &&
          cache.remoteFavoritesHasMore &&
          cache.remoteFavoriteItemKeys.length ==
              previousCache.remoteFavoriteItemKeys.length) {
        cache = cache.copyWith(remoteFavoritesHasMore: false);
      }
      final duplicatePage =
          isAppend &&
          posts.length == previousCache.posts.length &&
          !cache.localFavoritesHasMore &&
          !cache.remoteFavoritesHasMore;
      final hasMore =
          cache.localFavoritesHasMore || cache.remoteFavoritesHasMore;
      cache = cache.copyWith(
        posts: posts,
        page: pageNumber,
        nextCursor: hasMore ? '${pageNumber + 1}' : null,
        hasMore: hasMore,
        endedByDuplicatePage: duplicatePage,
        appendErrorCode: allAvailableBranchesFailed && isAppend
            ? _errorCode(remoteError ?? localError)
            : null,
        clearAppendError: !allAvailableBranchesFailed || !isAppend,
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
            clearError: !allAvailableBranchesFailed || isAppend,
          )
          .updateCurrentCache(cache);
    } catch (error, stack) {
      AppLogger.e('Failed to load favorites', error, stack, 'OnlineGallery');
      _finishRequestError(error, generation, cacheKey, isAppend, previousCache);
    }
  }

  bool _canLoadRemoteFavorites(GallerySourceId sourceId) {
    if (sourceId.capabilities.remoteFavorites ==
        GalleryRemoteFavoritesCapability.none) {
      return false;
    }
    return switch (sourceId) {
      GallerySourceId.danbooru =>
        _danbooruAuth.isLoggedIn && _danbooruAuth.user != null,
      GallerySourceId.gelbooru =>
        _gelbooruAuth.isAuthenticated && _gelbooruAuth.credentials != null,
      _ => false,
    };
  }

  bool _matchesFavoriteSearch(GalleryItem item) {
    final terms = state.favoriteSearchQuery
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isEmpty) return true;
    final haystack = [
      item.title,
      item.author,
      item.description,
      item.tagString,
      item.tagStringGeneral,
      item.tagStringCharacter,
      item.tagStringCopyright,
      item.tagStringArtist,
      item.tagStringMeta,
    ].whereType<String>().join(' ').toLowerCase().replaceAll('_', ' ');
    return terms.every(haystack.contains);
  }

  ChunkedGalleryItems _removeFavoriteBranch(
    ChunkedGalleryItems posts, {
    required Set<String> branchKeys,
    required Set<String> retainedByOtherBranch,
  }) {
    if (branchKeys.isEmpty) return posts;
    final keysToRemove = branchKeys.difference(retainedByOtherBranch);
    if (keysToRemove.isEmpty) return posts;
    return posts.removeStableKeys(keysToRemove);
  }

  GalleryItem _mergeFavoriteItem(GalleryItem current, GalleryItem incoming) {
    final incomingIsRicher =
        _favoriteItemCompleteness(incoming) >=
        _favoriteItemCompleteness(current);
    final primary = incomingIsRicher ? incoming : current;
    final secondary = incomingIsRicher ? current : incoming;
    String fill(String value, String fallback) =>
        value.isNotEmpty ? value : fallback;
    String? fillNullable(String? value, String? fallback) =>
        value?.isNotEmpty == true ? value : fallback;
    final primaryCover = primary.cover;
    final secondaryCover = secondary.cover;
    return primary.copyWith(
      title: fillNullable(primary.title, secondary.title),
      author: fillNullable(primary.author, secondary.author),
      description: fillNullable(primary.description, secondary.description),
      aiType: fillNullable(primary.aiType, secondary.aiType),
      createdAt: fill(primary.createdAt, secondary.createdAt),
      uploaderId: primary.uploaderId != 0
          ? primary.uploaderId
          : secondary.uploaderId,
      score: primary.score ?? secondary.score,
      source: fill(primary.source, secondary.source),
      md5: fill(primary.md5, secondary.md5),
      rating: fillNullable(primary.rating, secondary.rating),
      imageWidth: primary.imageWidth > 0
          ? primary.imageWidth
          : secondary.imageWidth,
      imageHeight: primary.imageHeight > 0
          ? primary.imageHeight
          : secondary.imageHeight,
      tagString: fill(primary.tagString, secondary.tagString),
      tags: {...primary.tags, ...secondary.tags}.toList(growable: false),
      tagStringGeneral: fill(
        primary.tagStringGeneral,
        secondary.tagStringGeneral,
      ),
      tagStringCharacter: fill(
        primary.tagStringCharacter,
        secondary.tagStringCharacter,
      ),
      tagStringCopyright: fill(
        primary.tagStringCopyright,
        secondary.tagStringCopyright,
      ),
      tagStringArtist: fill(primary.tagStringArtist, secondary.tagStringArtist),
      tagStringMeta: fill(primary.tagStringMeta, secondary.tagStringMeta),
      fileExt: fillNullable(primary.fileExt, secondary.fileExt),
      fileSize: primary.fileSize ?? secondary.fileSize,
      fileUrl: fillNullable(primary.fileUrl, secondary.fileUrl),
      largeFileUrl: fillNullable(primary.largeFileUrl, secondary.largeFileUrl),
      previewFileUrl: fillNullable(
        primary.previewFileUrl,
        secondary.previewFileUrl,
      ),
      sampleUrl: fillNullable(primary.sampleUrl, secondary.sampleUrl),
      sampleWidth: primary.sampleWidth ?? secondary.sampleWidth,
      sampleHeight: primary.sampleHeight ?? secondary.sampleHeight,
      cover: GalleryMedia(
        id: fill(primaryCover.id, secondaryCover.id),
        previewUrl: fill(primaryCover.previewUrl, secondaryCover.previewUrl),
        displayUrl: fill(primaryCover.displayUrl, secondaryCover.displayUrl),
        downloadUrl: fill(primaryCover.downloadUrl, secondaryCover.downloadUrl),
        width: primaryCover.width > 0
            ? primaryCover.width
            : secondaryCover.width,
        height: primaryCover.height > 0
            ? primaryCover.height
            : secondaryCover.height,
        extension: fillNullable(
          primaryCover.extension,
          secondaryCover.extension,
        ),
        mimeType: fillNullable(primaryCover.mimeType, secondaryCover.mimeType),
        rawMetadata: fillNullable(
          primaryCover.rawMetadata,
          secondaryCover.rawMetadata,
        ),
        mediaType: fill(primaryCover.mediaType, secondaryCover.mediaType),
        prompt: fillNullable(primaryCover.prompt, secondaryCover.prompt),
        negativePrompt: fillNullable(
          primaryCover.negativePrompt,
          secondaryCover.negativePrompt,
        ),
        metadataFormat: fillNullable(
          primaryCover.metadataFormat,
          secondaryCover.metadataFormat,
        ),
        metadataError: fillNullable(
          primaryCover.metadataError,
          secondaryCover.metadataError,
        ),
        metadata: {...secondaryCover.metadata, ...primaryCover.metadata},
      ),
      mediaCount: max(primary.mediaCount, secondary.mediaCount),
      viewCount: primary.viewCount ?? secondary.viewCount,
      favoriteCount: primary.favoriteCount ?? secondary.favoriteCount,
      rank: primary.rank ?? secondary.rank,
      rankingName: fillNullable(primary.rankingName, secondary.rankingName),
      focusedMediaId: fillNullable(
        primary.focusedMediaId,
        secondary.focusedMediaId,
      ),
      focusedMediaIndex:
          primary.focusedMediaIndex ?? secondary.focusedMediaIndex,
      artistChain: primary.artistChain ?? secondary.artistChain,
      rawSourceMetadata: {
        ...secondary.rawSourceMetadata,
        ...primary.rawSourceMetadata,
      },
    );
  }

  int _favoriteItemCompleteness(GalleryItem item) {
    int textScore(String? value) {
      final length = value?.trim().length ?? 0;
      return length == 0 ? 0 : 1 + min(4, length ~/ 40);
    }

    final cover = item.cover;
    return (textScore(item.title) +
            textScore(item.author) +
            textScore(item.description) +
            textScore(item.tagString) +
            textScore(item.tagStringGeneral) +
            textScore(item.tagStringCharacter) +
            textScore(item.tagStringCopyright) +
            textScore(item.tagStringArtist) +
            textScore(item.tagStringMeta) +
            min(20, item.tags.length) +
            (item.imageWidth > 0 && item.imageHeight > 0 ? 3 : 0) +
            (item.fileUrl?.isNotEmpty == true ? 3 : 0) +
            (item.largeFileUrl?.isNotEmpty == true ? 2 : 0) +
            (item.previewFileUrl?.isNotEmpty == true ? 2 : 0) +
            (cover.displayUrl.isNotEmpty ? 2 : 0) +
            (cover.downloadUrl.isNotEmpty ? 2 : 0) +
            min(10, item.rawSourceMetadata.length) +
            min(10, cover.metadata.length))
        .toInt();
  }

  Future<List<GalleryItem>> _filterByBlacklistCompletingDetails(
    List<GalleryItem> items,
    Set<String> blacklist,
  ) async {
    if (blacklist.isEmpty) return items;
    final normalizedBlacklist = blacklist;
    final allowed = <String, bool>{};
    final incomplete = <GalleryItem>[];
    for (final item in items) {
      if (item.tags.isEmpty) {
        incomplete.add(item);
      } else {
        allowed[item.stableKey] = !item.tags.any(
          (tag) =>
              normalizedBlacklist.contains(_normalizeGalleryPolicyTag(tag)),
        );
      }
    }

    const batchSize = 6;
    for (var offset = 0; offset < incomplete.length; offset += batchSize) {
      final end = min(offset + batchSize, incomplete.length);
      final batch = incomplete.sublist(offset, end);
      final details = await Future.wait(
        batch.map(
          (item) =>
              _details.request(item, priority: GalleryDetailPriority.visible),
        ),
      );
      for (var index = 0; index < details.length; index++) {
        final detail = details[index];
        final policyTags = <String>{
          ...detail.item.tags,
          ...detail.rawTags,
          for (final prompt in <String?>[
            detail.prompt,
            ...detail.media.map((media) => media.prompt),
          ])
            if (prompt != null)
              ...prompt
                  .split(RegExp(r'[,，\n]+'))
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty),
        };
        allowed[batch[index].stableKey] = !policyTags.any(
          (tag) =>
              normalizedBlacklist.contains(_normalizeGalleryPolicyTag(tag)),
        );
      }
    }
    return items
        .where((item) => allowed[item.stableKey] ?? false)
        .toList(growable: false);
  }

  List<GalleryItem> _filterLocal(
    List<GalleryItem> items,
    Set<String> blacklist,
  ) {
    final ratingFiltered = items.where((item) {
      if (!gallerySourceCapabilities[item.sourceId]!.supportsRatings) {
        return true;
      }
      return state.selectedRatings.length == 4 ||
          state.selectedRatings.contains(item.rating);
    });
    return _filterByBlacklist(ratingFiltered, blacklist);
  }

  List<GalleryItem> _filterByBlacklist(
    Iterable<GalleryItem> items,
    Set<String> blacklist,
  ) {
    if (blacklist.isEmpty) return items.toList(growable: false);
    final normalizedBlacklist = blacklist;
    return items
        .where(
          (item) => !item.tags.any(
            (tag) =>
                normalizedBlacklist.contains(_normalizeGalleryPolicyTag(tag)),
          ),
        )
        .toList(growable: false);
  }

  Set<String> _artistHuntDeduplicationKeys(Iterable<GalleryItem> items) {
    final keys = <String>{};
    for (final item in items) {
      final extraction = item.artistChain;
      final prompt = item.cover.prompt;
      if (extraction == null || extraction.isEmpty || prompt == null) continue;
      keys.add(ArtistChainParser.deduplicationKey(prompt, extraction));
    }
    return keys;
  }

  Future<_ArtistHuntResolution?> _resolveArtistHuntCandidates(
    List<GalleryItem> candidates, {
    required int generation,
    required String cacheKey,
    required Set<String> deduplicationKeys,
    void Function(List<GalleryItem> items, int resolvedDelta, int failureDelta)?
    onProgress,
  }) async {
    final pending = candidates
        .map((candidate) async {
          try {
            final detail = await _details.request(
              candidate,
              priority: GalleryDetailPriority.visible,
            );
            return _ArtistHuntCandidateOutcome.success(detail);
          } catch (error) {
            return _ArtistHuntCandidateOutcome.failure(error);
          }
        })
        .toList(growable: false);

    final allItems = <GalleryItem>[];
    final successfulKeys = <String>{};
    final progressItems = <GalleryItem>[];
    var resolvedCount = 0;
    var failureCount = 0;
    var pendingResolved = 0;
    var pendingFailures = 0;

    for (
      var candidateIndex = 0;
      candidateIndex < candidates.length;
      candidateIndex++
    ) {
      final outcome = await pending[candidateIndex];
      if (!_isCurrentRequest(generation, cacheKey)) return null;

      if (!outcome.succeeded) {
        failureCount++;
        pendingFailures++;
      } else {
        resolvedCount++;
        pendingResolved++;
        final candidate = candidates[candidateIndex];
        successfulKeys.add(candidate.detailStableKey);
        final media = outcome.detail!.media;
        for (var mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
          final focusedMedia = media[mediaIndex];
          final prompt = focusedMedia.prompt;
          final extraction = ArtistChainParser.parse(prompt);
          if (extraction.isEmpty || prompt == null) continue;
          final deduplicationKey = ArtistChainParser.deduplicationKey(
            prompt,
            extraction,
          );
          if (!deduplicationKeys.add(deduplicationKey)) continue;
          final focusedItem = candidate.copyWith(
            cover: focusedMedia,
            focusedMediaId: focusedMedia.id,
            focusedMediaIndex: mediaIndex,
            artistChain: extraction,
          );
          allItems.add(focusedItem);
          progressItems.add(focusedItem);
          break;
        }
      }

      final flush =
          pendingResolved + pendingFailures >= 4 ||
          candidateIndex == candidates.length - 1;
      if (flush && onProgress != null) {
        onProgress(
          List.unmodifiable(progressItems),
          pendingResolved,
          pendingFailures,
        );
        progressItems.clear();
        pendingResolved = 0;
        pendingFailures = 0;
      }
    }

    return _ArtistHuntResolution(
      items: List.unmodifiable(allItems),
      successfulCandidateKeys: Set.unmodifiable(successfulKeys),
      resolvedCount: resolvedCount,
      failureCount: failureCount,
    );
  }

  Future<GalleryDetail> loadDetail(
    GalleryItem item, {
    bool forceRefresh = false,
    GalleryDetailPriority priority = GalleryDetailPriority.interactive,
  }) {
    if (!forceRefresh && state.viewMode == GalleryViewMode.favorites) {
      final record = ref
          .read(onlineGalleryLocalFavoritesProvider.notifier)
          .getByStableKey(item.stableKey);
      if (record != null) return Future.value(record.detail);
    }
    return _details.request(
      item,
      forceRefresh: forceRefresh,
      priority: priority,
    );
  }

  void cancelDetail(GalleryItem item) => _details.cancel(item);

  Future<bool> addFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_danbooruAuth.isLoggedIn) return false;
    final key = 'danbooru:$postId';
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    try {
      final success = await _danbooruApi.addFavorite(postId);
      if (success) _remoteFavoriteKeys.add(key);
      state = success
          ? state.copyWith(
              favoritedPostKeys: {
                ..._localFavoriteKeys,
                ..._remoteFavoriteKeys,
              },
              localFavoritedPostKeys: _localFavoriteKeys,
              remoteFavoritedPostKeys: _remoteFavoriteKeys,
            )
          : state;
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
      state = state.copyWith(
        favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys}
          ..remove(key),
      );
    }
  }

  Future<bool> removeFavorite(Object postOrId) async {
    final postId = _danbooruFavoritePostId(postOrId);
    if (postId == null || !_danbooruAuth.isLoggedIn) return false;
    final key = 'danbooru:$postId';
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    try {
      final success = await _danbooruApi.removeFavorite(postId);
      if (!success) return false;
      _remoteFavoriteKeys.remove(key);
      state = state.copyWith(
        favoritedPostKeys: {..._localFavoriteKeys, ..._remoteFavoriteKeys},
        localFavoritedPostKeys: _localFavoriteKeys,
        remoteFavoritedPostKeys: _remoteFavoriteKeys,
      );
      if (state.viewMode == GalleryViewMode.favorites &&
          state.favoritesSourceId == GallerySourceId.danbooru &&
          !_localFavoriteKeys.contains(key)) {
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
      state = state.copyWith(
        favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys}
          ..remove(key),
      );
    }
  }

  Future<void> recordQuickTagCloudViewed(GalleryItem item) async {
    if (item.sourceId != GallerySourceId.quickTagCloud) return;
    await ref
        .read(quickTagCloudGallerySourceAdapterProvider)
        .recordViewed(item);
    final recentKeyFragment = '|${QuickTagCloudBrowseScope.recent.name}|';
    final activeRecent =
        state.viewMode == GalleryViewMode.search &&
        state.sourceId == GallerySourceId.quickTagCloud &&
        ref.read(quickTagCloudFilterProvider).scope ==
            QuickTagCloudBrowseScope.recent;
    final filteredCaches = <String, ModeCache>{
      for (final entry in state.caches.entries)
        if (!(entry.key.startsWith('search:quick_tag_cloud:') &&
            entry.key.contains(recentKeyFragment)))
          entry.key: entry.value,
    };
    state = state.copyWith(caches: filteredCaches);
    if (activeRecent) await loadPosts(refresh: true);
  }

  Future<int> saveVisiblePostsToLocalFavorites() async {
    final candidates = state.posts
        .where((item) => item.sourceId == state.favoritesSourceId)
        .where((item) => !_localFavoriteKeys.contains(item.stableKey))
        .toList(growable: false);
    if (candidates.isEmpty) return 0;

    final details = <GalleryDetail>[];
    const batchSize = 6;
    for (var offset = 0; offset < candidates.length; offset += batchSize) {
      final end = min(offset + batchSize, candidates.length);
      final batch = await Future.wait(
        candidates
            .sublist(offset, end)
            .map(
              (item) => _details.request(
                item,
                priority: GalleryDetailPriority.interactive,
              ),
            ),
      );
      details.addAll(batch);
    }
    await ref
        .read(onlineGalleryLocalFavoritesProvider.notifier)
        .upsertAll(details);
    return details.length;
  }

  Future<bool> toggleFavorite(Object postOrId) async {
    if (postOrId is! GalleryItem) {
      final postId = _danbooruFavoritePostId(postOrId);
      if (postId == null) return false;
      return _remoteFavoriteKeys.contains('danbooru:$postId')
          ? removeFavorite(postOrId)
          : addFavorite(postOrId);
    }

    if (postOrId.sourceId == GallerySourceId.danbooru &&
        _danbooruAuth.isLoggedIn) {
      return _remoteFavoriteKeys.contains(postOrId.stableKey)
          ? removeFavorite(postOrId)
          : addFavorite(postOrId);
    }

    final key = postOrId.stableKey;
    state = state.copyWith(
      favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys, key},
    );
    try {
      final localFavorites = ref.read(
        onlineGalleryLocalFavoritesProvider.notifier,
      );
      if (_localFavoriteKeys.contains(key)) {
        await localFavorites.remove(key);
        return true;
      }
      final detail = await _details.request(
        postOrId,
        priority: GalleryDetailPriority.interactive,
      );
      await localFavorites.upsert(detail);
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
      state = state.copyWith(
        favoriteLoadingPostKeys: {...state.favoriteLoadingPostKeys}
          ..remove(key),
      );
    }
  }

  bool isFavorited(Object postOrId) {
    if (postOrId is GalleryItem) {
      return postOrId.sourceId == GallerySourceId.danbooru &&
              _danbooruAuth.isLoggedIn
          ? _remoteFavoriteKeys.contains(postOrId.stableKey)
          : _localFavoriteKeys.contains(postOrId.stableKey);
    }
    if (postOrId is! int) return false;
    final key = 'danbooru:$postOrId';
    return _danbooruAuth.isLoggedIn
        ? _remoteFavoriteKeys.contains(key)
        : _localFavoriteKeys.contains(key);
  }

  bool isLocallyFavorited(GalleryItem item) =>
      _localFavoriteKeys.contains(item.stableKey);

  bool isRemotelyFavorited(GalleryItem item) =>
      _remoteFavoriteKeys.contains(item.stableKey);

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
    _remoteFavoriteKeys.removeWhere((key) => key.startsWith('gelbooru:'));
    state = state.copyWith(
      caches: filteredCaches,
      favoritedPostKeys: {..._localFavoriteKeys, ..._remoteFavoriteKeys},
      localFavoritedPostKeys: _localFavoriteKeys,
      remoteFavoritedPostKeys: _remoteFavoriteKeys,
      favoriteLoadingPostKeys: state.favoriteLoadingPostKeys
          .where((key) => !key.startsWith('gelbooru:'))
          .toSet(),
    );
  }

  OnlineGalleryErrorCode _errorCode(Object error) {
    if (error is _ArtistHuntDetailException) {
      return OnlineGalleryErrorCode.artistHuntDetailFailed;
    }
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
