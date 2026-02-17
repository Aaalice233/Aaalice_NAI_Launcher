import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_pool_holder.dart';
import 'health_checker.dart';

/// 数据库初始化状态
enum DatabaseInitState {
  uninitialized,
  initializing,
  initialized,
  error,
}

/// 数据库管理器 V2
/// 
/// 关键改进：
/// 1. 使用 ConnectionPoolHolder 而不是直接持有 ConnectionPool
/// 2. 支持 recover() 后自动更新 ConnectionPool 引用
/// 3. 所有操作都通过 Holder 获取当前有效实例
class DatabaseManager {
  DatabaseManager._();

  static DatabaseManager? _instance;

  /// 获取单例实例
  static DatabaseManager get instance {
    if (_instance == null) {
      throw StateError(
        'DatabaseManager not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }

  /// 初始化数据库管理器
  static Future<DatabaseManager> initialize({
    String dbName = 'nai_launcher.db',
    int maxConnections = 3,
  }) async {
    if (_instance != null) {
      // 检查是否可用
      try {
        final pool = ConnectionPoolHolder.getInstanceOrNull();
        if (pool != null && !pool.isDisposed) {
          AppLogger.w('DatabaseManager already initialized', 'DatabaseManager');
          return _instance!;
        }
        
        // 不可用，需要重置
        AppLogger.i('DatabaseManager exists but ConnectionPool disposed, resetting...', 'DatabaseManager');
        _instance = null;
      } catch (e) {
        _instance = null;
      }
    }

    AppLogger.i('Initializing DatabaseManager...', 'DatabaseManager');

    _instance = DatabaseManager._();
    await _instance!._doInitialize(
      dbName: dbName,
      maxConnections: maxConnections,
    );

    return _instance!;
  }

  static const int _maxConnections = 3;

  DatabaseInitState _state = DatabaseInitState.uninitialized;
  String? _dbPath;
  String? _errorMessage;

  // 初始化完成标记
  final _initCompleter = Completer<void>();
  final bool _backgroundCheckCompleted = false;

  /// 获取初始化状态
  DatabaseInitState get state => _state;

  /// 获取数据库路�?
  String? get dbPath => _dbPath;

  /// 获取错误信息
  String? get errorMessage => _errorMessage;

  /// 是否已初始化
  bool get isInitialized => _state == DatabaseInitState.initialized;

  /// 是否有错误
  bool get hasError => _state == DatabaseInitState.error;

  /// 后台检查是否完成
  bool get backgroundCheckCompleted => _backgroundCheckCompleted;

  /// 初始化完成Future
  Future<void> get initialized => _initCompleter.future;

  /// 执行初始化
  Future<void> _doInitialize({
    required String dbName,
    required int maxConnections,
  }) async {
    _state = DatabaseInitState.initializing;

    try {
      // 1. FFI 已在 main.dart 中通过 SqfliteBootstrapService 初始化
      // 这里不再重复初始化，避免冲突
      AppLogger.i('FFI already initialized by SqfliteBootstrapService', 'DatabaseManager');

      // 2. 获取数据库路径
      _dbPath = await _getDatabasePath(dbName);
      AppLogger.i('Database path: $_dbPath', 'DatabaseManager');

      // 3. 初始化 ConnectionPool（通过 Holder）
      await ConnectionPoolHolder.initialize(
        dbPath: _dbPath!,
        maxConnections: maxConnections,
      );
      AppLogger.i('ConnectionPool initialized', 'DatabaseManager');

      _state = DatabaseInitState.initialized;
      _initCompleter.complete();

      AppLogger.i('DatabaseManager initialized successfully', 'DatabaseManager');
    } catch (e, stack) {
      _state = DatabaseInitState.error;
      _errorMessage = e.toString();

      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stack);
      }

      AppLogger.e('DatabaseManager initialization failed', e, stack, 'DatabaseManager');
      rethrow;
    }
  }

  /// 获取数据库路径
  Future<String> _getDatabasePath(String dbName) async {
    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appDir.path, 'database'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    return p.join(dbDir.path, dbName);
  }

  /// 获取数据库连接（通过 Holder 获取当前有效实例）
  Future<Database> acquireDatabase() async {
    return await ConnectionPoolHolder.instance.acquire();
  }

  /// 释放数据库连接
  Future<void> releaseDatabase(Database db) async {
    await ConnectionPoolHolder.instance.release(db);
  }

  /// 获取数据库统计信息
  Future<Map<String, dynamic>> getStatistics() async {
    final pool = ConnectionPoolHolder.instance;
    final db = await pool.acquire();

    try {
      // 获取数据库文件大小
      final dbFile = File(_dbPath!);
      final fileSize = await dbFile.exists() ? await dbFile.length() : 0;

      // 获取表统计
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final tableStats = <String, int>{};
      for (final row in tables) {
        final tableName = row['name'] as String;
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM "$tableName"',
        );
        tableStats[tableName] = countResult.first['count'] as int? ?? 0;
      }

      return {
        'dbPath': _dbPath,
        'fileSize': fileSize,
        'tables': tableStats,
        'tableCount': tables.length,
        'connectionPool': {
          'maxConnections': _maxConnections,
          'available': pool.availableCount,
          'inUse': pool.inUseCount,
        },
      };
    } finally {
      await pool.release(db);
    }
  }

  /// 执行数据库恢复
  /// 
  /// 关键：恢复后 ConnectionPool 会被重置，所有组件通过 Holder 获取新实例
  Future<void> recover() async {
    AppLogger.i('Starting database recovery...', 'DatabaseManager');

    try {
      // 1. 重置 ConnectionPool（关闭旧连接，创建新连接）
      await ConnectionPoolHolder.reset(
        dbPath: _dbPath!,
        maxConnections: _maxConnections,
      );

      AppLogger.i('Database recovery completed', 'DatabaseManager');
    } catch (e, stack) {
      AppLogger.e('Database recovery failed', e, stack, 'DatabaseManager');
      throw StateError('Recovery failed: $e');
    }
  }

  /// 快速健康检查
  ///
  /// 检查数据库是否损坏，返回健康检查结果
  Future<HealthCheckResult> quickHealthCheck() async {
    try {
      final pool = ConnectionPoolHolder.instance;
      final db = await pool.acquire();

      try {
        // 基本查询测试 - 检查 sqlite_master 表
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' LIMIT 1",
        );

        return HealthCheckResult(
          status: HealthStatus.healthy,
          message: 'Database is healthy',
          details: {'tableCount': result.length},
          timestamp: DateTime.now(),
        );
      } catch (e) {
        return HealthCheckResult(
          status: HealthStatus.corrupted,
          message: 'Database health check failed: $e',
          timestamp: DateTime.now(),
        );
      } finally {
        await pool.release(db);
      }
    } catch (e) {
      return HealthCheckResult(
        status: HealthStatus.corrupted,
        message: 'Failed to acquire database connection: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// 关闭数据库管理器
  Future<void> dispose() async {
    AppLogger.i('Disposing DatabaseManager...', 'DatabaseManager');

    await ConnectionPoolHolder.dispose();

    _state = DatabaseInitState.uninitialized;
    _instance = null;

    AppLogger.i('DatabaseManager disposed', 'DatabaseManager');
  }
}
