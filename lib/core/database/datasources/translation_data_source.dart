import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../utils/app_logger.dart';
import '../asset_database_manager.dart';
import '../data_source.dart';
import '../utils/lru_cache.dart';

/// 翻译记录
class TranslationRecord {
  final String enTag;
  final String zhTranslation;
  final String source;
  final int? lastAccessed;

  const TranslationRecord({
    required this.enTag,
    required this.zhTranslation,
    this.source = 'unknown',
    this.lastAccessed,
  });
}

/// 翻译匹配结果
class TranslationMatch {
  final String tag;
  final String translation;
  final int score;

  const TranslationMatch({
    required this.tag,
    required this.translation,
    required this.score,
  });
}

/// 翻译数据源（V2 - 使用预打包数据库）
///
/// 从预打包的 SQLite 数据库读取翻译数据，不再支持写入。
/// 使用 LRU 缓存策略，最大缓存 2000 条翻译记录。
class TranslationDataSource {
  static const int _maxCacheSize = 2000;
  
  final LRUCache<String, String> _cache = LRUCache(maxSize: _maxCacheSize);
  
  Database? _db;
  bool _initialized = false;

  /// 数据源名称
  String get name => 'translation';

  /// 初始化数据源
  ///
  /// 打开预打包的翻译数据库（只读）
  Future<void> initialize() async {
    if (_initialized) return;
    
    AppLogger.i('Initializing TranslationDataSource...', 'TranslationDS');
    
    try {
      _db = await AssetDatabaseManager.instance.openTranslationDatabase();
      _initialized = true;
      
      // 验证数据
      final count = await getCount();
      AppLogger.i('Translation data source initialized with $count records', 'TranslationDS');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize TranslationDataSource', e, stack, 'TranslationDS');
      rethrow;
    }
  }

  /// 查询单个翻译
  ///
  /// 1. 检查 LRU 缓存
  /// 2. 查询数据库
  /// 3. 写入缓存
  Future<String?> query(String enTag) async {
    if (enTag.isEmpty) return null;
    if (!_initialized) await initialize();

    final normalizedTag = enTag.toLowerCase().trim();

    // 1. 检查缓存
    final cached = _cache.get(normalizedTag);
    if (cached != null) {
      AppLogger.d('Translation cache hit: $normalizedTag', 'TranslationDS');
      return cached;
    }

    // 2. 查询数据库（预打包数据库使用 tags + translations 表结构）
    final translation = await _queryFromDb(normalizedTag);

    // 3. 写入缓存
    if (translation != null) {
      _cache.put(normalizedTag, translation);
    }

    return translation;
  }

  /// 批量查询翻译
  ///
  /// 优先从缓存获取，缓存未命中则查询数据库
  Future<Map<String, String>> queryBatch(List<String> enTags) async {
    // 空列表直接返回空结果，无需初始化
    if (enTags.isEmpty) return {};
    if (!_initialized) await initialize();
    
    final result = <String, String>{};
    final missingTags = <String>[];

    // 1. 从缓存获取
    for (final tag in enTags) {
      final normalizedTag = tag.toLowerCase().trim();
      final cached = _cache.get(normalizedTag);
      if (cached != null) {
        result[normalizedTag] = cached;
      } else {
        missingTags.add(normalizedTag);
      }
    }

    // 2. 查询缺失的标签
    if (missingTags.isNotEmpty) {
      final dbResults = await _queryBatchFromDb(missingTags);
      result.addAll(dbResults);

      // 3. 写入缓存
      for (final entry in dbResults.entries) {
        _cache.put(entry.key, entry.value);
      }
    }

    return result;
  }

