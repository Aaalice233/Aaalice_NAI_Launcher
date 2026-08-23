import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../data/models/online_gallery/chunked_gallery_items.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../../data/models/online_gallery/gelbooru_post_parser.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/gelbooru_auth_service.dart';
import '../../data/services/online_gallery/artist_chain_parser.dart';
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
  final bool endedByDuplicatePage;
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
    this.randomEnabled = false,
    this.randomSession = const RandomGallerySession(),
    this.artistHuntEnabled = false,
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
  final bool randomEnabled;
  final RandomGallerySession randomSession;
  final bool artistHuntEnabled;

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
        return 'search:${sourceId.key}:${searchQuery.trim()}|${promptQuery.trim()}|$fuzzySearchEnabled|${_ratingsKey(selectedRatings)}|${dateRangeStart?.toIso8601String() ?? ''}|${dateRangeEnd?.toIso8601String() ?? ''}|$aiTagTimeRange|artistHunt:${sourceId == GallerySourceId.aiTag && artistHuntEnabled}';
      case GalleryViewMode.popular:
        return 'popular:${popularSourceId.key}:${popularScale.name}|${popularDate?.toIso8601String() ?? ''}|$aiTagPopularPeriod|${popularQuery.trim()}|${popularPromptQuery.trim()}|${_ratingsKey(selectedRatings)}|artistHunt:${popularSourceId == GallerySourceId.aiTag && artistHuntEnabled}';
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
    bool? randomEnabled,
    RandomGallerySession? randomSession,
    bool? artistHuntEnabled,
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
      randomEnabled: randomEnabled ?? this.randomEnabled,
      randomSession: randomSession ?? this.randomSession,
      artistHuntEnabled: artistHuntEnabled ?? this.artistHuntEnabled,
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
    final updated = LinkedHashMap<String, ModeCache>.of(caches)
      ..remove(key)
      ..[key] = cache;
    _trimCaches(updated, currentCacheKey);
    return sourceId == GallerySourceId.gelbooru
        ? copyWith(caches: updated, gelbooruFavoritesCache: cache)
        : copyWith(caches: updated, danbooruFavoritesCache: cache);
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
    'version': 1,
    'viewMode': state.viewMode.name,
    'sourceId': state.sourceId.key,
    'popularSourceId': state.popularSourceId.key,
    'favoritesSourceId': state.favoritesSourceId.key,
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
    if (decoded is! Map || decoded['version'] != 1) {
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
    final favoritesSourceCandidate = _decodeGallerySource(
      json['favoritesSourceId'],
    );
    final favoritesSourceId =
        favoritesSourceCandidate == GallerySourceId.gelbooru
        ? GallerySourceId.gelbooru
        : GallerySourceId.danbooru;
    final viewMode = _decodeEnumByName(
      GalleryViewMode.values,
      json['viewMode'],
      GalleryViewMode.search,
    );
    final selectedRatings = _decodeRatings(json['selectedRatings']);
    final base = OnlineGalleryState(
      searchQuery: _decodeBoundedString(json['searchQuery']),
      promptQuery: _decodeBoundedString(json['promptQuery']),
      popularQuery: _decodeBoundedString(json['popularQuery']),
      popularPromptQuery: _decodeBoundedString(json['popularPromptQuery']),
      fuzzySearchEnabled: json['fuzzySearchEnabled'] == true,
      sourceId: sourceId,
      popularSourceId: popularSourceId,
      favoritesSourceId: favoritesSourceId,
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
      dateRangeStart: _decodeDate(json['dateRangeStart']),
      dateRangeEnd: _decodeDate(json['dateRangeEnd']),
      artistHuntEnabled: json['artistHuntEnabled'] == true,
    );

    final caches = <String, ModeCache>{};
    final rawPositions = json['positions'];
    if (rawPositions is Map) {
      for (final entry in rawPositions.entries.take(12)) {
        final key = entry.key;
        if (key is! String || key.isEmpty || key.length > 4096) continue;
        final position = _decodeGalleryPosition(entry.value);
        if (position != null) caches[key] = position;
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
  final offsetValue = raw['scrollOffset'];
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
  static const int _pageSize = 40;
  static const int _maxFilteredEmptyPagesPerLoad = 5;

  CancelToken? _cancelToken;
  int _requestGeneration = 0;
  OnlineGalleryState? _normalRestorePoint;
  OnlineGalleryDetailCoordinator? _detailCoordinator;
  String? _lastPersistedBrowsingSession;
  Future<void> _persistenceQueue = Future<void>.value();

  OnlineGalleryDetailCoordinator get _details =>
      _detailCoordinator ??= OnlineGalleryDetailCoordinator(
        loader: (item, cancelToken) =>
            _adapters[item.sourceId]!.detail(item, cancelToken: cancelToken),
      );

  @override
  OnlineGalleryState build() {
    ref.keepAlive();
    ref.onDispose(() => _detailCoordinator?.clear());
    final storage = ref.read(localStorageServiceProvider);
    final restored = decodeOnlineGalleryBrowsingSession(
      storage.getSetting<String>(StorageKeys.onlineGalleryBrowsingSessionV1),
    );
    _lastPersistedBrowsingSession = encodeOnlineGalleryBrowsingSession(
      restored,
    );
    if (restored.randomEnabled) {
      _normalRestorePoint = restored.copyWith(randomEnabled: false);
    }
    listenSelf((_, next) => _persistBrowsingSession(storage, next));
    ref.listen<String?>(
      danbooruAuthProvider.select((value) => value.user?.name),
      (_, _) => _handleRandomAccountIdentityChanged(GallerySourceId.danbooru),
    );
    ref.listen<String?>(
      gelbooruAuthProvider.select(
        (value) => value.credentials?.userId.toString(),
      ),
      (_, _) => _handleRandomAccountIdentityChanged(GallerySourceId.gelbooru),
    );
    ref.listen<String>(
      onlineGalleryBlacklistNotifierProvider.select((value) {
        final tags = value.effectiveTags.toList()..sort();
        return tags.join('\u0000');
      }),
      (_, _) => _handleRandomScopeInputChanged(),
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

  void _handleRandomScopeInputChanged() {
    if (!state.randomEnabled) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      randomSession: const RandomGallerySession(),
      clearError: true,
    );
    unawaited(_loadRandom(replace: true, restart: true));
  }

  void _handleRandomAccountIdentityChanged(GallerySourceId sourceId) {
    if (!state.randomEnabled || state.activeSourceId != sourceId) return;
    _cancelCurrentRequest();
    state = state.copyWith(
      randomSession: const RandomGallerySession(),
      clearError: true,
    );
    unawaited(_loadRandom(replace: true, restart: true));
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
    _cancelCurrentRequest();
    state = state.copyWith(viewMode: GalleryViewMode.search, clearError: true);
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> switchToPopular() async {
    if (state.viewMode == GalleryViewMode.popular) return;
    _cancelCurrentRequest();
    state = state.copyWith(viewMode: GalleryViewMode.popular, clearError: true);
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> switchToFavorites() async {
    _cancelCurrentRequest();
    state = state.copyWith(
      viewMode: GalleryViewMode.favorites,
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
    state = state.copyWith(sourceId: sourceId, clearError: true);
    if (state.randomEnabled || state.currentCache.posts.isEmpty) {
      await loadPosts(refresh: true);
    }
  }

  Future<void> setPopularSource(Object source) async {
    final sourceId = _normalizeSource(source);
    if (sourceId == null || !sourceId.capabilities.supportsRanking) return;
    if (state.popularSourceId == sourceId) return;
    _cancelCurrentRequest();
    state = state.copyWith(popularSourceId: sourceId, clearError: true);
    if (state.viewMode == GalleryViewMode.popular &&
        (state.randomEnabled || state.currentCache.posts.isEmpty)) {
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
        (state.randomEnabled || state.currentCache.posts.isEmpty)) {
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

    final generation = _beginRequest();
    final cacheKey = state.currentCacheKey;
    state = state.copyWith(
      isLoading: replace,
      isLoadingMore: !replace,
      clearError: true,
    );
    try {
      await ref
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .ensureInitialized();
      if (generation != _requestGeneration || !state.randomEnabled) return;
      final blacklist = ref
          .read(onlineGalleryBlacklistNotifierProvider)
          .effectiveTags;
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

      final sourceId = state.activeSourceId;
      final adapter = _adapters[sourceId]!;
      final request = _randomRequest(session, blacklist);
      final page = await adapter.random(request, cancelToken: _cancelToken);
      if (generation != _requestGeneration ||
          !state.randomEnabled ||
          state.currentCacheKey != cacheKey) {
        return;
      }

      final normalizedBlacklist = blacklist
          .map((tag) => tag.trim().toLowerCase().replaceAll(' ', '_'))
          .where((tag) => tag.isNotEmpty)
          .toSet();
      final artistHuntActive = state.isArtistHuntActive;
      final seen = Set<String>.of(session.seenStableKeys);
      final seenCandidates = Set<String>.of(session.seenCandidateStableKeys);
      final candidates = <GalleryItem>[];
      for (final item in page.items) {
        final blocked = item.tags.any(
          (tag) => normalizedBlacklist.contains(
            tag.trim().toLowerCase().replaceAll(' ', '_'),
          ),
        );
        final identity = artistHuntActive
            ? item.detailStableKey
            : item.stableKey;
        final alreadySeen = artistHuntActive
            ? seenCandidates.contains(identity)
            : seen.contains(identity);
        if (blocked || alreadySeen || seen.length >= 20000) continue;
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
      final exhausted = misses >= 4 || seen.length >= 20000;
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
                  fuzzyMatch: state.fuzzySearchEnabled,
                ),
          prompt: _effectivePromptQuery(state.promptQuery),
          timeRange: state.aiTagTimeRange,
          ratings: state.selectedRatings,
          dateStart: state.dateRangeStart,
          dateEnd: state.dateRangeEnd,
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
        final identity = state.favoritesSourceId == GallerySourceId.danbooru
            ? _danbooruAuth.user?.name
            : _gelbooruAuth.credentials?.userId.toString();
        if (identity == null || identity.isEmpty) {
          throw GallerySourceException(
            GallerySourceErrorCode.credentialsRequired,
            source: state.favoritesSourceId,
          );
        }
        return GalleryRandomFavoritesRequest(
          pageSize: _pageSize,
          username: identity,
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
    final restoredPage = !refresh && state.currentCache.posts.isEmpty
        ? state.currentCache.page
        : null;
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
                  fuzzyMatch: state.fuzzySearchEnabled,
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

        List<GalleryItem> visiblePageItems = page.items;
        if (artistHuntActive) {
          candidateCount += page.items.length;
          final resolution = await _resolveArtistHuntCandidates(
            page.items,
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
          if (page.items.isNotEmpty &&
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
        final filteredEmptyPage =
            page.rawItemCount > 0 && visiblePageItems.isEmpty;
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
          username: _danbooruAuth.user!.name,
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
      final base = refresh
          ? ChunkedGalleryItems()
          : cache.posts is ChunkedGalleryItems
          ? cache.posts as ChunkedGalleryItems
          : ChunkedGalleryItems.from(cache.posts);
      final merged = base.appendPage(filtered);
      final duplicatePage =
          !refresh && rawCount > 0 && merged.length == base.length;
      final favorites = {...state.favoritedPostKeys}
        ..addAll(filtered.map(onlineGalleryPostKey));
      final nextCache = ModeCache(
        posts: merged,
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
    return _details.request(
      item,
      forceRefresh: forceRefresh,
      priority: priority,
    );
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
            posts: ChunkedGalleryItems.from(
              state.currentCache.posts.where((item) => item.id != postId),
            ),
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
