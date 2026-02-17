import 'dart:collection';

import '../../utils/app_logger.dart';
import '../data_source.dart';

/// 通用 LRU 缓存实现
///
/// 使用 LinkedHashMap 实现 LRU 缓存，限制最大条目数。
/// 当缓存满时，自动移除最久未使用的条目。
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  LRUCache({required this.maxSize});

  /// 获取缓存值
  ///
  /// 如果找到，将条目移到末尾（标记为最近使用）
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
      _hitCount++;
      return value;
    }
    _missCount++;
    return null;
  }

  /// 设置缓存值
  ///
  /// 如果缓存已满，先移除最旧的条目
  void put(K key, V value) {
    _cache.remove(key);

    if (_cache.length >= maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      _evictionCount++;
    }

    _cache[key] = value;
  }

  /// 检查是否包含键
  bool containsKey(K key) => _cache.containsKey(key);

  /// 获取当前大小
  int get size => _cache.length;

  /// 检查是否为空
  bool get isEmpty => _cache.isEmpty;

  /// 检查是否已满
  bool get isFull => _cache.length >= maxSize;

  /// 清除所有缓存
  void clear() {
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
  }

  /// 移除特定键
  bool remove(K key) => _cache.remove(key) != null;

  /// 获取命中率
  double get hitRate {
    final total = _hitCount + _missCount;
    return total == 0 ? 0.0 : _hitCount / total;
  }

  /// 获取统计信息
  Map<String, dynamic> get statistics => {
        'size': _cache.length,
        'maxSize': maxSize,
        'hitCount': _hitCount,
        'missCount': _missCount,
        'evictionCount': _evictionCount,
        'hitRate': hitRate,
      };
}

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

  Map<String, dynamic> toMap() => {
        'en_tag': enTag,
        'zh_translation': zhTranslation,
        'source': source,
        'last_accessed': lastAccessed,
      };

  factory TranslationRecord.fromMap(Map<String, dynamic> map) {
    return TranslationRecord(
      enTag: map['en_tag'] as String,
      zhTranslation: map['zh_translation'] as String,
      source: map['source'] as String? ?? 'unknown',
      lastAccessed: map['last_accessed'] as int?,
    );
  }
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

/// 翻译数据源
///
/// 管理标签翻译数据的查询和缓存。
/// 使用 LRU 缓存策略，最大缓存 1000 条翻译记录。
class TranslationDataSource extends BaseDataSource {
  static const int _maxCacheSize = 1000;
  static const String _tableName = 'translations';

  final LRUCache<String, String> _cache = LRUCache(maxSize: _maxCacheSize);

  // 数据库连接（通过外部注入，旧模式）
  dynamic _db;

  // 连接池（新模式，优先使用）
  dynamic _connectionPool;

  @override
  String get name => 'translation';

  @override
  DataSourceType get type => DataSourceType.translation;

  @override
  Set<String> get dependencies => {}; // 无依赖

  /// 设置数据库连接
  ///
  /// 在初始化前必须设置数据库连接
  void setDatabase(dynamic db) {
    _db = db;
  }

  /// 设置连接池
  ///
  /// 使用连接池模式，每次操作时动态获取连接
  void setConnectionPool(dynamic pool) {
    _connectionPool = pool;
  }

  /// 获取数据库连接
  ///
  /// 优先使用连接池，回退到固定连接
  Future<dynamic> _acquireDb() async {
    if (_connectionPool != null) {
      return await _connectionPool.acquire();
    }
    return _db;
  }

  /// 释放数据库连接
  ///
  /// 如果是从连接池获取的，需要释放
  Future<void> _releaseDb(dynamic db) async {
    if (_connectionPool != null && db != null) {
      await _connectionPool.release(db);
    }
  }

