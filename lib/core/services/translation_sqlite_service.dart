import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    AppLogger.i('SQLite FFI re-initialized', 'TranslationSqlite');
  }
}

/// SQLite 翻译数据服务
/// 使用数据库存储替代内存存储，支持按需查询
class TranslationSqliteService {
  static const String _databaseName = 'translation.db';
  static const int _databaseVersion = 1;

  /// 数据库实例
  Database? _db;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 热数据缓存（高频标签）
  final Map<String, String> _hotCache = {};

  /// 最大热缓存条目数
  static const int _maxHotCacheSize = 500;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取数据库实例
  Database get _database {
    if (_db == null) {
      throw StateError(
        'TranslationSqliteService not initialized. Call initialize() first.',
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
      AppLogger.i('Translation SQLite service initialized', 'TranslationSqlite');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize Translation SQLite service',
        e,
        stack,
        'TranslationSqlite',
      );
      rethrow;
    }
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 翻译数据表
    await db.execute('''
      CREATE TABLE translations (
        tag TEXT PRIMARY KEY,
        translation TEXT NOT NULL,
        category INTEGER DEFAULT 0,
        count INTEGER DEFAULT 0
      )
    ''');

    // 创建索引以加速查询
    await db.execute('''
      CREATE INDEX idx_tag ON translations(tag)
    ''');

    // 元数据表
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    AppLogger.i('Translation database tables created', 'TranslationSqlite');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.i(
      'Database upgrade from $oldVersion to $newVersion',
      'TranslationSqlite',
    );
  }

  /// 从CSV批量导入数据（使用事务提高性能）
  Future<void> importFromCsv(
    List<String> lines, {
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
      await txn.delete('translations');

      final batch = txn.batch();

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.isEmpty) continue;

        // 跳过标题行
        if (i == 0 && line.toLowerCase().startsWith('tag,')) continue;

        // 移除可能的引号包裹
        if (line.startsWith('"') && line.endsWith('"')) {
          line = line.substring(1, line.length - 1);
        }

        final parts = line.split(',');
        if (parts.length >= 4) {
          final tag = parts[0].trim().toLowerCase();
          final category = int.tryParse(parts[1].trim()) ?? 0;
          final count = int.tryParse(parts[2].trim()) ?? 0;
          final alias = parts[3].trim();

          // 如果 alias 包含中文字符，使用它作为翻译
          if (tag.isNotEmpty && alias.isNotEmpty && _containsChinese(alias)) {
            batch.insert(
              'translations',
              {
                'tag': tag,
                'translation': alias,
                'category': category,
                'count': count,
              },
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
      'Imported $processed translation records in ${stopwatch.elapsedMilliseconds}ms',
      'TranslationSqlite',
    );

    // 更新统计信息
    await _updateMetadata('lastImport', DateTime.now().toIso8601String());
    await _updateMetadata('recordCount', processed.toString());
  }

  /// 检查字符串是否包含中文
  static bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
  }

  /// 获取单个标签的翻译
  Future<String?> getTranslation(String tag) async {
    final normalizedTag = tag.toLowerCase().trim();

    // 先检查热缓存
    if (_hotCache.containsKey(normalizedTag)) {
      return _hotCache[normalizedTag];
    }

    if (!_isInitialized) {
      return null;
    }

    try {
      final results = await _database.query(
        'translations',
        columns: ['translation'],
        where: 'tag = ?',
        whereArgs: [normalizedTag],
        limit: 1,
      );

      if (results.isEmpty) return null;

      final translation = results.first['translation'] as String;

      // 加入热缓存
      _addToHotCache(normalizedTag, translation);

      return translation;
    } catch (e) {
      AppLogger.w(
        'Failed to get translation for "$tag": $e',
        'TranslationSqlite',
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
      if (_hotCache.containsKey(tag)) {
        result[tag] = _hotCache[tag]!;
      } else {
        uncachedTags.add(tag);
      }
    }

    if (uncachedTags.isEmpty) return result;

    try {
      // 使用 IN 查询批量获取
      final placeholders = List.filled(uncachedTags.length, '?').join(',');
      final dbResults = await _database.rawQuery('''
        SELECT tag, translation
        FROM translations
        WHERE tag IN ($placeholders)
      ''',
        uncachedTags,
      );

      for (final row in dbResults) {
        final tag = row['tag'] as String;
        final translation = row['translation'] as String;
        result[tag] = translation;
        _addToHotCache(tag, translation);
      }

      return result;
    } catch (e) {
      AppLogger.w('Failed to get translations batch: $e', 'TranslationSqlite');
      return result;
    }
  }

  /// 搜索翻译（用于标签联想）
  Future<List<Map<String, String>>> searchTranslations(
    String query, {
    int limit = 20,
  }) async {
    if (!_isInitialized) return [];

    final normalizedQuery = query.toLowerCase().trim();

    try {
      final results = await _database.query(
        'translations',
        columns: ['tag', 'translation'],
        where: 'tag LIKE ? OR translation LIKE ?',
        whereArgs: ['%$normalizedQuery%', '%$normalizedQuery%'],
        orderBy: 'count DESC',
        limit: limit,
      );

      return results
          .map(
            (row) => {
              'tag': row['tag'] as String,
              'translation': row['translation'] as String,
            },
          )
          .toList();
    } catch (e) {
      AppLogger.w('Failed to search translations: $e', 'TranslationSqlite');
      return [];
    }
  }

  /// 预加载热数据（高频标签）
  Future<void> loadHotData(Set<String> hotTags) async {
    if (!_isInitialized) return;

    try {
      final stopwatch = Stopwatch()..start();

      // 批量查询热标签
      final translations = await getTranslations(hotTags.toList());

      // 保存到热缓存
      for (final entry in translations.entries) {
        _hotCache[entry.key] = entry.value;
      }

      stopwatch.stop();
      AppLogger.i(
        'Loaded ${translations.length} hot translations into cache in ${stopwatch.elapsedMilliseconds}ms',
        'TranslationSqlite',
      );
    } catch (e) {
      AppLogger.w('Failed to load hot data: $e', 'TranslationSqlite');
    }
  }

  /// 添加数据到热缓存
  void _addToHotCache(String tag, String translation) {
    if (_hotCache.length >= _maxHotCacheSize) {
      // 简单的LRU：移除第一个
      final firstKey = _hotCache.keys.first;
      _hotCache.remove(firstKey);
    }

    _hotCache[tag] = translation;
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
      'SELECT COUNT(*) as count FROM translations',
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

    await _database.delete('translations');
    await _database.delete('metadata');
    _hotCache.clear();

    AppLogger.i('All translation data cleared', 'TranslationSqlite');
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
      _hotCache.clear();
      AppLogger.i('Translation SQLite service closed', 'TranslationSqlite');
    }
  }
}