  /// 搜索翻译（支持部分匹配）
  ///
  /// [query] 搜索关键词
  /// [limit] 返回结果数量限制
  /// [matchTag] 是否匹配标签名
  /// [matchTranslation] 是否匹配翻译文本
  Future<List<TranslationMatch>> search(
    String query, {
    int limit = 20,
    bool matchTag = true,
    bool matchTranslation = true,
  }) async {
    if (query.isEmpty) return [];
    if (!_initialized) await initialize();

    final results = <TranslationMatch>[];
    final lowerQuery = query.toLowerCase();

    // 从 tags 表和 translations 表联合查询
    if (matchTag) {
      final tagResults = await _db!.rawQuery(
        '''
        SELECT t.name as tag, tr.translation 
        FROM tags t 
        LEFT JOIN translations tr ON t.id = tr.tag_id AND tr.language = 'zh'
        WHERE t.name LIKE ? 
        ORDER BY t.count DESC 
        LIMIT ?
        ''',
        ['%$lowerQuery%', limit],
      );

      for (final row in tagResults) {
        results.add(TranslationMatch(
          tag: row['tag'] as String,
          translation: (row['translation'] ?? '') as String,
          score: _calculateMatchScore(row['tag'] as String, lowerQuery, isTagMatch: true),
        ),);
      }
    }

    if (matchTranslation) {
      final transResults = await _db!.rawQuery(
        '''
        SELECT t.name as tag, tr.translation
        FROM tags t
        JOIN translations tr ON t.id = tr.tag_id
        WHERE tr.language = 'zh' AND tr.translation LIKE ?
        ORDER BY t.count DESC
        LIMIT ?
        ''',
        ['%$query%', limit],
      );

      for (final row in transResults) {
        final tag = row['tag'] as String;
        // 避免重复
        if (!results.any((r) => r.tag == tag)) {
          results.add(TranslationMatch(
            tag: tag,
            translation: row['translation'] as String,
            score: _calculateMatchScore(row['translation'] as String, query, isTagMatch: false),
          ),);
        }
      }
    }

    // 按相关度排序
    results.sort((a, b) => b.score.compareTo(a.score));

    return results.take(limit).toList();
  }

  /// 获取翻译总数
  Future<int> getCount() async {
    if (!_initialized) await initialize();
    
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM translations WHERE language = ?',
      ['zh'],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// 获取标签总数
  Future<int> getTagCount() async {
    if (!_initialized) await initialize();
    
    final result = await _db!.rawQuery('SELECT COUNT(*) as count FROM tags');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() => _cache.statistics;

  /// 健康检查
  Future<DataSourceHealth> checkHealth() async {
    try {
      if (!_initialized) {
        return DataSourceHealth(
          status: HealthStatus.corrupted,
          message: 'Translation data source not initialized',
          timestamp: DateTime.now(),
        );
      }

      // 尝试查询
      await _db!.rawQuery('SELECT 1 FROM tags LIMIT 1');
      final count = await getCount();

      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'Translation data source is healthy',
        details: {
          'translationCount': count,
          'cacheSize': _cache.size,
          'cacheHitRate': _cache.hitRate,
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
    _cache.clear();
    AppLogger.i('Translation cache cleared', 'TranslationDS');
  }

  /// 释放资源
  Future<void> dispose() async {
    _cache.clear();
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _initialized = false;
    AppLogger.i('Translation data source disposed', 'TranslationDS');
  }

  // 私有辅助方法

  /// 从数据库查询单个翻译
  Future<String?> _queryFromDb(String normalizedTag) async {
    final result = await _db!.rawQuery(
      '''
      SELECT tr.translation 
      FROM tags t
      JOIN translations tr ON t.id = tr.tag_id
      WHERE t.name = ? AND tr.language = ?
      LIMIT 1
      ''',
      [normalizedTag, 'zh'],
    );

    if (result.isNotEmpty) {
      return result.first['translation'] as String?;
    }
    return null;
  }

  /// 从数据库批量查询翻译
  Future<Map<String, String>> _queryBatchFromDb(List<String> tags) async {
    if (tags.isEmpty) return {};

    final placeholders = tags.map((_) => '?').join(',');
    // Use GROUP_CONCAT to get all translations, then take the first one
    // Or use MIN(tr.id) to get the first translation for each tag
    final result = await _db!.rawQuery(
      '''
      SELECT t.name as tag, tr.translation
      FROM tags t
      JOIN translations tr ON t.id = tr.tag_id
      WHERE t.name IN ($placeholders) AND tr.language = ?
      GROUP BY t.name
      ORDER BY MIN(tr.id)
      ''',
      [...tags, 'zh'],
    );

    return {
      for (final row in result)
        row['tag'] as String: row['translation'] as String,
    };
  }

  int _calculateMatchScore(String text, String query, {required bool isTagMatch}) {
    final lowerText = text.toLowerCase();
    int score = 0;

    // 完全匹配得分最高
    if (lowerText == query) {
      score += 100;
    }
    // 开头匹配得分较高
    else if (lowerText.startsWith(query)) {
      score += 50;
    }
    // 包含匹配
    else if (lowerText.contains(query)) {
      score += 25;
    }

    // 标签匹配权重更高
    if (isTagMatch) {
      score += 10;
    }

    return score;
  }
}


