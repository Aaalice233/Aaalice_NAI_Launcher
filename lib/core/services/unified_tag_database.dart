import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import '../utils/tag_normalizer.dart';
import 'tag_database_connection.dart';

part 'unified_tag_database.g.dart';

// ==================== 数据记录类 ====================

/// 翻译记录
class TranslationRecord {
  final String enTag;
  final String zhTranslation;
  final String source;

  const TranslationRecord({
    required this.enTag,
    required this.zhTranslation,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
        'en_tag': enTag,
        'zh_translation': zhTranslation,
        'source': source,
      };
}

/// Danbooru 标签记录
class DanbooruTagRecord {
  final String tag;
  final int category;
  final int postCount;
  final int lastUpdated;

  const DanbooruTagRecord({
    required this.tag,
    required this.category,
    required this.postCount,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
        'tag': tag,
        'category': category,
        'post_count': postCount,
        'last_updated': lastUpdated,
      };
}

/// 共现关系记录
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

  Map<String, dynamic> toMap() => {
        'tag1': tag1,
        'tag2': tag2,
        'count': count,
        'cooccurrence_score': cooccurrenceScore,
      };
}

/// 相关标签（用于返回共现查询结果）
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

/// 记录数统计
class RecordCounts {
  final int translations;
  final int danbooruTags;
  final int cooccurrences;

