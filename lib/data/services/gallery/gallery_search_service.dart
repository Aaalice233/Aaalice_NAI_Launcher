import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';

/// 搜索结果
class SearchResult {
  final List<int> imageIds;
  final int totalCount;
  final Duration searchTime;

  SearchResult({
    required this.imageIds,
    required this.totalCount,
    required this.searchTime,
  });
}

/// 画廊搜索服务
///
/// 封装FTS5全文搜索和结构化查询
class GallerySearchService {
  final GalleryDataSource _dataSource;

  /// 单例实例
  static GallerySearchService? _instance;
  static GallerySearchService get instance {
    _instance ??= GallerySearchService(dataSource: GalleryDataSource());
    return _instance!;
  }

  GallerySearchService({required GalleryDataSource dataSource}) : _dataSource = dataSource;

  /// 全文搜索
  ///
  /// 搜索提示词、负向提示词、模型名称、采样器等
  Future<SearchResult> search(
    String query, {
    int limit = 100,
    int offset = 0,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (query.trim().isEmpty) {
      return SearchResult(
        imageIds: [],
        totalCount: 0,
        searchTime: Duration.zero,
      );
    }

    try {
      final imageIds = await _dataSource.searchFullText(query, limit: limit);

      stopwatch.stop();

      AppLogger.d(
        'Search "$query" returned ${imageIds.length} results in ${stopwatch.elapsedMilliseconds}ms',
        'GallerySearchService',
      );

      return SearchResult(
        imageIds: imageIds,
        totalCount: imageIds.length,
        searchTime: stopwatch.elapsed,
      );
    } catch (e, stack) {
      AppLogger.e('Search failed', e, stack, 'GallerySearchService');
      return SearchResult(
        imageIds: [],
        totalCount: 0,
        searchTime: stopwatch.elapsed,
      );
    }
  }

  /// 高级搜索（结合FTS5和结构化查询）
  Future<List<Map<String, dynamic>>> advancedSearch({
    String? textQuery,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? model,
    String? sampler,
    int? minSteps,
    int? maxSteps,
    double? minCfg,
    double? maxCfg,
    String? resolution,
    bool favoritesOnly = false,
    List<String>? tags,
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at DESC',
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 如果有文本搜索，先用FTS5获取候选ID
      List<int>? candidateIds;
      if (textQuery != null && textQuery.trim().isNotEmpty) {
        candidateIds = await _dataSource.searchFullText(textQuery, limit: 10000);
        if (candidateIds.isEmpty) {
          // FTS5没有匹配结果
          return [];
        }
      }

      // 执行结构化查询
      final images = await _dataSource.queryImages(
        orderBy: orderBy.split(' ').first,
        descending: orderBy.contains('DESC'),
        limit: limit,
        offset: offset,
      );

      final results = images.map((img) => img.toMap()).toList();

      // 如果有候选ID，过滤结果
      if (candidateIds != null) {
        final candidateSet = candidateIds.toSet();
        final filtered = results.where((row) {
          final id = row['id'] as int;
          return candidateSet.contains(id);
        }).toList();

        stopwatch.stop();
        AppLogger.d(
          'Advanced search returned ${filtered.length} results in ${stopwatch.elapsedMilliseconds}ms',
          'GallerySearchService',
        );

        return filtered;
      }

      stopwatch.stop();
      AppLogger.d(
        'Advanced search returned ${results.length} results in ${stopwatch.elapsedMilliseconds}ms',
        'GallerySearchService',
      );

      return results;
    } catch (e, stack) {
      AppLogger.e('Advanced search failed', e, stack, 'GallerySearchService');
      return [];
    }
  }

  /// 搜索建议（自动补全）
  Future<List<String>> getSuggestions(String prefix, {int limit = 10}) async {
    if (prefix.trim().isEmpty) return [];

    try {
      // 从模型名称中搜索
      final models = await _dataSource.getModelDistribution();
      final modelSuggestions = models
          .where(
            (m) =>
                (m['model'] as String?)
                    ?.toLowerCase()
                    .contains(prefix.toLowerCase()) ??
                false,
          )
          .take(limit ~/ 2)
          .map((m) => m['model'] as String)
          .toList();

      // 从采样器名称中搜索
      final samplers = await _dataSource.getSamplerDistribution();
      final samplerSuggestions = samplers
          .where(
            (s) =>
                (s['sampler'] as String?)
                    ?.toLowerCase()
                    .contains(prefix.toLowerCase()) ??
                false,
          )
          .take(limit ~/ 2)
          .map((s) => s['sampler'] as String)
          .toList();

      return [...modelSuggestions, ...samplerSuggestions];
    } catch (e) {
      return [];
    }
  }

  /// 获取热门搜索词
  Future<List<Map<String, dynamic>>> getPopularTerms({int limit = 20}) async {
    try {
      // 返回模型和采样器的使用频率
      final models = await _dataSource.getModelDistribution();
      final samplers = await _dataSource.getSamplerDistribution();

      final terms = <Map<String, dynamic>>[];

      for (final m in models.take(limit ~/ 2)) {
        terms.add({
          'term': m['model'],
          'count': m['count'],
          'type': 'model',
        });
      }

      for (final s in samplers.take(limit ~/ 2)) {
        terms.add({
          'term': s['sampler'],
          'count': s['count'],
          'type': 'sampler',
        });
      }

      // 按使用频率排序
      terms.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return terms.take(limit).toList();
    } catch (e) {
      return [];
    }
  }
}