  /// 查询单个翻译
  ///
  /// 1. 检查 LRU 缓存
  /// 2. 查询数据库
  /// 3. 写入缓存
  Future<String?> query(String enTag) async {
    if (enTag.isEmpty) return null;

    final normalizedTag = enTag.toLowerCase().trim();

    // 1. 检查缓存
    final cached = _cache.get(normalizedTag);
    if (cached != null) {
      AppLogger.d('Translation cache hit: $normalizedTag', 'TranslationDS');
      return cached;
    }

    // 2. 查询数据库
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
    final db = await _acquireDb();
    if (query.isEmpty || db == null) return [];

    try {
      final results = <TranslationMatch>[];
      final lowerQuery = query.toLowerCase();

      if (matchTag) {
        final tagResults = await db.rawQuery(
          'SELECT en_tag, zh_translation FROM $_tableName '
          'WHERE en_tag LIKE ? ORDER BY en_tag LIMIT ?',
          ['%$lowerQuery%', limit],
        );

        for (final row in tagResults) {
          results.add(TranslationMatch(
            tag: row['en_tag'] as String,
            translation: row['zh_translation'] as String,
            score: _calculateMatchScore(
              row['en_tag'] as String,
              lowerQuery,
              isTagMatch: true,
            ),
          ),
        );
        }
      }

      if (matchTranslation) {
        final transResults = await db.rawQuery(
          'SELECT en_tag, zh_translation FROM $_tableName '
          'WHERE zh_translation LIKE ? ORDER BY zh_translation LIMIT ?',
          ['%$query%', limit],
        );

        for (final row in transResults) {
          final tag = row['en_tag'] as String;
          // 避免重复
          if (!results.any((r) => r.tag == tag)) {
            results.add(TranslationMatch(
              tag: tag,
              translation: row['zh_translation'] as String,
              score: _calculateMatchScore(
                row['zh_translation'] as String,
                query,
                isTagMatch: false,
              ),
            ),
          );
          }
        }
      }

      // 按相关度排序
      results.sort((a, b) => b.score.compareTo(a.score));

      return results.take(limit).toList();
    } catch (e, stack) {
      AppLogger.e('Failed to search translations', e, stack, 'TranslationDS');
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 获取翻译总数
  Future<int> getCount() async {
    final db = await _acquireDb();
    if (db == null) return 0;

    try {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName',
      );
      return (result.first['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      AppLogger.w('Failed to get translation count: $e', 'TranslationDS');
      return 0;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 插入或更新翻译记录
  Future<void> upsert(TranslationRecord record) async {
    final db = await _acquireDb();
    if (db == null) throw StateError('Database not initialized');

    try {
      // 使用 INSERT OR REPLACE 语法
      await db.rawInsert(
        'INSERT OR REPLACE INTO $_tableName (en_tag, zh_translation, source, last_accessed) VALUES (?, ?, ?, ?)',
        [
          record.enTag,
          record.zhTranslation,
          record.source,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );

      // 更新缓存
      _cache.put(record.enTag.toLowerCase(), record.zhTranslation);
    } catch (e, stack) {
      AppLogger.e('Failed to upsert translation', e, stack, 'TranslationDS');
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 批量插入翻译记录
  Future<void> upsertBatch(List<TranslationRecord> records) async {
    if (records.isEmpty) return;

    final db = await _acquireDb();
    if (db == null) throw StateError('Database not initialized');

    try {
      // 使用事务保护批量操作
      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final record in records) {
          batch.rawInsert(
            'INSERT OR REPLACE INTO $_tableName (en_tag, zh_translation, source, last_accessed) VALUES (?, ?, ?, ?)',
            [
              record.enTag,
              record.zhTranslation,
              record.source,
              DateTime.now().millisecondsSinceEpoch,
            ],
          );
        }

        await batch.commit(noResult: true);
      });

      // 更新缓存
      for (final record in records) {
        _cache.put(record.enTag.toLowerCase(), record.zhTranslation);
      }

      AppLogger.i(
        'Inserted ${records.length} translations',
        'TranslationDS',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to batch upsert translations',
        e,
        stack,
        'TranslationDS',
      );
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStatistics() => _cache.statistics;

  @override
  Future<void> doInitialize() async {
    final db = await _acquireDb();
    if (db == null) {
      throw StateError('Database connection not set. Call setDatabase() first.');
    }

    // 验证表是否存在
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [_tableName],
      );

      if (result.isEmpty) {
        // 创建表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableName (
            en_tag TEXT PRIMARY KEY,
            zh_translation TEXT NOT NULL,
            source TEXT DEFAULT 'unknown',
            last_accessed INTEGER
          )
        ''');

        // 创建索引
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_translations_source
          ON $_tableName(source)
        ''');

        AppLogger.i('Created translations table', 'TranslationDS');
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize translations table',
        e,
        stack,
        'TranslationDS',
      );
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    final db = await _acquireDb();
    if (db == null) {
      return DataSourceHealth(
        status: HealthStatus.corrupted,
        message: 'Database connection is null',
        timestamp: DateTime.now(),
      );
    }

    try {
      // 检查表是否存在
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [_tableName],
      );

      if (result.isEmpty) {
        return DataSourceHealth(
          status: HealthStatus.corrupted,
          message: 'Translations table does not exist',
          timestamp: DateTime.now(),
        );
      }

      // 尝试查询
      await db.rawQuery('SELECT 1 FROM $_tableName LIMIT 1');

      final count = await getCount();

      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'Translation data source is healthy',
        details: {
          'recordCount': count,
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
    } finally {
      await _releaseDb(db);
    }
  }

  @override
  Future<void> doClear() async {
    _cache.clear();
    AppLogger.i('Translation cache cleared', 'TranslationDS');
  }

  @override
  Future<void> doRestore() async {
    // 清除缓存，数据将从预构建数据库重新加载
    _cache.clear();

    // 预构建数据库恢复逻辑由上层处理
    AppLogger.i('Translation data source ready for restore', 'TranslationDS');
  }

  @override
  Future<void> doDispose() async {
    _cache.clear();
    _db = null;
  }

  // 私有辅助方法

  Future<String?> _queryFromDb(String normalizedTag) async {
    final db = await _acquireDb();
    if (db == null) return null;

    try {
      final result = await db.query(
        _tableName,
        columns: ['zh_translation'],
        where: 'en_tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return result.first['zh_translation'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.w('Failed to query translation from DB: $e', 'TranslationDS');
      return null;
    } finally {
      await _releaseDb(db);
    }
  }

  Future<Map<String, String>> _queryBatchFromDb(List<String> tags) async {
    final db = await _acquireDb();
    if (db == null || tags.isEmpty) return {};

    try {
      final placeholders = tags.map((_) => '?').join(',');
      final result = await db.rawQuery(
        'SELECT en_tag, zh_translation FROM $_tableName WHERE en_tag IN ($placeholders)',
        tags,
      );

      return {
        for (final row in result)
          row['en_tag'] as String: row['zh_translation'] as String,
      };
    } catch (e) {
      AppLogger.w('Failed to batch query translations: $e', 'TranslationDS');
      return {};
    } finally {
      await _releaseDb(db);
    }
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
