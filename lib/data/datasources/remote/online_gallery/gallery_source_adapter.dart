import 'package:dio/dio.dart';

import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';

enum GallerySourceErrorCode {
  network,
  timeout,
  rateLimited,
  malformedResponse,
  detailNotFound,
  imageUnavailable,
  rankingProcessing,
  configurationUnavailable,
  credentialsRequired,
  credentialsInvalid,
  server,
  unknown,
}

class GallerySourceException implements Exception {
  const GallerySourceException(
    this.code, {
    this.source,
    this.statusCode,
    this.cause,
    this.message,
  });

  final GallerySourceErrorCode code;
  final GallerySourceId? source;
  final int? statusCode;
  final Object? cause;
  final String? message;

  @override
  String toString() =>
      'GallerySourceException($code, source: $source, status: $statusCode, message: $message)';
}

class GallerySearchRequest {
  const GallerySearchRequest({
    required this.cursor,
    required this.pageSize,
    this.query = '',
    this.prompt = '',
    this.timeRange = 'all',
    this.ratings = const {'g', 's', 'q', 'e'},
    this.dateStart,
    this.dateEnd,
    this.blacklistTags = const {},
  });

  final String cursor;
  final int pageSize;
  final String query;
  final String prompt;
  final String timeRange;
  final Set<String> ratings;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final Set<String> blacklistTags;
}

class GalleryRankingRequest {
  const GalleryRankingRequest({
    required this.cursor,
    required this.pageSize,
    this.kind = GalleryRankingKind.day,
    this.date,
    this.period = 'current',
    this.query = '',
    this.prompt = '',
    this.ratings = const {'g', 's', 'q', 'e'},
    this.blacklistTags = const {},
  });

  final String cursor;
  final int pageSize;
  final GalleryRankingKind kind;
  final DateTime? date;
  final String period;
  final String query;
  final String prompt;
  final Set<String> ratings;
  final Set<String> blacklistTags;
}

class AiTagSourceConfig {
  const AiTagSourceConfig({
    required this.assetBaseUrl,
    required this.pageSize,
    required this.availableYears,
    required this.availableMonths,
    required this.fetchedAt,
  });

  final String assetBaseUrl;
  final int pageSize;
  final List<int> availableYears;
  final List<String> availableMonths;
  final DateTime fetchedAt;

  List<String> get searchTimeRanges => timeRanges.keys.toList(growable: false);

  Map<String, String> get timeRanges {
    final ranges = <String, String>{'all': 'All time'};
    for (final year in availableYears) {
      ranges['y$year'] = '$year';
      if (year > 2023) {
        for (var quarter = 1; quarter <= 4; quarter++) {
          ranges['q${year}Q$quarter'] = '$year Q$quarter';
        }
      }
    }
    ranges['older'] = 'Older archive';
    return ranges;
  }

  List<String> get rankMonths => availableMonths;
}

abstract class GallerySourceAdapter {
  GallerySourceId get sourceId;

  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  });

  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) {
    throw GallerySourceException(
      GallerySourceErrorCode.malformedResponse,
      source: sourceId,
      message: 'Ranking is not supported by this source',
    );
  }

  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    return GalleryDetail(item: item, media: [item.cover]);
  }
}

int galleryCursorPage(String cursor, {int fallback = 1}) {
  final page = int.tryParse(cursor);
  return page != null && page > 0 ? page : fallback;
}

String formatGalleryDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

GallerySourceException mapGalleryDioException(
  DioException error,
  GallerySourceId source,
) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return GallerySourceException(
      GallerySourceErrorCode.timeout,
      source: source,
      cause: error,
    );
  }
  final status = error.response?.statusCode;
  if (status == 404) {
    return GallerySourceException(
      GallerySourceErrorCode.detailNotFound,
      source: source,
      statusCode: status,
      cause: error,
    );
  }
  if (status == 429) {
    return GallerySourceException(
      GallerySourceErrorCode.rateLimited,
      source: source,
      statusCode: status,
      cause: error,
    );
  }
  if (status != null && status >= 500) {
    return GallerySourceException(
      GallerySourceErrorCode.server,
      source: source,
      statusCode: status,
      cause: error,
    );
  }
  return GallerySourceException(
    GallerySourceErrorCode.network,
    source: source,
    statusCode: status,
    cause: error,
  );
}
