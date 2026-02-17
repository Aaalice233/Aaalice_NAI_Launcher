import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/sqflite_bootstrap_service.dart';
import '../utils/app_logger.dart';
import 'connection_pool.dart';
import 'data_source_registry.dart';
import 'health_checker.dart';
import 'migration_engine.dart';
import 'recovery_manager.dart';

/// 数据库管理器初始化状态
enum DatabaseInitState {
  uninitialized,
  initializing,
  initialized,
  error,
}

/// 数据库管理器
///
/// 单例模式，负责协调所有数据库组件：
/// - ConnectionPool: 连接池管理
/// - HealthChecker: 健康检查
/// - RecoveryManager: 自动恢复
/// - MigrationEngine: 迁移管理
/// - DataSourceRegistry: 数据源注册
///
/// 初始化顺序：
/// ConnectionPool → HealthChecker → RecoveryManager → MigrationEngine → QuickCheck → BackgroundFullCheck
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
  ///
  /// [dbName] 数据库文件名
  /// [maxConnections] 最大连接数
  static Future<DatabaseManager> initialize({
    String dbName = 'nai_launcher.db',
    int maxConnections = 3,
  }) async {
    if (_instance != null) {
      AppLogger.w('DatabaseManager already initialized', 'DatabaseManager');
      return _instance!;
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

  // 组件引用
  late final ConnectionPool _connectionPool;
  late final HealthChecker _healthChecker;
  late final RecoveryManager _recoveryManager;
  late final MigrationEngine _migrationEngine;
  late final DataSourceRegistry _dataSourceRegistry;

  // 初始化完成标志
  final _initCompleter = Completer<void>();
  bool _backgroundCheckCompleted = false;

  /// 获取初始化状态
  DatabaseInitState get state => _state;

  /// 获取数据库路径
  String? get dbPath => _dbPath;

  /// 获取错误信息
  String? get errorMessage => _errorMessage;

  /// 是否已初始化
  bool get isInitialized => _state == DatabaseInitState.initialized;

  /// 是否正在初始化
  bool get isInitializing => _state == DatabaseInitState.initializing;

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
      // 1. 初始化 FFI（桌面端支持）
      await SqfliteBootstrapService.instance.ensureInitialized();

      // 2. 获取数据库路径
      _dbPath = await _getDatabasePath(dbName);
      AppLogger.i('Database path: $_dbPath', 'DatabaseManager');

      // 3. 初始化 ConnectionPool
      await ConnectionPool.initialize(
        dbPath: _dbPath!,
        maxConnections: maxConnections,
      );
      _connectionPool = ConnectionPool.instance;
      AppLogger.i('ConnectionPool initialized', 'DatabaseManager');

      // 4. 初始化 HealthChecker
      _healthChecker = HealthChecker.instance;
      AppLogger.i('HealthChecker initialized', 'DatabaseManager');

      // 5. 初始化 RecoveryManager
      _recoveryManager = RecoveryManager.instance;
      await _recoveryManager.initialize(_dbPath!);
      AppLogger.i('RecoveryManager initialized', 'DatabaseManager');

      // 6. 初始化 MigrationEngine
      _migrationEngine = MigrationEngine.instance;
      await _migrationEngine.initialize();
      AppLogger.i('MigrationEngine initialized', 'DatabaseManager');

      // 7. 初始化 DataSourceRegistry
      _dataSourceRegistry = DataSourceRegistry.instance;
      await _dataSourceRegistry.initialize();
      AppLogger.i('DataSourceRegistry initialized', 'DatabaseManager');

      // 8. 快速健康检查
      final quickCheckResult = await _healthChecker.quickCheck();
      if (!quickCheckResult.isHealthy) {
        AppLogger.w(
          'Quick check failed, attempting recovery',
          'DatabaseManager',
        );

        final recoveryResult = await _recoveryManager.autoRecover();
        if (!recoveryResult.success) {
          throw StateError('Database recovery failed: ${recoveryResult.message}');
        }

        // 重新初始化连接池
        await _connectionPool.reset();
      }

      _state = DatabaseInitState.initialized;
      _initCompleter.complete();

      AppLogger.i('DatabaseManager initialized successfully', 'DatabaseManager');

      // 9. 后台完整检查
      _runBackgroundFullCheck();
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

  /// 后台完整检查
  Future<void> _runBackgroundFullCheck() async {
    try {
      AppLogger.d('Starting background full check', 'DatabaseManager');

      // 执行完整检查
      final fullResult = await _healthChecker.fullCheck();

      if (fullResult.isCorrupted) {
        AppLogger.w(
          'Full check detected corruption, attempting recovery',
          'DatabaseManager',
        );

        final recoveryResult = await _recoveryManager.autoRecover();
        if (recoveryResult.success) {
          // 重新检查
          await _healthChecker.fullCheck();
        }
      }

      // 执行数据验证
      await _healthChecker.validateData();

      _backgroundCheckCompleted = true;

      AppLogger.i('Background full check completed', 'DatabaseManager');
    } catch (e, stack) {
      AppLogger.e('Background full check failed', e, stack, 'DatabaseManager');
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

  /// 在事务中执行操作
  ///
  /// 自动处理 PRAGMA 状态恢复
  /// [action] 事务操作
  /// [exclusive] 是否使用独占事务
  Future<T> executeInTransaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool exclusive = false,
  }) async {
    final db = await _connectionPool.acquire();

    try {
      // 保存当前 PRAGMA 状态
      final foreignKeys = await _getPragma(db, 'foreign_keys');
      final recursiveTriggers = await _getPragma(db, 'recursive_triggers');

      T result;

      if (exclusive) {
        result = await db.transaction(action, exclusive: true);
      } else {
        result = await db.transaction(action);
      }

      // 恢复 PRAGMA 状态
      await _setPragma(db, 'foreign_keys', foreignKeys);
      await _setPragma(db, 'recursive_triggers', recursiveTriggers);

      return result;
    } finally {
      await _connectionPool.release(db);
    }
  }

  /// 获取 PRAGMA 值
  Future<dynamic> _getPragma(Database db, String name) async {
    final result = await db.rawQuery('PRAGMA $name');
    if (result.isEmpty) return null;
    return result.first.values.first;
  }

  /// 设置 PRAGMA 值
  Future<void> _setPragma(Database db, String name, dynamic value) async {
    if (value != null) {
      await db.execute('PRAGMA $name = $value');
    }
  }

  /// 获取原始数据库连接（用于复杂操作）
  ///
  /// 注意：使用后必须调用 [releaseDatabase]
  Future<Database> acquireDatabase() async {
    return await _connectionPool.acquire();
  }

  /// 释放数据库连接
  Future<void> releaseDatabase(Database db) async {
    await _connectionPool.release(db);
  }

  /// 执行快速健康检查
  Future<HealthCheckResult> quickHealthCheck() async {
    return await _healthChecker.quickCheck();
  }

  /// 执行完整健康检查
  Future<HealthCheckResult> fullHealthCheck() async {
    return await _healthChecker.fullCheck();
  }

  /// 验证数据完整性
  Future<HealthCheckResult> validateData() async {
    return await _healthChecker.validateData();
  }

  /// 执行数据库恢复
  Future<void> recover() async {
    final result = await _recoveryManager.autoRecover();
    if (!result.success) {
      throw StateError('Recovery failed: ${result.message}');
    }
  }

  /// 创建数据库备份
  Future<void> createBackup() async {
    final result = await _recoveryManager.createBackup();
    if (!result.success) {
      throw StateError('Backup failed: ${result.message}');
    }
  }

  /// 运行迁移
  Future<void> migrate() async {
    final result = await _migrationEngine.migrate();
    if (!result.success) {
      throw StateError('Migration failed: ${result.message}');
    }
  }

  /// 注册迁移
  void registerMigration(migration) {
    _migrationEngine.registerMigration(migration);
  }

  /// 注册数据源
  void registerDataSource(DataSource source, {bool autoInitialize = false}) {
    _dataSourceRegistry.register(source, autoInitialize: autoInitialize);
  }

  /// 获取数据源
  T getDataSource<T extends DataSource>(String name) {
    return _dataSourceRegistry.getSource<T>(name);
  }

  /// 关闭数据库管理器
  Future<void> dispose() async {
    AppLogger.i('Disposing DatabaseManager...', 'DatabaseManager');

    // 释放数据源
    await _dataSourceRegistry.disposeAll();

    // 释放连接池
    await _connectionPool.dispose();

    _state = DatabaseInitState.uninitialized;
    _instance = null;

    AppLogger.i('DatabaseManager disposed', 'DatabaseManager');
  }

  /// 获取数据库统计信息
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await _connectionPool.acquire();

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
        'fileSizeFormatted': _formatBytes(fileSize),
        'tables': tableStats,
        'tableCount': tables.length,
        'connectionPool': {
          'maxConnections': _maxConnections,
          'available': _connectionPool.availableCount,
          'inUse': _connectionPool.inUseCount,
        },
        'healthCheck': {
          'lastQuickCheck': _healthChecker.lastQuickCheck?.toIso8601String(),
          'lastFullCheck': _healthChecker.lastFullCheck?.toIso8601String(),
          'lastStatus': _healthChecker.lastResult?.status.name,
        },
        'migration': {
          'currentVersion': await _migrationEngine.getCurrentVersion(),
          'targetVersion': _migrationEngine.getTargetVersion(),
          'registeredMigrations': _migrationEngine.migrationCount,
        },
        'dataSources': _dataSourceRegistry.getStatistics(),
      };
    } finally {
      await _connectionPool.release(db);
    }
  }

  /// 格式化字节大小
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 重置数据库管理器（仅用于测试）
  static void reset() {
    _instance = null;
    AppLogger.d('DatabaseManager reset', 'DatabaseManager');
  }
}