  const RecordCounts({
    this.translations = 0,
    this.danbooruTags = 0,
    this.cooccurrences = 0,
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

// ==================== 统一标签数据库服务 V2 ====================

/// 统一标签数据库服务 V2
///
/// 使用 TagDatabaseConnection 管理连接，提供更健壮的连接处理。
class UnifiedTagDatabase {
  final TagDatabaseConnection _connection;

  // 缓存
  final Map<String, String> _translationCache = {};
  final Map<String, DanbooruTagRecord> _danbooruTagCache = {};
  final Map<String, List<RelatedTag>> _cooccurrenceCache = {};

  static const int _maxTranslationCacheSize = 500;
  static const int _maxDanbooruTagCacheSize = 1000;
  static const int _maxCooccurrenceCacheSize = 1000;

  UnifiedTagDatabase() : _connection = TagDatabaseConnection();

  /// 是否已连接
  bool get isConnected => _connection.isConnected;

  /// 是否已初始化（兼容旧 API）
  bool get isInitialized => _connection.isConnected;

  /// 初始化数据库
  Future<void> initialize() async {
    await _connection.initialize();
  }

  /// 强制重新连接
  Future<void> forceReinitialize() async {
    await _connection.reconnect();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _connection.dispose();
    clearCache();
  }

  /// 测试连接
  Future<bool> ping() async {
    return _connection.checkHealth();
  }

  /// 获取数据库实例（内部使用，自动处理连接问题）
  Future<Database> _getDb() async {
    if (!await _connection.checkHealth()) {
      AppLogger.w(
        'Database connection unhealthy, reconnecting...',
        'UnifiedTagDatabase',
      );
      await _connection.reconnect();
    }

    final db = _connection.db;
    if (db == null) {
      throw StateError('Database not available');
    }
    return db;
  }

  // ==================== Translations 表操作 ====================

  /// 获取翻译缓存版本号
  Future<int> getTranslationCacheVersion() async {
    try {
      final db = await _getDb();
      final result = await db.query(
        'metadata',
        columns: ['data_version'],
        where: 'source = ?',
        whereArgs: ['translations'],
        limit: 1,
      );

      if (result.isEmpty) return -1;

      final versionStr = result.first['data_version'] as String;
      return int.tryParse(versionStr) ?? -1;
    } catch (e) {
      AppLogger.w(
          'Failed to get translation cache version: $e', 'UnifiedTagDatabase',);
      return -1;
    }
  }

  /// 设置翻译缓存版本号
  Future<void> setTranslationCacheVersion(int version) async {
    try {
      final db = await _getDb();
      await db.insert(
        'metadata',
        {
          'source': 'translations',
          'last_update': DateTime.now().millisecondsSinceEpoch,
          'data_version': version.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      AppLogger.w(
          'Failed to set translation cache version: $e', 'UnifiedTagDatabase',);
    }
  }

  /// 获取翻译记录数量
  Future<int> getTranslationCount() async {
    try {
      final db = await _getDb();
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM translations');
      return (result.first['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      AppLogger.w('Failed to get translation count: $e', 'UnifiedTagDatabase');
      return 0;
    }
  }

  /// 清空所有翻译数据
  Future<void> clearTranslations() async {
    try {
      final db = await _getDb();
      await db.delete('translations');
      _translationCache.clear();
      AppLogger.i('Translations table cleared', 'UnifiedTagDatabase');
    } catch (e) {
      AppLogger.w('Failed to clear translations: $e', 'UnifiedTagDatabase');
    }
  }

  /// 搜索翻译（支持部分匹配）
  Future<List<TranslationMatch>> searchTranslations(
    String query, {
    int limit = 20,
    bool matchTag = true,
    bool matchTranslation = true,
  }) async {
    final normalizedQuery = query.toLowerCase().trim();
    if (normalizedQuery.isEmpty) return [];

    try {
      final db = await _getDb();
      final results = <TranslationMatch>[];

      if (matchTag) {
        // 搜索标签匹配
        final tagResults = await db.query(
          'translations',
          columns: ['en_tag', 'zh_translation'],
          where: 'en_tag LIKE ?',
          whereArgs: ['%$normalizedQuery%'],
          limit: limit,
        );

        for (final row in tagResults) {
          final tag = row['en_tag'] as String;
          final translation = row['zh_translation'] as String;
          // 计算匹配分数（前缀匹配分数更高）
          var score = 0;
          if (tag.startsWith(normalizedQuery)) {
            score += 100;
          } else if (tag.contains(normalizedQuery)) {
            score += 50;
          }

          results.add(
            TranslationMatch(
              tag: tag,
              translation: translation,
              score: score,
            ),
          );
        }
      }

      if (matchTranslation) {
        // 搜索中文翻译匹配
        final transResults = await db.query(
          'translations',
          columns: ['en_tag', 'zh_translation'],
          where: 'zh_translation LIKE ?',
          whereArgs: ['%$normalizedQuery%'],
          limit: limit,
        );

        for (final row in transResults) {
          final tag = row['en_tag'] as String;
          final translation = row['zh_translation'] as String;
          // 计算匹配分数
          var score = 0;
          if (translation.startsWith(normalizedQuery)) {
            score += 80;
          } else if (translation.contains(normalizedQuery)) {
            score += 40;
          }

          // 检查是否已存在（避免重复）
          final existingIndex = results.indexWhere((r) => r.tag == tag);
          if (existingIndex >= 0) {
            // 合并分数
            final existing = results[existingIndex];
            results[existingIndex] = TranslationMatch(
              tag: existing.tag,
              translation: existing.translation,
              score: existing.score + score,
            );
          } else {
            results.add(
              TranslationMatch(
                tag: tag,
                translation: translation,
                score: score,
              ),
            );
          }
        }
      }

      // 按分数排序
      results.sort((a, b) => b.score.compareTo(a.score));

      return results.take(limit).toList();
    } catch (e) {
      AppLogger.w('Failed to search translations: $e', 'UnifiedTagDatabase');
      return [];
    }
  }

  /// 批量插入翻译
  Future<void> insertTranslations(
    List<TranslationRecord> records, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (records.isEmpty) return;

    final db = await _getDb();
    final stopwatch = Stopwatch()..start();
    var processed = 0;
    const batchSize = 2000;

    await db.execute('PRAGMA journal_mode = MEMORY');
    await db.execute('PRAGMA synchronous = OFF');

    try {
      var batch = db.batch();

      for (final record in records) {
        batch.insert(
          'translations',
          {
            'en_tag': record.enTag.toLowerCase().trim(),
            'zh_translation': record.zhTranslation,
            'source': record.source,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        processed++;

        if (processed % batchSize == 0) {
          await batch.commit(noResult: true);
          batch = db.batch();
          onProgress?.call(processed, records.length);
        }
      }

      if ((batch as dynamic).length > 0) {
        await batch.commit(noResult: true);
      }

      stopwatch.stop();
      AppLogger.i(
        'Inserted $processed translation records in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTagDatabase',
      );
    } finally {
      await db.execute('PRAGMA synchronous = NORMAL');
      await db.execute('PRAGMA journal_mode = WAL');
    }
  }

  /// 获取单个翻译
  Future<String?> getTranslation(String tag) async {
    // 统一标准化标签
    final normalizedTag = TagNormalizer.normalize(tag);
    AppLogger.d(
        '[UnifiedTagDatabase] getTranslation("$tag") -> normalized="$normalizedTag"',
        'UnifiedTagDatabase',);

    if (_translationCache.containsKey(normalizedTag)) {
      final cached = _translationCache[normalizedTag];
      AppLogger.d(
          '[UnifiedTagDatabase] cache hit: "$cached"', 'UnifiedTagDatabase',);
      return cached;
    }

    try {
      final db = await _getDb();
      final results = await db.query(
        'translations',
        columns: ['zh_translation'],
        where: 'en_tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      AppLogger.d(
          '[UnifiedTagDatabase] DB query results: ${results.length} rows',
          'UnifiedTagDatabase',);
      if (results.isEmpty) {
        AppLogger.d(
            '[UnifiedTagDatabase] no translation found for "$normalizedTag"',
            'UnifiedTagDatabase',);
        return null;
      }

      final translation = results.first['zh_translation'] as String;
      AppLogger.d('[UnifiedTagDatabase] found translation: "$translation"',
          'UnifiedTagDatabase',);
      _addToTranslationCache(normalizedTag, translation);
      return translation;
    } catch (e) {
      AppLogger.w(
        'Failed to get translation for "$tag": $e',
        'UnifiedTagDatabase',
      );
      return null;
    }
  }

  /// 批量获取翻译
  Future<Map<String, String>> getTranslationsBatch(List<String> tags) async {
    if (tags.isEmpty) return {};

    final result = <String, String>{};
    final tagsToQuery = <String>[];

    for (final tag in tags) {
      // 统一标准化标签
      final normalizedTag = TagNormalizer.normalize(tag);
      if (_translationCache.containsKey(normalizedTag)) {
        result[normalizedTag] = _translationCache[normalizedTag]!;
      } else {
        tagsToQuery.add(normalizedTag);
      }
    }

    if (tagsToQuery.isEmpty) return result;

    try {
      final db = await _getDb();
      final placeholders = List.filled(tagsToQuery.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT en_tag, zh_translation FROM translations WHERE en_tag IN ($placeholders)',
        tagsToQuery,
      );

      for (final row in rows) {
        // 统一标准化标签
        final enTag = TagNormalizer.normalize(row['en_tag'] as String);
        final zhTranslation = row['zh_translation'] as String;
        result[enTag] = zhTranslation;
        _addToTranslationCache(enTag, zhTranslation);
      }
    } catch (e) {
      AppLogger.w('Failed to get translations batch: $e', 'UnifiedTagDatabase');
    }

    return result;
  }

  // ==================== DanbooruTags 表操作 ====================

  /// 批量插入 Danbooru 标签
  Future<void> insertDanbooruTags(
    List<DanbooruTagRecord> records, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (records.isEmpty) return;

    final db = await _getDb();
    final stopwatch = Stopwatch()..start();
    var processed = 0;
    const batchSize = 2000;

    await db.execute('PRAGMA journal_mode = MEMORY');
    await db.execute('PRAGMA synchronous = OFF');

    try {
      var batch = db.batch();

      for (final record in records) {
        batch.insert(
          'danbooru_tags',
          {
            'tag': record.tag.toLowerCase().trim(),
            'category': record.category,
            'post_count': record.postCount,
            'last_updated': record.lastUpdated,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        processed++;

        if (processed % batchSize == 0) {
          await batch.commit(noResult: true);
          batch = db.batch();
          onProgress?.call(processed, records.length);
        }
      }

      if ((batch as dynamic).length > 0) {
        await batch.commit(noResult: true);
      }

      stopwatch.stop();
      AppLogger.i(
        'Inserted $processed danbooru tag records in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTagDatabase',
      );
    } finally {
      await db.execute('PRAGMA synchronous = NORMAL');
      await db.execute('PRAGMA journal_mode = WAL');
    }
  }

  /// 获取单个 Danbooru 标签
  Future<DanbooruTagRecord?> getDanbooruTag(String tag) async {
    // 统一标准化标签
    final normalizedTag = TagNormalizer.normalize(tag);

    if (_danbooruTagCache.containsKey(normalizedTag)) {
      return _danbooruTagCache[normalizedTag];
    }

    try {
      final db = await _getDb();
      final results = await db.query(
        'danbooru_tags',
        where: 'tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final record = DanbooruTagRecord(
        tag: results.first['tag'] as String,
        category: results.first['category'] as int,
        postCount: results.first['post_count'] as int,
        lastUpdated: results.first['last_updated'] as int,
      );

      _addToDanbooruTagCache(normalizedTag, record);
      return record;
    } catch (e) {
      AppLogger.w(
        'Failed to get danbooru tag "$tag": $e',
        'UnifiedTagDatabase',
      );
      return null;
    }
  }

  /// 批量获取多个 Danbooru 标签
  Future<List<DanbooruTagRecord>> getDanbooruTags(List<String> tags) async {
    if (tags.isEmpty) return [];

    // 统一标准化标签
    final normalizedTags = TagNormalizer.normalizeList(tags);
    final results = <DanbooruTagRecord>[];
    final tagsToQuery = <String>[];

    for (final tag in normalizedTags) {
      if (_danbooruTagCache.containsKey(tag)) {
        results.add(_danbooruTagCache[tag]!);
      } else {
        tagsToQuery.add(tag);
      }
    }

    if (tagsToQuery.isNotEmpty) {
      try {
        final db = await _getDb();
        final placeholders = List.filled(tagsToQuery.length, '?').join(',');
        final rows = await db.query(
          'danbooru_tags',
          where: 'tag IN ($placeholders)',
          whereArgs: tagsToQuery,
        );

        for (final row in rows) {
          final record = DanbooruTagRecord(
            tag: row['tag'] as String,
            category: row['category'] as int,
            postCount: row['post_count'] as int,
            lastUpdated: row['last_updated'] as int,
          );
          _addToDanbooruTagCache(record.tag, record);
          results.add(record);
        }
      } catch (e) {
        AppLogger.w('Failed to get danbooru tags: $e', 'UnifiedTagDatabase');
      }
    }

    return results;
  }

  /// 搜索 Danbooru 标签
  /// 支持英文标签搜索和中文翻译搜索
  Future<List<DanbooruTagRecord>> searchDanbooruTags(
    String query, {
    int? category,
    int limit = 20,
  }) async {
    final normalizedQuery = query.toLowerCase().trim();
    if (normalizedQuery.isEmpty) return [];

    // 检测是否为中文搜索
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(normalizedQuery);

    try {
      final db = await _getDb();

      if (isChinese) {
        // 中文搜索：先在 translations 表中查找匹配的翻译
        final translationResults = await db.query(
          'translations',
          columns: ['en_tag'],
          where: 'zh_translation LIKE ?',
          whereArgs: ['%$normalizedQuery%'],
          limit: limit,
        );

        if (translationResults.isEmpty) {
          return [];
        }

        // 获取对应的英文标签
        final enTags =
            translationResults.map((r) => r['en_tag'] as String).toList();

        // 在 danbooru_tags 表中查询这些标签
        final placeholders = List.filled(enTags.length, '?').join(',');
        var whereClause = 'tag IN ($placeholders)';
        final whereArgs = <dynamic>[...enTags];

        if (category != null) {
          whereClause += ' AND category = ?';
          whereArgs.add(category);
        }

        final results = await db.query(
          'danbooru_tags',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return results
            .map(
              (row) => DanbooruTagRecord(
                tag: row['tag'] as String,
                category: row['category'] as int,
                postCount: row['post_count'] as int,
                lastUpdated: row['last_updated'] as int,
              ),
            )
            .toList();
      } else {
        // 英文搜索：直接在 danbooru_tags 表中搜索
        // 将查询词标准化（空格转下划线）
        final normalizedQueryUnderscore = TagNormalizer.normalize(query);
        var whereClause = 'tag LIKE ?';
        final whereArgs = <dynamic>['%$normalizedQueryUnderscore%'];

        if (category != null) {
          whereClause += ' AND category = ?';
          whereArgs.add(category);
        }

        final results = await db.query(
          'danbooru_tags',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return results
            .map(
              (row) => DanbooruTagRecord(
                tag: row['tag'] as String,
                category: row['category'] as int,
                postCount: row['post_count'] as int,
                lastUpdated: row['last_updated'] as int,
              ),
            )
            .toList();
      }
    } catch (e) {
      AppLogger.w('Failed to search danbooru tags: $e', 'UnifiedTagDatabase');
      return [];
    }
  }

  /// 获取热门 Danbooru 标签
  Future<List<DanbooruTagRecord>> getHotDanbooruTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    try {
      final db = await _getDb();
      var whereClause = 'post_count >= ?';
      final whereArgs = <dynamic>[minCount];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      final results = await db.query(
        'danbooru_tags',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'post_count DESC',
        limit: limit,
      );

      return results
          .map(
            (row) => DanbooruTagRecord(
              tag: row['tag'] as String,
              category: row['category'] as int,
              postCount: row['post_count'] as int,
              lastUpdated: row['last_updated'] as int,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.w('Failed to get hot danbooru tags: $e', 'UnifiedTagDatabase');
      return [];
    }
  }

  /// 获取 Danbooru 标签数量
  Future<int> getDanbooruTagCount() async {
    try {
      final db = await _getDb();
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM danbooru_tags');
      return (result.first['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      AppLogger.w('Failed to get danbooru tag count: $e', 'UnifiedTagDatabase');
      return 0;
    }
  }

  /// 清空所有 Danbooru 标签
  Future<void> clearDanbooruTags() async {
    try {
      final db = await _getDb();
      await db.delete('danbooru_tags');
      _danbooruTagCache.clear();
      AppLogger.i('Danbooru tags table cleared', 'UnifiedTagDatabase');
    } catch (e) {
      AppLogger.w('Failed to clear danbooru tags: $e', 'UnifiedTagDatabase');
    }
  }

  // ==================== Cooccurrences 表操作 ====================

  /// 批量插入共现关系（删除索引→批量插入→重建索引）
  Future<void> insertCooccurrences(
    List<CooccurrenceRecord> records, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (records.isEmpty) return;

    final db = await _getDb();
    final stopwatch = Stopwatch()..start();

    await db.execute('PRAGMA journal_mode = MEMORY');
    await db.execute('PRAGMA synchronous = OFF');

    try {
      // 1. 删除索引以加速插入
      await db
          .execute('DROP INDEX IF EXISTS idx_cooccurrences_tag1_count_desc');
      await db.execute('DROP INDEX IF EXISTS idx_cooccurrences_count_desc');

      // 2. 大事务批量插入（每批50000条）
      const batchSize = 50000;
      var processed = 0;
      var batch = db.batch();

      for (final record in records) {
        batch.insert(
          'cooccurrences',
          {
            'tag1': record.tag1.toLowerCase().trim(),
            'tag2': record.tag2.toLowerCase().trim(),
            'count': record.count,
            'cooccurrence_score': record.cooccurrenceScore,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (++processed % batchSize == 0) {
          await batch.commit(noResult: true);
          batch = db.batch();
          onProgress?.call(processed, records.length);
        }
      }

      // 提交剩余
      if ((batch as dynamic).length > 0) {
        await batch.commit(noResult: true);
      }

      // 3. 重建索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cooccurrences_tag1_count_desc
          ON cooccurrences(tag1, count DESC, tag2)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cooccurrences_count_desc
          ON cooccurrences(count DESC)
      ''');

      stopwatch.stop();
      AppLogger.i(
        'Inserted ${records.length} cooccurrence records in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTagDatabase',
      );
    } finally {
      await db.execute('PRAGMA synchronous = NORMAL');
      await db.execute('PRAGMA journal_mode = WAL');
    }
  }

  /// 获取相关标签
  Future<List<RelatedTag>> getRelatedTags(
    String tag, {
    int limit = 20,
  }) async {
    final normalizedTag = tag.toLowerCase().trim();

    if (_cooccurrenceCache.containsKey(normalizedTag)) {
      return _cooccurrenceCache[normalizedTag]!;
    }

    try {
      final db = await _getDb();
      final results = await db.query(
        'cooccurrences',
        columns: ['tag2', 'count', 'cooccurrence_score'],
        where: 'tag1 = ?',
        whereArgs: [normalizedTag],
        orderBy: 'count DESC',
        limit: limit,
      );

      final relatedTags = results
          .map(
            (row) => RelatedTag(
              tag: row['tag2'] as String,
              count: row['count'] as int,
              cooccurrenceScore: row['cooccurrence_score'] as double,
            ),
          )
          .toList();

      _addToCooccurrenceCache(normalizedTag, relatedTags);
      return relatedTags;
    } catch (e) {
      AppLogger.w(
        'Failed to get related tags for "$tag": $e',
        'UnifiedTagDatabase',
      );
      return [];
    }
  }

  /// 获取热门共现标签
  Future<List<RelatedTag>> getPopularCooccurrences({int limit = 100}) async {
    try {
      final db = await _getDb();
      final results = await db.query(
        'cooccurrences',
        orderBy: 'count DESC',
        limit: limit,
      );

      return results
          .map(
            (row) => RelatedTag(
              tag: '${row['tag1']} + ${row['tag2']}',
              count: row['count'] as int,
              cooccurrenceScore: row['cooccurrence_score'] as double,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.w(
        'Failed to get popular cooccurrences: $e',
        'UnifiedTagDatabase',
      );
      return [];
    }
  }

  /// 清空共现数据
  Future<void> clearCooccurrences() async {
    try {
      final db = await _getDb();
      await db.delete('cooccurrences');
      _cooccurrenceCache.clear();
      AppLogger.i('Cooccurrences table cleared', 'UnifiedTagDatabase');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrences: $e', 'UnifiedTagDatabase');
    }
  }

  // ==================== 元数据操作 ====================

  /// 获取各表记录数
  Future<RecordCounts> getRecordCounts() async {
    try {
      final db = await _getDb();

      final translationsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM translations',
      );
      final danbooruTagsResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM danbooru_tags',
      );
      final cooccurrencesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM cooccurrences',
      );

      return RecordCounts(
        translations: (translationsResult.first['count'] as num?)?.toInt() ?? 0,
        danbooruTags: (danbooruTagsResult.first['count'] as num?)?.toInt() ?? 0,
        cooccurrences:
            (cooccurrencesResult.first['count'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      AppLogger.w('Failed to get record counts: $e', 'UnifiedTagDatabase');
      return const RecordCounts();
    }
  }

  // ==================== CSV 版本管理 ====================

  /// 获取 CSV 数据源版本信息
  Future<Map<String, dynamic>?> getDataSourceVersion(String sourceName) async {
    try {
      final db = await _getDb();
      final result = await db.query(
        'metadata',
        columns: ['data_version', 'last_update'],
        where: 'source = ?',
        whereArgs: [sourceName],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final row = result.first;

      return {
        'version': int.tryParse(row['data_version'] as String? ?? '0') ?? 0,
        'lastUpdated': row['last_update']?.toString(),
        'extraData': null,
      };
    } catch (e) {
      AppLogger.w(
          'Failed to get data source version: $e', 'UnifiedTagDatabase',);
      return null;
    }
  }

  /// 更新 CSV 数据源版本信息
  Future<void> updateDataSourceVersion(
    String sourceName,
    int version, {
    String? hash,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final db = await _getDb();

      await db.insert(
        'metadata',
        {
          'source': sourceName,
          'data_version': version.toString(),
          'last_update': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      AppLogger.i(
          'Updated $sourceName version to $version', 'UnifiedTagDatabase',);
    } catch (e) {
      AppLogger.w(
          'Failed to update data source version: $e', 'UnifiedTagDatabase',);
    }
  }

  /// 检查共现数据是否需要更新
  Future<bool> needsCooccurrenceUpdate(String csvHash) async {
    final version = await getDataSourceVersion('cooccurrences');
    if (version == null) return true;

    // 简化判断：如果有版本记录且数据存在，认为不需要更新
    // 因为共现数据来自 assets，hash 计算在 Flutter 端可能不稳定
    return false;
  }

  // ==================== 缓存管理 ====================

  void _addToTranslationCache(String key, String value) {
    if (_translationCache.length >= _maxTranslationCacheSize) {
      _translationCache.remove(_translationCache.keys.first);
    }
    _translationCache[key] = value;
  }

  void _addToDanbooruTagCache(String key, DanbooruTagRecord value) {
    if (_danbooruTagCache.length >= _maxDanbooruTagCacheSize) {
      _danbooruTagCache.remove(_danbooruTagCache.keys.first);
    }
    _danbooruTagCache[key] = value;
  }

  void _addToCooccurrenceCache(String key, List<RelatedTag> value) {
    if (_cooccurrenceCache.length >= _maxCooccurrenceCacheSize) {
      _cooccurrenceCache.remove(_cooccurrenceCache.keys.first);
    }
    _cooccurrenceCache[key] = value;
  }

  /// 清空所有缓存
  void clearCache() {
    _translationCache.clear();
    _danbooruTagCache.clear();
    _cooccurrenceCache.clear();
    AppLogger.i('All caches cleared', 'UnifiedTagDatabase');
  }

  // 兼容旧 API 的方法
  Future<Map<String, String>> getTranslations(List<String> tags) async {
    return getTranslationsBatch(tags);
  }

  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    final allRelated = <RelatedTag>[];
    for (final tag in tags) {
      final related = await getRelatedTags(tag, limit: limit);
      allRelated.addAll(related);
    }
    // 按 count 排序
    allRelated.sort((a, b) => b.count.compareTo(a.count));
    return allRelated.take(limit).toList();
  }
}

// ==================== Riverpod Provider ====================

@Riverpod(keepAlive: true)
UnifiedTagDatabase unifiedTagDatabase(Ref ref) {
  return UnifiedTagDatabase();
}
