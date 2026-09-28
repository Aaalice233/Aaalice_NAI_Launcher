import 'dart:async';

import 'package:dio/dio.dart';

import '../../data/models/tag/local_tag.dart';
import '../database/datasources/danbooru_tag_data_source.dart';
import '../utils/app_logger.dart';
import 'danbooru_tags_protocol.dart';

class DanbooruTagsRefreshService {
  DanbooruTagsRefreshService({
    required Dio dio,
    required DanbooruTagDataSource tagDataSource,
    required DanbooruTagsState state,
  }) : _dio = dio,
       _tagDataSource = tagDataSource,
       _state = state;

  final Dio _dio;
  final DanbooruTagDataSource _tagDataSource;
  final DanbooruTagsState _state;
  final DanbooruRefreshGenerationOwner _generations =
      DanbooruRefreshGenerationOwner();

  void cancel() => _generations.cancel();

  Future<int> refreshAll() async {
    final generation = _generations.begin();
    final thresholds = _state.thresholds;
    final tags = <LocalTag>[];
    tags.addAll(
      await _fetchCategory(
        generation: generation,
        category: 0,
        threshold: thresholds.general,
        maxPages: danbooruTagsMaxPages,
        label: '一般标签',
      ),
    );
    tags.addAll(
      await _fetchCategory(
        generation: generation,
        category: 1,
        threshold: thresholds.artist,
        maxPages: danbooruTagsMaxPages,
        label: '画师标签',
      ),
    );
    tags.addAll(
      await _fetchCategory(
        generation: generation,
        category: 4,
        threshold: thresholds.character,
        maxPages: danbooruTagsMaxPages,
        label: '角色标签',
      ),
    );
    tags.addAll(
      await _fetchCategory(
        generation: generation,
        category: 3,
        threshold: thresholds.copyright,
        maxPages: danbooruTagsMaxPages,
        label: '版权标签',
      ),
    );
    tags.addAll(
      await _fetchCategory(
        generation: generation,
        category: 5,
        threshold: thresholds.meta,
        maxPages: danbooruTagsMaxPages,
        label: '元标签',
      ),
    );
    generation.throwIfCancelled();
    if (tags.isEmpty) throw StateError('未拉取到任何标签');
    _state.onProgress?.call(0.95, '导入数据库...');
    await _write(tags, generation);
    return tags.length;
  }

  Future<int> fetchCategory({
    required int category,
    required int threshold,
    required int maxPages,
    required String label,
  }) async {
    final generation = _generations.begin();
    final tags = await _fetchCategory(
      generation: generation,
      category: category,
      threshold: threshold,
      maxPages: maxPages,
      label: label,
    );
    generation.throwIfCancelled();
    if (tags.isNotEmpty) await _write(tags, generation);
    return tags.length;
  }

