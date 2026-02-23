import '../../utils/app_logger.dart';
import '../datasources/cooccurrence_data_source.dart';

/// 推荐结果
class Recommendation {
  final String tag;
  final int count;
  final double score;
  final String? translation;

  const Recommendation({
    required this.tag,
    required this.count,
    this.score = 0.0,
    this.translation,
  });

  /// 格式化计数显示
  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// 共现服务
///
/// 提供标签共现关系分析和推荐功能的高级服务层。
/// 基于预打包的 CooccurrenceDataSource，支持获取相关标签推荐。
///
/// V2 简化版：移除所有 CSV 导入逻辑，直接使用预打包数据库。
class CooccurrenceService {
  final CooccurrenceDataSource _dataSource;

  bool _isLoaded = false;
  bool _hasData = false;

  CooccurrenceService(this._dataSource);

  /// 数据是否已加载
  bool get isLoaded => _isLoaded;

  /// 是否有数据
  bool get hasData => _hasData;

  /// 初始化服务
  ///
  /// 验证数据源可用性，在预热阶段调用
  Future<bool> initialize() async {
    AppLogger.i('Initializing cooccurrence service...', 'Cooccurrence');
    final stopwatch = Stopwatch()..start();

    try {
      // 验证数据源已初始化
      if (!_dataSource.isInitialized) {
        await _dataSource.initialize();
      }

      // 获取记录数验证数据存在
      final count = await _dataSource.getCount();
      _hasData = count > 0;
      _isLoaded = true;

      stopwatch.stop();
      AppLogger.i(
        'Cooccurrence service initialized: $count records in ${stopwatch.elapsedMilliseconds}ms',
        'Cooccurrence',
      );

      return _hasData;
    } catch (e, stack) {
      AppLogger.e('Cooccurrence service initialization failed', e, stack, 'Cooccurrence');
      _isLoaded = true;
      _hasData = false;
      return false;
    }
  }

  /// 获取标签推荐
  ///
  /// 根据已选标签列表，返回推荐的相关标签。
  /// 推荐基于共现频率和共现分数计算。
  ///
  /// [selectedTags] 已选标签列表
  /// [limit] 返回结果数量限制
  /// [minCount] 最小共现次数过滤
  Future<List<Recommendation>> getRecommendations(
    List<String> selectedTags, {
    int limit = 10,
    int minCount = 1,
  }) async {
    if (selectedTags.isEmpty) {
      return [];
    }

    try {
      final results = await _processRecommendations(
        selectedTags,
        limit: limit,
        minCount: minCount,
      );

      AppLogger.d(
        'Got ${results.length} recommendations for ${selectedTags.length} tags',
        'CooccurrenceService',
      );

      return results;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get recommendations',
        e,
        stack,
        'CooccurrenceService',
      );
      return [];
    }
  }

  /// 获取单个标签的相关标签
  ///
  /// [tag] 查询的标签
  /// [limit] 返回结果数量限制
  /// [minCount] 最小共现次数过滤
  Future<List<Recommendation>> getRelatedTags(
    String tag, {
    int limit = 20,
    int minCount = 1,
  }) async {
    if (tag.isEmpty) {
      return [];
    }

    try {
      final relatedTags = await _dataSource.getRelatedTags(
        tag,
        limit: limit,
        minCount: minCount,
      );

      final recommendations = relatedTags
          .map(
            (r) => Recommendation(
              tag: r.tag,
              count: r.count,
              score: r.cooccurrenceScore,
            ),
          )
          .toList();

      AppLogger.d(
        'Got ${recommendations.length} related tags for "$tag"',
        'CooccurrenceService',
      );

      return recommendations;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get related tags for "$tag"',
        e,
        stack,
        'CooccurrenceService',
      );
      return [];
    }
  }

  /// 获取热门共现标签
  ///
  /// [limit] 返回结果数量限制
  Future<List<Recommendation>> getPopularCooccurrences({int limit = 100}) async {
    try {
      final popularTags = await _dataSource.getPopularCooccurrences(limit: limit);

      final recommendations = popularTags
          .map(
            (r) => Recommendation(
              tag: r.tag,
              count: r.count,
              score: r.cooccurrenceScore,
            ),
          )
          .toList();

      AppLogger.d(
        'Got ${recommendations.length} popular cooccurrences',
        'CooccurrenceService',
      );

      return recommendations;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get popular cooccurrences',
        e,
        stack,
        'CooccurrenceService',
      );
      return [];
    }
  }

  /// 计算两个标签的共现分数
  ///
  /// 使用 Jaccard 相似度系数
  Future<double> calculateCooccurrenceScore(String tag1, String tag2) async {
    if (tag1.isEmpty || tag2.isEmpty) {
      return 0.0;
    }

    try {
      final score = await _dataSource.calculateCooccurrenceScore(tag1, tag2);
      return score;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to calculate cooccurrence score',
        e,
        stack,
        'CooccurrenceService',
      );
      return 0.0;
    }
  }

  /// 获取共现记录总数
  Future<int> getCount() async {
    try {
      return await _dataSource.getCount();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get cooccurrence count',
        e,
        stack,
        'CooccurrenceService',
      );
      return 0;
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() {
    return _dataSource.getCacheStatistics();
  }

  // 私有辅助方法

  /// 处理推荐结果
  ///
  /// 当选择多个标签时，综合计算推荐结果
  Future<List<Recommendation>> _processRecommendations(
    List<String> selectedTags, {
    required int limit,
    required int minCount,
  }) async {
    if (selectedTags.length == 1) {
      // 单个标签，直接查询
      return getRelatedTags(
        selectedTags.first,
        limit: limit,
        minCount: minCount,
      );
    }

    // 多个标签，批量获取并合并结果
    final normalizedTags =
        selectedTags.map((t) => t.toLowerCase().trim()).toList();
    final batchResults = await _dataSource.getRelatedTagsBatch(
      normalizedTags,
      limit: limit * 2, // 获取更多以便合并
    );

    // 合并并去重
    final mergedScores = <String, _RecommendationScore>{};

    for (final tag in normalizedTags) {
      final related = batchResults[tag] ?? [];
      for (final r in related) {
        // 跳过已在选中列表中的标签
        if (normalizedTags.contains(r.tag)) {
          continue;
        }

        final existing = mergedScores[r.tag];
        if (existing == null) {
          mergedScores[r.tag] = _RecommendationScore(
            tag: r.tag,
            count: r.count,
            score: r.cooccurrenceScore,
            sourceCount: 1,
          );
        } else {
          // 累加分数和计数
          mergedScores[r.tag] = _RecommendationScore(
            tag: r.tag,
            count: existing.count + r.count,
            score: existing.score + r.cooccurrenceScore,
            sourceCount: existing.sourceCount + 1,
          );
        }
      }
    }

    // 转换为 Recommendation 并排序
    final recommendations = mergedScores.values
        .where((s) => s.count >= minCount)
        .map(
          (s) => Recommendation(
            tag: s.tag,
            count: s.count ~/ s.sourceCount, // 平均计数
            score: s.score / s.sourceCount, // 平均分数
          ),
        )
        .toList();

    // 按分数降序排序
    recommendations.sort((a, b) => b.score.compareTo(a.score));

    return recommendations.take(limit).toList();
  }
}

/// 内部使用的推荐分数计算类
class _RecommendationScore {
  final String tag;
  final int count;
  final double score;
  final int sourceCount;

  _RecommendationScore({
    required this.tag,
    required this.count,
    required this.score,
    required this.sourceCount,
  });
}
