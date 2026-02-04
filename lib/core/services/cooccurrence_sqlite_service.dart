import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'cooccurrence_service.dart';

/// 确保 SQLite FFI 已初始化
void _ensureSqliteFfiInitialized() {
  try {
    // 尝试访问 databaseFactory，如果未初始化会抛出异常
    databaseFactory;
  } catch (e) {
    // 未初始化，需要重新设置
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppLogger.i('SQLite FFI re-initialized', 'CooccurrenceSqlite');
  }
}

/// SQLite 共现数据服务
/// 使用数据库存储替代内存存储，支持按需查询
class CooccurrenceSqliteService {
  static const String _databaseName = 'cooccurrence.db';
  static const int _databaseVersion = 1;

  /// 数据库实例
  Database? _db;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 热数据缓存（高频标签）
  final Map<String, List<RelatedTag>> _hotCache = {};

  /// 热数据阈值（出现次数超过此值的标签视为热数据）
  static const int _hotThreshold = 10000;

  /// 最大热缓存条目数
  static const int _maxHotCacheSize = 1000;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取数据库实例
  Database get _database {
    if (_db == null) {
      throw StateError('CooccurrenceSqliteService not initialized. Call initialize() first.');
    }
    return _db!;
  }

  /// 初始化数据库
  Future<void> initialize() async {
    // 确保 SQLite FFI 已初始化（清除缓存后可能需要重新初始化）
    _ensureSqliteFfiInitialized();

    if (_isInitialized) return;

    try {
      final appDir = await getApplicationSupportDirectory();
      final dbPath = path.join(appDir.path, 'databases', _databaseName);

      // 确保目录存在
      final dbDir = Directory(path.dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      // 检查数据库文件是否被锁定，如果被锁定则删除重新创建
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        try {
          // 尝试以独占模式打开文件，如果失败说明文件被锁定
          final testAccess = await dbFile.open(mode: FileMode.write);
          await testAccess.close();
        } catch (e) {
          AppLogger.w('Database file is locked, attempting to delete and recreate: $e', 'CooccurrenceSqlite');
          try {
            await dbFile.delete();
            AppLogger.i('Locked database file deleted successfully', 'CooccurrenceSqlite');
          } catch (deleteError) {
            AppLogger.e('Failed to delete locked database file', deleteError, null, 'CooccurrenceSqlite');
          }
        }
      }

      _db = await openDatabase(
        dbPath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // 使用单实例模式，但设置忙等待超时
        singleInstance: true,
      );

      // 设置 SQLite 忙等待超时（5秒）
      await _db!.execute('PRAGMA busy_timeout = 5000');

      _isInitialized = true;
      AppLogger.i('Cooccurrence SQLite service initialized', 'CooccurrenceSqlite');

      // 预加载热数据
      await _loadHotData();
    } catch (e, stack) {
      AppLogger.e('Failed to initialize Cooccurrence SQLite service', e, stack, 'CooccurrenceSqlite');
      rethrow;
    }
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 共现数据表
    await db.execute('''
      CREATE TABLE cooccurrence (
        tag1 TEXT NOT NULL,
        tag2 TEXT NOT NULL,
        count INTEGER NOT NULL,
        PRIMARY KEY (tag1, tag2)
      )
    ''');

    // 创建索引以加速查询
    await db.execute('''
      CREATE INDEX idx_tag1 ON cooccurrence(tag1)
    ''');

    await db.execute('''
      CREATE INDEX idx_count ON cooccurrence(count DESC)
    ''');

    // 元数据表
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    AppLogger.i('Cooccurrence database tables created', 'CooccurrenceSqlite');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本升级逻辑
    AppLogger.i('Database upgrade from $oldVersion to $newVersion', 'CooccurrenceSqlite');
  }