  Future<void> fetchArtist({
    required int threshold,
    required int maxPages,
    required void Function(int currentPage, int importedCount, String message)
    onProgress,
  }) async {
    final generation = _generations.begin();
    var page = 1;
    var imported = 0;
    final buffered = <LocalTag>[];
    while (page <= maxPages) {
      generation.throwIfCancelled();
      final batchSize = _batchSize(page, maxPages);
      final results = await Future.wait(
        List.generate(
          batchSize,
          (index) => _fetchPage(
            generation: generation,
            page: page + index,
            category: 1,
            minPostCount: threshold,
            trustRequestedCategory: false,
            hideEmpty: false,
          ),
        ),
      );
      generation.throwIfCancelled();
      if (results.every((result) => result == null || result.isEmpty)) break;
      for (final result in results) {
        if (result != null) buffered.addAll(result);
      }
      if (buffered.length >= 2000) {
        await _write(buffered, generation);
        imported += buffered.length;
        buffered.clear();
        onProgress(
          page + batchSize - 1,
          imported,
          '第 ${page + batchSize - 1} 页，已导入 $imported 条',
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      page += batchSize;
      if (page <= maxPages) {
        await Future<void>.delayed(danbooruTagsRequestInterval);
      }
    }
    generation.throwIfCancelled();
    if (buffered.isNotEmpty) {
      await _write(buffered, generation);
      imported += buffered.length;
    }
    onProgress(page - 1, imported, '画师标签导入完成，共 $imported 条');
  }

  Future<List<LocalTag>> _fetchCategory({
    required DanbooruRefreshGeneration generation,
    required int category,
    required int threshold,
    required int maxPages,
    required String label,
  }) async {
    final tags = <LocalTag>[];
    var page = 1;
    var consecutiveEmpty = 0;
    while (page <= maxPages) {
      generation.throwIfCancelled();
      final batchSize = _batchSize(page, maxPages);
      final results = await Future.wait(
        List.generate(
          batchSize,
          (index) => _fetchPage(
            generation: generation,
            page: page + index,
            category: category,
            minPostCount: threshold,
            trustRequestedCategory: true,
            hideEmpty: true,
          ),
        ),
      );
      generation.throwIfCancelled();
      var hasData = false;
      var reachedEnd = false;
      for (final result in results) {
        if (result == null) throw StateError('$label 下载失败');
        if (result.isEmpty) {
          consecutiveEmpty++;
          if (consecutiveEmpty >= 2) reachedEnd = true;
        } else {
          consecutiveEmpty = 0;
          hasData = true;
          tags.addAll(result);
        }
      }
      _state.onProgress?.call(0, '$label: 已拉取 ${tags.length} 条');
      if (reachedEnd) break;
      page += batchSize;
      if (page <= maxPages && hasData) {
        await Future<void>.delayed(danbooruTagsRequestInterval);
      }
    }
    generation.throwIfCancelled();
    AppLogger.i(
      'Fetched ${tags.length} $label with threshold >= $threshold',
      'DanbooruTagsLazy',
    );
    return tags;
  }

  Future<List<LocalTag>?> _fetchPage({
    required DanbooruRefreshGeneration generation,
    required int page,
    required int category,
    required int minPostCount,
    required bool trustRequestedCategory,
    required bool hideEmpty,
    int maxRetries = 3,
  }) async {
    var retries = 0;
    while (retries <= maxRetries) {
      generation.throwIfCancelled();
      try {
        final parameters = <String, dynamic>{
          'search[order]': 'count',
          if (hideEmpty) 'search[hide_empty]': 'true',
          'search[category]': '$category',
          'limit': danbooruTagsPageSize,
          'page': page,
          if (minPostCount > 0) 'search[post_count]': '>=$minPostCount',
        };
        final response = await _dio.get(
          '$danbooruTagsBaseUrl$danbooruTagsEndpoint',
          queryParameters: parameters,
          options: Options(
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 10),
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'NAI-Launcher/1.0',
            },
          ),
        );
        generation.throwIfCancelled();
        final data = response.data;
        if (data is! List) return [];
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) {
              return LocalTag(
                tag: (item['name'] as String?)?.toLowerCase() ?? '',
                category: trustRequestedCategory
                    ? category
                    : item['category'] as int? ?? category,
                count: item['post_count'] as int? ?? 0,
              );
            })
            .where((tag) => tag.tag.isNotEmpty)
            .toList();
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) return [];
        if (error.response?.statusCode == 429 && retries < maxRetries) {
          retries++;
          await Future<void>.delayed(
            Duration(milliseconds: 1000 * (1 << retries)),
          );
          continue;
        }
        AppLogger.w(
          'Failed to fetch category $category page $page: $error',
          'DanbooruTagsLazy',
        );
        return null;
      } on DanbooruRefreshCancelledException {
        rethrow;
      } catch (error) {
        AppLogger.w(
          'Failed to fetch category $category page $page: $error',
          'DanbooruTagsLazy',
        );
        return null;
      }
    }
    return null;
  }

  int _batchSize(int page, int maxPages) {
    final remaining = maxPages - page + 1;
    return remaining < danbooruTagsConcurrentRequests
        ? remaining
        : danbooruTagsConcurrentRequests;
  }

  Future<void> _write(
    Iterable<LocalTag> tags,
    DanbooruRefreshGeneration generation,
  ) async {
    generation.throwIfCancelled();
    final updatedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _tagDataSource.upsertBatch(
      tags
          .map(
            (tag) => DanbooruTagRecord(
              tag: tag.tag,
              category: tag.category,
              postCount: tag.count,
              lastUpdated: updatedAt,
            ),
          )
          .toList(),
    );
    generation.throwIfCancelled();
  }
}
