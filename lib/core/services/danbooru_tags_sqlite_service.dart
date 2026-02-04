import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data/models/tag/local_tag.dart';
import '../utils/app_logger.dart';

/// 确保 SQLite FFI 已初始化
void _ensureSqliteFfiInitialized() {
  try {
    // 尝试访问 databaseFactory，如果未初始化会抛出异常
    databaseFactory;
  } catch (e) {
    // 未初始化，需要重新设置
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppLogger.i('SQLite FFI re-initialized', 'DanbooruTagsSqlite');
  }
}

/// SQLite Danbooru 标签服务
/// 使用数据库存储替代内存存储，支持按需查询
class DanbooruTagsSqliteService {
  static const String _databaseName = 'danbooru_tags.db';
  static const int _databaseVersion = 1;

  /// 数据库实例
  Database? _db;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 热数据缓存（高频标签）
  final Map<String, LocalTag> _hotCache = {};

  /// 最大热缓存条目数
  static const int _maxHotCacheSize = 1000;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取数据库实例
  Database get _database {
    if (_db == null) {
      throw StateError(
        'DanbooruTagsSqliteService not initialized. Call initialize() first.',
      );
    }
    return _db!;
  }

  /// 初始化数据库
  Future<void> initialize() async {
    // 确保 SQLite FFI 已初始化（清除缓存后可能需要重新初始化）
    _ensureSqliteFfiInitialized();

    // 如果已初始化，先关闭之前的连接（可能在清除缓存后重新初始化）
    if (_isInitialized && _db != null) {
      await close();
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final dbPath = path.join(appDir.path, 'databases', _databaseName);

      // 确保目录存在
      final dbDir = Directory(path.dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      _db = await openDatabase(
        dbPath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _isInitialized = true;
      AppLogger.i('Danbooru tags SQLite service initialized', 'DanbooruTagsSqlite');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize Danbooru tags SQLite service',
        e,
        stack,
        'DanbooruTagsSqlite',
      );
      rethrow;
    }
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 标签数据表
    await db.execute('''
      CREATE TABLE tags (
        tag TEXT PRIMARY KEY,
        category INTEGER NOT NULL DEFAULT 0,
        count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 创建索引以加速查询
    await db.execute('''
      CREATE INDEX idx_tag_name ON tags(tag)
    ''');

    await db.execute('''
      CREATE INDEX idx_category ON tags(category)
    ''');

    await db.execute('''
      CREATE INDEX idx_count ON tags(count DESC)
    ''');

    // 元数据表
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    AppLogger.i('Danbooru tags database tables created', 'DanbooruTagsSqlite');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.i(
      'Database upgrade from $oldVersion to $newVersion',
      'DanbooruTagsSqlite',
    );
  }

  /// 批量导入标签数据（使用事务提高性能）
  Future<void> importTags(
    List<LocalTag> tags, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    final stopwatch = Stopwatch()..start();
    var processed = 0;
    const batchSize = 1000;

    await _database.transaction((txn) async {
      // 先清空现有数据
      await txn.delete('tags');

      final batch = txn.batch();

      for (final tag in tags) {
        batch.insert(
          'tags',
          {
            'tag': tag.tag.toLowerCase(),
            'category': tag.category,
            'count': tag.count,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        processed++;

        // 定期提交批次
        if (processed % batchSize == 0) {
          await batch.commit(noResult: true);
          onProgress?.call(processed, tags.length);
        }
      }

      // 提交剩余批次
      await batch.commit(noResult: true);
    });

    stopwatch.stop();
    AppLogger.i(
      'Imported $processed tags in ${stopwatch.elapsedMilliseconds}ms',
      'DanbooruTagsSqlite',
    );

    // 更新统计信息
    await _updateMetadata('lastImport', DateTime.now().toIso8601String());
    await _updateMetadata('recordCount', processed.toString());
  }

  /// 获取单个标签
  Future<LocalTag?> getTag(String tag) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 先检查热缓存
    if (_hotCache.containsKey(normalizedTag)) {
      return _hotCache[normalizedTag];
    }

    if (!_isInitialized) return null;

    try {
      final results = await _database.query(
        'tags',
        where: 'tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final localTag = LocalTag(
        tag: results.first['tag'] as String,
        category: results.first['category'] as int,
        count: results.first['count'] as int,
      );

      // 加入热缓存
      _addToHotCache(normalizedTag, localTag);

      return localTag;
    } catch (e) {
      AppLogger.w('Failed to get tag "$tag": $e', 'DanbooruTagsSqlite');
      return null;
    }
  }

  /// 批量获取标签
  Future<List<LocalTag>> getTags(List<String> tags) async {
    if (tags.isEmpty) return [];
    if (!_isInitialized) return [];

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();
    final result = <LocalTag>[];

    // 先检查热缓存
    final uncachedTags = <String>[];
    for (final tag in normalizedTags) {
      if (_hotCache.containsKey(tag)) {
        result.add(_hotCache[tag]!);
      } else {
        uncachedTags.add(tag);
      }
    }

    if (uncachedTags.isEmpty) return result;

    try {
      // 使用 IN 查询批量获取
      final placeholders = List.filled(uncachedTags.length, '?').join(',');
      final dbResults = await _database.rawQuery('''
        SELECT tag, category, count
        FROM tags
        WHERE tag IN ($placeholders)
      ''',
        uncachedTags,
      );

      for (final row in dbResults) {
        final tag = LocalTag(
          tag: row['tag'] as String,
          category: row['category'] as int,
          count: row['count'] as int,
        );
        result.add(tag);
        _addToHotCache(tag.tag, tag);
      }

      return result;
    } catch (e) {
      AppLogger.w('Failed to get tags batch: $e', 'DanbooruTagsSqlite');
      return result;
    }
  }

  /// 搜索标签（用于标签联想）
  Future<List<LocalTag>> searchTags(
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
        'tags',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'count DESC',
        limit: limit,
      );

      return results
          .map(
            (row) => LocalTag(
              tag: row['tag'] as String,
              category: row['category'] as int,
              count: row['count'] as int,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.w('Failed to search tags: $e', 'DanbooruTagsSqlite');
      return [];
    }
  }

  /// 获取热门标签
  Future<List<LocalTag>> getHotTags({
    int? category,
    int minCount = 1000,
    int limit = 100,
  }) async {
    if (!_isInitialized) return [];

    try {
      var whereClause = 'count >= ?';
      final whereArgs = <dynamic>[minCount];

      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      final results = await _database.query(
        'tags',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'count DESC',
        limit: limit,
      );

      return results
          .map(
            (row) => LocalTag(
              tag: row['tag'] as String,
              category: row['category'] as int,
              count: row['count'] as int,
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.w('Failed to get hot tags: $e', 'DanbooruTagsSqlite');
      return [];
    }
  }

  /// 预加载热数据（高频标签）
  Future<void> loadHotData(Set<String> hotTags) async {
    if (!_isInitialized) return;

    try {
      final stopwatch = Stopwatch()..start();

      // 批量查询热标签
      final tags = await getTags(hotTags.toList());

      // 保存到热缓存
      for (final tag in tags) {
        _hotCache[tag.tag] = tag;
      }

      stopwatch.stop();
      AppLogger.i(
        'Loaded ${tags.length} hot tags into cache in ${stopwatch.elapsedMilliseconds}ms',
        'DanbooruTagsSqlite',
      );
    } catch (e) {
      AppLogger.w('Failed to load hot data: $e', 'DanbooruTagsSqlite');
    }
  }

  /// 添加数据到热缓存
  void _addToHotCache(String tag, LocalTag localTag) {
    if (_hotCache.length >= _maxHotCacheSize) {
      // 简单的LRU：移除第一个
      final firstKey = _hotCache.keys.first;
      _hotCache.remove(firstKey);
    }

    _hotCache[tag] = localTag;
  }

  /// 更新元数据
  Future<void> _updateMetadata(String key, String value) async {
    await _database.insert(
      'metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取元数据
  Future<String?> _getMetadata(String key) async {
    final results = await _database.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  /// 获取数据库中的记录数
  Future<int> getRecordCount() async {
    if (!_isInitialized) return 0;

    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM tags',
    );
    return (result.first['count'] as num).toInt();
  }

  /// 检查数据库是否已有数据
  Future<bool> hasData() async {
    if (!_isInitialized) return false;
    final count = await getRecordCount();
    return count > 0;
  }

  /// 获取上次导入时间
  Future<DateTime?> getLastImportTime() async {
    final value = await _getMetadata('lastImport');
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    if (!_isInitialized) return;

    await _database.delete('tags');
    await _database.delete('metadata');
    _hotCache.clear();

    AppLogger.i('All Danbooru tags data cleared', 'DanbooruTagsSqlite');
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
      _hotCache.clear();
      AppLogger.i('Danbooru tags SQLite service closed', 'DanbooruTagsSqlite');
    }
  }
}
