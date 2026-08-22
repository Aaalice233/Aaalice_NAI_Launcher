import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import 'gallery_random_sampler.dart';
import 'gallery_source_adapter.dart';

class DonmaiGallerySourceAdapter implements GallerySourceAdapter {
  DonmaiGallerySourceAdapter({
    required this.sourceId,
    required Dio dio,
    String? Function()? authHeader,
    Random? random,
  }) : assert(
         sourceId == GallerySourceId.danbooru ||
             sourceId == GallerySourceId.safebooru,
       ),
       _dio = dio,
       _authHeader = authHeader,
       _random = random ?? Random.secure();

  @override
  final GallerySourceId sourceId;

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  final Dio _dio;
  final String? Function()? _authHeader;
  final Random _random;

  @override
  Random get randomGenerator => _random;

  // Cache for ID boundary probes (5 minutes TTL, 64 entries max)
  static final _boundaryCache = GalleryRandomCache<DanbooruIdBoundary>(
    maxSize: 64,
    ttl: const Duration(minutes: 5),
  );

  // Remember native-random support per endpoint to avoid repeated 422 probes.
  static final Map<String, bool> _safebooruRandomSupport = {};

  String get _baseUrl => sourceId == GallerySourceId.safebooru
      ? 'https://safebooru.donmai.us'
      : 'https://danbooru.donmai.us';

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final tags = _buildSearchTags(request);
    final tagsWithBlacklist = _appendBlacklist(tags, request.blacklistTags);

    Future<Response<dynamic>> fetch(String requestTags) {
      return _dio.get(
        '$_baseUrl/posts.json',
        queryParameters: {
          'tags': requestTags,
          'limit': request.pageSize,
          'page': request.cursor,
        },
        options: Options(headers: _headers('$_baseUrl/posts.json')),
        cancelToken: cancelToken,
      );
    }

