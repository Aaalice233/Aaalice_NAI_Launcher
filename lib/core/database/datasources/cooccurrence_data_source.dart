import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../utils/app_logger.dart';
import '../asset_database_manager.dart';
import '../data_source.dart';

/// 相关标签记录
class RelatedTag {
  final String tag;
  final int count;
  final double cooccurrenceScore;

  const RelatedTag({
    required this.tag,
    required this.count,
    this.cooccurrenceScore = 0.0,
  });

  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// 共现记录
class CooccurrenceRecord {
  final String tag1;
  final String tag2;
  final int count;
  final double cooccurrenceScore;

  const CooccurrenceRecord({
    required this.tag1,
    required this.tag2,
    required this.count,
    required this.cooccurrenceScore,
  });
}

/// 共现数据源（V2 - 使用预打包数据库）
///
/// 从预打包的 SQLite 数据库读取共现数据，不再支持写入。
/// 使用内存缓存热点查询结果。
class CooccurrenceDataSource {
  static const int _maxCacheSize = 1000;

  // 缓存相关标签查询结果
  final Map<String, List<RelatedTag>> _relatedCache = {};

  Database? _db;
  bool _initialized = false;

  /// 数据源名称
  String get name => 'cooccurrence';

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 初始化数据源
  ///
  /// 打开预打包的共现数据库（只读）
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.i('Initializing CooccurrenceDataSource...', 'CooccurrenceDS');

    try {
      _db = await AssetDatabaseManager.instance.openCooccurrenceDatabase();
      _initialized = true;

      // 验证数据
      final count = await getCount();
      AppLogger.i('Cooccurrence data source initialized with $count records', 'CooccurrenceDS');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize CooccurrenceDataSource', e, stack, 'CooccurrenceDS');
      rethrow;
    }
  }

