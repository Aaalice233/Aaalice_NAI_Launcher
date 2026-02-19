import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_pool_holder.dart';
import 'metrics/metrics_collector.dart';

/// 连接租借异常
class ConnectionLeaseException implements Exception {
  final String message;
  final String? operationId;

  ConnectionLeaseException(this.message, {this.operationId});

  @override
  String toString() => 'ConnectionLeaseException: $message${operationId != null ? ' (operation: $operationId)' : ''}';
}

/// 连接已失效异常
class ConnectionInvalidException extends ConnectionLeaseException {
  ConnectionInvalidException({String? operationId})
      : super('Connection is no longer valid', operationId: operationId);
}

/// 连接版本不匹配异常
class ConnectionVersionMismatchException extends ConnectionLeaseException {
  final int expectedVersion;
  final int actualVersion;

  ConnectionVersionMismatchException({
    required this.expectedVersion,
    required this.actualVersion,
    String? operationId,
  }) : super(
          'Connection version mismatch: expected $expectedVersion, got $actualVersion',
          operationId: operationId,
        );
}

/// 连接租借令牌
/// 
/// 封装数据库连接及其生命周期管理，确保：
/// 1. 连接在有效期内使用
/// 2. 连接版本与连接池一致
/// 3. 自动检测连接健康状态
/// 4. 使用时长监控
class ConnectionLease {
  final Database connection;
  final int poolVersion;
  final String? operationId;
  final DateTime issuedAt;
  final Stopwatch _usageTimer;
  final void Function(ConnectionLease)? onExpired;
  final void Function(ConnectionLease, Duration)? onLongUsage;

  bool _isValid = true;
  bool _isDisposed = false;
  int _validationCount = 0;

  /// 最大有效期
  static const maxAge = Duration(minutes: 5);

  /// 健康检查间隔（验证次数）
  static const validationInterval = 10;

  /// 长时间使用阈值
  static const longUsageThreshold = Duration(seconds: 5);

  ConnectionLease({
    required this.connection,
    required this.poolVersion,
    this.operationId,
    this.onExpired,
    this.onLongUsage,
  })  : issuedAt = DateTime.now(),
        _usageTimer = Stopwatch()..start();

  /// 检查租借是否有效
  bool get isValid => _isValid && !_isDisposed;

  /// 检查租借是否已释放
  bool get isDisposed => _isDisposed;

  /// 获取使用时长
  Duration get usageTime => _usageTimer.elapsed;

  /// 获取租借年龄
  Duration get age => DateTime.now().difference(issuedAt);

  /// 验证连接是否仍然有效
  /// 
  /// 执行以下检查：
  /// 1. 租借状态检查
  /// 2. 年龄检查
  /// 3. 版本一致性检查
  /// 4. 连接健康检查（每隔一定次数执行一次）
  Future<bool> validate() async {
    if (!_isValid || _isDisposed) {
      AppLogger.d(
        'Connection lease invalid: valid=$_isValid, disposed=$_isDisposed',
        'ConnectionLease',
      );
      return false;
    }

    // 检查年龄
    if (age > maxAge) {
      AppLogger.w(
        'Connection lease expired after ${age.inSeconds}s',
        'ConnectionLease',
      );
      _isValid = false;
      return false;
    }

    // 检查版本是否变化
    final currentVersion = ConnectionPoolHolder.version;
    if (currentVersion != poolVersion) {
      AppLogger.w(
        'Connection version mismatch: lease=$poolVersion, current=$currentVersion',
        'ConnectionLease',
      );
      _isValid = false;
      throw ConnectionVersionMismatchException(
        expectedVersion: poolVersion,
        actualVersion: currentVersion,
        operationId: operationId,
      );
    }

    // 定期执行健康检查
    _validationCount++;
    if (_validationCount % validationInterval == 0) {
      try {
        await connection.rawQuery('SELECT 1');
      } catch (e) {
        AppLogger.w(
          'Connection health check failed: $e',
          'ConnectionLease',
        );
        _isValid = false;
        return false;
      }
    }

    return true;
  }

  /// 快速验证（不执行健康检查）
  bool validateFast() {
    if (!_isValid || _isDisposed) return false;
    if (age > maxAge) {
      _isValid = false;
      return false;
    }
    if (ConnectionPoolHolder.version != poolVersion) {
      _isValid = false;
      return false;
    }
    return true;
  }