    try {
      Response<dynamic> response;
      try {
        response = await fetch(tagsWithBlacklist);
      } on DioException catch (error) {
        if (error.response?.statusCode == 422 &&
            request.blacklistTags.isNotEmpty) {
          response = await fetch(tags);
        } else {
          rethrow;
        }
      }
      final raw = response.data;
      if (raw is! List) {
        throw GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: sourceId,
          message: 'Expected a JSON array from /posts.json',
        );
      }
      final parsed = raw
          .whereType<Map>()
          .map(
            (value) => GalleryItem.fromDanbooruJson(
              Map<String, dynamic>.from(value),
              sourceId: sourceId,
            ),
          )
          .where((item) => item.hasValidPreview)
          .toList(growable: false);
      final filtered = _filterLocally(
        parsed,
        request.ratings,
        request.blacklistTags,
      );
      final nextCursor = parsed.isEmpty ? null : 'b${parsed.last.id}';
      return GalleryPage(
        items: filtered,
        cursor: request.cursor,
        nextCursor: nextCursor,
        hasMore: raw.length >= request.pageSize && nextCursor != null,
        rawItemCount: raw.length,
      );
    } on GallerySourceException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw mapGalleryDioException(error, sourceId);
    } catch (error) {
      throw GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: sourceId,
        cause: error,
      );
    }
  }

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) async {
    final page = galleryCursorPage(request.cursor);
    final scale = switch (request.kind) {
      GalleryRankingKind.day => 'day',
      GalleryRankingKind.week => 'week',
      GalleryRankingKind.month => 'month',
      GalleryRankingKind.aiTagMonthly => 'day',
    };
    try {
      final response = await _dio.get(
        '$_baseUrl/explore/posts/popular.json',
        queryParameters: {
          'scale': scale,
          'page': page,
          'limit': request.pageSize,
          if (request.date != null) 'date': formatGalleryDate(request.date!),
        },
        options: Options(
          headers: _headers('$_baseUrl/explore/posts/popular.json'),
        ),
        cancelToken: cancelToken,
      );
      final raw = response.data;
      if (raw is! List) {
        throw GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: sourceId,
          message: 'Expected a JSON array from popular posts',
        );
      }
      final parsed = raw
          .whereType<Map>()
          .map(
            (value) => GalleryItem.fromDanbooruJson(
              Map<String, dynamic>.from(value),
              sourceId: sourceId,
            ),
          )
          .where((item) => item.hasValidPreview)
          .toList(growable: false);
      final filtered = _filterLocally(
        parsed,
        request.ratings,
        request.blacklistTags,
      );
      final ranked = <GalleryItem>[
        for (var index = 0; index < filtered.length; index++)
          filtered[index].copyWith(
            rank: (page - 1) * request.pageSize + index + 1,
          ),
      ];
      return GalleryPage(
        items: ranked,
        cursor: request.cursor,
        nextCursor: raw.isEmpty ? null : '${page + 1}',
        // This endpoint may enforce its own page size, so only an empty page
        // conclusively means the end. Repeated pages are stopped by the provider.
        hasMore: raw.isNotEmpty,
        rawItemCount: raw.length,
      );
    } on GallerySourceException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw mapGalleryDioException(error, sourceId);
    } catch (error) {
      throw GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: sourceId,
        cause: error,
      );
    }
  }

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/posts/${item.id}.json',
        options: Options(headers: _headers('$_baseUrl/posts/${item.id}.json')),
        cancelToken: cancelToken,
      );
      if (response.data is! Map) {
        throw GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: sourceId,
        );
      }
      final detailed = GalleryItem.fromDanbooruJson(
        Map<String, dynamic>.from(response.data as Map),
        sourceId: sourceId,
      );
      return GalleryDetail(item: detailed, media: [detailed.cover]);
    } on GallerySourceException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw mapGalleryDioException(error, sourceId);
    }
  }

  String _buildSearchTags(GallerySearchRequest request) {
    var tags = request.query.trim();
    if (sourceId != GallerySourceId.safebooru && request.ratings.length < 4) {
      final ratingExpression = request.ratings.length == 1
          ? 'rating:${request.ratings.first}'
          : request.ratings.map((rating) => '~rating:$rating').join(' ');
      tags = tags.isEmpty ? ratingExpression : '$tags $ratingExpression';
    }
    if (request.dateStart != null || request.dateEnd != null) {
      final dateExpression = switch ((request.dateStart, request.dateEnd)) {
        (final DateTime start, final DateTime end) =>
          'date:${formatGalleryDate(start)}..${formatGalleryDate(end)}',
        (final DateTime start, null) => 'date:>=${formatGalleryDate(start)}',
        (null, final DateTime end) => 'date:<=${formatGalleryDate(end)}',
        _ => '',
      };
      if (dateExpression.isNotEmpty) {
        tags = tags.isEmpty ? dateExpression : '$tags $dateExpression';
      }
    }
    return tags;
  }

  String _appendBlacklist(String tags, Set<String> blacklistTags) {
    final safeTags = blacklistTags
        .where(
          (tag) => tag.isNotEmpty && !tag.contains(':') && !tag.startsWith('-'),
        )
        .take(50)
        .map((tag) => '-$tag')
        .join(' ');
    if (safeTags.isEmpty) return tags;
    return tags.isEmpty ? safeTags : '$tags $safeTags';
  }

  List<GalleryItem> _filterLocally(
    List<GalleryItem> items,
    Set<String> ratings,
    Set<String> blacklistTags,
  ) {
    final ratingFiltered =
        sourceId == GallerySourceId.safebooru || ratings.length == 4
        ? items
        : items.where((item) => ratings.contains(item.rating)).toList();
    return _filterBlacklist(ratingFiltered, blacklistTags);
  }

  List<GalleryItem> _filterBlacklist(
    List<GalleryItem> items,
    Set<String> blacklistTags,
  ) {
    if (blacklistTags.isEmpty) return items;
    return items
        .where((item) {
          return !item.tags.any(
            (tag) => blacklistTags.contains(
              tag.trim().toLowerCase().replaceAll(' ', '_'),
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async {
    return switch (request) {
      GalleryRandomSearchRequest() => _randomSearch(request, cancelToken),
      GalleryRandomRankingRequest() => _randomRanking(request, cancelToken),
      GalleryRandomFavoritesRequest() => _randomFavorites(request, cancelToken),
    };
  }

  Future<GalleryPage> _randomSearch(
    GalleryRandomSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final tags = _buildSearchTagsFromRandom(request);
    final normalizedQuery = _normalizeQueryForCache(tags);

    // For Safebooru, try native random first
    if (sourceId == GallerySourceId.safebooru) {
      final instanceKey = _baseUrl;
      if (_safebooruRandomSupport[instanceKey] != false) {
        try {
          final result = await _fetchSafebooruNativeRandom(
            tags,
            request,
            cancelToken,
          );
          _safebooruRandomSupport[instanceKey] = true;
          return result;
        } on GallerySourceException catch (error) {
          if (error.statusCode == 422) {
            _safebooruRandomSupport[instanceKey] = false;
            // Fall through to ID strategy.
          } else {
            rethrow;
          }
        } on DioException catch (error) {
          if (error.response?.statusCode == 422) {
            _safebooruRandomSupport[instanceKey] = false;
            // Dio validates status codes before the adapter can map the error.
          } else {
            rethrow;
          }
        }
      }
    }

    // Safebooru that rejected native random stays on the ID strategy for the
    // lifetime of this adapter instead of repeating the same 422 probe.
    if (sourceId == GallerySourceId.safebooru &&
        _safebooruRandomSupport[_baseUrl] == false) {
      return _fetchWithIdBoundary(tags, normalizedQuery, request, cancelToken);
    }

    // Use random:N strategy for simple queries (0-1 normal tags)
    final queryTags = _parseQueryTags(tags);
    if (queryTags.length <= 1) {
      return _fetchWithRandomTag(tags, request, cancelToken);
    }

    // Use ID boundary strategy for complex queries (>=2 tags)
    return await _fetchWithIdBoundary(
      tags,
      normalizedQuery,
      request,
      cancelToken,
    );
  }

  Future<GalleryPage> _randomRanking(
    GalleryRandomRankingRequest request,
    CancelToken? cancelToken,
  ) async {
    var windowStart = 1;
    var remaining = <int>[];
    final cursor = request.cursor;
    if (cursor != null && cursor.startsWith('rw:')) {
      final parts = cursor.split(':');
      windowStart = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
      if (parts.length > 2 && parts[2].isNotEmpty) {
        remaining = parts[2]
            .split(',')
            .map(int.tryParse)
            .whereType<int>()
            .toList();
      }
    }
    if (remaining.isEmpty) {
      remaining = List<int>.generate(4, (index) => windowStart + index);
      for (var index = remaining.length - 1; index > 0; index--) {
        final swap = randomGenerator.nextInt(index + 1);
        final value = remaining[index];
        remaining[index] = remaining[swap];
        remaining[swap] = value;
      }
    }

    final pageNumber = remaining.removeAt(0);
    final page = await ranking(
      GalleryRankingRequest(
        cursor: pageNumber.toString(),
        pageSize: request.pageSize,
        kind: request.kind,
        date: request.date,
        period: request.period,
        query: request.query,
        prompt: request.prompt,
        ratings: request.ratings,
        blacklistTags: request.blacklistTags,
      ),
      cancelToken: cancelToken,
    );
    final nextCursor = remaining.isEmpty
        ? 'rw:${windowStart + 4}:'
        : 'rw:$windowStart:${remaining.join(',')}';
    return GalleryPage(
      items: shuffleGalleryItems(page.items, randomGenerator),
      cursor: pageNumber.toString(),
      nextCursor: nextCursor,
      hasMore: true,
      total: page.total,
      rawItemCount: page.rawItemCount,
    );
  }

  Future<GalleryPage> _randomFavorites(
    GalleryRandomFavoritesRequest request,
    CancelToken? cancelToken,
  ) async {
    // Use fav:username random:N strategy for Danbooru favorites
    final tags = 'fav:${request.username} random:${request.pageSize}';

    try {
      final response = await _dio.get(
        '$_baseUrl/posts.json',
        queryParameters: {'tags': tags, 'limit': request.pageSize},
        options: Options(
          headers: {
            ..._headers('$_baseUrl/posts.json'),
            'Cache-Control': 'no-cache',
          },
        ),
        cancelToken: cancelToken,
      );

      final raw = response.data;
      if (raw is! List) {
        throw GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: sourceId,
          message: 'Expected a JSON array from favorites random',
        );
      }

      final parsed = raw
          .whereType<Map>()
          .map(
            (value) => GalleryItem.fromDanbooruJson(
              Map<String, dynamic>.from(value),
              sourceId: sourceId,
            ),
          )
          .where((item) => item.hasValidPreview)
          .toList(growable: false);

      final filtered = _filterLocally(
        parsed,
        request.ratings,
        request.blacklistTags,
      );

      final shuffled = shuffleGalleryItems(filtered, randomGenerator);

      return GalleryPage(
        items: shuffled,
        cursor: 'random',
        nextCursor: null, // Random results don't have pagination
        hasMore: false,
        rawItemCount: raw.length,
      );
    } on GallerySourceException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw mapGalleryDioException(error, sourceId);
    } catch (error) {
      throw GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: sourceId,
        cause: error,
      );
    }
  }

  Future<GalleryPage> _fetchSafebooruNativeRandom(
    String tags,
    GalleryRandomSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final randomTags = tags.isEmpty
        ? 'random:${request.pageSize}'
        : '$tags random:${request.pageSize}';

    final response = await _dio.get(
      '$_baseUrl/posts.json',
      queryParameters: {'tags': randomTags, 'limit': request.pageSize},
      options: Options(
        headers: {
          ..._headers('$_baseUrl/posts.json'),
          'Cache-Control': 'no-cache',
        },
      ),
      cancelToken: cancelToken,
    );

    final raw = response.data;
    if (raw is! List) {
      throw GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: sourceId,
        message: 'Expected a JSON array from random search',
      );
    }

    final parsed = raw
        .whereType<Map>()
        .map(
          (value) => GalleryItem.fromDanbooruJson(
            Map<String, dynamic>.from(value),
            sourceId: sourceId,
          ),
        )
        .where((item) => item.hasValidPreview)
        .toList(growable: false);

    final filtered = _filterLocally(
      parsed,
      request.ratings,
      request.blacklistTags,
    );

    final shuffled = shuffleGalleryItems(filtered, randomGenerator);

    return GalleryPage(
      items: shuffled,
      cursor: 'random',
      nextCursor: null,
      hasMore: false,
      rawItemCount: raw.length,
    );
  }

  Future<GalleryPage> _fetchWithRandomTag(
    String tags,
    GalleryRandomSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final randomTag = 'random:${request.pageSize}';
    final finalTags = tags.isEmpty ? randomTag : '$tags $randomTag';

    final response = await _dio.get(
      '$_baseUrl/posts.json',
      queryParameters: {'tags': finalTags, 'limit': request.pageSize},
      options: Options(
        headers: {
          ..._headers('$_baseUrl/posts.json'),
          'Cache-Control': 'no-cache',
        },
      ),
      cancelToken: cancelToken,
    );

    final raw = response.data;
    if (raw is! List) {
      throw GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: sourceId,
        message: 'Expected a JSON array from random tag search',
      );
    }

    final parsed = raw
        .whereType<Map>()
        .map(
          (value) => GalleryItem.fromDanbooruJson(
            Map<String, dynamic>.from(value),
            sourceId: sourceId,
          ),
        )
        .where((item) => item.hasValidPreview)
        .toList(growable: false);

    final filtered = _filterLocally(
      parsed,
      request.ratings,
      request.blacklistTags,
    );

    final shuffled = shuffleGalleryItems(filtered, randomGenerator);

    return GalleryPage(
      items: shuffled,
      cursor: 'random',
      nextCursor: null,
      hasMore: false,
      rawItemCount: raw.length,
    );
  }

  Future<GalleryPage> _fetchWithIdBoundary(
    String tags,
    String normalizedQuery,
    GalleryRandomSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final cacheKey = GalleryRandomCacheKeys.danbooruBoundary(
      query: normalizedQuery,
      ratings: request.ratings,
      dateStart: request.dateStart,
      dateEnd: request.dateEnd,
      userHash: _getUserHash(),
    );

    var boundary = _boundaryCache.get(cacheKey);
    if (boundary?.isValid != true) {
      boundary = await _probeBoundary(tags, request, cancelToken);
      if (boundary.isValid) _boundaryCache.put(cacheKey, boundary);
    }
    if (boundary?.isValid != true) {
      return _fallbackToLatest(tags, request, cancelToken);
    }

    final validBoundary = boundary!;
    final edgeByKey = <String, GalleryItem>{
      for (final item in validBoundary.edgeItems) item.stableKey: item,
    };
    final smallSet =
        validBoundary.oldestPageSize < 60 ||
        validBoundary.newestPageSize < 60 ||
        edgeByKey.length <
            validBoundary.oldestPageSize + validBoundary.newestPageSize;
    if (smallSet && edgeByKey.isNotEmpty) {
      final filtered = _filterLocally(
        edgeByKey.values.toList(growable: false),
        request.ratings,
        request.blacklistTags,
      );
      final items = shuffleGalleryItems(
        filtered,
        randomGenerator,
      ).take(request.pageSize).toList(growable: false);
      return GalleryPage(
        items: items,
        cursor: 'random',
        nextCursor: null,
        hasMore: false,
        rawItemCount: edgeByKey.length,
      );
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final targetId =
          randomGenerator.nextInt(
            validBoundary.maxId - validBoundary.minId + 1,
          ) +
          validBoundary.minId;
      final firstDirectionAfter = randomGenerator.nextBool();
      for (final after in [firstDirectionAfter, !firstDirectionAfter]) {
        final response = await _dio.get(
          '$_baseUrl/posts.json',
          queryParameters: {
            'tags': tags,
            'limit': request.pageSize,
            'page': '${after ? 'a' : 'b'}$targetId',
          },
          options: Options(
            headers: {
              ..._headers('$_baseUrl/posts.json'),
              'Cache-Control': 'no-cache',
            },
          ),
          cancelToken: cancelToken,
        );
        final raw = response.data;
        if (raw is! List) {
          throw GallerySourceException(
            GallerySourceErrorCode.malformedResponse,
            source: sourceId,
          );
        }
        if (raw.isEmpty) continue;
        final parsed = raw
            .whereType<Map>()
            .map(
              (value) => GalleryItem.fromDanbooruJson(
                Map<String, dynamic>.from(value),
                sourceId: sourceId,
              ),
            )
            .where((item) => item.hasValidPreview)
            .toList(growable: false);
        final filtered = _filterLocally(
          parsed,
          request.ratings,
          request.blacklistTags,
        );
        return GalleryPage(
          items: shuffleGalleryItems(filtered, randomGenerator),
          cursor: 'random',
          nextCursor: null,
          hasMore: false,
          rawItemCount: raw.length,
        );
      }
    }

    return _fallbackToLatest(tags, request, cancelToken);
  }

  Future<DanbooruIdBoundary> _probeBoundary(
    String tags,
    GalleryRandomSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    // Probe newest 60 posts
    final newestResponse = await _dio.get(
      '$_baseUrl/posts.json',
      queryParameters: {'tags': tags, 'limit': 60},
      options: Options(
        headers: {
          ..._headers('$_baseUrl/posts.json'),
          'Cache-Control': 'no-cache',
        },
      ),
      cancelToken: cancelToken,
    );

    final newestRaw = newestResponse.data as List;
    final newestItems = newestRaw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((json) => json['id'] is int)
        .toList();

    if (newestItems.isEmpty) {
      return const DanbooruIdBoundary(
        minId: 0,
        maxId: 0,
        oldestPageSize: 0,
        newestPageSize: 0,
      );
    }

    // Probe oldest 60 posts
    final oldestResponse = await _dio.get(
      '$_baseUrl/posts.json',
      queryParameters: {'tags': tags, 'limit': 60, 'page': 'a0'},
      options: Options(
        headers: {
          ..._headers('$_baseUrl/posts.json'),
          'Cache-Control': 'no-cache',
        },
      ),
      cancelToken: cancelToken,
    );

    final oldestRaw = oldestResponse.data as List;
    final oldestItems = oldestRaw
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((json) => json['id'] is int)
        .toList();

    if (oldestItems.isEmpty) {
      return const DanbooruIdBoundary(
        minId: 0,
        maxId: 0,
        oldestPageSize: 0,
        newestPageSize: 0,
      );
    }

    final maxId = newestItems
        .map((json) => json['id'] as int)
        .reduce((a, b) => a > b ? a : b);
    final minId = oldestItems
        .map((json) => json['id'] as int)
        .reduce((a, b) => a < b ? a : b);

    final edgeItems = [...newestItems, ...oldestItems]
        .map((json) => GalleryItem.fromDanbooruJson(json, sourceId: sourceId))
        .where((item) => item.hasValidPreview)
        .toList(growable: false);
    return DanbooruIdBoundary(
      minId: minId,
      maxId: maxId,
      oldestPageSize: oldestItems.length,
      newestPageSize: newestItems.length,
      edgeItems: edgeItems,
    );
  }

  Future<GalleryPage> _fallbackToLatest(
    String tags,
    GalleryRandomSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final response = await _dio.get(
      '$_baseUrl/posts.json',
      queryParameters: {'tags': tags, 'limit': 60},
      options: Options(
        headers: {
          ..._headers('$_baseUrl/posts.json'),
          'Cache-Control': 'no-cache',
        },
      ),
      cancelToken: cancelToken,
    );

    final raw = response.data as List;
    final parsed = raw
        .whereType<Map>()
        .map(
          (value) => GalleryItem.fromDanbooruJson(
            Map<String, dynamic>.from(value),
            sourceId: sourceId,
          ),
        )
        .where((item) => item.hasValidPreview)
        .toList(growable: false);

    final filtered = _filterLocally(
      parsed,
      request.ratings,
      request.blacklistTags,
    );

    final shuffled = shuffleGalleryItems(filtered, randomGenerator);
    final items = shuffled.take(request.pageSize).toList();

    return GalleryPage(
      items: items,
      cursor: 'random',
      nextCursor: null,
      hasMore: false,
      rawItemCount: raw.length,
    );
  }

  String _buildSearchTagsFromRandom(GalleryRandomSearchRequest request) {
    var tags = request.query.trim();
    if (sourceId != GallerySourceId.safebooru && request.ratings.length < 4) {
      final ratingExpression = request.ratings.length == 1
          ? 'rating:${request.ratings.first}'
          : request.ratings.map((rating) => '~rating:$rating').join(' ');
      tags = tags.isEmpty ? ratingExpression : '$tags $ratingExpression';
    }
    if (request.dateStart != null || request.dateEnd != null) {
      final dateExpression = switch ((request.dateStart, request.dateEnd)) {
        (final DateTime start, final DateTime end) =>
          'date:${formatGalleryDate(start)}..${formatGalleryDate(end)}',
        (final DateTime start, null) => 'date:>=${formatGalleryDate(start)}',
        (null, final DateTime end) => 'date:<=${formatGalleryDate(end)}',
        _ => '',
      };
      if (dateExpression.isNotEmpty) {
        tags = tags.isEmpty ? dateExpression : '$tags $dateExpression';
      }
    }
    return tags;
  }

  String _normalizeQueryForCache(String query) {
    return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _parseQueryTags(String query) {
    return query
        .split(RegExp(r'\s+'))
        .where(
          (tag) => tag.isNotEmpty && !tag.contains(':') && !tag.startsWith('-'),
        )
        .toList();
  }

  String? _getUserHash() {
    final authHeader = _authHeader?.call();
    if (authHeader == null) return null;

    // Create a simple hash of the auth header for cache keying
    // This desensitizes the actual credentials
    final bytes = authHeader.codeUnits;
    var hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  Map<String, String> _headers(String url) {
    final authHeader = _authHeader?.call();
    return {
      ...onlineGalleryImageHeadersForUrl(url),
      'Accept': 'application/json',
      'User-Agent': 'NAI-Launcher/1.0',
      if (authHeader != null) 'Authorization': authHeader,
    };
  }
}
