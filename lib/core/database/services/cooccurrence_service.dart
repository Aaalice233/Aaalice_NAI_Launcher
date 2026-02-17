import '../../utils/app_logger.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/storage_keys.dart';
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

/// 自动刷新间隔枚举
enum AutoRefreshInterval {
  always(0),
  hours24(1),
  days7(7),
  days30(30),
  never(-1);

  final int days;
  const AutoRefreshInterval(this.days);

  static AutoRefreshInterval fromDays(int days) {
    return switch (days) {
      0 => AutoRefreshInterval.always,
      1 => AutoRefreshInterval.hours24,
      7 => AutoRefreshInterval.days7,
      30 => AutoRefreshInterval.days30,
      _ => AutoRefreshInterval.never,
    };
  }

  bool shouldRefresh(DateTime? lastUpdate) {
    if (days < 0) return false; // never
    if (lastUpdate == null) return true; // always if never updated
    final elapsed = DateTime.now().difference(lastUpdate).inDays;
    return elapsed >= days;
  }
}

/// 共现服务
///
/// 提供标签共现关系分析和推荐功能的高级服务层。
/// 基于 CooccurrenceDataSource，支持获取相关标签推荐。
class CooccurrenceService {
  final CooccurrenceDataSource _dataSource;

  bool _isLoaded = false;
  bool _hasData = false;
  DateTime? _lastUpdate;
  final AutoRefreshInterval _refreshInterval = AutoRefreshInterval.days30;

  CooccurrenceService(this._dataSource) {
    // 构造函数中异步加载 meta
    _loadMeta();
  }
  
  /// 数据是否已加载
  bool get isLoaded => _isLoaded;
  
  /// 是否有数据
  bool get hasData => _hasData;
  
  /// 上次更新时间
  DateTime? get lastUpdate => _lastUpdate;
  
  /// 刷新间隔
  AutoRefreshInterval get refreshInterval => _refreshInterval;
  
  /// 统一的初始化流程
  ///
  /// 返回: true 表示数据已就绪，false 表示需要后台导入
  Future<bool> initializeUnified() async {
    AppLogger.i('Initializing cooccurrence (unified)...', 'Cooccurrence');
    final stopwatch = Stopwatch()..start();

    try {
      // 确保 meta 已加载
      await _loadMeta();

      // 检查数据是否已存在
      final count = await _dataSource.getCount();

      if (count > 0) {
        _isLoaded = true;
        _hasData = true;
        // 如果没有记录更新时间，使用当前时间
        if (_lastUpdate == null) {
          _lastUpdate = DateTime.now();
          await _saveMeta(count);
        }
        stopwatch.stop();
        AppLogger.i(
          'Cooccurrence data up to date ($count records, lastUpdate: $_lastUpdate) in ${stopwatch.elapsedMilliseconds}ms',
          'Cooccurrence',
        );
        return true;
      }

      // 数据库为空，需要首次导入
      AppLogger.i('Cooccurrence database empty, needs initial import', 'Cooccurrence');
      _isLoaded = true;
      _hasData = false;
      return false;
    } catch (e, stack) {
      AppLogger.e('Cooccurrence unified init failed', e, stack, 'Cooccurrence');
      _isLoaded = true;
      return false;
    }
  }
  
  /// 检查是否需要刷新数据
  Future<bool> shouldRefresh() async {
    return _refreshInterval.shouldRefresh(_lastUpdate);
  }
  
  /// 执行后台导入
  ///
  /// [onProgress] 进度回调 (progress: 0.0-1.0, message: 状态消息)
  Future<void> performBackgroundImport({
    void Function(double progress, String message)? onProgress,
  }) async {
    try {
      // 后台导入使用增量模式（不清空预构建数据库中的数据）
      final imported = await importCsvToSQLite(
        onProgress: onProgress,
        incremental: true,
      );

      if (imported > 0) {
        _isLoaded = true;
        _hasData = true;
        _lastUpdate = DateTime.now();
        await _saveMeta(imported);
        AppLogger.i('Cooccurrence background import completed', 'Cooccurrence');
      }
    } catch (e, stack) {
      AppLogger.e('Background import failed', e, stack, 'Cooccurrence');
    }
  }

  /// 加载元数据（上次更新时间等）
  Future<void> _loadMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateMillis = prefs.getInt(StorageKeys.cooccurrenceLastUpdate);
      if (lastUpdateMillis != null) {
        _lastUpdate = DateTime.fromMillisecondsSinceEpoch(lastUpdateMillis);
        AppLogger.i('Cooccurrence meta loaded: lastUpdate=$_lastUpdate', 'Cooccurrence');
      }
    } catch (e) {
      AppLogger.w('Failed to load cooccurrence meta: $e', 'Cooccurrence');
    }
  }

  /// 保存元数据
  Future<void> _saveMeta(int totalRecords) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setInt(StorageKeys.cooccurrenceLastUpdate, now.millisecondsSinceEpoch);
      _lastUpdate = now;
      AppLogger.i('Cooccurrence meta saved: lastUpdate=$now, records=$totalRecords', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to save cooccurrence meta: $e', 'Cooccurrence');
    }
  }

  /// 清除元数据（用于重置缓存状态）
  Future<void> clearMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.cooccurrenceLastUpdate);
      _lastUpdate = null;
      AppLogger.i('Cooccurrence meta cleared', 'Cooccurrence');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrence meta: $e', 'Cooccurrence');
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

  /// 将 Assets 中的 CSV 导入 SQLite
  ///
  /// 从 `assets/translations/hf_danbooru_cooccurrence.csv` 读取数据并导入。
  /// 使用批量插入以获得最佳性能。
  ///
  /// [onProgress] 进度回调 (progress: 0.0-1.0, message: 状态消息)
  /// [incremental] 是否为增量导入（不清空已有数据）
  /// 返回导入的记录数，-1 表示失败
  Future<int> importCsvToSQLite({
    void Function(double progress, String message)? onProgress,
    bool incremental = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    onProgress?.call(0.0, '读取 CSV 文件...');

    try {
      // 1. 读取 CSV 内容
      final csvContent = await rootBundle.loadString(
        'assets/translations/hf_danbooru_cooccurrence.csv',
      );

      onProgress?.call(0.1, '读取共现标签数据...');

      // 2. 委托给数据源执行导入
      final importedCount = await _dataSource.importFromCsv(
        csvContent,
        onProgress: (progress, message) {
          // 调整进度范围: 0.1-1.0
          onProgress?.call(0.1 + progress * 0.9, message);
        },
        incremental: incremental,
      );

      stopwatch.stop();
      AppLogger.i(
        'Cooccurrence CSV imported: $importedCount records in ${stopwatch.elapsedMilliseconds}ms',
        'CooccurrenceService',
      );

      return importedCount;
    } catch (e, stack) {
      AppLogger.e('Failed to import CSV to SQLite', e, stack, 'CooccurrenceService');
      onProgress?.call(1.0, '共现标签数据导入失败');
      return -1;
    }
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
