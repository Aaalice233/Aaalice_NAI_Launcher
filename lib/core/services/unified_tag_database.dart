import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';

part 'unified_tag_database.g.dart';

/// 确保 SQLite FFI 已初始化
void _ensureSqliteFfiInitialized() {
  try {
    // 尝试访问 databaseFactory，如果未初始化会抛出异常
    databaseFactory;
  } catch (e) {
    // 未初始化，需要重新设置
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppLogger.i('SQLite FFI re-initialized', 'UnifiedTagDatabase');
  }
}

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

/// 元数据记录
class MetadataRecord {
  final String source;
  final DateTime lastUpdate;
  final String version;

  const MetadataRecord({
    required this.source,
    required this.lastUpdate,
    required this.version,
  });
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

  /// 格式化显示的计数
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

// ==================== 统一标签数据库服务 ====================

/// 统一标签数据库服务
/// 整合翻译标签、Danbooru 标签和共现关系到单一 SQLite 数据库
class UnifiedTagDatabase {
  static const String _databaseName = 'tag_data_v2.db';
  static const int _databaseVersion = 1;

  /// 数据库实例
  Database? _db;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 热数据缓存 - 翻译
  final Map<String, String> _translationCache = {};

  /// 热数据缓存 - Danbooru 标签
  final Map<String, DanbooruTagRecord> _danbooruTagCache = {};

  /// 热数据缓存 - 共现关系
  final Map<String, List<RelatedTag>> _cooccurrenceCache = {};

  /// 最大热缓存条目数
  static const int _maxTranslationCacheSize = 500;
  static const int _maxDanbooruTagCacheSize = 1000;
  static const int _maxCooccurrenceCacheSize = 1000;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取数据库实例
  Database get _database {
    if (_db == null) {
      throw StateError(
        'UnifiedTagDatabase not initialized. Call initialize() first.',
      );
    }
    return _db!;
  }

  /// 获取数据库路径
  Future<String> getDatabasePath() async {
    final appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'databases', _databaseName);
  }

