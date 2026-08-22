import 'dart:async';

import 'connection_pool.dart';
import '../utils/app_logger.dart';
import 'metrics/metrics_collector.dart';

/// 连接池预热结果
class WarmupResult {
  final bool success;
  final int validatedConnections;
  final Duration duration;
  final String? error;

  WarmupResult({
    required this.success,
    required this.validatedConnections,
    required this.duration,
    this.error,
  });

  @override
  String toString() =>
      'WarmupResult(success: $success, connections: $validatedConnections, duration: ${duration.inMilliseconds}ms)';
}

/// ConnectionPool 全局持有者
class ConnectionPoolHolder {
  static ConnectionPool? _instance;
  static Future<ConnectionPool>? _initialization;

  /// 连接池版本号，每次重置时递增
  /// 用于检测连接池是否在操作期间被重置
  static int _version = 0;

  /// 获取当前连接池版本号
  static int get version => _version;

  /// 检查版本是否匹配（用于检测重置）
  static bool isVersionValid(int expectedVersion) =>
      _version == expectedVersion;

  /// 获取当前实例
  static ConnectionPool get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'ConnectionPool not initialized. Call initialize() first.',
      );
    }
    return inst;
  }

  /// 检查是否已初始化
  static bool get isInitialized => _instance != null;

  /// 初始化（首次启动）
  static Future<ConnectionPool> initialize({
    required String dbPath,
    int maxConnections = 20,
  }) async {
    if (_instance != null) {
      throw StateError(
        'ConnectionPool already initialized. Use reset() to recreate.',
      );
    }

    final inFlight = _initialization;
    if (inFlight != null) return inFlight;

    final attempt = _initializeNew(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    _initialization = attempt;
    try {
      return await attempt;
    } finally {
      if (identical(_initialization, attempt)) {
        _initialization = null;
      }
    }
  }

  static Future<ConnectionPool> _initializeNew({
    required String dbPath,
    required int maxConnections,
  }) async {
    _version++;
    final currentVersion = _version;
    final candidate = ConnectionPool(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    try {
      await candidate.initialize();
      _instance = candidate;
    } catch (error, stackTrace) {
      try {
        await candidate.dispose();
      } catch (cleanupError, cleanupStackTrace) {
        AppLogger.e(
          'Failed to clean up an unsuccessful connection pool',
          cleanupError,
          cleanupStackTrace,
          'ConnectionPoolHolder',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    AppLogger.i(
      'ConnectionPool initialized (version: $currentVersion)',
      'ConnectionPoolHolder',
    );
    return candidate;
  }

  static Future<ConnectionPool> reset({
    required String dbPath,
    int maxConnections = 20,
  }) async {
    final oldInstance = _instance;
    _instance = null;
    _version++;
    final currentVersion = _version;

    if (oldInstance != null) {
      await oldInstance.dispose();
    }

    MetricsCollector().recordPoolReset();

    final newInstance = ConnectionPool(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    await newInstance.initialize();

    _instance = newInstance;

    AppLogger.i(
      'ConnectionPool reset (version: $currentVersion)',
      'ConnectionPoolHolder',
    );
    return newInstance;
  }

  /// 获取当前实例（如果已初始化）
  static ConnectionPool? getInstanceOrNull() {
    return _instance;
  }

  /// 销毁（应用退出时）
  static Future<void> dispose() async {
    final inst = _instance;
    if (inst != null) {
      await inst.dispose();
      _instance = null;
    }
  }

  /// 预热连接池
  static Future<WarmupResult> warmup({
    int connections = 3,
    Duration timeout = const Duration(seconds: 5),
    String validationQuery = 'SELECT 1',
  }) async {
    final stopwatch = Stopwatch()..start();

    if (!isInitialized) {
      return WarmupResult(
        success: false,
        validatedConnections: 0,
        duration: stopwatch.elapsed,
        error: 'Connection pool not initialized',
      );
    }

    final pool = instance;
    final validatedConnections = <dynamic>[];
    var lastError = '';

    for (var i = 0; i < connections; i++) {
      try {
        final conn = await pool.acquire().timeout(timeout);

        try {
          await conn
              .rawQuery(validationQuery)
              .timeout(const Duration(seconds: 2));
          validatedConnections.add(conn);
        } catch (e) {
          lastError = 'Validation failed: $e';
          try {
            await pool.release(conn);
          } catch (releaseError) {
            AppLogger.d(
              'Failed to release invalid warmup connection: $releaseError',
              'ConnectionPoolHolder',
            );
          }
        }
      } on TimeoutException {
        lastError = 'Connection acquisition timeout';
        break;
      } catch (e) {
        lastError = 'Failed to acquire connection: $e';
        break;
      }
    }

    stopwatch.stop();

    for (final conn in validatedConnections) {
      try {
        await pool.release(conn);
      } catch (releaseError) {
        AppLogger.d(
          'Failed to release validated warmup connection: $releaseError',
          'ConnectionPoolHolder',
        );
      }
    }

    final success = validatedConnections.length >= connections ~/ 2;

    if (success) {
      AppLogger.i(
        'Connection pool warmed up: ${validatedConnections.length}/$connections in ${stopwatch.elapsed.inMilliseconds}ms',
        'ConnectionPoolHolder',
      );
    } else {
      AppLogger.w(
        'Connection pool warmup incomplete: ${validatedConnections.length}/$connections. Error: $lastError',
        'ConnectionPoolHolder',
      );
    }

    return WarmupResult(
      success: success,
      validatedConnections: validatedConnections.length,
      duration: stopwatch.elapsed,
      error: success ? null : lastError,
    );
  }

  static Future<WarmupResult> resetAndWarmup({
    required String dbPath,
    int maxConnections = 20,
    int warmupConnections = 3,
    Duration warmupTimeout = const Duration(seconds: 5),
  }) async {
    await reset(dbPath: dbPath, maxConnections: maxConnections);

    // 小延迟确保连接池完全就绪
    await Future.delayed(const Duration(milliseconds: 100));

    return await warmup(connections: warmupConnections, timeout: warmupTimeout);
  }
}