  /// 使用连接执行操作
  /// 
  /// [operation] 数据库操作
  /// [validateBefore] 操作前是否验证连接
  /// [autoRetry] 连接失效时是否自动重试一次
  Future<T> execute<T>(
    Future<T> Function(Database db) operation, {
    bool validateBefore = true,
    bool autoRetry = true,
  }) async {
    if (_isDisposed) {
      throw ConnectionLeaseException(
        'Cannot execute on disposed lease',
        operationId: operationId,
      );
    }

    // 验证连接
    if (validateBefore) {
      final isValid = await validate();
      if (!isValid) {
        if (autoRetry) {
          AppLogger.d(
            'Connection invalid, requesting retry',
            'ConnectionLease',
          );
          throw ConnectionInvalidException(operationId: operationId);
        }
        throw ConnectionInvalidException(operationId: operationId);
      }
    }

    try {
      return await operation(connection);
    } on ConnectionVersionMismatchException {
      _isValid = false;
      rethrow;
    } catch (e) {
      // 检查是否是连接相关错误
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('database_closed') ||
          errorStr.contains('database_closed')) {
        _isValid = false;
        throw ConnectionInvalidException(operationId: operationId);
      }
      rethrow;
    }
  }

  /// 强制释放连接
  /// 
  /// 释放连接回连接池，并触发回调
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _usageTimer.stop();

    // 记录连接使用时长
    MetricsCollector().recordConnectionReleased(_usageTimer.elapsed);

    // 检查长时间使用
    if (_usageTimer.elapsed > longUsageThreshold && onLongUsage != null) {
      onLongUsage!(this, _usageTimer.elapsed);
    }

    // 触发过期回调
    if (!_isValid && onExpired != null) {
      onExpired!(this);
    }

    // 释放连接回连接池
    try {
      await ConnectionPoolHolder.instance.release(connection);
    } catch (e) {
      // 如果连接池已被重置，释放可能会失败，这是正常的
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('not initialized') ||
          errorStr.contains('database_closed')) {
        AppLogger.d(
          'Ignoring release error during pool reset: $e',
          'ConnectionLease',
        );
        return;
      }
      rethrow;
    }
  }

  /// 获取诊断信息
  Map<String, dynamic> get diagnostics => {
        'operationId': operationId,
        'poolVersion': poolVersion,
        'currentVersion': ConnectionPoolHolder.version,
        'isValid': _isValid,
        'isDisposed': _isDisposed,
        'ageMs': age.inMilliseconds,
        'usageTimeMs': usageTime.inMilliseconds,
        'validationCount': _validationCount,
      };

  @override
  String toString() =>
      'ConnectionLease(operationId: $operationId, version: $poolVersion, age: ${age.inSeconds}s)';
}

/// 连接租借管理器
/// 
/// 管理多个连接租借的生命周期
class ConnectionLeaseManager {
  final Set<ConnectionLease> _activeLeases = {};
  final Duration _cleanupInterval;
  Timer? _cleanupTimer;

  ConnectionLeaseManager({
    Duration cleanupInterval = const Duration(seconds: 30),
  }) : _cleanupInterval = cleanupInterval;

  /// 启动清理定时器
  void start() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _cleanup());
  }

  /// 停止清理定时器
  void stop() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// 注册新的租借
  void register(ConnectionLease lease) {
    _activeLeases.add(lease);
  }

  /// 注销租借
  void unregister(ConnectionLease lease) {
    _activeLeases.remove(lease);
  }

  /// 获取活动租借数量
  int get activeLeaseCount => _activeLeases.length;

  /// 获取所有活动租借的诊断信息
  List<Map<String, dynamic>> get diagnostics =>
      _activeLeases.map((l) => l.diagnostics).toList();

  /// 清理失效的租借
  Future<void> _cleanup() async {
    final expiredLeases = _activeLeases.where((lease) {
      if (lease.isDisposed) return true;
      if (!lease.validateFast()) return true;
      return false;
    }).toList();

    for (final lease in expiredLeases) {
      AppLogger.d(
        'Cleaning up expired lease: ${lease.operationId}',
        'ConnectionLeaseManager',
      );
      await lease.dispose();
      _activeLeases.remove(lease);
    }
  }

  /// 强制释放所有租借
  Future<void> disposeAll() async {
    final leases = List<ConnectionLease>.from(_activeLeases);
    for (final lease in leases) {
      await lease.dispose();
    }
    _activeLeases.clear();
    stop();
  }
}

/// 便捷函数：获取连接租借
/// 
/// [operationId] 操作标识，用于诊断
/// [timeout] 获取连接的超时时间
Future<ConnectionLease> acquireLease({
  String? operationId,
  Duration timeout = const Duration(seconds: 5),
  String dataSource = 'default',
}) async {
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    try {
      // 检查连接池是否已初始化
      if (!ConnectionPoolHolder.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final poolVersion = ConnectionPoolHolder.version;
      final connection = await ConnectionPoolHolder.instance.acquire();

      // 验证连接
      try {
        await connection.rawQuery('SELECT 1');
      } catch (e) {
        // 连接无效，释放并继续
        try {
          await ConnectionPoolHolder.instance.release(connection);
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      // 记录连接获取
      MetricsCollector().recordConnectionAcquired(stopwatch.elapsed, dataSource);

      return ConnectionLease(
        connection: connection,
        poolVersion: poolVersion,
        operationId: operationId,
        onLongUsage: (lease, duration) {
          AppLogger.w(
            'Long connection usage detected: ${duration.inSeconds}s '
            'for operation ${lease.operationId}',
            'ConnectionLease',
          );
        },
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('database_closed') ||
          errorStr.contains('not initialized')) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }
      rethrow;
    }
  }

  throw ConnectionLeaseException(
    'Timeout acquiring connection lease after ${timeout.inSeconds}s',
    operationId: operationId,
  );
}

/// 便捷函数：使用连接租借执行操作
/// 
/// [operation] 数据库操作
/// [operationId] 操作标识
/// [timeout] 操作超时时间
Future<T> withLease<T>(
  Future<T> Function(Database db) operation, {
  String? operationId,
  Duration acquireTimeout = const Duration(seconds: 5),
  Duration operationTimeout = const Duration(seconds: 30),
}) async {
  final lease = await acquireLease(
    operationId: operationId,
    timeout: acquireTimeout,
  );

  try {
    return await lease.execute(operation).timeout(operationTimeout);
  } finally {
    await lease.dispose();
  }
}
