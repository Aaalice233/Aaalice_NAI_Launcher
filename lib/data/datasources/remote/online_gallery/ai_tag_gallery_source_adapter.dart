import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/cache/online_gallery_image_cache_manager.dart';
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
      registerAiTagImageBaseUrl(cached.assetBaseUrl);
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
      final rawAssetBaseUrl = json['asset_base_url']?.toString().trim() ?? '';
      final assetBaseUrl = _normalizeAiTagAssetBaseUrl(rawAssetBaseUrl);
      if (assetBaseUrl == null) {
        throw const GallerySourceException(
          GallerySourceErrorCode.configurationUnavailable,
          source: GallerySourceId.aiTag,
          message: 'AI TAG asset_base_url is missing or invalid',
        );
      }
      final config = AiTagSourceConfig(
        assetBaseUrl: assetBaseUrl,
        pageSize: (_asInt(json['page_size']) ?? 60).clamp(60, 200),
        availableYears: _parseIntList(json['available_years']),
        availableMonths: _parseStringList(json['available_months'])
            .where((month) => RegExp(r'^\d{4}-\d{2}$').hasMatch(month))
            .toList(growable: false),
        fetchedAt: DateTime.now(),
      );
      registerAiTagImageBaseUrl(config.assetBaseUrl);
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
        'q': _toAiTagWeightedQuery(request.query),
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
      'q': _toAiTagWeightedQuery(request.query),
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
        rawPageIdentity: rawItems
            .map((value) => value is Map ? value['id'] : null)
            .join(','),
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
      final imageRows = payload['images'] as List;
      final copiedImageRows = imageRows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      // Some works contain many embedded metadata blobs. Keep JSON metadata
      // parsing off the UI isolate so a completed detail request cannot stall
      // an active masonry-grid fling.
      final parsedBatch = await _parseAiTagMediaRowsCancellable(
        copiedImageRows,
        config.assetBaseUrl,
        cancelToken,
      );
      if (cancelToken?.isCancelled ?? false) {
        throw DioException.requestCancelled(
          requestOptions: response.requestOptions,
          reason: 'AI TAG detail parsing cancelled',
        );
      }
      for (final failure in parsedBatch.failures) {
        AppLogger.w(
          'Skipped malformed AI TAG media (source=ai_tag, work=${item.id}, file=${failure.fileName}): ${failure.error}',
          'AiTagGallery',
        );
      }
      final media = parsedBatch.media;
      if (media.isEmpty) {
        throw const GallerySourceException(
          GallerySourceErrorCode.imageUnavailable,
          source: GallerySourceId.aiTag,
        );
      }
      final listItem = _parseListItem(work);
      final searchableTags = <String>{
        ...listItem.tags,
        for (final image in media)
          if (image.prompt != null) ..._parsePromptTags(image.prompt!),
      };
      final searchTerms = <String>{
        ...listItem.searchTerms,
        ...searchableTags,
        for (final tag in searchableTags) ..._searchTextTerms(tag),
        for (final image in media) ...[
          ..._searchTextTerms(image.metadata['model']?.toString()),
          ..._searchTextTerms(image.metadata['source_model']?.toString()),
        ],
      };
      final promptMetadataComplete =
          media.length == imageRows.length &&
          media.every(
            (image) =>
                image.metadataError == null &&
                image.prompt != null &&
                image.prompt!.trim().isNotEmpty,
          );
      final detailedItem = listItem.copyWith(
        cover: media.first,
        mediaCount: media.length,
        rank: item.rank,
        tags: List.unmodifiable(searchableTags),
        searchTerms: List.unmodifiable(searchTerms),
        tagsComplete: promptMetadataComplete,
      );
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
    final caption = json['caption']?.toString() ?? '';
    final description = _plainText(caption);
    final title = json['title']?.toString().trim();
    final author = json['userName']?.toString().trim();
    final aiType = (json['AI_type'] ?? json['ai_type'])?.toString();
    final searchableTags = <String>{..._parseStringList(json['tags'])};
    final searchTerms = <String>{
      ...searchableTags,
      for (final tag in searchableTags) ..._searchTextTerms(tag),
      ..._searchTextTerms(title),
      ..._searchTextTerms(author),
      ..._searchTextTerms(description),
      ..._searchTextTerms(aiType),
      ..._searchTextTerms(
        (json['model'] ?? json['model_name'] ?? json['modelName'])?.toString(),
      ),
    };
    return GalleryItem(
      id: id,
      sourceId: GallerySourceId.aiTag,
      createdAt: json['create_date']?.toString() ?? '',
      uploaderId: _asInt(json['userId'] ?? json['userid']) ?? 0,
      score: _asNum(json['score'])?.round(),
      rating: null,
      title: title,
      author: author,
      description: description,
      viewCount: _asInt(json['total_view']),
      favCount: _asInt(json['total_bookmarks']),
      aiType: aiType,
      mediaCount: (_asInt(json['image_count']) ?? 1).clamp(1, 10000),
      rank: rank,
      tags: List<String>.unmodifiable(searchableTags),
      searchTerms: List<String>.unmodifiable(searchTerms),
      // The list payload omits per-media prompts searched by the upstream q
      // endpoint. Detail loading must aggregate every media prompt first.
      tagsComplete: false,
      cover: GalleryMedia(
        id: '${id}_pending',
        previewUrl: '',
        displayUrl: '',
        downloadUrl: '',
        mediaType: 'image',
      ),
    );
  }

  static MetadataParseResult _parseMetadata(
    String? rawAiJson,
    String? promptText,
  ) {
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

  static Map<String, Object?> _metadataMap(
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

  static String? _rawJsonString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  static int _mediaPageIndex(String value) {
    final match = RegExp(r'_p(\d+)(?:\D|$)').firstMatch(value);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  String _toAiTagWeightedQuery(String query) {
    return query
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .map((term) => '$term::1')
        .join(' ');
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
        : await search(searchRequest, cancelToken: cancelToken, noCache: true);
    final shuffled = shuffleGalleryItems(pageResult.items, randomGenerator);

    return GalleryPage(
      items: shuffled,
      cursor: 'random',
      nextCursor: null,
      hasMore: false,
      rawItemCount: pageResult.rawItemCount,
    );
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
  }

  Future<AiTagTotalInfo> _probeTotalCount(
    GalleryRandomSearchRequest request,
    AiTagSourceConfig config,
    CancelToken? cancelToken,
  ) async {
    final firstPageRequest = GallerySearchRequest(
      cursor: '1',
      pageSize: config.pageSize,
      query: request.query,
      prompt: request.prompt,
      timeRange: request.timeRange,
      ratings: request.ratings,
      blacklistTags: const {},
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
  }

  Future<AiTagTotalInfo> _probeRankingTotalCount(
    GalleryRandomRankingRequest request,
    CancelToken? cancelToken,
  ) async {
    final firstPageRequest = GalleryRankingRequest(
      cursor: '1',
      pageSize: 60,
      kind: request.kind,
      date: request.date,
      period: request.period,
      query: request.query,
      prompt: request.prompt,
      ratings: request.ratings,
      blacklistTags: const {},
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
  }

  List<String> _parsePromptTags(String raw) {
    if (raw.trim().isEmpty) return const [];
    return _plainText(raw)
        .split(RegExp(r'[,\n]+'))
        .map(_cleanPromptTag)
        .where((tag) => tag.isNotEmpty && tag.length <= 200)
        .toList(growable: false);
  }

  static List<String> _searchTextTerms(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return const [];
    return <String>{
      value,
      ...value
          .split(RegExp(r'[\s,，;；/|:：\-—]+'))
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty),
    }.toList(growable: false);
  }

  static List<String> _parseStringList(Object? value) {
    final decoded = _decodeList(value);
    return decoded
        .map((item) => _cleanPromptTag(item?.toString() ?? ''))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _cleanPromptTag(String raw) {
    var value = raw.trim();
    value = value.replaceAll(RegExp(r'^[{}\[\]()\s]+|[{}\[\]()\s]+$'), '');
    value = value.replaceFirst(RegExp(r'^-?\d+(?:\.\d+)?::'), '');
    value = value.replaceFirst(RegExp(r'::$'), '');
    value = value.replaceFirst(RegExp(r'::-?\d+(?:\.\d+)?$'), '');
    value = value.replaceFirst(RegExp(r':-?\d+(?:\.\d+)?$'), '');
    value = value.replaceAll(RegExp(r'^[{}\[\]()\s]+|[{}\[\]()\s,，;；]+$'), '');
    return value.trim();
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

String? _normalizeAiTagAssetBaseUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final pathSegments = uri.pathSegments
      .where((segment) => segment.isNotEmpty && segment != '.')
      .toList(growable: true);
  if (pathSegments.any((segment) => segment == '..')) return null;
  pathSegments.add('');
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    pathSegments: pathSegments,
  ).toString();
}

Future<_ParsedAiTagMediaBatch> _parseAiTagMediaRowsCancellable(
  List<Map<String, dynamic>> rows,
  String assetBaseUrl,
  CancelToken? cancelToken,
) async {
  if (cancelToken?.isCancelled ?? false) {
    throw DioException.requestCancelled(
      requestOptions: RequestOptions(path: '/api/work'),
      reason: cancelToken?.cancelError,
    );
  }

  final resultPort = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();
  final completer = Completer<_ParsedAiTagMediaBatch>();
  final resultSubscription = resultPort.listen((message) {
    if (!completer.isCompleted && message is _ParsedAiTagMediaBatch) {
      completer.complete(message);
    }
  });
  final errorSubscription = errorPort.listen((message) {
    if (completer.isCompleted) return;
    final values = message is List ? message : const [];
    completer.completeError(
      RemoteError(
        values.isNotEmpty ? values.first.toString() : 'AI TAG parse failed',
        values.length > 1 ? values[1].toString() : '',
      ),
    );
  });
  final exitSubscription = exitPort.listen((_) {
    scheduleMicrotask(() {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('AI TAG metadata parser exited without a result'),
        );
      }
    });
  });
  Isolate? isolate;
  try {
    isolate = await Isolate.spawn<List<Object?>>(
      _parseAiTagMediaRowsEntry,
      [resultPort.sendPort, rows, assetBaseUrl],
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
      errorsAreFatal: true,
    );
    if (cancelToken != null) {
      final activeIsolate = isolate;
      unawaited(
        cancelToken.whenCancel.then((error) {
          if (!completer.isCompleted) {
            activeIsolate.kill(priority: Isolate.immediate);
            completer.completeError(error);
          }
        }),
      );
    }
    return await completer.future;
  } finally {
    isolate?.kill(priority: Isolate.immediate);
    await resultSubscription.cancel();
    await errorSubscription.cancel();
    await exitSubscription.cancel();
    resultPort.close();
    errorPort.close();
    exitPort.close();
  }
}

void _parseAiTagMediaRowsEntry(List<Object?> message) {
  final port = message[0] as SendPort;
  final rows = (message[1] as List).cast<Map<String, dynamic>>();
  final assetBaseUrl = message[2] as String;
  port.send(_parseAiTagMediaRows(rows, assetBaseUrl));
}

_ParsedAiTagMediaBatch _parseAiTagMediaRows(
  List<Map<String, dynamic>> rows,
  String assetBaseUrl,
) {
  final media = <GalleryMedia>[];
  final failures = <_AiTagMediaFailure>[];
  for (final row in rows) {
    final fileName = row['file_name']?.toString().trim() ?? '';
    try {
      final imageType = row['image_type']?.toString().trim() ?? '';
      final authorId = row['author_id']?.toString().trim() ?? '';
      if (imageType.isEmpty || authorId.isEmpty || fileName.isEmpty) {
        throw const FormatException('AI TAG image path fields are incomplete');
      }
      final baseUri = Uri.parse(assetBaseUrl);
      final baseSegments = baseUri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      final url = baseUri
          .replace(
            pathSegments: [
              ...baseSegments,
              imageType,
              authorId,
              '$fileName.webp',
            ],
            query: null,
            fragment: null,
          )
          .toString();
      final rawAiJson = AiTagGallerySourceAdapter._rawJsonString(
        row['ai_json'],
      );
      final promptText = row['prompt_text']?.toString();
      final parsed = AiTagGallerySourceAdapter._parseMetadata(
        rawAiJson,
        promptText,
      );
      media.add(
        GalleryMedia(
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
          promptMetadata: parsed.metadata,
          metadata: AiTagGallerySourceAdapter._metadataMap(
            parsed.metadata,
            row,
          ),
        ),
      );
    } catch (error) {
      failures.add(
        _AiTagMediaFailure(
          fileName: fileName.isEmpty ? '<unknown>' : fileName,
          error: error.toString(),
        ),
      );
    }
  }
  media.sort(
    (left, right) => AiTagGallerySourceAdapter._mediaPageIndex(
      left.id,
    ).compareTo(AiTagGallerySourceAdapter._mediaPageIndex(right.id)),
  );
  return _ParsedAiTagMediaBatch(media: media, failures: failures);
}

class _ParsedAiTagMediaBatch {
  const _ParsedAiTagMediaBatch({required this.media, required this.failures});

  final List<GalleryMedia> media;
  final List<_AiTagMediaFailure> failures;
}

class _AiTagMediaFailure {
  const _AiTagMediaFailure({required this.fileName, required this.error});

  final String fileName;
  final String error;
}
