import '../../utils/app_logger.dart';
import '../connection_pool_holder.dart';
import '../data_source.dart';
import 'danbooru_tag_data_source.dart';

export 'danbooru_tag_data_source.dart' show DanbooruTagRecord, TagCategory, TagSearchMode;

/// Danbooru 标签数据源 V2
/// 
/// 关键改进：
/// 1. 不再直接持有数据库连接，每次操作从 ConnectionPoolHolder 获取
/// 2. recover() 后自动使用新的有效连接
/// 3. 支持热重启后重建
class DanbooruTagDataSourceV2 extends BaseDataSource {
  static const String _tableName = 'danbooru_tags';

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

  /// 设置翻译数据源
  void setTranslationDataSource(dynamic dataSource) {
    _translationDataSource = dataSource;
  }

  /// 获取翻译数据源
  dynamic get translationDataSource => _translationDataSource;

  /// 获取数据库连接（从 Holder 获取当前有效实例）
  Future<dynamic> _acquireDb() async {
    // 关键修复：如果连接池未初始化（可能正在重置），等待并重试
    var retryCount = 0;
    const maxRetries = 10;

    while (retryCount < maxRetries) {
      try {
        if (!ConnectionPoolHolder.isInitialized) {
          throw StateError('Connection pool not initialized');
        }
        final db = await ConnectionPoolHolder.instance.acquire();

        // 关键修复：验证连接是否真正可用（可能被外部关闭）
        try {
          await db.rawQuery('SELECT 1');
          return db;
        } catch (e) {
          // 连接无效，释放它并让循环重试
          AppLogger.w(
            'Acquired connection is invalid, releasing and retrying...',
            'DanbooruTagDSV2',
          );
          try {
            await ConnectionPoolHolder.instance.release(db);
          } catch (_) {
            // 忽略释放错误
          }
          throw StateError('Database connection invalid');
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        final isDbClosed = errorStr.contains('database_closed') ||
            errorStr.contains('not initialized') ||
            errorStr.contains('connection invalid');
        if (isDbClosed && retryCount < maxRetries - 1) {
          retryCount++;
          AppLogger.w(
            'Database connection not ready, retrying ($retryCount/$maxRetries)...',
            'DanbooruTagDSV2',
          );
          // 指数退避：100ms, 200ms, 400ms...
          await Future.delayed(
            Duration(milliseconds: 100 * (1 << (retryCount - 1))),
          );
        } else {
          rethrow;
        }
      }
    }
    
    throw StateError('Failed to acquire database connection after $maxRetries retries');
  }

  /// 释放数据库连接
  Future<void> _releaseDb(dynamic db) async {
    await ConnectionPoolHolder.instance.release(db);
  }

  /// 根据标签名获取记录
  Future<DanbooruTagRecord?> getByName(String tag) async {
    if (tag.isEmpty) return null;

    final normalizedTag = tag.toLowerCase().trim();
    final db = await _acquireDb();

    try {
      final result = await db.query(
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
    } finally {
      await _releaseDb(db);
    }
  }

  /// 批量获取标签记录
  Future<List<DanbooruTagRecord>> getByNames(List<String> tags) async {
    if (tags.isEmpty) return [];

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');
    final db = await _acquireDb();

    try {
      final result = await db.rawQuery(
        'SELECT tag, category, post_count, last_updated '
        'FROM $_tableName WHERE tag IN ($placeholders)',
        normalizedTags,
      );

      return result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();
    } catch (e, stack) {
      AppLogger.e('Failed to get Danbooru tags batch', e, stack, 'DanbooruTagDS');
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 搜索标签（前缀匹配）
  Future<List<DanbooruTagRecord>> search(
    String query, {
    int limit = 20,
    int? category,
    int minPostCount = 0,
  }) async {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();
    final db = await _acquireDb();

    try {
      String whereClause = 'tag LIKE ?';
      final List<dynamic> whereArgs = ['$normalizedQuery%'];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      if (minPostCount > 0) {
        whereClause += ' AND post_count >= ?';
        whereArgs.add(minPostCount);
      }

      final result = await db.query(
        _tableName,
        columns: ['tag', 'category', 'post_count', 'last_updated'],
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'post_count DESC',
        limit: limit,
      );

      return result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to search Danbooru tags',
        e,
        stack,
        'DanbooruTagDSV2',
      );
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 模糊搜索标签（包含匹配）
  Future<List<DanbooruTagRecord>> searchFuzzy(
    String query, {
    int limit = 20,
    int? category,
    int minPostCount = 0,
  }) async {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();
    final db = await _acquireDb();

    try {
      String whereClause = 'tag LIKE ?';
      final List<dynamic> whereArgs = ['%$normalizedQuery%'];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      if (minPostCount > 0) {
        whereClause += ' AND post_count >= ?';
        whereArgs.add(minPostCount);
      }

      final result = await db.query(
        _tableName,
        columns: ['tag', 'category', 'post_count', 'last_updated'],
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'post_count DESC',
        limit: limit,
      );

      return result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to fuzzy search Danbooru tags',
        e,
        stack,
        'DanbooruTagDSV2',
      );
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 获取热门标签
  Future<List<DanbooruTagRecord>> getHotTags({
    int limit = 100,
    int? category,
    int minPostCount = 1000,
  }) async {
    // 检查缓存
    if (_hotTagsCache != null) {
      return _hotTagsCache!.where((tag) {
        if (category != null && tag.category != category) return false;
        if (tag.postCount < minPostCount) return false;
        return true;
      }).take(limit).toList();
    }

    final db = await _acquireDb();

    try {
      String whereClause = 'post_count >= ?';
      final List<dynamic> whereArgs = [minPostCount];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      final result = await db.query(
        _tableName,
        columns: ['tag', 'category', 'post_count', 'last_updated'],
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'post_count DESC',
        limit: limit,
      );

      final tags = result.map((row) => DanbooruTagRecord.fromMap(row)).toList();

      // 缓存结果
      _hotTagsCache = tags;

      return tags;
    } catch (e, stack) {
      AppLogger.e('Failed to get hot tags', e, stack, 'DanbooruTagDS');
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 清除缓存
  void clearCache() {
    _hotTagsCache = null;
  }

  // ===== 实现 BaseDataSource 的抽象方法 =====

  @override
  Future<void> doInitialize() async {
    // V2 数据源不需要预初始化数据库连接
    // 连接在使用时动态从 Holder 获取
    // 但需要确保表结构已创建
    await _ensureTableExists();
  }

  /// 确保表结构存在
  Future<void> _ensureTableExists() async {
    final db = await _acquireDb();

    try {
      // 验证表是否存在
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [_tableName],
      );

      if (result.isEmpty) {
        // 创建表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableName (
            tag TEXT PRIMARY KEY,
            category INTEGER NOT NULL DEFAULT 0,
            post_count INTEGER NOT NULL DEFAULT 0 CHECK (post_count >= 0),
            last_updated INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // 创建索引
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_danbooru_tags_category
          ON $_tableName(category)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_danbooru_tags_post_count
          ON $_tableName(post_count DESC)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_danbooru_tags_category_post_count
          ON $_tableName(category, post_count DESC)
        ''');

        AppLogger.i('Created danbooru_tags table', 'DanbooruTagDSV2');
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize danbooru_tags table',
        e,
        stack,
        'DanbooruTagDSV2',
      );
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    final db = await _acquireDb();

    try {
      // 简单的健康检查：尝试查询
      await db.rawQuery('SELECT 1');
      return DataSourceHealth(
        status: HealthStatus.healthy,
        message: 'DanbooruTagDataSource is healthy',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return DataSourceHealth(
        status: HealthStatus.degraded,
        message: 'DanbooruTagDataSource check failed: $e',
        timestamp: DateTime.now(),
      );
    } finally {
      await _releaseDb(db);
    }
  }

  @override
  Future<void> doClear() async {
    clearCache();
  }

  @override
  Future<void> doRestore() async {
    clearCache();
  }

  /// 根据前缀搜索标签
  ///
  /// [prefix] 搜索前缀
  /// [limit] 返回结果数量限制
  /// [category] 可选的分类过滤
  Future<List<DanbooruTagRecord>> searchByPrefix(
    String prefix, {
    int limit = 20,
    int? category,
  }) async {
    if (prefix.isEmpty) return [];

    final normalizedPrefix = prefix.toLowerCase().trim();
    final db = await _acquireDb();

    try {
      if (category != null) {
        final result = await db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'tag LIKE ? AND category = ?',
          whereArgs: ['$normalizedPrefix%', category],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();
      } else {
        final result = await db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'tag LIKE ?',
          whereArgs: ['$normalizedPrefix%'],
          orderBy: 'post_count DESC',
          limit: limit,
        );

        return result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to search Danbooru tags by prefix',
        e,
        stack,
        'DanbooruTagDSV2',
      );
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 检查标签是否存在
  Future<bool> exists(String tag) async {
    if (tag.isEmpty) return false;

    final normalizedTag = tag.toLowerCase().trim();
    final db = await _acquireDb();

    try {
      final result = await db.query(
        _tableName,
        columns: ['tag'],
        where: 'tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      AppLogger.w('Failed to check Danbooru tag existence: $e', 'DanbooruTagDSV2');
      return false;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 批量检查标签是否存在
  Future<Set<String>> existsBatch(List<String> tags) async {
    if (tags.isEmpty) return {};

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');
    final db = await _acquireDb();

    try {
      final result = await db.rawQuery(
        'SELECT tag FROM $_tableName WHERE tag IN ($placeholders)',
        normalizedTags,
      );

      return result.map((row) => row['tag'] as String).toSet();
    } catch (e) {
      AppLogger.w(
        'Failed to batch check Danbooru tag existence: $e',
        'DanbooruTagDSV2',
      );
      return {};
    } finally {
      await _releaseDb(db);
    }
  }

  @override
  Future<void> doDispose() async {
    clearCache();
  }

  /// 获取标签总数
  Future<int> getCount({int? category}) async {
    AppLogger.i(
      '[DatabaseQuery] DanbooruTagDataSourceV2.getCount() START - category=$category, table=$_tableName',
      'DanbooruTagDSV2',
    );
    final db = await _acquireDb();

    try {
      if (category != null) {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName WHERE category = ?',
          [category],
        );
        final count = (result.first['count'] as num?)?.toInt() ?? 0;
        AppLogger.i(
          '[DatabaseQuery] DanbooruTagDataSourceV2.getCount() END - category=$category, count=$count',
          'DanbooruTagDSV2',
        );
        return count;
      } else {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName',
        );
        final count = (result.first['count'] as num?)?.toInt() ?? 0;
        AppLogger.i(
          '[DatabaseQuery] DanbooruTagDataSourceV2.getCount() END - total count=$count',
          'DanbooruTagDSV2',
        );
        return count;
      }
    } catch (e) {
      AppLogger.e(
        '[DatabaseQuery] DanbooruTagDataSourceV2.getCount() FAILED - returning 0',
        e,
        null,
        'DanbooruTagDSV2',
      );
      return 0;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 批量插入标签记录
  Future<void> upsertBatch(List<DanbooruTagRecord> records) async {
    if (records.isEmpty) return;

    final db = await _acquireDb();

    try {
      final batch = db.batch();

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
    } catch (e, stack) {
      AppLogger.e(
        'Failed to upsert Danbooru tags batch',
        e,
        stack,
        'DanbooruTagDSV2',
      );
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }
}
