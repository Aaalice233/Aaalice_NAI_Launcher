import '../../utils/app_logger.dart';
import '../connection_pool_holder.dart';
import '../data_source.dart';
import '../lease_extensions.dart';

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
///
/// 关键改进：
/// 1. 不再直接持有数据库连接，每次操作从 ConnectionPoolHolder 获取
/// 2. recover() 后自动使用新的有效连接
/// 3. 支持热重启后重建
///
/// 新架构：使用 ConnectionLease 连接生命周期管理
class DanbooruTagDataSource extends BaseDataSource {
  static const String _tableName = 'danbooru_tags';

  // 可选的翻译数据源引用
  dynamic _translationDataSource;

  // 热门标签缓存
  List<DanbooruTagRecord>? _hotTagsCache;

  // 租借助手（新架构）
  final SimpleLeaseHelper _leaseHelper = SimpleLeaseHelper('DanbooruTagDataSource');

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
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 ConnectionLease 模式
  @Deprecated('请使用新架构方法替代')
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
            'DanbooruTagDS',
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
            'DanbooruTagDS',
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
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 ConnectionLease 模式
  @Deprecated('请使用新架构方法替代')
  Future<void> _releaseDb(dynamic db) async {
    await ConnectionPoolHolder.instance.release(db);
  }

  /// 根据标签名获取记录
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<DanbooruTagRecord?> getByName(String tag) async {
    if (tag.isEmpty) return null;

    final normalizedTag = tag.toLowerCase().trim();

    return await _leaseHelper.execute(
      'getByName',
      (db) async {
        final result = await db.query(
          _tableName,
          columns: ['tag', 'category', 'post_count', 'last_updated'],
          where: 'tag = ?',
          whereArgs: [normalizedTag],
          limit: 1,
        );

        if (result.isEmpty) return null;

        return DanbooruTagRecord.fromMap(result.first);
      },
    );
  }

