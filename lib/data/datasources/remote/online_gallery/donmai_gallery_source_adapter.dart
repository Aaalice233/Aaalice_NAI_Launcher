import 'package:dio/dio.dart';

import '../../../../core/cache/danbooru_image_cache_manager.dart';
import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import 'gallery_source_adapter.dart';

class DonmaiGallerySourceAdapter implements GallerySourceAdapter {
  DonmaiGallerySourceAdapter({
    required this.sourceId,
    required Dio dio,
    String? Function()? authHeader,
  }) : assert(
         sourceId == GallerySourceId.danbooru ||
             sourceId == GallerySourceId.safebooru,
       ),
       _dio = dio,
       _authHeader = authHeader;

  @override
  final GallerySourceId sourceId;

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  final Dio _dio;
  final String? Function()? _authHeader;

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
