import 'dart:async';

import 'package:dio/dio.dart';

import '../utils/app_logger.dart';
import 'autocomplete_cache_database.dart';
import 'completion_models.dart';

class DanbooruCompletionSource implements CompletionSource {
  DanbooruCompletionSource({Dio? dio, required AutocompleteCacheDatabase cache})
    : _cache = cache,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://danbooru.donmai.us',
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
              sendTimeout: const Duration(seconds: 3),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'Aaalice-NAI-Launcher/Autocomplete',
              },
            ),
          );

  final Dio _dio;
  final AutocompleteCacheDatabase _cache;
  final Map<String, _MemoryEntry> _memory = {};
  CancelToken? _cancelToken;
  DateTime? _lastRequestAt;
  DateTime? _breakerOpenUntil;
  int _consecutiveFailures = 0;
  String? _lastError;

  bool get circuitOpen =>
      _breakerOpenUntil != null && DateTime.now().isBefore(_breakerOpenUntil!);
  String? get lastError => _lastError;

  void cancelPending() {
    _cancelToken?.cancel('Autocomplete query replaced');
    _cancelToken = null;
  }

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    final token = query.token.trim().toLowerCase();
    if (query.isChinese || token.length < 2) return const [];
    final key =
        'tags:$token:${query.categoryFilter?.value ?? 'all'}:${query.limit}';
    final now = DateTime.now();
    final memory = _memory[key];
    if (memory != null &&
        now.difference(memory.storedAt) < const Duration(minutes: 5)) {
      _lastError = null;
      return memory.candidates;
    }

    final disk = await _cache.getRemote(key);
    if (disk != null &&
        now.toUtc().difference(disk.fetchedAt) < const Duration(days: 7)) {
      final candidates = _decodeCandidates(disk.payload);
      _memory[key] = _MemoryEntry(candidates, now);
      _lastError = null;
      return candidates;
    }
    if (circuitOpen) {
      _lastError = 'Danbooru requests are temporarily paused';
      return _staleCandidates(disk, now);
    }

    cancelPending();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      final targetCount = CompletionResultLimits.isAll(query.limit)
          ? CompletionResultLimits.all
          : (query.limit * 2).clamp(50, 200);
      final pageSize = targetCount.clamp(
        1,
        CompletionResultLimits.danbooruPageSize,
      );
      final maxPages = (targetCount / pageSize).ceil();
      final candidates = <CompletionCandidate>[];
      for (var page = 1; page <= maxPages; page++) {
        await _waitForRateLimit();
        final response = await _requestWithRetry(
          '/tags.json',
          queryParameters: {
            'search[name_matches]': token.length < 3 ? '$token*' : '*$token*',
            'search[hide_empty]': 'yes',
            'search[is_deprecated]': 'no',
            'search[order]': 'count',
            if (query.categoryFilter != null)
              'search[category]': query.categoryFilter!.value,
            'limit': pageSize,
            if (page > 1) 'page': page,
          },
          cancelToken: cancelToken,
        );
        final data = response.data;
        if (data is! List) {
          throw StateError('Unexpected Danbooru tags response');
        }
        candidates.addAll(_extractTagCandidates(data, token));
        if (data.length < pageSize) break;
      }
      _consecutiveFailures = 0;
      _lastError = null;
      final payload = candidates.map(_encodeCandidate).toList();
      await _cache.putRemote(key, payload);
      _memory[key] = _MemoryEntry(candidates, now);
      return candidates;
    } on DioException catch (error, stack) {
      if (CancelToken.isCancel(error)) return const [];
      _lastError = error.message ?? error.toString();
      _registerFailure();
      AppLogger.w(
        'Danbooru autocomplete request failed: $error',
        'Autocomplete',
      );
      AppLogger.d('$stack', 'Autocomplete');
      return _staleCandidates(disk, now);
    } catch (error, stack) {
      _lastError = error.toString();
      _registerFailure();
      AppLogger.e('Danbooru autocomplete response failed', error, stack);
      return _staleCandidates(disk, now);
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  Future<List<CompletionCandidate>> relatedTags(
    String tag, {
    int limit = 20,
  }) async {
    final normalized = tag.trim().toLowerCase().replaceAll(' ', '_');
    if (normalized.isEmpty) return const [];
    final requestedLimit = CompletionResultLimits.isAll(limit)
        ? 500
        : limit.clamp(1, 500);
    final key = 'related:v3:$normalized:$requestedLimit';
    final now = DateTime.now();
    final memory = _memory[key];
    if (memory != null &&
        now.difference(memory.storedAt) < const Duration(minutes: 5)) {
      _lastError = null;
      return memory.candidates;
    }
    final disk = await _cache.getRemote(key);
    if (disk != null &&
        now.toUtc().difference(disk.fetchedAt) < const Duration(days: 7)) {
      final candidates = _decodeCandidates(disk.payload);
      _memory[key] = _MemoryEntry(candidates, now);
      _lastError = null;
      return candidates;
    }
    if (circuitOpen) {
      _lastError = 'Danbooru requests are temporarily paused';
      return _staleCandidates(disk, now);
    }
    cancelPending();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      await _waitForRateLimit();
      final response = await _requestWithRetry(
        '/related_tag.json',
        queryParameters: {
          'query': normalized,
          'limit': requestedLimit,
          'order': 'jaccard',
        },
        cancelToken: cancelToken,
      );
      final candidates = _extractRelatedCandidates(
        response.data,
        requestedLimit,
      );
      await _cache.putRemote(key, candidates.map(_encodeCandidate).toList());
      _memory[key] = _MemoryEntry(candidates, now);
      _consecutiveFailures = 0;
      _lastError = null;
      return candidates;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return const [];
      _lastError = error.message ?? error.toString();
      _registerFailure();
      AppLogger.w('Danbooru related tags failed: $error');
      return _staleCandidates(disk, now);
    } catch (error) {
      _lastError = error.toString();
      _registerFailure();
      AppLogger.w('Danbooru related tags failed: $error');
      return _staleCandidates(disk, now);
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  Future<Response<dynamic>> _requestWithRetry(
    String path, {
    required Map<String, dynamic> queryParameters,
    required CancelToken cancelToken,
  }) async {
    DioException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _dio.get<dynamic>(
          path,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        lastError = error;
        if (CancelToken.isCancel(error)) rethrow;
        final status = error.response?.statusCode;
        if (status != 429 && status != 503) rethrow;
        if (attempt == 1) rethrow;
        final retryAfter = int.tryParse(
          error.response?.headers.value('retry-after') ?? '',
        );
        await Future<void>.delayed(
          Duration(seconds: (retryAfter ?? 1).clamp(1, 5)),
        );
      }
    }
    throw lastError!;
  }

  Future<void> _waitForRateLimit() async {
    final previous = _lastRequestAt;
    if (previous != null) {
      final remaining =
          const Duration(milliseconds: 250) -
          DateTime.now().difference(previous);
      if (!remaining.isNegative) await Future<void>.delayed(remaining);
    }
    _lastRequestAt = DateTime.now();
  }

  void _registerFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3) {
      _breakerOpenUntil = DateTime.now().add(const Duration(seconds: 30));
      _consecutiveFailures = 0;
    }
  }

  static List<CompletionCandidate> _staleCandidates(
    CachedAutocompletePayload? disk,
    DateTime now,
  ) {
    if (disk == null ||
        now.toUtc().difference(disk.fetchedAt) > const Duration(days: 30)) {
      return const [];
    }
    return _decodeCandidates(disk.payload);
  }

  static List<CompletionCandidate> _extractTagCandidates(
    List<dynamic> data,
    String token,
  ) {
    final candidates = <CompletionCandidate>[];
    for (final item in data.whereType<Map>()) {
      final map = item.map((key, value) => MapEntry('$key', value));
      final name = (map['name'] as String? ?? '').trim().toLowerCase();
      final count = (map['post_count'] as num?)?.toInt() ?? 0;
      final category = TagCategory.fromDanbooru(
        (map['category'] as num?)?.toInt() ?? -1,
      );
      final deprecated = map['is_deprecated'] == true;
      if (name.isEmpty || count <= 0 || category == null || deprecated) {
        continue;
      }
      candidates.add(
        CompletionCandidate(
          canonicalTag: name,
          category: category,
          postCount: count,
          matchKind: name == token
              ? CompletionMatchKind.englishExact
              : name.startsWith(token)
              ? CompletionMatchKind.englishPrefix
              : CompletionMatchKind.fullText,
          sources: const {CompletionSourceKind.danbooruApi},
        ),
      );
    }
    return candidates;
  }

  static Map<String, dynamic> _encodeCandidate(CompletionCandidate value) => {
    'tag': value.canonicalTag,
    'category': value.category.value,
    'postCount': value.postCount,
    'matchKind': value.matchKind.name,
    if (value.relatedScore case final score?) 'relatedScore': score,
    if (value.cooccurrenceCount case final count?) 'cooccurrenceCount': count,
  };

  static List<CompletionCandidate> _decodeCandidates(List<dynamic> payload) {
    return payload
        .whereType<Map>()
        .map((raw) {
          final map = raw.map((key, value) => MapEntry('$key', value));
          return CompletionCandidate(
            canonicalTag: map['tag'] as String,
            category:
                TagCategory.fromDanbooru((map['category'] as num).toInt()) ??
                TagCategory.general,
            postCount: (map['postCount'] as num).toInt(),
            matchKind: CompletionMatchKind.values.firstWhere(
              (kind) => kind.name == map['matchKind'],
              orElse: () => CompletionMatchKind.fullText,
            ),
            sources: const {CompletionSourceKind.danbooruApi},
            relatedScore: (map['relatedScore'] as num?)?.toDouble(),
            cooccurrenceCount: (map['cooccurrenceCount'] as num?)?.toInt(),
          );
        })
        .toList(growable: false);
  }

  static List<CompletionCandidate> _extractRelatedCandidates(
    dynamic data,
    int limit,
  ) {
    dynamic values;
    if (data is Map) values = data['related_tags'] ?? data['tags'];
    values ??= data;
    if (values is! List) return const [];

    final candidates = <CompletionCandidate>[];
    for (final item in values) {
      String? name;
      TagCategory category = TagCategory.general;
      var postCount = 0;
      double? relatedScore;
      int? cooccurrenceCount;
      var isDeprecated = false;
      if (item is String) {
        name = item;
      } else if (item is List && item.isNotEmpty && item.first is String) {
        name = item.first as String;
      } else if (item is Map) {
        final tag = item['tag'] is Map ? item['tag'] as Map : item;
        name = tag['name'] as String?;
        final rawCategory = (tag['category'] as num?)?.toInt();
        if (rawCategory != null) {
          final parsed = TagCategory.fromDanbooru(rawCategory);
          if (parsed == null) continue;
          category = parsed;
        }
        postCount = (tag['post_count'] as num?)?.toInt() ?? 0;
        relatedScore =
            (item['jaccard'] as num?)?.toDouble() ??
            (item['score'] as num?)?.toDouble() ??
            (item['similarity'] as num?)?.toDouble() ??
            (item['frequency'] as num?)?.toDouble();
        cooccurrenceCount =
            (item['count'] as num?)?.toInt() ??
            (item['cooccurrence_count'] as num?)?.toInt();
        isDeprecated = tag['is_deprecated'] == true;
      }
      final normalized = name?.trim().toLowerCase() ?? '';
      if (normalized.isEmpty || isDeprecated) continue;
      candidates.add(
        CompletionCandidate(
          canonicalTag: normalized,
          category: category,
          postCount: postCount,
          matchKind: CompletionMatchKind.related,
          sources: const {CompletionSourceKind.danbooruApi},
          relatedScore: relatedScore?.clamp(0.0, 1.0),
          cooccurrenceCount: cooccurrenceCount,
        ),
      );
      if (candidates.length >= limit) break;
    }
    return candidates;
  }
}

class _MemoryEntry {
  const _MemoryEntry(this.candidates, this.storedAt);

  final List<CompletionCandidate> candidates;
  final DateTime storedAt;
}