  /// 获取与指定标签共现的相关标签
  ///
  /// [tag] 查询的标签
  /// [limit] 返回结果数量限制
  /// [minCount] 最小共现次数过滤
  Future<List<RelatedTag>> getRelatedTags(
    String tag, {
    int limit = 20,
    int minCount = 1,
  }) async {
    if (tag.isEmpty) return [];
    if (!_initialized) await initialize();

    final normalizedTag = tag.toLowerCase().trim();

    // 检查缓存
    final cached = _relatedCache[normalizedTag];
    if (cached != null) {
      AppLogger.d('Cooccurrence cache hit: $normalizedTag', 'CooccurrenceDS');
      return cached
          .where((r) => r.count >= minCount)
          .take(limit)
          .toList();
    }

    final results = await _db!.query(
      'cooccurrences',
      columns: ['tag2', 'count', 'cooccurrence_score'],
      where: 'tag1 = ? AND count >= ?',
      whereArgs: [normalizedTag, minCount],
      orderBy: 'count DESC',
      limit: limit,
    );

    final relatedTags = results.map<RelatedTag>((row) {
      return RelatedTag(
        tag: row['tag2'] as String,
        count: (row['count'] as num?)?.toInt() ?? 0,
        cooccurrenceScore: (row['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    // 添加到缓存
    _addToCache(normalizedTag, relatedTags);

    return relatedTags;
  }

  /// 批量获取相关标签
  ///
  /// [tags] 标签列表
  /// [limit] 每个标签返回的相关标签数量
  Future<Map<String, List<RelatedTag>>> getRelatedTagsBatch(
    List<String> tags, {
    int limit = 10,
  }) async {
    if (tags.isEmpty) return {};
    if (!_initialized) await initialize();

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');

    final result = <String, List<RelatedTag>>{};

    final rows = await _db!.rawQuery(
      'SELECT tag1, tag2, count, cooccurrence_score '
      'FROM cooccurrences '
      'WHERE tag1 IN ($placeholders) '
      'ORDER BY tag1, count DESC',
      normalizedTags,
    );

    // 按 tag1 分组
    final groups = <String, List<RelatedTag>>{};
    for (final row in rows) {
      final tag1 = row['tag1'] as String;
      groups.putIfAbsent(tag1, () => []).add(
        RelatedTag(
          tag: row['tag2'] as String,
          count: (row['count'] as num?)?.toInt() ?? 0,
          cooccurrenceScore: (row['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    // 限制每个标签的结果数量并填充结果
    for (final tag in normalizedTags) {
      final related = groups[tag] ?? [];
      result[tag] = related.take(limit).toList();

      // 更新缓存
      if (related.isNotEmpty) {
        _addToCache(tag, related);
      }
    }

    return result;
  }

  /// 获取热门共现标签
  ///
  /// [limit] 返回结果数量限制
  Future<List<RelatedTag>> getPopularCooccurrences({int limit = 100}) async {
    if (limit <= 0) return [];
    if (!_initialized) await initialize();

    final results = await _db!.query(
      'cooccurrences',
      columns: ['tag1', 'tag2', 'count', 'cooccurrence_score'],
      orderBy: 'count DESC',
      limit: limit,
    );

    return results.map<RelatedTag>((row) {
      return RelatedTag(
        tag: '${row['tag1']} → ${row['tag2']}',
        count: (row['count'] as num?)?.toInt() ?? 0,
        cooccurrenceScore: (row['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  /// 计算共现分数
  ///
  /// 使用 Jaccard 相似度系数
  /// Jaccard(A, B) = |A ∩ B| / |A ∪ B|
  Future<double> calculateCooccurrenceScore(
    String tag1,
    String tag2,
  ) async {
    final t1 = tag1.toLowerCase().trim();
    final t2 = tag2.toLowerCase().trim();
    if (t1.isEmpty || t2.isEmpty) return 0.0;
    if (!_initialized) await initialize();

    final result = await _db!.query(
      'cooccurrences',
      columns: ['count'],
      where: '(tag1 = ? AND tag2 = ?) OR (tag1 = ? AND tag2 = ?)',
      whereArgs: [t1, t2, t2, t1],
      limit: 1,
    );

    if (result.isEmpty) return 0.0;

    final cooccurrence = (result.first['count'] as num?)?.toInt() ?? 0;

    // 获取两个标签的独立计数（近似值，从共现表中获取）
    final count1Result = await _db!.rawQuery(
      'SELECT SUM(count) as total FROM cooccurrences WHERE tag1 = ?',
      [t1],
    );
    final count2Result = await _db!.rawQuery(
      'SELECT SUM(count) as total FROM cooccurrences WHERE tag1 = ?',
      [t2],
    );

    final count1 = (count1Result.first['total'] as num?)?.toInt() ?? 0;
    final count2 = (count2Result.first['total'] as num?)?.toInt() ?? 0;

    // Jaccard = cooccurrence / (count1 + count2 - cooccurrence)
    final union = count1 + count2 - cooccurrence;
    if (union <= 0) return 0.0;

    return cooccurrence / union;
  }

  /// 获取共现记录总数
  Future<int> getCount() async {
    if (!_initialized) await initialize();

    final result = await _db!.rawQuery('SELECT COUNT(*) as count FROM cooccurrences');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// 获取与指定标签相关的唯一标签数量
  Future<int> getRelatedTagCount(String tag) async {
    if (tag.isEmpty) return 0;
    if (!_initialized) await initialize();

    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM cooccurrences WHERE tag1 = ?',
      [tag.toLowerCase().trim()],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// 健康检查
  Future<DataSourceHealth> checkHealth() async {
    try {
      if (!_initialized) {
        return DataSourceHealth(
          status: HealthStatus.corrupted,
          message: 'Cooccurrence data source not initialized',
          timestamp: DateTime.now(),
        );
      }

      // 尝试查询
      await _db!.rawQuery('SELECT 1 FROM cooccurrences LIMIT 1');
      final count = await getCount();

      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'Cooccurrence data source is healthy',
        details: {
          'recordCount': count,
          'cacheSize': _relatedCache.length,
        },
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return DataSourceHealth(
        status: HealthStatus.corrupted,
        message: 'Health check failed: $e',
        details: {'error': e.toString()},
        timestamp: DateTime.now(),
      );
    }
  }

  /// 清除缓存
  Future<void> clear() async {
    _relatedCache.clear();
    AppLogger.i('Cooccurrence cache cleared', 'CooccurrenceDS');
  }

  /// 释放资源
  Future<void> dispose() async {
    _relatedCache.clear();
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _initialized = false;
    AppLogger.i('Cooccurrence data source disposed', 'CooccurrenceDS');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() => {
        'cacheSize': _relatedCache.length,
        'maxCacheSize': _maxCacheSize,
      };

  // 私有辅助方法

  void _addToCache(String key, List<RelatedTag> value) {
    if (_relatedCache.length >= _maxCacheSize) {
      // 移除最旧的条目
      _relatedCache.remove(_relatedCache.keys.first);
    }
    _relatedCache[key] = value;
  }
}


