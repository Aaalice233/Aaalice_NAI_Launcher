import '../../utils/app_logger.dart';
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

}
