import '../../utils/app_logger.dart';
import '../data_source.dart';

/// 标签分类枚举
enum TagCategory {
  general(0),
  artist(1),
  copyright(3),
  character(4),
  meta(5);

  final int value;

  const TagCategory(this.value);

  static TagCategory fromInt(int value) {
    return TagCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => TagCategory.general,
    );
  }
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

  factory DanbooruTagRecord.fromMap(Map<String, dynamic> map) {
    return DanbooruTagRecord(
      tag: map['tag'] as String,
      category: (map['category'] as num?)?.toInt() ?? 0,
      postCount: (map['post_count'] as num?)?.toInt() ?? 0,
      lastUpdated: (map['last_updated'] as num?)?.toInt() ?? 0,
    );
  }

  /// 获取分类枚举
  TagCategory get categoryEnum => TagCategory.fromInt(category);

  /// 格式化使用量显示
  String get formattedCount {
    if (postCount >= 1000000) {
      return '${(postCount / 1000000).toStringAsFixed(1)}M';
    } else if (postCount >= 1000) {
      return '${(postCount / 1000).toStringAsFixed(1)}K';
    }
    return postCount.toString();
  }
}

/// Danbooru 标签搜索模式
enum TagSearchMode {
  /// 前缀匹配（默认）
  prefix,

  /// 包含匹配
  contains,

  /// 后缀匹配
  suffix,
}

/// Danbooru 标签数据源
///
/// 管理 Danbooru 标签数据的查询和存储。
/// 支持前缀搜索、分类过滤和热门标签查询。
/// 依赖于 TranslationDataSource 进行标签翻译。
class DanbooruTagDataSource extends BaseDataSource {
  static const String _tableName = 'danbooru_tags';

  // 数据库连接
  dynamic _db;

  // 可选的翻译数据源引用
  dynamic _translationDataSource;

  // 热门标签缓存
  List<DanbooruTagRecord>? _hotTagsCache;

  @override
  String get name => 'danbooruTag';

  @override
  DataSourceType get type => DataSourceType.danbooruTag;

  @override
  Set<String> get dependencies => {'translation'};

  /// 设置数据库连接
  void setDatabase(dynamic db) {
    _db = db;
  }

  /// 设置翻译数据源
  void setTranslationDataSource(dynamic dataSource) {
    _translationDataSource = dataSource;
  }

  /// 获取翻译数据源
  dynamic get translationDataSource => _translationDataSource;

  /// 根据标签名获取记录
  Future<DanbooruTagRecord?> getByName(String tag) async {
    if (tag.isEmpty || _db == null) return null;

    final normalizedTag = tag.toLowerCase().trim();

    try {
      final result = await _db.query(
        _tableName,
        columns: ['tag', 'category', 'post_count', 'last_updated'],
        where: 'tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      if (result.isEmpty) return null;

      return DanbooruTagRecord.fromMap(result.first);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get Danbooru tag "$normalizedTag"',
        e,
        stack,
        'DanbooruTagDS',
      );
      return null;
    }
  }

