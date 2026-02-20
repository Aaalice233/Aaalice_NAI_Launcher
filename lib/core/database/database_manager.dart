import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'asset_database_manager.dart';
import 'connection_health_monitor.dart' as health_monitor;
import 'data_source.dart' show HealthStatus;
import 'data_source_types.dart' show HealthCheckResult;
import 'connection_pool_holder.dart';
import 'datasources/cooccurrence_data_source.dart';
import 'datasources/danbooru_tag_data_source.dart';
import 'datasources/gallery_data_source.dart';
import 'datasources/translation_data_source.dart';
import 'migrations/gallery_data_migration.dart';
import 'metrics/metrics_reporter.dart' as metrics_reporter;

/// 数据库初始化状态
enum DatabaseInitState {
  uninitialized,
  initializing,
  initialized,
  error,
}

/// 数据库管理器 V3
///
/// 架构：
/// 1. 资产数据库（预打包，只读）：translation.db, cooccurrence.db
/// 2. 运行时数据库（可写）：danbooru.db（原统一数据库）, gallery 等
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
        AppLogger.i(
          'DatabaseManager exists but ConnectionPool disposed, resetting...',
          'DatabaseManager',
        );
        _instance = null;
      } catch (e) {
        _instance = null;
      }
    }

    AppLogger.i('Initializing DatabaseManager...', 'DatabaseManager');

    _instance = DatabaseManager._();
    await _instance!._doInitialize(maxConnections: maxConnections);

    return _instance!;
  }

  static const int _maxConnections = 3;
  static const String _danbooruDbName = 'danbooru.db';

  DatabaseInitState _state = DatabaseInitState.uninitialized;
  String? _dbPath;
  String? _errorMessage;

  // 初始化完成标记
  final _initCompleter = Completer<void>();
  final bool _backgroundCheckCompleted = false;

  // 数据源
  TranslationDataSource? _translationDataSource;
  CooccurrenceDataSource? _cooccurrenceDataSource;
  DanbooruTagDataSource? _danbooruTagDataSource;
  GalleryDataSource? _galleryDataSource;

  // 健康监控器
  health_monitor.ConnectionHealthMonitor? _healthMonitor;

  // 指标报告器
  metrics_reporter.MetricsReporter? _metricsReporter;

  /// 翻译数据源
  TranslationDataSource get translationDataSource {
    if (_translationDataSource == null) {
      throw StateError('TranslationDataSource not initialized');
    }
    return _translationDataSource!;
  }

  /// 共现数据源
  CooccurrenceDataSource get cooccurrenceDataSource {
    if (_cooccurrenceDataSource == null) {
      throw StateError('CooccurrenceDataSource not initialized');
    }
    return _cooccurrenceDataSource!;
  }

  /// Danbooru 标签数据源
  DanbooruTagDataSource? get danbooruTagDataSource => _danbooruTagDataSource;

  /// 画廊数据源
  GalleryDataSource? get galleryDataSource => _galleryDataSource;

  /// 获取数据源（泛型方法）
  ///
  /// 根据类型返回对应的数据源实例：
  /// - TranslationDataSource: 翻译数据源
  /// - CooccurrenceDataSource: 共现数据源
  /// - DanbooruTagDataSource: Danbooru 标签数据源
  /// - GalleryDataSource: 画廊数据源
  T? getDataSource<T>(String name) {
    if (T == TranslationDataSource) {
      return _translationDataSource as T?;
    }
    if (T == CooccurrenceDataSource) {
      return _cooccurrenceDataSource as T?;
    }
    if (T == DanbooruTagDataSource) {
      return _danbooruTagDataSource as T?;
    }
    if (T == GalleryDataSource) {
      return _galleryDataSource as T?;
    }
    return null;
  }

  /// 获取初始化状态
  DatabaseInitState get state => _state;

  /// 获取数据库路径
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
    required int maxConnections,
  }) async {
    _state = DatabaseInitState.initializing;

    try {
      // 1. 初始化资产数据库（预打包数据库）
      AppLogger.i('Initializing asset databases...', 'DatabaseManager');
      await AssetDatabaseManager.initialize();

      // 2. 初始化翻译数据源
      _translationDataSource = TranslationDataSource();
      await _translationDataSource!.initialize();
      AppLogger.i('TranslationDataSource initialized', 'DatabaseManager');

      // 3. 初始化共现数据源
      _cooccurrenceDataSource = CooccurrenceDataSource();
      await _cooccurrenceDataSource!.initialize();
      AppLogger.i('CooccurrenceDataSource initialized', 'DatabaseManager');

      // 4. 初始化 Danbooru 数据库（运行时数据库）
      _dbPath = await _getDatabasePath(_danbooruDbName);
      AppLogger.i('Danbooru database path: $_dbPath', 'DatabaseManager');

      await ConnectionPoolHolder.initialize(
        dbPath: _dbPath!,
        maxConnections: maxConnections,
      );
      AppLogger.i(
        'ConnectionPool initialized for Danbooru DB',
        'DatabaseManager',
      );

      // 5. 注册运行时数据源
      await _registerRuntimeDataSources();

      // 6. 启动健康监控
      _startHealthMonitoring();

      // 7. 启动指标报告
      _startMetricsReporting();

      _state = DatabaseInitState.initialized;
      _initCompleter.complete();

      AppLogger.i(
        'DatabaseManager initialized successfully',
        'DatabaseManager',
      );
    } catch (e, stack) {
      _state = DatabaseInitState.error;
      _errorMessage = e.toString();

      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stack);
      }

      AppLogger.e(
        'DatabaseManager initialization failed',
        e,
        stack,
        'DatabaseManager',
      );
      rethrow;
    }
  }

  /// 获取数据库路径
  Future<String> _getDatabasePath(String dbName) async {
    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appDir.path, 'databases'));
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
  Future<void> recover() async {
    AppLogger.i('Starting database recovery...', 'DatabaseManager');

    try {
      // 重置 ConnectionPool
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
  Future<HealthCheckResult> quickHealthCheck() async {
    try {
      // 检查资产数据库
      final assetHealth =
          await AssetDatabaseManager.instance.checkDatabasesExist();
      if (!assetHealth) {
        return HealthCheckResult(
          status: HealthStatus.corrupted,
          message: 'Asset databases missing',
          timestamp: DateTime.now(),
        );
      }

      // 检查 Danbooru 数据库
      final pool = ConnectionPoolHolder.instance;
      final db = await pool.acquire();

      try {
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

    // 停止健康监控
    _healthMonitor?.stop();
    _healthMonitor?.dispose();
    _healthMonitor = null;
    AppLogger.i('Health monitor stopped', 'DatabaseManager');

    // 停止指标报告
    _metricsReporter?.stopReporting();
    _metricsReporter = null;
    AppLogger.i('Metrics reporter stopped', 'DatabaseManager');

    // 释放资产数据源
    try {
      await _translationDataSource?.dispose();
      AppLogger.i('TranslationDataSource disposed', 'DatabaseManager');
    } catch (e) {
      AppLogger.w(
        'Failed to dispose TranslationDataSource: $e',
        'DatabaseManager',
      );
    }

    try {
      await _cooccurrenceDataSource?.dispose();
      AppLogger.i('CooccurrenceDataSource disposed', 'DatabaseManager');
    } catch (e) {
      AppLogger.w(
        'Failed to dispose CooccurrenceDataSource: $e',
        'DatabaseManager',
      );
    }

    // 释放运行时数据源
    try {
      await _danbooruTagDataSource?.dispose();
      AppLogger.i('DanbooruTagDataSource disposed', 'DatabaseManager');
    } catch (e) {
      AppLogger.w(
        'Failed to dispose DanbooruTagDataSource: $e',
        'DatabaseManager',
      );
    }

    try {
      await _galleryDataSource?.dispose();
      AppLogger.i('GalleryDataSource disposed', 'DatabaseManager');
    } catch (e) {
      AppLogger.w('Failed to dispose GalleryDataSource: $e', 'DatabaseManager');
    }

    await ConnectionPoolHolder.dispose();

    _state = DatabaseInitState.uninitialized;
    _instance = null;

    AppLogger.i('DatabaseManager disposed', 'DatabaseManager');
  }

  // ===========================================================================
  // 数据源管理
  // ===========================================================================

  /// 注册运行时数据源（使用 ConnectionPool 的数据源）
  Future<void> _registerRuntimeDataSources() async {
    AppLogger.i('Registering runtime data sources...', 'DatabaseManager');

    // 注册 Danbooru 标签数据源
    _danbooruTagDataSource = DanbooruTagDataSource();
    try {
      await _danbooruTagDataSource!.initialize();
      AppLogger.i('DanbooruTagDataSource initialized', 'DatabaseManager');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize DanbooruTagDataSource',
        e,
        stack,
        'DatabaseManager',
      );
    }

    // 注册画廊数据源
    _galleryDataSource = GalleryDataSource();
    try {
      await _galleryDataSource!.initialize();
      AppLogger.i('GalleryDataSource initialized', 'DatabaseManager');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize GalleryDataSource',
        e,
        stack,
        'DatabaseManager',
      );
      // 数据源初始化失败不应阻塞整体启动
    }

    // 检查并执行数据迁移
    await _checkAndMigrateGalleryData(_galleryDataSource!);

    // 预热连接池
    await _warmupConnectionPool();

    AppLogger.i('Runtime data sources registered', 'DatabaseManager');
  }

  /// 预热连接池
  Future<void> _warmupConnectionPool() async {
    try {
      AppLogger.i('Warming up connection pool...', 'DatabaseManager');
      final result = await ConnectionPoolHolder.warmup(
        connections: _maxConnections,
        timeout: const Duration(seconds: 5),
      );

      if (result.success) {
        AppLogger.i(
          'Connection pool warmed up successfully: '
              '${result.validatedConnections} connections validated in ${result.duration.inMilliseconds}ms',
          'DatabaseManager',
        );
      } else {
        AppLogger.w(
          'Connection pool warmup incomplete: '
              '${result.validatedConnections} connections validated. Error: ${result.error}',
          'DatabaseManager',
        );
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to warmup connection pool',
        e,
        stack,
        'DatabaseManager',
      );
      // 预热失败不应阻塞整体启动
    }
  }

  /// 启动健康监控
  void _startHealthMonitoring() {
    try {
      _healthMonitor = health_monitor.ConnectionHealthMonitor(
        config: health_monitor.HealthCheckConfig(),
        onStatusChange: (oldStatus, newStatus, result) {
          AppLogger.w(
            'Database health status changed: $oldStatus -> $newStatus '
                '(latency: ${result.connectionAcquireLatency.inMilliseconds}ms, '
                'failureRate: ${result.failureRate.toStringAsFixed(2)}%)',
            'DatabaseManager',
          );
        },
        onAlert: (alertType, message, result) {
          AppLogger.e(
            'Database health alert [$alertType]: $message',
            null,
            null,
            'DatabaseManager',
          );
        },
      );
      _healthMonitor!.start();
      AppLogger.i(
        'Health monitoring started (interval: 30s)',
        'DatabaseManager',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to start health monitoring',
        e,
        stack,
        'DatabaseManager',
      );
    }
  }

  /// 启动指标报告
  void _startMetricsReporting() {
    try {
      _metricsReporter = metrics_reporter.MetricsReporter();

      // 根据环境配置报告间隔
      const isProduction =
          bool.fromEnvironment('dart.vm.product', defaultValue: false);
      const reportInterval =
          isProduction ? Duration(minutes: 5) : Duration(minutes: 10);

      _metricsReporter!.startReporting(interval: reportInterval);
      AppLogger.i(
        'Metrics reporting started (interval: ${reportInterval.inMinutes}min, environment: ${isProduction ? 'production' : 'development'})',
        'DatabaseManager',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to start metrics reporting',
        e,
        stack,
        'DatabaseManager',
      );
    }
  }

  /// 检查并执行画廊数据迁移
  Future<void> _checkAndMigrateGalleryData(GalleryDataSource dataSource) async {
    try {
      if (await GalleryDataMigration.needsMigration()) {
        AppLogger.i(
          'Gallery data migration needed, starting...',
          'DatabaseManager',
        );
        final result = await GalleryDataMigration.migrate(dataSource);
        if (result.success) {
          AppLogger.i(
            'Gallery migration completed: ${result.imagesMigrated} images migrated',
            'DatabaseManager',
          );
        } else {
          AppLogger.w(
            'Gallery migration failed: ${result.error}',
            'DatabaseManager',
          );
        }
      }
    } catch (e) {
      AppLogger.w(
        'Failed to check/migrate gallery data: $e',
        'DatabaseManager',
      );
    }
  }
}