  /// 初始化数据库
  ///
  /// 如果数据库不存在，会尝试从 assets 加载预打包数据库。
  Future<void> initialize() async {
    _ensureSqliteFfiInitialized();

    if (_isInitialized) return;

    try {
      final dbPath = await getDatabasePath();

      // 确保目录存在
      final dbDir = Directory(path.dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      // 检查数据库文件是否存在
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        try {
          final testAccess = await dbFile.open(mode: FileMode.write);
          await testAccess.close();
        } catch (e) {
          AppLogger.w(
            'Database file is locked, attempting to delete and recreate: $e',
            'UnifiedTagDatabase',
          );
          try {
            await dbFile.delete();
            AppLogger.i(
              'Locked database file deleted successfully',
              'UnifiedTagDatabase',
            );
          } catch (deleteError) {
            AppLogger.e(
              'Failed to delete locked database file',
              deleteError,
              null,
              'UnifiedTagDatabase',
            );
          }
        }
      }

      // 如果数据库不存在，尝试从 assets 加载预打包数据库
      if (!await dbFile.exists()) {
        await _extractPrebuiltDatabase(dbPath);
      }

      _db = await openDatabase(
        dbPath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        singleInstance: true,
      );

      // 设置 PRAGMA
      await _db!.execute('PRAGMA foreign_keys = ON');
      await _db!.execute('PRAGMA journal_mode = WAL');
      await _db!.execute('PRAGMA synchronous = NORMAL');
      await _db!.execute('PRAGMA busy_timeout = 5000');

      _isInitialized = true;
      AppLogger.i('UnifiedTagDatabase initialized', 'UnifiedTagDatabase');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize UnifiedTagDatabase',
        e,
        stack,
        'UnifiedTagDatabase',
      );
      rethrow;
    }
  }

  /// 从 assets 解压预打包数据库
  Future<void> _extractPrebuiltDatabase(String targetPath) async {
    const assetPath = 'assets/database/prebuilt_tags.db.gz';

    try {
      // 检查 assets 中是否存在预打包数据库
      final byteData = await rootBundle.load(assetPath);
      final compressedBytes = byteData.buffer.asUint8List();

      AppLogger.i(
        'Found prebuilt database in assets (${compressedBytes.length} bytes compressed)',
        'UnifiedTagDatabase',
      );

      // 解压 gzip
      final dbBytes = gzip.decode(compressedBytes);

      // 写入文件
      final dbFile = File(targetPath);
      await dbFile.writeAsBytes(dbBytes);

      AppLogger.i(
        'Prebuilt database extracted to $targetPath (${dbBytes.length} bytes)',
        'UnifiedTagDatabase',
      );
    } catch (e) {
      // 如果 assets 中不存在或解压失败，记录日志并继续
      // 数据库将在 openDatabase 的 onCreate 回调中创建
      AppLogger.i(
        'No prebuilt database found in assets or extraction failed: $e',
        'UnifiedTagDatabase',
      );
    }
  }

  /// 创建数据库表和索引
  Future<void> _onCreate(Database db, int version) async {
    // 1) Danbooru 标签主表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS danbooru_tags (
        tag TEXT NOT NULL COLLATE NOCASE,
        category INTEGER NOT NULL DEFAULT 0 CHECK (category >= 0),
        post_count INTEGER NOT NULL DEFAULT 0 CHECK (post_count >= 0),
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (tag)
      ) WITHOUT ROWID
    ''');

    // 2) 翻译表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translations (
        en_tag TEXT NOT NULL COLLATE NOCASE,
        zh_translation TEXT NOT NULL,
        source TEXT NOT NULL,
        PRIMARY KEY (en_tag)
      ) WITHOUT ROWID
    ''');

    // 3) 共现关系表（双向存储：A->B 和 B->A）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cooccurrences (
        tag1 TEXT NOT NULL COLLATE NOCASE,
        tag2 TEXT NOT NULL COLLATE NOCASE,
        count INTEGER NOT NULL CHECK (count > 0),
        cooccurrence_score REAL NOT NULL DEFAULT 0.0 CHECK (cooccurrence_score >= 0),
        PRIMARY KEY (tag1, tag2),
        CHECK (tag1 <> tag2),
        FOREIGN KEY (tag1) REFERENCES danbooru_tags(tag)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (tag2) REFERENCES danbooru_tags(tag)
          ON UPDATE CASCADE ON DELETE CASCADE
      ) WITHOUT ROWID
    ''');

    // 4) 元数据表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        source TEXT NOT NULL PRIMARY KEY
          CHECK (source IN ('translations', 'danbooru_tags', 'cooccurrences', 'unified')),
        last_update INTEGER NOT NULL,
        data_version TEXT NOT NULL
      ) WITHOUT ROWID
    ''');

    // ========== 创建索引 ==========

    // translations: 按来源筛选/增量维护
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_translations_source
        ON translations(source)
    ''');

    // danbooru_tags: 热门标签、分类热门、增量刷新
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_danbooru_tags_post_count_desc
        ON danbooru_tags(post_count DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_danbooru_tags_category_post_count_desc
        ON danbooru_tags(category, post_count DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_danbooru_tags_last_updated_desc
        ON danbooru_tags(last_updated DESC)
    ''');

    // cooccurrences: 核心查询路径
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cooccurrences_tag1_count_desc
        ON cooccurrences(tag1, count DESC, tag2)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cooccurrences_count_desc
        ON cooccurrences(count DESC)
    ''');

    AppLogger.i('UnifiedTagDatabase tables created', 'UnifiedTagDatabase');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.i(
      'Database upgrade from $oldVersion to $newVersion',
      'UnifiedTagDatabase',
    );
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
      _translationCache.clear();
      _danbooruTagCache.clear();
      _cooccurrenceCache.clear();
      AppLogger.i('UnifiedTagDatabase closed', 'UnifiedTagDatabase');
    }
  }

  // ==================== Translations 表操作 ====================

  /// 批量插入翻译
  Future<void> insertTranslations(
    List<TranslationRecord> records, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Database not initialized');
    }

    if (records.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    var processed = 0;
    const batchSize = 2000;

    // 禁用 WAL 模式以提高批量写入性能
    await _database.execute('PRAGMA journal_mode = MEMORY');
    await _database.execute('PRAGMA synchronous = OFF');

    try {
      var batch = _database.batch();

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
          batch = _database.batch();
          onProgress?.call(processed, records.length);
        }
      }

      // 提交剩余批次
      if ((batch as dynamic).length > 0) {
        await batch.commit(noResult: true);
      }

      stopwatch.stop();
      AppLogger.i(
        'Inserted $processed translation records in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTagDatabase',
      );
    } finally {
      // 恢复默认设置
      await _database.execute('PRAGMA synchronous = NORMAL');
      await _database.execute('PRAGMA journal_mode = WAL');
    }
  }

  /// 获取单个翻译
  Future<String?> getTranslation(String tag) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 先检查热缓存
    if (_translationCache.containsKey(normalizedTag)) {
      return _translationCache[normalizedTag];
    }

    if (!_isInitialized) return null;

    try {
      final results = await _database.query(
        'translations',
        columns: ['zh_translation'],
        where: 'en_tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final translation = results.first['zh_translation'] as String;
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
  Future<Map<String, String>> getTranslations(List<String> tags) async {
    if (tags.isEmpty) return {};
    if (!_isInitialized) return {};

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final result = <String, String>{};

    // 先检查热缓存
    final uncachedTags = <String>[];
    for (final tag in normalizedTags) {
      if (_translationCache.containsKey(tag)) {
        result[tag] = _translationCache[tag]!;
      } else {
        uncachedTags.add(tag);
      }
    }

    if (uncachedTags.isEmpty) return result;

    try {
      final placeholders = List.filled(uncachedTags.length, '?').join(',');
      final dbResults = await _database.rawQuery(
        'SELECT en_tag, zh_translation FROM translations WHERE en_tag IN ($placeholders)',
        uncachedTags,
      );

      for (final row in dbResults) {
        final tag = row['en_tag'] as String;
        final translation = row['zh_translation'] as String;
        result[tag] = translation;
        _addToTranslationCache(tag, translation);
      }

      return result;
    } catch (e) {
      AppLogger.w(
        'Failed to get translations batch: $e',
        'UnifiedTagDatabase',
      );
      return result;
    }
  }

  void _addToTranslationCache(String tag, String translation) {
    if (_translationCache.length >= _maxTranslationCacheSize) {
      final firstKey = _translationCache.keys.first;
      _translationCache.remove(firstKey);
    }
    _translationCache[tag] = translation;
  }

  // ==================== DanbooruTags 表操作 ====================

  /// 批量插入 Danbooru 标签
  Future<void> insertDanbooruTags(
    List<DanbooruTagRecord> records, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Database not initialized');
    }

    if (records.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    var processed = 0;
    const batchSize = 2000;

    // 禁用 WAL 模式以提高批量写入性能
    await _database.execute('PRAGMA journal_mode = MEMORY');
    await _database.execute('PRAGMA synchronous = OFF');

    try {
      var batch = _database.batch();

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
          batch = _database.batch();
          onProgress?.call(processed, records.length);
        }
      }

      // 提交剩余批次
      if ((batch as dynamic).length > 0) {
        await batch.commit(noResult: true);
      }

      stopwatch.stop();
      AppLogger.i(
        'Inserted $processed danbooru tag records in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTagDatabase',
      );
    } finally {
      // 恢复默认设置
      await _database.execute('PRAGMA synchronous = NORMAL');
      await _database.execute('PRAGMA journal_mode = WAL');
    }
  }

  /// 获取单个 Danbooru 标签
  Future<DanbooruTagRecord?> getDanbooruTag(String tag) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 先检查热缓存
    if (_danbooruTagCache.containsKey(normalizedTag)) {
      return _danbooruTagCache[normalizedTag];
    }

    if (!_isInitialized) return null;

    try {
      final results = await _database.query(
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
    if (!_isInitialized || tags.isEmpty) return [];

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();

    // 检查缓存
    final results = <DanbooruTagRecord>[];
    final tagsToQuery = <String>[];

    for (final tag in normalizedTags) {
      if (_danbooruTagCache.containsKey(tag)) {
        results.add(_danbooruTagCache[tag]!);
      } else {
        tagsToQuery.add(tag);
      }
    }

    // 查询剩余标签
    if (tagsToQuery.isNotEmpty) {
      try {
        // 使用 IN 子句批量查询
        final placeholders = List.filled(tagsToQuery.length, '?').join(',');
        final rows = await _database.query(
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
        AppLogger.w(
          'Failed to get danbooru tags: $e',
          'UnifiedTagDatabase',
        );
      }
    }

    return results;
  }

  /// 搜索 Danbooru 标签
  Future<List<DanbooruTagRecord>> searchDanbooruTags(
    String query, {
    int? category,
    int limit = 20,
  }) async {
    if (!_isInitialized) return [];

    final normalizedQuery = query.toLowerCase().trim();

    try {
      var whereClause = 'tag LIKE ?';
      final whereArgs = <dynamic>['%$normalizedQuery%'];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      final results = await _database.query(
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
      AppLogger.w(
        'Failed to search danbooru tags: $e',
        'UnifiedTagDatabase',
      );
      return [];
    }
  }

  /// 获取热门 Danbooru 标签
  Future<List<DanbooruTagRecord>> getHotDanbooruTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    if (!_isInitialized) return [];

    try {
      var whereClause = 'post_count >= ?';
      final whereArgs = <dynamic>[minCount];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      final results = await _database.query(
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
      AppLogger.w(
        'Failed to get hot danbooru tags: $e',
        'UnifiedTagDatabase',
      );
      return [];
    }
  }

  void _addToDanbooruTagCache(String tag, DanbooruTagRecord record) {
    if (_danbooruTagCache.length >= _maxDanbooruTagCacheSize) {
      final firstKey = _danbooruTagCache.keys.first;
      _danbooruTagCache.remove(firstKey);
    }
    _danbooruTagCache[tag] = record;
  }

  // ==================== Cooccurrences 表操作 ====================

  /// 批量插入共现关系
  Future<void> insertCooccurrences(
    List<CooccurrenceRecord> records, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Database not initialized');
    }

    if (records.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    var processed = 0;
    const batchSize = 5000;

    // 禁用 WAL 模式以提高批量写入性能
    await _database.execute('PRAGMA journal_mode = MEMORY');
    await _database.execute('PRAGMA synchronous = OFF');

    try {
      var batch = _database.batch();

      for (final record in records) {
        final tag1 = record.tag1.toLowerCase().trim();
        final tag2 = record.tag2.toLowerCase().trim();

        // 插入双向关系
        batch.insert(
          'cooccurrences',
          {
            'tag1': tag1,
            'tag2': tag2,
            'count': record.count,
            'cooccurrence_score': record.cooccurrenceScore,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          'cooccurrences',
          {
            'tag1': tag2,
            'tag2': tag1,
            'count': record.count,
            'cooccurrence_score': record.cooccurrenceScore,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        processed++;

        if (processed % batchSize == 0) {
          await batch.commit(noResult: true);
          batch = _database.batch();
          onProgress?.call(processed, records.length);
        }
      }

      // 提交剩余批次
      if ((batch as dynamic).length > 0) {
        await batch.commit(noResult: true);
      }

      stopwatch.stop();
      AppLogger.i(
        'Inserted $processed cooccurrence records in ${stopwatch.elapsedMilliseconds}ms',
        'UnifiedTagDatabase',
      );
    } finally {
      // 恢复默认设置
      await _database.execute('PRAGMA synchronous = NORMAL');
      await _database.execute('PRAGMA journal_mode = WAL');
    }
  }

  /// 获取相关标签
  Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 先检查热缓存
    if (_cooccurrenceCache.containsKey(normalizedTag)) {
      return _cooccurrenceCache[normalizedTag]!.take(limit).toList();
    }

    if (!_isInitialized) return [];

    try {
      final results = await _database.query(
        'cooccurrences',
        columns: ['tag2', 'count', 'cooccurrence_score'],
        where: 'tag1 = ?',
        whereArgs: [normalizedTag],
        orderBy: 'count DESC',
        limit: limit,
      );

      final tags = results
          .map(
            (row) => RelatedTag(
              tag: row['tag2'] as String,
              count: row['count'] as int,
              cooccurrenceScore:
                  (row['cooccurrence_score'] as num?)?.toDouble() ?? 0.0,
            ),
          )
          .toList();

      _addToCooccurrenceCache(normalizedTag, tags);
      return tags;
    } catch (e) {
      AppLogger.w(
        'Failed to get related tags for "$tag": $e',
        'UnifiedTagDatabase',
      );
      return [];
    }
  }

  /// 批量获取相关标签（交集优先）
  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    if (tags.isEmpty) return [];
    if (tags.length == 1) return getRelatedTags(tags.first, limit: limit);

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();

    if (!_isInitialized) return [];

    try {
      final placeholders = List.filled(normalizedTags.length, '?').join(',');
      final results = await _database.rawQuery(
        '''
        SELECT tag2, SUM(count) as total_count, AVG(cooccurrence_score) as avg_score
        FROM cooccurrences
        WHERE tag1 IN ($placeholders)
          AND tag2 NOT IN ($placeholders)
        GROUP BY tag2
        ORDER BY total_count DESC
        LIMIT ?
        ''',
        [...normalizedTags, ...normalizedTags, limit],
      );

      return results
          .map(
            (row) => RelatedTag(
              tag: row['tag2'] as String,
              count: (row['total_count'] as num).toInt(),
              cooccurrenceScore: (row['avg_score'] as num?)?.toDouble() ?? 0.0,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.w(
        'Failed to get related tags for multiple: $e',
        'UnifiedTagDatabase',
      );
      return [];
    }
  }

  void _addToCooccurrenceCache(String tag, List<RelatedTag> tags) {
    if (_cooccurrenceCache.length >= _maxCooccurrenceCacheSize) {
      final firstKey = _cooccurrenceCache.keys.first;
      _cooccurrenceCache.remove(firstKey);
    }
    _cooccurrenceCache[tag] = tags;
  }

  // ==================== 元数据操作 ====================

  /// 设置元数据
  Future<void> setMetadata(
    String source,
    DateTime lastUpdate,
    String version,
  ) async {
    if (!_isInitialized) return;

    await _database.insert(
      'metadata',
      {
        'source': source,
        'last_update': lastUpdate.millisecondsSinceEpoch,
        'data_version': version,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取元数据
  Future<MetadataRecord?> getMetadata(String source) async {
    if (!_isInitialized) return null;

    try {
      final results = await _database.query(
        'metadata',
        where: 'source = ?',
        whereArgs: [source],
        limit: 1,
      );

      if (results.isEmpty) return null;

      return MetadataRecord(
        source: results.first['source'] as String,
        lastUpdate: DateTime.fromMillisecondsSinceEpoch(
          results.first['last_update'] as int,
        ),
        version: results.first['data_version'] as String,
      );
    } catch (e) {
      AppLogger.w(
        'Failed to get metadata for "$source": $e',
        'UnifiedTagDatabase',
      );
      return null;
    }
  }

  /// 获取各表记录数
  Future<RecordCounts> getRecordCounts() async {
    if (!_isInitialized) {
      return const RecordCounts();
    }

    try {
      final translationsResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM translations',
      );
      final danbooruTagsResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM danbooru_tags',
      );
      final cooccurrencesResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM cooccurrences',
      );

      return RecordCounts(
        translations: (translationsResult.first['count'] as num?)?.toInt() ?? 0,
        danbooruTags: (danbooruTagsResult.first['count'] as num?)?.toInt() ?? 0,
        cooccurrences:
            (cooccurrencesResult.first['count'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      AppLogger.w(
        'Failed to get record counts: $e',
        'UnifiedTagDatabase',
      );
      return const RecordCounts();
    }
  }

  /// 清空共现数据表
  Future<void> clearCooccurrences() async {
    if (!_isInitialized) return;

    try {
      await _database.delete('cooccurrences');
      _cooccurrenceCache.clear();
      AppLogger.i('Cooccurrences table cleared', 'UnifiedTagDatabase');
    } catch (e) {
      AppLogger.w('Failed to clear cooccurrences: $e', 'UnifiedTagDatabase');
    }
  }

  /// 清空所有缓存
  void clearCache() {
    _translationCache.clear();
    _danbooruTagCache.clear();
    _cooccurrenceCache.clear();
    AppLogger.i('All caches cleared', 'UnifiedTagDatabase');
  }
}

// ==================== Riverpod Provider ====================

/// UnifiedTagDatabase 服务 Provider
///
/// 提供一个统一的标签数据库服务，包含翻译、Danbooru标签和共现关系数据。
/// 使用 keepAlive: true 保持数据库连接，避免频繁开闭。
@Riverpod(keepAlive: true)
Future<UnifiedTagDatabase> unifiedTagDatabase(Ref ref) async {
  final database = UnifiedTagDatabase();
  await database.initialize();
  return database;
}