  /// 批量获取标签记录
  Future<List<DanbooruTagRecord>> getByNames(List<String> tags) async {
    if (tags.isEmpty || _db == null) return [];

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');

    try {
      final result = await _db.rawQuery(
        'SELECT tag, category, post_count, last_updated '
        'FROM $_tableName WHERE tag IN ($placeholders)',
        normalizedTags,
      );

      return result.map((row) => DanbooruTagRecord.fromMap(row)).toList();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to batch get Danbooru tags',
        e,
        stack,
        'DanbooruTagDS',
      );
      return [];
    }
  }

  /// 前缀搜索标签
  ///
  /// [prefix] 搜索前缀
  /// [limit] 返回结果数量限制
  /// [category] 可选的分类过滤
  Future<List<DanbooruTagRecord>> searchByPrefix(
    String prefix, {
    int limit = 20,
    TagCategory? category,
  }) async {
    if (prefix.isEmpty || _db == null) return [];

    final normalizedPrefix = prefix.toLowerCase().trim();

    try {
      if (category != null) {
        final result = await _db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'tag LIKE ? AND category = ?',
          whereArgs: ['$normalizedPrefix%', category.value],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return result.map((row) => DanbooruTagRecord.fromMap(row)).toList();
      } else {
        final result = await _db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'tag LIKE ?',
          whereArgs: ['$normalizedPrefix%'],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return result.map((row) => DanbooruTagRecord.fromMap(row)).toList();
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to search Danbooru tags by prefix',
        e,
        stack,
        'DanbooruTagDS',
      );
      return [];
    }
  }

  /// 搜索标签（支持多种模式）
  ///
  /// [query] 搜索关键词
  /// [mode] 搜索模式
  /// [limit] 返回结果数量限制
  Future<List<DanbooruTagRecord>> search(
    String query, {
    TagSearchMode mode = TagSearchMode.prefix,
    int limit = 20,
    TagCategory? category,
  }) async {
    if (query.isEmpty || _db == null) return [];

    final normalizedQuery = query.toLowerCase().trim();
    String pattern;

    switch (mode) {
      case TagSearchMode.prefix:
        pattern = '$normalizedQuery%';
      case TagSearchMode.contains:
        pattern = '%$normalizedQuery%';
      case TagSearchMode.suffix:
        pattern = '%$normalizedQuery';
    }

    try {
      if (category != null) {
        final result = await _db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'tag LIKE ? AND category = ?',
          whereArgs: [pattern, category.value],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return result.map((row) => DanbooruTagRecord.fromMap(row)).toList();
      } else {
        final result = await _db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'tag LIKE ?',
          whereArgs: [pattern],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return result.map((row) => DanbooruTagRecord.fromMap(row)).toList();
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to search Danbooru tags',
        e,
        stack,
        'DanbooruTagDS',
      );
      return [];
    }
  }

  /// 获取热门标签
  ///
  /// [limit] 返回结果数量限制
  /// [category] 可选的分类过滤
  Future<List<DanbooruTagRecord>> getHotTags({
    int limit = 50,
    TagCategory? category,
    bool useCache = true,
  }) async {
    if (_db == null) return [];

    // 使用缓存（如果不指定分类）
    if (useCache && category == null && _hotTagsCache != null) {
      return _hotTagsCache!.take(limit).toList();
    }

    try {
      if (category != null) {
        final result = await _db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'category = ?',
          whereArgs: [category.value],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return result.map((row) => DanbooruTagRecord.fromMap(row)).toList();
      } else {
        final result = await _db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        final tags = result.map((row) => DanbooruTagRecord.fromMap(row)).toList();

        // 更新缓存
        if (useCache) {
          _hotTagsCache = tags;
        }

        return tags;
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get hot Danbooru tags',
        e,
        stack,
        'DanbooruTagDS',
      );
      return [];
    }
  }

  /// 获取标签总数
  Future<int> getCount({TagCategory? category}) async {
    if (_db == null) return 0;

    try {
      if (category != null) {
        final result = await _db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName WHERE category = ?',
          [category.value],
        );
        return (result.first['count'] as num?)?.toInt() ?? 0;
      } else {
        final result = await _db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName',
        );
        return (result.first['count'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      AppLogger.w('Failed to get Danbooru tag count: $e', 'DanbooruTagDS');
      return 0;
    }
  }

  /// 检查标签是否存在
  Future<bool> exists(String tag) async {
    if (_db == null || tag.isEmpty) return false;

    try {
      final result = await _db.query(
        _tableName,
        columns: ['tag'],
        where: 'tag = ?',
        whereArgs: [tag.toLowerCase().trim()],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      AppLogger.w('Failed to check Danbooru tag existence: $e', 'DanbooruTagDS');
      return false;
    }
  }

  /// 批量检查标签是否存在
  Future<Set<String>> existsBatch(List<String> tags) async {
    if (_db == null || tags.isEmpty) return {};

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');

    try {
      final result = await _db.rawQuery(
        'SELECT tag FROM $_tableName WHERE tag IN ($placeholders)',
        normalizedTags,
      );

      return result.map((row) => row['tag'] as String).toSet();
    } catch (e) {
      AppLogger.w(
        'Failed to batch check Danbooru tag existence: $e',
        'DanbooruTagDS',
      );
      return {};
    }
  }

  /// 插入或更新标签记录
  Future<void> upsert(DanbooruTagRecord record) async {
    if (_db == null) throw StateError('Database not initialized');

    try {
      await _db.rawInsert(
        'INSERT OR REPLACE INTO $_tableName (tag, category, post_count, last_updated) VALUES (?, ?, ?, ?)',
        [
          record.tag.toLowerCase().trim(),
          record.category,
          record.postCount,
          record.lastUpdated,
        ],
      );

      // 清除热门标签缓存
      _hotTagsCache = null;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to upsert Danbooru tag',
        e,
        stack,
        'DanbooruTagDS',
      );
      rethrow;
    }
  }

  /// 批量插入标签记录
  Future<void> upsertBatch(List<DanbooruTagRecord> records) async {
    if (_db == null) throw StateError('Database not initialized');
    if (records.isEmpty) return;

    try {
      final batch = _db.batch();

      for (final record in records) {
        batch.rawInsert(
          'INSERT OR REPLACE INTO $_tableName (tag, category, post_count, last_updated) VALUES (?, ?, ?, ?)',
          [
            record.tag.toLowerCase().trim(),
            record.category,
            record.postCount,
            record.lastUpdated,
          ],
        );
      }

      await batch.commit(noResult: true);

      // 清除热门标签缓存
      _hotTagsCache = null;

      AppLogger.i(
        'Inserted ${records.length} Danbooru tag records',
        'DanbooruTagDS',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to batch upsert Danbooru tags',
        e,
        stack,
        'DanbooruTagDS',
      );
      rethrow;
    }
  }

  /// 获取分类统计
  Future<Map<TagCategory, int>> getCategoryStats() async {
    if (_db == null) return {};

    try {
      final result = await _db.rawQuery(
        'SELECT category, COUNT(*) as count FROM $_tableName GROUP BY category',
      );

      return {
        for (final row in result)
          TagCategory.fromInt((row['category'] as num?)?.toInt() ?? 0):
              (row['count'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      AppLogger.w('Failed to get category stats: $e', 'DanbooruTagDS');
      return {};
    }
  }

  @override
  Future<void> doInitialize() async {
    if (_db == null) {
      throw StateError('Database connection not set. Call setDatabase() first.');
    }

    // 验证表是否存在
    try {
      final result = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [_tableName],
      );

      if (result.isEmpty) {
        // 创建表
        await _db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableName (
            tag TEXT PRIMARY KEY,
            category INTEGER NOT NULL DEFAULT 0,
            post_count INTEGER NOT NULL DEFAULT 0 CHECK (post_count >= 0),
            last_updated INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // 创建索引
        await _db.execute('''
          CREATE INDEX IF NOT EXISTS idx_danbooru_tags_category 
          ON $_tableName(category)
        ''');

        await _db.execute('''
          CREATE INDEX IF NOT EXISTS idx_danbooru_tags_post_count 
          ON $_tableName(post_count DESC)
        ''');

        await _db.execute('''
          CREATE INDEX IF NOT EXISTS idx_danbooru_tags_category_post_count 
          ON $_tableName(category, post_count DESC)
        ''');

        AppLogger.i('Created danbooru_tags table', 'DanbooruTagDS');
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize danbooru_tags table',
        e,
        stack,
        'DanbooruTagDS',
      );
      rethrow;
    }
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    if (_db == null) {
      return DataSourceHealth(
        status: HealthStatus.corrupted,
        message: 'Database connection is null',
        timestamp: DateTime.now(),
      );
    }

    try {
      // 检查表是否存在
      final result = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [_tableName],
      );

      if (result.isEmpty) {
        return DataSourceHealth(
          status: HealthStatus.corrupted,
          message: 'Danbooru tags table does not exist',
          timestamp: DateTime.now(),
        );
      }

      // 尝试查询
      await _db.rawQuery('SELECT 1 FROM $_tableName LIMIT 1');

      final count = await getCount();
      final categoryStats = await getCategoryStats();

      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'Danbooru tag data source is healthy',
        details: {
          'recordCount': count,
          'categoryStats': categoryStats.map(
            (k, v) => MapEntry(k.name, v),
          ),
          'hotTagsCached': _hotTagsCache != null,
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

  @override
  Future<void> doClear() async {
    _hotTagsCache = null;
    AppLogger.i('Danbooru tag cache cleared', 'DanbooruTagDS');
  }

  @override
  Future<void> doRestore() async {
    _hotTagsCache = null;
    AppLogger.i('Danbooru tag data source ready for restore', 'DanbooruTagDS');
  }

  @override
  Future<void> doDispose() async {
    _hotTagsCache = null;
    _db = null;
    _translationDataSource = null;
  }
}