  /// 从CSV批量导入数据（使用事务提高性能）
  Future<void> importFromCsv(List<String> lines, {
    void Function(int processed, int total)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    final stopwatch = Stopwatch()..start();
    var processed = 0;
    // 减小批次大小，避免单次事务过大
    const batchSize = 2000;

    await _database.transaction((txn) async {
      final batch = txn.batch();

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.isEmpty) continue;

        // 跳过标题行
        if (i == 0 && line.contains(',')) continue;

        // 移除可能的引号包裹
        if (line.startsWith('"') && line.endsWith('"')) {
          line = line.substring(1, line.length - 1);
        }

        final parts = line.split(',');
        if (parts.length >= 3) {
          final tag1 = parts[0].trim().toLowerCase();
          final tag2 = parts[1].trim().toLowerCase();
          final countStr = parts[2].trim();
          final count = double.tryParse(countStr)?.toInt() ?? 0;

          if (tag1.isNotEmpty && tag2.isNotEmpty && count > 0) {
            // 插入双向关系
            batch.insert(
              'cooccurrence',
              {'tag1': tag1, 'tag2': tag2, 'count': count},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            batch.insert(
              'cooccurrence',
              {'tag1': tag2, 'tag2': tag1, 'count': count},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        processed++;

        // 定期提交批次
        if (processed % batchSize == 0) {
          await batch.commit(noResult: true);
          onProgress?.call(processed, lines.length);
        }
      }

      // 提交剩余批次
      await batch.commit(noResult: true);
    });

    stopwatch.stop();
    AppLogger.i(
      'Imported $processed cooccurrence records in ${stopwatch.elapsedMilliseconds}ms',
      'CooccurrenceSqlite',
    );

    // 更新统计信息
    await _updateMetadata('lastImport', DateTime.now().toIso8601String());
    await _updateMetadata('recordCount', processed.toString());
  }

  /// 获取相关标签（使用数据库查询）
  Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 先检查热缓存
    if (_hotCache.containsKey(normalizedTag)) {
      return _hotCache[normalizedTag]!.take(limit).toList();
    }

    if (!_isInitialized) {
      return [];
    }

    try {
      final results = await _database.query(
        'cooccurrence',
        columns: ['tag2', 'count'],
        where: 'tag1 = ?',
        whereArgs: [normalizedTag],
        orderBy: 'count DESC',
        limit: limit,
      );

      final tags = results.map((row) {
        return RelatedTag(
          tag: row['tag2'] as String,
          count: row['count'] as int,
        );
      }).toList();

      // 加入热缓存
      _addToHotCache(normalizedTag, tags);

      return tags;
    } catch (e) {
      AppLogger.w('Failed to get related tags for "$tag": $e', 'CooccurrenceSqlite');
      return [];
    }
  }

  /// 获取多个标签的相关标签（交集优先）
  Future<List<RelatedTag>> getRelatedTagsForMultiple(
    List<String> tags, {
    int limit = 20,
  }) async {
    if (tags.isEmpty) return [];
    if (tags.length == 1) return getRelatedTags(tags.first, limit: limit);

    final normalizedTags = tags.map((t) => t.toLowerCase().trim()).toList();

    if (!_isInitialized) {
      return [];
    }

    try {
      // 使用 SQL 聚合查询
      final placeholders = List.filled(normalizedTags.length, '?').join(',');
      final results = await _database.rawQuery('''
        SELECT tag2, SUM(count) as total_count
        FROM cooccurrence
        WHERE tag1 IN ($placeholders)
          AND tag2 NOT IN ($placeholders)
        GROUP BY tag2
        ORDER BY total_count DESC
        LIMIT ?
      ''', [
        ...normalizedTags,
        ...normalizedTags,
        limit,
      ],);

      return results.map((row) {
        return RelatedTag(
          tag: row['tag2'] as String,
          count: (row['total_count'] as num).toInt(),
        );
      }).toList();
    } catch (e) {
      AppLogger.w('Failed to get related tags for multiple: $e', 'CooccurrenceSqlite');
      return [];
    }
  }

  /// 预加载热数据（高频标签）
  Future<void> _loadHotData() async {
    if (!_isInitialized) return;

    try {
      final stopwatch = Stopwatch()..start();

      // 查询出现频率最高的标签作为热数据
      final results = await _database.rawQuery('''
        SELECT tag1, tag2, count
        FROM cooccurrence
        WHERE count >= ?
        ORDER BY count DESC
        LIMIT ?
      ''', [
        _hotThreshold,
        _maxHotCacheSize * 10,
      ],);

      // 组织成热缓存
      for (final row in results) {
        final tag1 = row['tag1'] as String;
        final tag2 = row['tag2'] as String;
        final count = row['count'] as int;

        _hotCache.putIfAbsent(tag1, () => []).add(
          RelatedTag(tag: tag2, count: count),
        );

        // 限制缓存大小
        if (_hotCache.length >= _maxHotCacheSize) break;
      }

      stopwatch.stop();
      AppLogger.i(
        'Loaded ${_hotCache.length} hot tags into cache in ${stopwatch.elapsedMilliseconds}ms',
        'CooccurrenceSqlite',
      );
    } catch (e) {
      AppLogger.w('Failed to load hot data: $e', 'CooccurrenceSqlite');
    }
  }

  /// 添加数据到热缓存
  void _addToHotCache(String tag, List<RelatedTag> tags) {
    if (_hotCache.length >= _maxHotCacheSize) {
      // 简单的LRU：随机移除一个
      final firstKey = _hotCache.keys.first;
      _hotCache.remove(firstKey);
    }

    _hotCache[tag] = tags;
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

    final result = await _database.rawQuery('SELECT COUNT(*) as count FROM cooccurrence');
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

    await _database.delete('cooccurrence');
    await _database.delete('metadata');
    _hotCache.clear();

    AppLogger.i('All cooccurrence data cleared', 'CooccurrenceSqlite');
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
      _hotCache.clear();
      AppLogger.i('Cooccurrence SQLite service closed', 'CooccurrenceSqlite');
    }
  }
}
