import 'package:dio/dio.dart';

import '../../../../core/cache/danbooru_image_cache_manager.dart';
import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import '../../../models/online_gallery/gelbooru_credentials.dart';
import '../../../models/online_gallery/gelbooru_post_parser.dart';
import '../gelbooru_api_service.dart';
import 'gallery_source_adapter.dart';

class GelbooruGallerySourceAdapter implements GallerySourceAdapter {
  GelbooruGallerySourceAdapter({
    required Dio dio,
    required GelbooruApiService apiService,
    required Future<GelbooruCredentials?> Function() credentials,
    required void Function() markCredentialsInvalid,
  }) : _dio = dio,
       _apiService = apiService,
       _credentials = credentials,
       _markCredentialsInvalid = markCredentialsInvalid;

  final Dio _dio;
  final GelbooruApiService _apiService;
  final Future<GelbooruCredentials?> Function() _credentials;
  final void Function() _markCredentialsInvalid;

  @override
  GallerySourceId get sourceId => GallerySourceId.gelbooru;

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) {
    throw const GallerySourceException(
      GallerySourceErrorCode.malformedResponse,
      source: GallerySourceId.gelbooru,
      message: 'Gelbooru has no supported native ranking endpoint',
    );
  }

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    return GalleryDetail(item: item, media: [item.cover]);
  }

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    final page = galleryCursorPage(request.cursor);
    final baseTags = _buildTags(request);
    final tagsWithBlacklist = _appendBlacklist(baseTags, request.blacklistTags);
    final credentials = await _credentials();
    if (credentials != null) {
      try {
        final result = await _apiService.searchPosts(
          credentials: credentials,
          tags: _formatTags(tagsWithBlacklist),
          pid: page - 1,
          limit: request.pageSize,
          cancelToken: cancelToken,
        );
        return _pageFromItems(result.posts, result.rawCount, page, request);
      } on GelbooruApiException catch (error) {
        if (error.type != GelbooruApiErrorType.invalidCredentials) {
          throw _mapGelbooruError(error);
        }
        _markCredentialsInvalid();
      }
    }
    return _searchPublicHtml(
      request,
      page,
      tagsWithBlacklist,
      baseTags,
      cancelToken,
    );
  }

  Future<GalleryPage> _searchPublicHtml(
    GallerySearchRequest request,
    int page,
    String tagsWithBlacklist,
    String baseTags,
    CancelToken? cancelToken,
  ) async {
    Future<Response<dynamic>> fetch(String tags) {
      return _dio.get(
        GelbooruApiService.endpoint,
        queryParameters: {
          'page': 'post',
          's': 'list',
          'tags': _formatTags(tags),
          'pid': (page - 1) * 42,
        },
        options: Options(
          headers: {
            ...onlineGalleryImageHeadersForUrl(GelbooruApiService.endpoint),
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'User-Agent': 'Mozilla/5.0 NAI-Launcher/1.0',
          },
          responseType: ResponseType.plain,
        ),
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
          response = await fetch(baseTags);
        } else {
          rethrow;
        }
      }
      final parsed = parseGelbooruHtmlPosts(response.data?.toString() ?? '');
      return _pageFromItems(parsed, parsed.length, page, request);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw mapGalleryDioException(error, sourceId);
    }
  }

  GalleryPage _pageFromItems(
    List<GalleryItem> items,
    int rawCount,
    int page,
    GallerySearchRequest request,
  ) {
    final filtered = items
        .where((item) {
          if (request.ratings.length < 4 &&
              !request.ratings.contains(item.rating)) {
            return false;
          }
          return !item.tags.any(
            (tag) => request.blacklistTags.contains(
              tag.trim().toLowerCase().replaceAll(' ', '_'),
            ),
          );
        })
        .toList(growable: false);
    final hasMore = rawCount >= request.pageSize;
    return GalleryPage(
      items: filtered,
      cursor: request.cursor,
      nextCursor: hasMore ? '${page + 1}' : null,
      hasMore: hasMore,
      rawItemCount: rawCount,
    );
  }

  String _buildTags(GallerySearchRequest request) {
    var tags = request.query;
    if (request.ratings.length == 1) {
      tags = _join(tags, 'rating:${gelbooruRatingName(request.ratings.first)}');
    }
    if (request.dateStart != null || request.dateEnd != null) {
      final expression = switch ((request.dateStart, request.dateEnd)) {
        (final DateTime start, final DateTime end) =>
          'date:${formatGalleryDate(start)}..${formatGalleryDate(end)}',
        (final DateTime start, null) => 'date:>=${formatGalleryDate(start)}',
        (null, final DateTime end) => 'date:<=${formatGalleryDate(end)}',
        _ => '',
      };
      tags = _join(tags, expression);
    }
    return tags;
  }

  String _appendBlacklist(String tags, Set<String> blacklistTags) {
    final expression = blacklistTags
        .where(
          (tag) => tag.isNotEmpty && !tag.contains(':') && !tag.startsWith('-'),
        )
        .take(50)
        .map((tag) => '-$tag')
        .join(' ');
    return _join(tags, expression);
  }

  String _formatTags(String tags) {
    return tags
        .split(RegExp(r'\s+'))
        .map((tag) {
          final negative = tag.startsWith('-');
          final body = negative ? tag.substring(1) : tag;
          final match = RegExp(r'^rating:([a-zA-Z])$').firstMatch(body);
          if (match == null) return tag;
          return '${negative ? '-' : ''}rating:${gelbooruRatingName(match.group(1)!)}';
        })
        .join(' ');
  }

  String _join(String left, String right) {
    if (right.isEmpty) return left.trim();
    if (left.trim().isEmpty) return right;
    return '${left.trim()} $right';
  }

  GallerySourceException _mapGelbooruError(GelbooruApiException error) {
    final code = switch (error.type) {
      GelbooruApiErrorType.invalidCredentials =>
        GallerySourceErrorCode.credentialsInvalid,
      GelbooruApiErrorType.rateLimited => GallerySourceErrorCode.rateLimited,
      GelbooruApiErrorType.timeout => GallerySourceErrorCode.timeout,
      GelbooruApiErrorType.server => GallerySourceErrorCode.server,
      GelbooruApiErrorType.network => GallerySourceErrorCode.network,
      GelbooruApiErrorType.malformedResponse =>
        GallerySourceErrorCode.malformedResponse,
      GelbooruApiErrorType.cancelled ||
      GelbooruApiErrorType.unknown => GallerySourceErrorCode.unknown,
    };
    return GallerySourceException(
      code,
      source: sourceId,
      statusCode: error.statusCode,
      cause: error,
    );
  }
}
