import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';

/// 数据库连接管理器
/// 
/// 负责管理数据库连接的生命周期，包括：
/// - 初始化和打开连接
/// - 检测连接健康状态
/// - 自动重建损坏的连接
/// - 确保所有操作使用有效的连接
class TagDatabaseConnection {
  static const String _databaseName = 'tag_data.db';
  static const int _databaseVersion = 2;
  
  Database? _db;
  bool _isInitializing = false;
  final _initCompleter = Completer<void>();
  
  /// 获取数据库实例（可能为 null）
  Database? get db => _db;
  
  /// 检查数据库是否已初始化且连接有效
  bool get isConnected => _db != null;
  
  /// 确保数据库已初始化
  Future<void> initialize() async {
    if (_isInitializing) {
      return _initCompleter.future;
    }
    
    if (_db != null) {
      return;
    }
    
    _isInitializing = true;
    
    try {
      await _openDatabase();
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e, stack) {
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stack);
      }
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }
  
  /// 重新初始化数据库连接
  Future<void> reconnect() async {
    AppLogger.w('Reconnecting to database...', 'TagDatabaseConnection');
    await _closeConnection();
    await initialize();
  }
  
  /// 关闭数据库连接
  Future<void> dispose() async {
    await _closeConnection();
  }
  
  /// 检查连接是否健康
  Future<bool> checkHealth() async {
    if (_db == null) return false;
    try {
      await _db!.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 重建数据库（当检测到损坏时）
  Future<void> rebuild() async {
    AppLogger.w('Rebuilding database...', 'TagDatabaseConnection');
    
    await _closeConnection();
    
    final dbPath = await _getDatabasePath();
    
    // 删除所有相关文件
    final filesToDelete = [
      dbPath,
      '$dbPath-wal',
      '$dbPath-shm',
    ];
    
    for (final filePath in filesToDelete) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          AppLogger.i('Deleted: $filePath', 'TagDatabaseConnection');
        }
      } catch (e) {
        AppLogger.w('Failed to delete $filePath: $e', 'TagDatabaseConnection');
      }
    }
    
    // 重新打开数据库
    await _openDatabase();
    AppLogger.i('Database rebuilt successfully', 'TagDatabaseConnection');
  }

  /// 有效的数据表名称集合
  static const Set<String> _validTables = {
    'danbooru_tags',
    'translations',
    'cooccurrences',
    'metadata',
  };

  /// 清空所有数据表（用于"清除缓存"功能）
  /// 相比删除文件，此方法避免 Windows 文件锁定问题
  Future<void> clearAllTables() async {
    AppLogger.i('Clearing all database tables...', 'TagDatabaseConnection');

    // 确保数据库已连接
    if (_db == null) {
      await initialize();
    }

    if (_db == null) {
      AppLogger.w('Database not connected, nothing to clear', 'TagDatabaseConnection');
      return;
    }

    await _db!.transaction((txn) async {
      for (final table in _validTables) {
        await txn.execute('DELETE FROM $table');
      }
    });

    await _db!.execute('VACUUM');

    AppLogger.i('All tables cleared successfully', 'TagDatabaseConnection');
  }

  /// 清空指定数据源的表
  Future<void> clearTable(String tableName) async {
    if (_db == null) {
      throw StateError('Database not connected');
    }

    if (!_validTables.contains(tableName)) {
      throw ArgumentError('Invalid table name: $tableName');
    }

    await _db!.execute('DELETE FROM $tableName');
    AppLogger.i('Table $tableName cleared', 'TagDatabaseConnection');
  }

  /// 检查数据库是否存在
  Future<bool> databaseExists() async {
    final dbPath = await _getDatabasePath();
    return File(dbPath).exists();
  }

  /// 内部方法：打开数据库
  Future<void> _openDatabase() async {
    _ensureSqliteFfiInitialized();
    
    final dbPath = await _getDatabasePath();
    
    // 确保目录存在
    final dbDir = Directory(path.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    
    // 如果数据库文件不存在，尝试从 assets 加载
    final dbFile = File(dbPath);
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
    
    // 验证表结构
    await _verifyTables();
    
    // 设置 PRAGMA
    await _db!.execute('PRAGMA foreign_keys = ON');
    await _db!.execute('PRAGMA journal_mode = WAL');
    await _db!.execute('PRAGMA synchronous = NORMAL');
    await _db!.execute('PRAGMA busy_timeout = 5000');
    
    AppLogger.i('Database connection established', 'TagDatabaseConnection');
  }
  
  /// 关闭当前连接
  Future<void> _closeConnection() async {
    if (_db != null) {
      try {
        await _db!.close();
      } catch (e) {
        AppLogger.w('Error closing database: $e', 'TagDatabaseConnection');
      }
      _db = null;
    }
  }
  
  /// 获取数据库路径
  Future<String> _getDatabasePath() async {
    final appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'databases', _databaseName);
  }
  
  /// 确保 SQLite FFI 已初始化
  void _ensureSqliteFfiInitialized() {
    try {
      databaseFactory;
    } catch (e) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      AppLogger.i('SQLite FFI initialized', 'TagDatabaseConnection');
    }
  }
  
  /// 验证数据库表是否存在
  Future<void> _verifyTables() async {
    try {
      final tables = await _db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='danbooru_tags'",
      );
      
      if (tables.isEmpty) {
        AppLogger.w('Database tables missing, recreating...', 'TagDatabaseConnection');
        await _onCreate(_db!, _databaseVersion);
      }
    } catch (e) {
      AppLogger.e('Failed to verify tables', e, null, 'TagDatabaseConnection');
      rethrow;
    }
  }
  
  /// 从 assets 解压预打包数据库
  Future<void> _extractPrebuiltDatabase(String targetPath) async {
    const assetPath = 'assets/database/prebuilt_tags.db.gz';
    
    try {
      final byteData = await rootBundle.load(assetPath);
      final compressedBytes = byteData.buffer.asUint8List();
      
      AppLogger.i(
        'Extracting prebuilt database (${compressedBytes.length} bytes)',
        'TagDatabaseConnection',
      );
      
      final dbBytes = gzip.decode(compressedBytes);
      final dbFile = File(targetPath);
      await dbFile.writeAsBytes(dbBytes);
      
      AppLogger.i('Prebuilt database extracted', 'TagDatabaseConnection');
    } catch (e) {
      AppLogger.i('No prebuilt database found: $e', 'TagDatabaseConnection');
      
      // 删除可能部分创建的文件
      try {
        final dbFile = File(targetPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      } catch (_) {}
    }
  }
  
  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // Danbooru 标签主表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS danbooru_tags (
        tag TEXT NOT NULL COLLATE NOCASE,
        category INTEGER NOT NULL DEFAULT 0 CHECK (category >= 0),
        post_count INTEGER NOT NULL DEFAULT 0 CHECK (post_count >= 0),
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (tag)
      ) WITHOUT ROWID
    ''');
    
    // 翻译表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translations (
        en_tag TEXT NOT NULL COLLATE NOCASE,
        zh_translation TEXT NOT NULL,
        source TEXT NOT NULL,
        PRIMARY KEY (en_tag)
      ) WITHOUT ROWID
    ''');
    
    // 共现关系表
    // 注意：移除外键约束，因为 CSV 数据可能包含 danbooru_tags 表中不存在的标签
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cooccurrences (
        tag1 TEXT NOT NULL COLLATE NOCASE,
        tag2 TEXT NOT NULL COLLATE NOCASE,
        count INTEGER NOT NULL CHECK (count > 0),
        cooccurrence_score REAL NOT NULL DEFAULT 0.0 CHECK (cooccurrence_score >= 0),
        PRIMARY KEY (tag1, tag2),
        CHECK (tag1 <> tag2)
      ) WITHOUT ROWID
    ''');
    
    // 元数据表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        source TEXT NOT NULL PRIMARY KEY
          CHECK (source IN ('translations', 'danbooru_tags', 'cooccurrences', 'unified')),
        last_update INTEGER NOT NULL,
        data_version TEXT NOT NULL
      ) WITHOUT ROWID
    ''');
    
    // 创建索引
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_translations_source
        ON translations(source)
    ''');
    
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
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cooccurrences_tag1_count_desc
        ON cooccurrences(tag1, count DESC, tag2)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cooccurrences_count_desc
        ON cooccurrences(count DESC)
    ''');
    
    AppLogger.i('Database tables created', 'TagDatabaseConnection');
  }
  
  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.i('Database upgrade from $oldVersion to $newVersion', 'TagDatabaseConnection');
    
    if (oldVersion < 2) {
      // 版本 2: 移除外键约束以解决共现数据导入失败问题
      AppLogger.i('Upgrading to v2: Recreating cooccurrences table without foreign keys', 'TagDatabaseConnection');
      
      // 删除旧表（外键约束会导致导入失败）
      await db.execute('DROP TABLE IF EXISTS cooccurrences');
      
      // 重新创建表（无 FK 约束）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cooccurrences (
          tag1 TEXT NOT NULL COLLATE NOCASE,
          tag2 TEXT NOT NULL COLLATE NOCASE,
          count INTEGER NOT NULL CHECK (count > 0),
          cooccurrence_score REAL NOT NULL DEFAULT 0.0 CHECK (cooccurrence_score >= 0),
          PRIMARY KEY (tag1, tag2),
          CHECK (tag1 <> tag2)
        ) WITHOUT ROWID
      ''');
      
      // 重建索引
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cooccurrences_tag1_count_desc
          ON cooccurrences(tag1, count DESC, tag2)
      ''');
      
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cooccurrences_count_desc
          ON cooccurrences(count DESC)
      ''');
      
      AppLogger.i('Cooccurrences table recreated without foreign keys', 'TagDatabaseConnection');
    }
  }
}

/// 数据库连接异常
class DatabaseConnectionException implements Exception {
  final String message;
  final dynamic originalError;
  
  DatabaseConnectionException(this.message, {this.originalError});
  
  @override
  String toString() => 'DatabaseConnectionException: $message';
}