  /// 根据标签名获取记录 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 getByName 方法
  @Deprecated('请使用新架构方法替代')
  Future<DanbooruTagRecord?> getByNameLegacy(String tag) async {
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
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<List<DanbooruTagRecord>> getByNames(List<String> tags) async {
    if (tags.isEmpty) return [];

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');

    return await _leaseHelper.execute(
      'getByNames',
      (db) async {
        final result = await db.rawQuery(
          'SELECT tag, category, post_count, last_updated '
          'FROM $_tableName WHERE tag IN ($placeholders)',
          normalizedTags,
        );

        return result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();
      },
    );
  }

  /// 批量获取标签记录 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 getByNames 方法
  @Deprecated('请使用新架构方法替代')
  Future<List<DanbooruTagRecord>> getByNamesLegacy(List<String> tags) async {
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
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<List<DanbooruTagRecord>> search(
    String query, {
    int limit = 20,
    int? category,
    int minPostCount = 0,
  }) async {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    return await _leaseHelper.execute(
      'search',
      (db) async {
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
      },
    );
  }

  /// 搜索标签（前缀匹配）- 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 search 方法
  @Deprecated('请使用新架构方法替代')
  Future<List<DanbooruTagRecord>> searchLegacy(
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
        'DanbooruTagDS',
      );
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 模糊搜索标签（包含匹配）
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<List<DanbooruTagRecord>> searchFuzzy(
    String query, {
    int limit = 20,
    int? category,
    int minPostCount = 0,
  }) async {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    return await _leaseHelper.execute(
      'searchFuzzy',
      (db) async {
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
      },
    );
  }

  /// 模糊搜索标签（包含匹配）- 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 searchFuzzy 方法
  @Deprecated('请使用新架构方法替代')
  Future<List<DanbooruTagRecord>> searchFuzzyLegacy(
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
        'DanbooruTagDS',
      );
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 获取热门标签
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
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

    return await _leaseHelper.execute(
      'getHotTags',
      (db) async {
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

        final tags = result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();

        // 缓存结果
        _hotTagsCache = tags;

        return tags;
      },
    );
  }

  /// 获取热门标签 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 getHotTags 方法
  @Deprecated('请使用新架构方法替代')
  Future<List<DanbooruTagRecord>> getHotTagsLegacy({
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

      final tags = result.map<DanbooruTagRecord>((row) => DanbooruTagRecord.fromMap(row)).toList();

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
    // 数据源不需要预初始化数据库连接
    // 连接在使用时动态从 Holder 获取
    // 但需要确保表结构已创建
    await _ensureTableExists();
  }

  /// 确保表结构存在
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<void> _ensureTableExists() async {
    await _leaseHelper.execute(
      'ensureTableExists',
      (db) async {
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

          AppLogger.i('Created danbooru_tags table', 'DanbooruTagDS');
        }
      },
    );
  }

  @override
  Future<DataSourceHealth> doCheckHealth() async {
    try {
      return await _leaseHelper.execute(
        'checkHealth',
        (db) async {
          // 简单的健康检查：尝试查询
          await db.rawQuery('SELECT 1');
          return DataSourceHealth(
            status: HealthStatus.healthy,
            message: 'DanbooruTagDataSource is healthy',
            timestamp: DateTime.now(),
          );
        },
      );
    } catch (e) {
      return DataSourceHealth(
        status: HealthStatus.degraded,
        message: 'DanbooruTagDataSource check failed: $e',
        timestamp: DateTime.now(),
      );
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
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<List<DanbooruTagRecord>> searchByPrefix(
    String prefix, {
    int limit = 20,
    int? category,
  }) async {
    if (prefix.isEmpty) return [];

    final normalizedPrefix = prefix.toLowerCase().trim();

    return await _leaseHelper.execute(
      'searchByPrefix',
      (db) async {
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
      },
    );
  }

  /// 根据前缀搜索标签 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 searchByPrefix 方法
  @Deprecated('请使用新架构方法替代')
  Future<List<DanbooruTagRecord>> searchByPrefixLegacy(
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
        'DanbooruTagDS',
      );
      return [];
    } finally {
      await _releaseDb(db);
    }
  }

  /// 检查标签是否存在
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<bool> exists(String tag) async {
    if (tag.isEmpty) return false;

    final normalizedTag = tag.toLowerCase().trim();

    return await _leaseHelper.execute(
      'exists',
      (db) async {
        final result = await db.query(
          _tableName,
          columns: ['tag'],
          where: 'tag = ?',
          whereArgs: [normalizedTag],
          limit: 1,
        );

        return result.isNotEmpty;
      },
    );
  }

  /// 检查标签是否存在 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 exists 方法
  @Deprecated('请使用新架构方法替代')
  Future<bool> existsLegacy(String tag) async {
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
      AppLogger.w('Failed to check Danbooru tag existence: $e', 'DanbooruTagDS');
      return false;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 批量检查标签是否存在
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<Set<String>> existsBatch(List<String> tags) async {
    if (tags.isEmpty) return {};

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final placeholders = normalizedTags.map((_) => '?').join(',');

    return await _leaseHelper.execute(
      'existsBatch',
      (db) async {
        final result = await db.rawQuery(
          'SELECT tag FROM $_tableName WHERE tag IN ($placeholders)',
          normalizedTags,
        );

        return result.map((row) => row['tag'] as String).toSet();
      },
    );
  }

  /// 批量检查标签是否存在 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 existsBatch 方法
  @Deprecated('请使用新架构方法替代')
  Future<Set<String>> existsBatchLegacy(List<String> tags) async {
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
        'DanbooruTagDS',
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
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<int> getCount({int? category}) async {
    return await _leaseHelper.execute(
      'getCount',
      (db) async {
        if (category != null) {
          final result = await db.rawQuery(
            'SELECT COUNT(*) as count FROM $_tableName WHERE category = ?',
            [category],
          );
          return (result.first['count'] as num?)?.toInt() ?? 0;
        } else {
          final result = await db.rawQuery(
            'SELECT COUNT(*) as count FROM $_tableName',
          );
          return (result.first['count'] as num?)?.toInt() ?? 0;
        }
      },
    );
  }

  /// 获取标签总数 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 getCount 方法
  @Deprecated('请使用新架构方法替代')
  Future<int> getCountLegacy({int? category}) async {
    AppLogger.i(
      '[DatabaseQuery] DanbooruTagDataSource.getCount() START - category=$category, table=$_tableName',
      'DanbooruTagDS',
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
          '[DatabaseQuery] DanbooruTagDataSource.getCount() END - category=$category, count=$count',
          'DanbooruTagDS',
        );
        return count;
      } else {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $_tableName',
        );
        final count = (result.first['count'] as num?)?.toInt() ?? 0;
        AppLogger.i(
          '[DatabaseQuery] DanbooruTagDataSource.getCount() END - total count=$count',
          'DanbooruTagDS',
        );
        return count;
      }
    } catch (e) {
      AppLogger.e(
        '[DatabaseQuery] DanbooruTagDataSource.getCount() FAILED - returning 0',
        e,
        null,
        'DanbooruTagDS',
      );
      return 0;
    } finally {
      await _releaseDb(db);
    }
  }

  /// 批量插入标签记录
  ///
  /// 使用新架构：ConnectionLease 连接生命周期管理
  Future<void> upsertBatch(List<DanbooruTagRecord> records) async {
    if (records.isEmpty) return;

    await _leaseHelper.execute(
      'upsertBatch',
      (db) async {
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
      },
    );
  }

  /// 批量插入标签记录 - 旧实现
  ///
  /// @Deprecated('请使用新架构方法替代') 请使用 upsertBatch 方法
  @Deprecated('请使用新架构方法替代')
  Future<void> upsertBatchLegacy(List<DanbooruTagRecord> records) async {
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
        'DanbooruTagDS',
      );
      rethrow;
    } finally {
      await _releaseDb(db);
    }
  }
}
