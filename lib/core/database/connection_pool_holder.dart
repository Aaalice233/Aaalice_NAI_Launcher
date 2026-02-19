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
///
/// 不是单例！支持在热重启或数据库恢复时替换实例。
/// 所有组件都通过此持有者获取 ConnectionPool，确保获取的是当前有效实例。
class ConnectionPoolHolder {
  static ConnectionPool? _instance;

  /// 连接池版本号，每次重置时递增
  /// 用于检测连接池是否在操作期间被重置
  static int _version = 0;

  /// 获取当前连接池版本号
  static int get version => _version;

  /// 检查版本是否匹配（用于检测重置）
  static bool isVersionValid(int expectedVersion) => _version == expectedVersion;

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
    int maxConnections = 3,
  }) async {
    if (_instance != null) {
      throw StateError(
        'ConnectionPool already initialized. Use reset() to recreate.',
      );
    }

    _version++;
    final currentVersion = _version;

    _instance = ConnectionPool(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    await _instance!.initialize();

    AppLogger.i(
      'ConnectionPool initialized (version: $currentVersion)',
      'ConnectionPoolHolder',
    );
    return _instance!;
  }

  /// 重置（热重启或数据库恢复后）
  ///
  /// 1. 原子性替换：先将 _instance 设为 null，阻止新请求获取旧实例
  /// 2. 关闭旧连接池
  /// 3. 创建并初始化新连接池
  /// 4. 原子性设置新实例
  /// 5. 递增版本号，使旧版本号的检测失效
  static Future<ConnectionPool> reset({
    required String dbPath,
    int maxConnections = 3,
  }) async {
    // 1. 原子性获取并清空旧实例
    // 这确保新请求会收到 "not initialized" 错误，而不是获取到正在关闭的实例
    final oldInstance = _instance;
    _instance = null;

    // 递增版本号 - 这会立即使所有正在进行的版本检测失效
    _version++;
    final currentVersion = _version;

    // 2. 关闭旧连接池（此时新请求已经被阻止）
    if (oldInstance != null) {
      await oldInstance.dispose();
    }

    // 记录池重置
    MetricsCollector().recordPoolReset();

    // 3. 创建并初始化新连接池
    final newInstance = ConnectionPool(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    await newInstance.initialize();

    // 4. 原子性设置新实例
    _instance = newInstance;

    AppLogger.i(
      'ConnectionPool reset completed (version: $currentVersion)',
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

  // ============================================================
  // 连接池预热机制
  // ============================================================

  /// 预热连接池
  ///
  /// 获取指定数量的连接并验证它们真正可用，然后释放回连接池。
  /// 这确保了在应用启动或重置后，连接池中的连接都是有效的。
  ///
  /// [connections] 要预热的连接数
  /// [timeout] 每个连接的超时时间
  /// [validationQuery] 用于验证连接的查询
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

    try {
      // 获取并验证指定数量的连接
      for (var i = 0; i < connections; i++) {
        try {
          final conn = await pool.acquire().timeout(timeout);

          try {
            // 执行验证查询
            await conn.rawQuery(validationQuery).timeout(
              const Duration(seconds: 2),
            );

            validatedConnections.add(conn);
          } catch (e) {
            lastError = 'Validation failed: $e';
            // 验证失败，关闭这个连接
            try {
              await pool.release(conn);
            } catch (_) {}
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

      // 释放所有验证过的连接
      for (final conn in validatedConnections) {
        try {
          await pool.release(conn);
        } catch (e) {
          // 忽略释放错误
        }
      }

      final success = validatedConnections.length >= connections ~/ 2;

      if (success) {
        AppLogger.i(
          'Connection pool warmed up: ${validatedConnections.length}/$connections connections validated in ${stopwatch.elapsed.inMilliseconds}ms',
          'ConnectionPoolHolder',
        );
      } else {
        AppLogger.w(
          'Connection pool warmup incomplete: ${validatedConnections.length}/$connections connections validated. Last error: $lastError',
          'ConnectionPoolHolder',
        );
      }

      return WarmupResult(
        success: success,
        validatedConnections: validatedConnections.length,
        duration: stopwatch.elapsed,
        error: success ? null : lastError,
      );
    } catch (e) {
      stopwatch.stop();

      // 确保释放所有连接
      for (final conn in validatedConnections) {
        try {
          await pool.release(conn);
        } catch (_) {}
      }

      AppLogger.e(
        'Connection pool warmup failed: $e',
        null,
        null,
        'ConnectionPoolHolder',
      );

      return WarmupResult(
        success: false,
        validatedConnections: validatedConnections.length,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
    }
  }

  /// 重置并预热（便捷方法）
  ///
  /// 先重置连接池，然后立即预热
  static Future<WarmupResult> resetAndWarmup({
    required String dbPath,
    int maxConnections = 3,
    int warmupConnections = 3,
    Duration warmupTimeout = const Duration(seconds: 5),
  }) async {
    await reset(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );

    // 小延迟确保连接池完全就绪
    await Future.delayed(const Duration(milliseconds: 100));

    return await warmup(
      connections: warmupConnections,
      timeout: warmupTimeout,
    );
  }
}
