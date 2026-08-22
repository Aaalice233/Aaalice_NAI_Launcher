import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/utils/app_logger.dart';
import '../../../models/gallery/nai_image_metadata.dart';
import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';
import '../../../services/metadata/unified_metadata_parser.dart';
import 'gallery_random_sampler.dart';
import 'gallery_source_adapter.dart';

class AiTagGallerySourceAdapter implements GallerySourceAdapter {
  AiTagGallerySourceAdapter({required Dio dio, Random? random})
    : _dio = dio,
      _random = random ?? Random.secure();

  static const _baseUrl = 'https://aitag.win';
  static const _configTtl = Duration(minutes: 30);

  final Dio _dio;
  final Random _random;
  AiTagSourceConfig? _cachedConfig;

  @override
  Random get randomGenerator => _random;

  // Cache for total count probes (5 minutes TTL, 64 entries max)
  static final _totalCountCache = GalleryRandomCache<AiTagTotalInfo>(
    maxSize: 64,
    ttl: const Duration(minutes: 5),
  );

  @override
  GallerySourceId get sourceId => GallerySourceId.aiTag;

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  Future<AiTagSourceConfig> getConfig({
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    final cached = _cachedConfig;
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _configTtl) {
      return cached;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/api/config',
        options: Options(headers: const {'Accept': 'application/json'}),
        cancelToken: cancelToken,
      );
      if (response.data is! Map) {
        throw const GallerySourceException(
          GallerySourceErrorCode.configurationUnavailable,
          source: GallerySourceId.aiTag,
          message: 'AI TAG config is not an object',
        );
      }
      final json = Map<String, dynamic>.from(response.data as Map);
      final assetBaseUrl = json['asset_base_url']?.toString().trim() ?? '';
      if (Uri.tryParse(assetBaseUrl)?.isAbsolute != true ||
          assetBaseUrl.isEmpty) {
        throw const GallerySourceException(
          GallerySourceErrorCode.configurationUnavailable,
          source: GallerySourceId.aiTag,
          message: 'AI TAG asset_base_url is missing or invalid',
        );
      }
      final config = AiTagSourceConfig(
        assetBaseUrl: assetBaseUrl.endsWith('/')
            ? assetBaseUrl
            : '$assetBaseUrl/',
        pageSize: (_asInt(json['page_size']) ?? 60).clamp(60, 200),
        availableYears: _parseIntList(json['available_years']),
        availableMonths: _parseStringList(json['available_months'])
            .where((month) => RegExp(r'^\d{4}-\d{2}$').hasMatch(month))
            .toList(growable: false),
        fetchedAt: DateTime.now(),
      );
      _cachedConfig = config;
      return config;
    } on GallerySourceException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      throw GallerySourceException(
        GallerySourceErrorCode.configurationUnavailable,
        source: sourceId,
        statusCode: error.response?.statusCode,
        cause: error,
      );
    } catch (error) {
      throw GallerySourceException(
        GallerySourceErrorCode.configurationUnavailable,
        source: sourceId,
        cause: error,
      );
    }
  }

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
    bool noCache = false,
  }) async {
    final config = await getConfig(cancelToken: cancelToken);
    final page = galleryCursorPage(request.cursor);
    return _fetchList(
      '$_baseUrl/api/ai_works_search',
      request.cursor,
      config,
      queryParameters: {
        'page': page,
        'page_size': config.pageSize,
        'q': request.query,
        'prompt': request.prompt,
        'sort': 'new',
        'time_range': request.timeRange,
      },
      blacklistTags: request.blacklistTags,
      noCache: noCache,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
    bool noCache = false,
  }) async {
    final config = await getConfig(cancelToken: cancelToken);
    final page = galleryCursorPage(request.cursor);
    final period = request.period.trim().isEmpty ? 'current' : request.period;
    final String url;
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': config.pageSize,
      'q': request.query,
      'prompt': request.prompt,
    };
    if (period == 'current') {
      url = '$_baseUrl/api/rank/monthly/real';
    } else {
      url = '$_baseUrl/api/rank/monthly/fixed';
      queryParameters['month'] = period;
    }
    return _fetchList(
      url,
      request.cursor,
      config,
      queryParameters: queryParameters,
      blacklistTags: request.blacklistTags,
      includeRank: true,
      noCache: noCache,
      cancelToken: cancelToken,
    );
  }

  Future<GalleryPage> _fetchList(
    String url,
    String cursor,
    AiTagSourceConfig config, {
    required Map<String, dynamic> queryParameters,
    required Set<String> blacklistTags,
    bool includeRank = false,
    bool noCache = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (noCache) 'Cache-Control': 'no-cache',
          },
        ),
        cancelToken: cancelToken,
      );
      if (response.data is! Map) {
        throw const GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: GallerySourceId.aiTag,
        );
      }
      final json = Map<String, dynamic>.from(response.data as Map);
      final status = json['status']?.toString() ?? json['error']?.toString();
      if (status == 'rank_processing') {
        throw const GallerySourceException(
          GallerySourceErrorCode.rankingProcessing,
          source: GallerySourceId.aiTag,
        );
      }
      final rawItems = json['items'];
      if (rawItems is! List) {
        throw const GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: GallerySourceId.aiTag,
          message: 'AI TAG items is not an array',
        );
      }
      final page = _asInt(json['page']) ?? galleryCursorPage(cursor);
      final pageSize = _asInt(json['page_size']) ?? config.pageSize;
      final total = _asInt(json['total']);
      final parsed = <GalleryItem>[];
      for (var index = 0; index < rawItems.length; index++) {
        final raw = rawItems[index];
        if (raw is! Map) continue;
        try {
          final item = _parseListItem(
            Map<String, dynamic>.from(raw),
            rank: includeRank ? (page - 1) * pageSize + index + 1 : null,
          );
          if (!_isBlacklisted(item, blacklistTags)) parsed.add(item);
        } catch (error) {
          final workId = raw['id']?.toString() ?? '<unknown>';
          AppLogger.w(
            'Skipped malformed AI TAG list item (source=ai_tag, work=$workId): $error',
            'AiTagGallery',
          );
        }
      }
      final hasMore = total != null
          ? page * pageSize < total
          : rawItems.length >= pageSize;
      return GalleryPage(
        items: parsed,
        cursor: cursor,
        nextCursor: hasMore ? '${page + 1}' : null,
        total: total,
        hasMore: hasMore,
        rawItemCount: rawItems.length,
      );
    } on GallerySourceException {
      rethrow;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      final data = error.response?.data;
      if (data is Map &&
          (data['status'] == 'rank_processing' ||
              data['error'] == 'rank_processing')) {
        throw const GallerySourceException(
          GallerySourceErrorCode.rankingProcessing,
          source: GallerySourceId.aiTag,
        );
      }
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
    final config = await getConfig(cancelToken: cancelToken);
    try {
      final response = await _dio.get(
        '$_baseUrl/api/work/${item.id}',
        options: Options(headers: const {'Accept': 'application/json'}),
        cancelToken: cancelToken,
      );
      if (response.data is! Map) {
        throw const GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: GallerySourceId.aiTag,
        );
      }
      final payload = Map<String, dynamic>.from(response.data as Map);
      if (payload['error'] == 'not_found') {
        throw const GallerySourceException(
          GallerySourceErrorCode.detailNotFound,
          source: GallerySourceId.aiTag,
        );
      }
      if (payload['work'] is! Map || payload['images'] is! List) {
        throw const GallerySourceException(
          GallerySourceErrorCode.malformedResponse,
          source: GallerySourceId.aiTag,
        );
      }
      final work = Map<String, dynamic>.from(payload['work'] as Map);
      final media = <GalleryMedia>[];
      for (final raw in payload['images'] as List) {
        if (raw is! Map) continue;
        try {
          media.add(
            _parseMedia(Map<String, dynamic>.from(raw), config.assetBaseUrl),
          );
        } catch (error) {
          final fileName = raw['file_name']?.toString() ?? '<unknown>';
          AppLogger.w(
            'Skipped malformed AI TAG media (source=ai_tag, work=${item.id}, file=$fileName): $error',
            'AiTagGallery',
          );
        }
      }
      media.sort(
        (left, right) =>
            _mediaPageIndex(left.id).compareTo(_mediaPageIndex(right.id)),
      );
      if (media.isEmpty) {
        throw const GallerySourceException(
          GallerySourceErrorCode.imageUnavailable,
          source: GallerySourceId.aiTag,
        );
      }
      final detailedItem = _parseListItem(
        work,
      ).copyWith(cover: media.first, mediaCount: media.length, rank: item.rank);
      return GalleryDetail(
        item: detailedItem,
        media: List.unmodifiable(media),
        prompt: media.first.prompt,
        negativePrompt: media.first.negativePrompt,
        description: detailedItem.description,
        rawSourceMetadata: payload.map(
          (key, value) => MapEntry(key, value as Object?),
        ),
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

  GalleryItem _parseListItem(Map<String, dynamic> json, {int? rank}) {
    final id = _asInt(json['id']);
    if (id == null || id <= 0) {
      throw const FormatException('AI TAG work id is invalid');
    }
    return GalleryItem(
      id: id,
      sourceId: GallerySourceId.aiTag,
      createdAt: json['create_date']?.toString() ?? '',
      uploaderId: _asInt(json['userId'] ?? json['userid']) ?? 0,
      score: _asNum(json['score'])?.round(),
      rating: null,
      title: json['title']?.toString().trim(),
      author: json['userName']?.toString().trim(),
      description: _plainText(json['caption']?.toString() ?? ''),
      viewCount: _asInt(json['total_view']),
      favCount: _asInt(json['total_bookmarks']),
      aiType: (json['AI_type'] ?? json['ai_type'])?.toString(),
      mediaCount: (_asInt(json['image_count']) ?? 1).clamp(1, 10000),
      rank: rank,
      tags: _parseStringList(json['tags']),
      cover: GalleryMedia(
        id: '${id}_pending',
        previewUrl: '',
        displayUrl: '',
        downloadUrl: '',
        mediaType: 'image',
      ),
    );
  }

  GalleryMedia _parseMedia(Map<String, dynamic> json, String assetBaseUrl) {
    final imageType = json['image_type']?.toString().trim() ?? '';
    final authorId = json['author_id']?.toString().trim() ?? '';
    final fileName = json['file_name']?.toString().trim() ?? '';
    if (imageType.isEmpty || authorId.isEmpty || fileName.isEmpty) {
      throw const FormatException('AI TAG image path fields are incomplete');
    }
    final url = '$assetBaseUrl$imageType/$authorId/$fileName.webp';
    final rawAiJson = _rawJsonString(json['ai_json']);
    final promptText = json['prompt_text']?.toString();
    final parsed = _parseMetadata(rawAiJson, promptText);
    return GalleryMedia(
      id: fileName,
      previewUrl: url,
      displayUrl: url,
      downloadUrl: url,
      width: parsed.metadata?.width ?? 0,
      height: parsed.metadata?.height ?? 0,
      extension: 'webp',
      mediaType: 'image',
      prompt: parsed.metadata?.prompt,
      negativePrompt: parsed.metadata?.negativePrompt,
      rawMetadata: rawAiJson ?? promptText,
      metadataFormat: parsed.sourceFormat,
      metadataError: parsed.success ? null : parsed.errorMessage,
      metadata: _metadataMap(parsed.metadata, json),
    );
  }

  MetadataParseResult _parseMetadata(String? rawAiJson, String? promptText) {
    if ((rawAiJson == null || rawAiJson.isEmpty) &&
        (promptText == null || promptText.isEmpty)) {
      return MetadataParseResult.failed(
        const [],
        'No AI metadata was provided',
      );
    }
    final values = <String, String>{};
    if (rawAiJson != null && rawAiJson.isNotEmpty) {
      values['Comment'] = rawAiJson;
      try {
        final decoded = jsonDecode(rawAiJson);
        if (decoded is Map) {
          final isComfyPromptGraph = decoded.values.any(
            (value) => value is Map && value['class_type'] != null,
          );
          if (isComfyPromptGraph) values['prompt'] = rawAiJson;
          for (final entry in decoded.entries) {
            if (entry.value == null) continue;
            values[entry.key.toString()] = entry.value is String
                ? entry.value as String
                : jsonEncode(entry.value);
          }
        }
      } catch (_) {
        values['parameters'] = rawAiJson;
      }
    }
    if (!values.containsKey('parameters') &&
        promptText != null &&
        promptText.isNotEmpty) {
      values['parameters'] = promptText;
    }
    final parsed = UnifiedMetadataParser.parseFromTextData(values);
    if (parsed.success || promptText == null || promptText.isEmpty) {
      return parsed;
    }
    return UnifiedMetadataParser.parseFromTextData({
      'parameters': promptText,
      'Description': promptText,
    });
  }

  Map<String, Object?> _metadataMap(
    NaiImageMetadata? metadata,
    Map<String, dynamic> raw,
  ) {
    return <String, Object?>{
      if (metadata?.seed != null) 'seed': metadata!.seed,
      if (metadata?.sampler != null) 'sampler': metadata!.sampler,
      if (metadata?.steps != null) 'steps': metadata!.steps,
      if (metadata?.scale != null) 'scale': metadata!.scale,
      if (metadata?.model != null) 'model': metadata!.model,
      if (metadata?.software != null) 'software': metadata!.software,
      if (raw['model'] != null) 'source_model': raw['model'].toString(),
    };
  }

  bool _isBlacklisted(GalleryItem item, Set<String> blacklistTags) {
    if (blacklistTags.isEmpty) return false;
    return item.tags.any(
      (tag) =>
          blacklistTags.contains(tag.trim().toLowerCase().replaceAll(' ', '_')),
    );
  }

  String _plainText(String html) {
    if (html.isEmpty) return '';
    final withBreaks = html.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    );
    return html_parser.parseFragment(withBreaks).text?.trim() ?? '';
  }

  String? _rawJsonString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  int _mediaPageIndex(String value) {
    final match = RegExp(r'_p(\d+)(?:\D|$)').firstMatch(value);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static num? _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  static List<int> _parseIntList(Object? value) {
    final decoded = _decodeList(value);
    return decoded.map(_asInt).whereType<int>().toList(growable: false);
  }

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async {
    return switch (request) {
      GalleryRandomSearchRequest() => _randomSearch(request, cancelToken),
      GalleryRandomRankingRequest() => _randomRanking(request, cancelToken),
      GalleryRandomFavoritesRequest() => throw const GallerySourceException(
        GallerySourceErrorCode.malformedResponse,
        source: GallerySourceId.aiTag,
        message: 'AI TAG does not support favorites',
      ),
    };
  }

  Future<GalleryPage> _randomSearch(
    GalleryRandomSearchRequest request,
    CancelToken? cancelToken,
  ) async {
    final config = await getConfig(cancelToken: cancelToken);
    final cacheKey = GalleryRandomCacheKeys.aiTagTotal(
      query: request.query,
      prompt: request.prompt,
      timeRange: request.timeRange,
    );

    // Try to get cached total count
    var totalInfo = _totalCountCache.get(cacheKey);

    if (totalInfo == null) {
      // Probe first page to get total count
      totalInfo = await _probeTotalCount(request, config, cancelToken);
      if (totalInfo.isValid) {
        _totalCountCache.put(
          cacheKey,
          AiTagTotalInfo(
            totalCount: totalInfo.totalCount,
            pageSize: totalInfo.pageSize,
          ),
        );
      }
    }

    if (!totalInfo.isValid || totalInfo.totalPages <= 1) {
      // 探测页已包含实际数据；选中第一页时不得重复请求。
      final firstPageRequest = GallerySearchRequest(
        cursor: '1',
        pageSize: request.pageSize,
        query: request.query,
        prompt: request.prompt,
        timeRange: request.timeRange,
        ratings: request.ratings,
        blacklistTags: request.blacklistTags,
      );

      final firstPage =
          totalInfo.probedPage ??
          await search(
            firstPageRequest,
            cancelToken: cancelToken,
            noCache: true,
          );
      final shuffled = shuffleGalleryItems(firstPage.items, randomGenerator);

      return GalleryPage(
        items: shuffled,
        cursor: 'random',
        nextCursor: null,
        hasMore: false,
        rawItemCount: firstPage.rawItemCount,
      );
    }

    // Select random page
    final randomPage = randomGenerator.nextInt(totalInfo.totalPages) + 1;

    try {
      final searchRequest = GallerySearchRequest(
        cursor: randomPage.toString(),
        pageSize: request.pageSize,
        query: request.query,
        prompt: request.prompt,
        timeRange: request.timeRange,
        ratings: request.ratings,
        blacklistTags: request.blacklistTags,
      );

      final pageResult = randomPage == 1 && totalInfo.probedPage != null
          ? totalInfo.probedPage!
          : await search(
              searchRequest,
              cancelToken: cancelToken,
              noCache: true,
            );
      final shuffled = shuffleGalleryItems(pageResult.items, randomGenerator);

      return GalleryPage(
        items: shuffled,
        cursor: 'random',
        nextCursor: null,
        hasMore: false,
        rawItemCount: pageResult.rawItemCount,
      );
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        rethrow;
      }
      // Fallback to first page on error
      final firstPageRequest = GallerySearchRequest(
        cursor: '1',
        pageSize: request.pageSize,
        query: request.query,
        prompt: request.prompt,
        timeRange: request.timeRange,
        ratings: request.ratings,
        blacklistTags: request.blacklistTags,
      );

      final firstPage =
          totalInfo.probedPage ??
          await search(
            firstPageRequest,
            cancelToken: cancelToken,
            noCache: true,
          );
      final shuffled = shuffleGalleryItems(firstPage.items, randomGenerator);

      return GalleryPage(
        items: shuffled,
        cursor: 'random',
        nextCursor: null,
        hasMore: false,
        rawItemCount: firstPage.rawItemCount,
      );
    }
  }

  Future<GalleryPage> _randomRanking(
    GalleryRandomRankingRequest request,
    CancelToken? cancelToken,
  ) async {
    final cacheKey = GalleryRandomCacheKeys.aiTagRankingTotal(
      period: request.period,
      query: request.query,
      prompt: request.prompt,
    );

    // Try to get cached total count for ranking
    var totalInfo = _totalCountCache.get(cacheKey);

    if (totalInfo == null) {
      // Probe first page to get total count
      totalInfo = await _probeRankingTotalCount(request, cancelToken);
      if (totalInfo.isValid) {
        _totalCountCache.put(
          cacheKey,
          AiTagTotalInfo(
            totalCount: totalInfo.totalCount,
            pageSize: totalInfo.pageSize,
          ),
        );
      }
    }

    if (!totalInfo.isValid || totalInfo.totalPages <= 1) {
      // 探测页已包含实际数据；选中第一页时不得重复请求。
      final firstPageRequest = GalleryRankingRequest(
        cursor: '1',
        pageSize: request.pageSize,
        kind: request.kind,
        date: request.date,
        period: request.period,
        query: request.query,
        prompt: request.prompt,
        ratings: request.ratings,
        blacklistTags: request.blacklistTags,
      );

      final firstPage =
          totalInfo.probedPage ??
          await ranking(
            firstPageRequest,
            cancelToken: cancelToken,
            noCache: true,
          );
      final shuffled = shuffleGalleryItems(firstPage.items, randomGenerator);

      return GalleryPage(
        items: shuffled,
        cursor: 'random',
        nextCursor: null,
        hasMore: false,
        rawItemCount: firstPage.rawItemCount,
      );
    }

    // Select random page
    final randomPage = randomGenerator.nextInt(totalInfo.totalPages) + 1;

    try {
      final rankingRequest = GalleryRankingRequest(
        cursor: randomPage.toString(),
        pageSize: request.pageSize,
        kind: request.kind,
        date: request.date,
        period: request.period,
        query: request.query,
        prompt: request.prompt,
        ratings: request.ratings,
        blacklistTags: request.blacklistTags,
      );

      final pageResult = randomPage == 1 && totalInfo.probedPage != null
          ? totalInfo.probedPage!
          : await ranking(
              rankingRequest,
              cancelToken: cancelToken,
              noCache: true,
            );
      final shuffled = shuffleGalleryItems(pageResult.items, randomGenerator);

      return GalleryPage(
        items: shuffled,
        cursor: 'random',
        nextCursor: null,
        hasMore: false,
        rawItemCount: pageResult.rawItemCount,
      );
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        rethrow;
      }
      // Fallback to first page on error
      final firstPageRequest = GalleryRankingRequest(
        cursor: '1',
        pageSize: request.pageSize,
        kind: request.kind,
        date: request.date,
        period: request.period,
        query: request.query,
        prompt: request.prompt,
        ratings: request.ratings,
        blacklistTags: request.blacklistTags,
      );

      final firstPage =
          totalInfo.probedPage ??
          await ranking(
            firstPageRequest,
            cancelToken: cancelToken,
            noCache: true,
          );
      final shuffled = shuffleGalleryItems(firstPage.items, randomGenerator);

      return GalleryPage(
        items: shuffled,
        cursor: 'random',
        nextCursor: null,
        hasMore: false,
        rawItemCount: firstPage.rawItemCount,
      );
    }
  }

  Future<AiTagTotalInfo> _probeTotalCount(
    GalleryRandomSearchRequest request,
    AiTagSourceConfig config,
    CancelToken? cancelToken,
  ) async {
    try {
      final firstPageRequest = GallerySearchRequest(
        cursor: '1',
        pageSize: config.pageSize, // Use config page size for probe
        query: request.query,
        prompt: request.prompt,
        timeRange: request.timeRange,
        ratings: request.ratings,
        blacklistTags: const {}, // Don't apply blacklist during probe
      );

      final firstPage = await search(
        firstPageRequest,
        cancelToken: cancelToken,
        noCache: true,
      );

      return AiTagTotalInfo(
        totalCount: firstPage.total ?? firstPage.rawItemCount,
        pageSize: config.pageSize,
        probedPage: firstPage,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      return const AiTagTotalInfo(totalCount: 0, pageSize: 0);
    } catch (_) {
      return const AiTagTotalInfo(totalCount: 0, pageSize: 0);
    }
  }

  Future<AiTagTotalInfo> _probeRankingTotalCount(
    GalleryRandomRankingRequest request,
    CancelToken? cancelToken,
  ) async {
    try {
      final firstPageRequest = GalleryRankingRequest(
        cursor: '1',
        pageSize: 60, // Standard page size for probe
        kind: request.kind,
        date: request.date,
        period: request.period,
        query: request.query,
        prompt: request.prompt,
        ratings: request.ratings,
        blacklistTags: const {}, // Don't apply blacklist during probe
      );

      final firstPage = await ranking(
        firstPageRequest,
        cancelToken: cancelToken,
        noCache: true,
      );

      return AiTagTotalInfo(
        totalCount: firstPage.total ?? firstPage.rawItemCount,
        pageSize: 60,
        probedPage: firstPage,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) rethrow;
      return const AiTagTotalInfo(totalCount: 0, pageSize: 0);
    } catch (_) {
      return const AiTagTotalInfo(totalCount: 0, pageSize: 0);
    }
  }

  static List<String> _parseStringList(Object? value) {
    final decoded = _decodeList(value);
    return decoded
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<dynamic> _decodeList(Object? value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }
}
