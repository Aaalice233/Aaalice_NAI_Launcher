import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_pool_holder.dart';

// ============================================================
// 健康状态定义
// ============================================================

/// 连接池健康状态
enum ConnectionHealthStatus {
  /// 健康 - 所有指标正常
  healthy,

  /// 降级 - 部分指标异常，但仍可工作
  degraded,

  /// 不健康 - 严重问题，需要立即处理
  unhealthy,
}

/// 健康状态扩展
extension ConnectionHealthStatusExtension on ConnectionHealthStatus {
  /// 是否为健康状态
  bool get isHealthy => this == ConnectionHealthStatus.healthy;

  /// 是否为可接受状态（健康或降级）
  bool get isAcceptable => this != ConnectionHealthStatus.unhealthy;

  /// 优先级（数值越小优先级越高/越好）
  int get priority {
    switch (this) {
      case ConnectionHealthStatus.healthy:
        return 0;
      case ConnectionHealthStatus.degraded:
        return 1;
      case ConnectionHealthStatus.unhealthy:
        return 2;
    }
  }
}

// ============================================================
// 健康检查配置
// ============================================================

/// 健康检查配置
class HealthCheckConfig {
  /// 检查间隔（默认30秒）
  final Duration checkInterval;

  /// 连接获取超时警告阈值
  final Duration connectionAcquireTimeoutThreshold;

  /// 长时间操作警告阈值
  final Duration longOperationThreshold;

  /// 失败率警告阈值（百分比）
  final double failureRateWarningThreshold;

  /// 失败率严重阈值（百分比）
  final double failureRateCriticalThreshold;

  /// 活跃连接数警告阈值（占最大连接数的百分比）
  final double activeConnectionWarningThreshold;

  /// 验证查询
  final String validationQuery;

  /// 最大失败重试次数
  final int maxRetries;

  /// 启用详细日志
  final bool verboseLogging;

  HealthCheckConfig({
    this.checkInterval = const Duration(seconds: 30),
    this.connectionAcquireTimeoutThreshold = const Duration(seconds: 2),
    this.longOperationThreshold = const Duration(seconds: 5),
    this.failureRateWarningThreshold = 10.0, // 10%
    this.failureRateCriticalThreshold = 50.0, // 50%
    this.activeConnectionWarningThreshold = 80.0, // 80%
    this.validationQuery = 'SELECT 1',
    this.maxRetries = 3,
    this.verboseLogging = false,
  });

  /// 生产环境配置（更严格的阈值）
  static final production = HealthCheckConfig(
    checkInterval: const Duration(seconds: 30),
    connectionAcquireTimeoutThreshold: const Duration(milliseconds: 500),
    longOperationThreshold: const Duration(seconds: 3),
    failureRateWarningThreshold: 5.0,
    failureRateCriticalThreshold: 20.0,
    activeConnectionWarningThreshold: 70.0,
  );

  /// 开发环境配置（宽松的阈值）
  static final development = HealthCheckConfig(
    checkInterval: const Duration(seconds: 60),
    connectionAcquireTimeoutThreshold: const Duration(seconds: 5),
    longOperationThreshold: const Duration(seconds: 10),
    failureRateWarningThreshold: 20.0,
    failureRateCriticalThreshold: 60.0,
    activeConnectionWarningThreshold: 90.0,
    verboseLogging: true,
  );
}

// ============================================================
// 健康检查结果
// ============================================================

/// 健康检查结果
class HealthCheckResult {
  /// 检查时间戳
  final DateTime timestamp;

  /// 健康状态
  final ConnectionHealthStatus status;

  /// 连接获取延迟
  final Duration connectionAcquireLatency;

  /// 验证查询是否成功
  final bool validationQuerySuccess;

  /// 验证查询错误信息
  final String? validationError;

  /// 当前连接池版本
  final int poolVersion;

  /// 活跃连接数
  final int activeConnections;

  /// 可用连接数
  final int availableConnections;

  /// 指标快照
  final ConnectionMetricsSnapshot metricsSnapshot;

  /// 失败率（百分比）
  double get failureRate => metricsSnapshot.failureRate;

  /// 平均操作时间（毫秒）
  double get averageOperationTimeMs =>
      metricsSnapshot.averageOperationTime.inMilliseconds.toDouble();

  const HealthCheckResult({
    required this.timestamp,
    required this.status,
    required this.connectionAcquireLatency,
    required this.validationQuerySuccess,
    this.validationError,
    required this.poolVersion,
    required this.activeConnections,
    required this.availableConnections,
    required this.metricsSnapshot,
  });

  @override
  String toString() =>
      'HealthCheckResult(status: $status, latency: ${connectionAcquireLatency.inMilliseconds}ms, '
      'active: $activeConnections, available: $availableConnections)';

  /// 转换为诊断信息
  Map<String, dynamic> toDiagnostics() => {
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'connectionAcquireLatencyMs': connectionAcquireLatency.inMilliseconds,
        'validationQuerySuccess': validationQuerySuccess,
        'validationError': validationError,
        'poolVersion': poolVersion,
        'activeConnections': activeConnections,
        'availableConnections': availableConnections,
        'failureRate': failureRate,
        'averageOperationTimeMs': averageOperationTimeMs,
      };
}

// ============================================================
// 状态变化回调
// ============================================================

/// 健康状态变化回调
typedef HealthStatusChangeCallback = void Function(
  ConnectionHealthStatus oldStatus,
  ConnectionHealthStatus newStatus,
  HealthCheckResult result,
);

/// 健康告警回调
typedef HealthAlertCallback = void Function(
  String alertType,
  String message,
  HealthCheckResult result,
);

// ============================================================
// 连接池健康监控器
// ============================================================

/// 连接池健康监控器
///
/// 功能：
/// 1. 定期检查连接池健康状态
/// 2. 监控连接获取延迟、活跃连接数、失败率等指标
/// 3. 执行简单查询验证连接可用性
/// 4. 检测连接池版本变化
/// 5. 健康状态分级（healthy, degraded, unhealthy）
/// 6. 状态变化时触发回调
/// 7. 可配置告警阈值
///
/// 使用示例：
/// ```dart
/// final monitor = ConnectionHealthMonitor(
///   config: HealthCheckConfig.production,
///   onStatusChange: (old, new, result) {
///     print('Health status changed: $old -> $new');
///   },
/// );
/// monitor.start();
/// ```
class ConnectionHealthMonitor {
  final HealthCheckConfig _config;
  final HealthStatusChangeCallback? _onStatusChange;
  final HealthAlertCallback? _onAlert;

  Timer? _checkTimer;
  ConnectionHealthStatus _currentStatus = ConnectionHealthStatus.healthy;
  HealthCheckResult? _lastResult;
  final ConnectionMetricsCollector _metricsCollector;

  /// 当前健康状态
  ConnectionHealthStatus get currentStatus => _currentStatus;

  /// 最后一次检查结果
  HealthCheckResult? get lastResult => _lastResult;

  /// 是否正在运行
  bool get isRunning => _checkTimer != null;

  ConnectionHealthMonitor({
    HealthCheckConfig? config,
    HealthStatusChangeCallback? onStatusChange,
    HealthAlertCallback? onAlert,
    ConnectionMetricsCollector? metricsCollector,
  })  : _config = config ?? HealthCheckConfig(),
        _onStatusChange = onStatusChange,
        _onAlert = onAlert,
        _metricsCollector =
            metricsCollector ?? ConnectionMetricsCollector();

  /// 启动健康检查
  void start() {
    if (_checkTimer != null) {
      AppLogger.w('Health monitor already running', 'ConnectionHealthMonitor');
      return;
    }

    AppLogger.i(
      'Starting health monitor with interval: ${_config.checkInterval.inSeconds}s',
      'ConnectionHealthMonitor',
    );

    // 立即执行一次检查
    _performCheck();

    // 设置定时检查
    _checkTimer = Timer.periodic(_config.checkInterval, (_) => _performCheck());
  }

  /// 停止健康检查
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    AppLogger.i('Health monitor stopped', 'ConnectionHealthMonitor');
  }

  /// 执行单次健康检查
  Future<HealthCheckResult> check() async {
    return _performCheck();
  }

  /// 执行健康检查
  Future<HealthCheckResult> _performCheck() async {
    final stopwatch = Stopwatch()..start();
    final timestamp = DateTime.now();

    if (_config.verboseLogging) {
      AppLogger.d('Performing health check...', 'ConnectionHealthMonitor');
    }

    // 1. 检查连接池初始化状态
    if (!ConnectionPoolHolder.isInitialized) {
      stopwatch.stop();
      final result = HealthCheckResult(
        timestamp: timestamp,
        status: ConnectionHealthStatus.unhealthy,
        connectionAcquireLatency: stopwatch.elapsed,
        validationQuerySuccess: false,
        validationError: 'Connection pool not initialized',
        poolVersion: ConnectionPoolHolder.version,
        activeConnections: 0,
        availableConnections: 0,
        metricsSnapshot: _metricsCollector.snapshot,
      );

      await _updateStatus(result);
      return result;
    }

    // 2. 测试连接获取时间
    var acquireLatency = Duration.zero;
    bool validationSuccess = false;
    String? validationError;
    int activeConnections = 0;
    int availableConnections = 0;
    Database? testConnection;

    try {
      final acquireStopwatch = Stopwatch()..start();
      testConnection = await ConnectionPoolHolder.instance.acquire().timeout(
            _config.connectionAcquireTimeoutThreshold * 2,
          );
      acquireLatency = acquireStopwatch.elapsed;

      // 记录连接获取时间
      _metricsCollector.recordConnectionAcquired(acquireLatency);

      // 检查连接获取是否超时
      if (acquireLatency > _config.connectionAcquireTimeoutThreshold) {
        AppLogger.w(
          'Slow connection acquisition: ${acquireLatency.inMilliseconds}ms',
          'ConnectionHealthMonitor',
        );
      }

      // 3. 执行验证查询
      try {
        await testConnection.rawQuery(_config.validationQuery);
        validationSuccess = true;
      } catch (e) {
        validationError = 'Validation query failed: $e';
        AppLogger.w(validationError, 'ConnectionHealthMonitor');
      }

      // 获取连接池统计
      final pool = ConnectionPoolHolder.instance;
      activeConnections = pool.inUseCount;
      availableConnections = pool.availableCount;

      // 释放测试连接
      await ConnectionPoolHolder.instance.release(testConnection);
      testConnection = null;
    } on TimeoutException {
      acquireLatency = stopwatch.elapsed;
      validationError = 'Connection acquisition timeout';
      AppLogger.e(
        'Connection acquisition timeout after ${stopwatch.elapsed.inSeconds}s',
        null,
        null,
        'ConnectionHealthMonitor',
      );
    } catch (e) {
      acquireLatency = stopwatch.elapsed;
      validationError = 'Connection acquisition failed: $e';
      AppLogger.e(
        'Connection acquisition failed: $e',
        e,
        null,
        'ConnectionHealthMonitor',
      );
    } finally {
      // 确保释放连接
      if (testConnection != null) {
        try {
          await ConnectionPoolHolder.instance.release(testConnection);
        } catch (_) {}
      }
    }

    stopwatch.stop();

    // 4. 计算健康状态
    final status = _calculateStatus(
      acquireLatency: acquireLatency,
      validationSuccess: validationSuccess,
      activeConnections: activeConnections,
    );

    // 5. 创建检查结果
    final result = HealthCheckResult(
      timestamp: timestamp,
      status: status,
      connectionAcquireLatency: acquireLatency,
      validationQuerySuccess: validationSuccess,
      validationError: validationError,
      poolVersion: ConnectionPoolHolder.version,
      activeConnections: activeConnections,
      availableConnections: availableConnections,
      metricsSnapshot: _metricsCollector.snapshot,
    );

    // 6. 更新状态
    await _updateStatus(result);

    if (_config.verboseLogging) {
      AppLogger.d(
        'Health check completed: $status, '
        'latency: ${acquireLatency.inMilliseconds}ms, '
        'active: $activeConnections, available: $availableConnections',
        'ConnectionHealthMonitor',
      );
    }

    return result;
  }

  /// 计算健康状态
  ConnectionHealthStatus _calculateStatus({
    required Duration acquireLatency,
    required bool validationSuccess,
    required int activeConnections,
  }) {
    int severity = 0;

    // 验证查询失败 -> 不健康
    if (!validationSuccess) {
      return ConnectionHealthStatus.unhealthy;
    }

    // 连接获取超时 -> 降级或不健康
    if (acquireLatency > _config.connectionAcquireTimeoutThreshold * 2) {
      return ConnectionHealthStatus.unhealthy;
    }
    if (acquireLatency > _config.connectionAcquireTimeoutThreshold) {
      severity++;
    }

    // 检查失败率
    final metrics = _metricsCollector.snapshot;
    if (metrics.failureRate >= _config.failureRateCriticalThreshold) {
      return ConnectionHealthStatus.unhealthy;
    }
    if (metrics.failureRate >= _config.failureRateWarningThreshold) {
      severity++;
    }

    // 检查活跃连接数
    if (ConnectionPoolHolder.isInitialized) {
      final pool = ConnectionPoolHolder.instance;
      final activeRatio =
          activeConnections / math.max(1, pool.inUseCount + pool.availableCount);
      if (activeRatio * 100 >= _config.activeConnectionWarningThreshold) {
        severity++;
      }
    }

    if (severity == 0) {
      return ConnectionHealthStatus.healthy;
    } else if (severity <= 1) {
      return ConnectionHealthStatus.degraded;
    } else {
      return ConnectionHealthStatus.unhealthy;
    }
  }

  /// 更新健康状态
  Future<void> _updateStatus(HealthCheckResult result) async {
    _lastResult = result;

    final oldStatus = _currentStatus;
    final newStatus = result.status;

    if (oldStatus != newStatus) {
      _currentStatus = newStatus;

      AppLogger.w(
        'Health status changed: $oldStatus -> $newStatus '
        '(latency: ${result.connectionAcquireLatency.inMilliseconds}ms, '
        'failureRate: ${result.failureRate.toStringAsFixed(2)}%)',
        'ConnectionHealthMonitor',
      );

      // 触发状态变化回调
      _onStatusChange?.call(oldStatus, newStatus, result);

      // 发送事件到事件总线
      DatabaseRecoveryEventBus.emit(
        DatabaseRecoveryEvent(
          timestamp: result.timestamp,
          reason: 'Health status changed: $oldStatus -> $newStatus',
          type: DatabaseRecoveryEventType.healthStatusChange,
          details: result.toDiagnostics(),
        ),
      );

      // 如果不健康，触发告警
      if (newStatus == ConnectionHealthStatus.unhealthy) {
        _onAlert?.call(
          'UNHEALTHY_STATUS',
          'Connection pool is unhealthy: ${result.validationError ?? "Unknown error"}',
          result,
        );
      }
    }
  }

  /// 获取指标收集器
  ConnectionMetricsCollector get metricsCollector => _metricsCollector;

  /// 获取诊断信息
  Map<String, dynamic> get diagnostics => {
        'currentStatus': _currentStatus.name,
        'isRunning': isRunning,
        'checkIntervalMs': _config.checkInterval.inMilliseconds,
        'lastResult': _lastResult?.toDiagnostics(),
        'metrics': _metricsCollector.snapshot.toDiagnostics(),
      };

  /// 释放资源
  void dispose() {
    stop();
    _metricsCollector.clear();
  }
}

// ============================================================
// 数据库恢复事件总线
// ============================================================

/// 数据库恢复事件类型
enum DatabaseRecoveryEventType {
  /// 健康状态变化
  healthStatusChange,

  /// 连接池重置
  poolReset,

  /// 连接恢复
  connectionRestored,

  /// 告警
  alert,

  /// 其他
  other,
}

/// 数据库恢复事件
class DatabaseRecoveryEvent {
  /// 事件时间戳
  final DateTime timestamp;

  /// 事件原因
  final String reason;

  /// 事件类型
  final DatabaseRecoveryEventType type;

  /// 事件详情
  final Map<String, dynamic>? details;

  const DatabaseRecoveryEvent({
    required this.timestamp,
    required this.reason,
    this.type = DatabaseRecoveryEventType.other,
    this.details,
  });

  @override
  String toString() =>
      'DatabaseRecoveryEvent($type: $reason at ${timestamp.toIso8601String()})';
}

/// 数据库恢复事件总线
///
/// 提供全局事件通知机制，用于：
/// 1. 健康状态变化通知
/// 2. 连接池恢复通知
/// 3. 告警广播
///
/// 使用示例：
/// ```dart
/// // 订阅事件
/// DatabaseRecoveryEventBus.events.listen((event) {
///   print('Received: $event');
/// });
///
/// // 发送事件
/// DatabaseRecoveryEventBus.emit(DatabaseRecoveryEvent(
///   timestamp: DateTime.now(),
///   reason: 'Connection restored',
/// ));
/// ```
class DatabaseRecoveryEventBus {
  static final _controller = StreamController<DatabaseRecoveryEvent>.broadcast();

  /// 获取事件流
  static Stream<DatabaseRecoveryEvent> get events => _controller.stream;

  /// 发送事件
  static void emit(DatabaseRecoveryEvent event) {
    if (_controller.isClosed) {
      AppLogger.w(
        'Cannot emit event, controller is closed',
        'DatabaseRecoveryEventBus',
      );
      return;
    }

    _controller.add(event);

    if (_controller.hasListener) {
      AppLogger.d('Event emitted: $event', 'DatabaseRecoveryEventBus');
    }
  }

  /// 关闭事件总线
  ///
  /// 注意：通常不需要手动调用，仅在应用退出时使用
  static void close() {
    _controller.close();
  }
}

// ============================================================
// 连接指标收集器
// ============================================================

/// 连接指标快照
class ConnectionMetricsSnapshot {
  /// 平均操作时间
  final Duration averageOperationTime;

  /// 失败率（0-100）
  final double failureRate;

  /// 活跃连接数
  final int activeConnections;

  /// 总操作数
  final int totalOperations;

  /// 成功操作数
  final int successfulOperations;

  /// 失败操作数
  final int failedOperations;

  /// 平均连接获取等待时间
  final Duration averageAcquireTime;

  /// 平均连接使用时长
  final Duration averageUsageTime;

  const ConnectionMetricsSnapshot({
    required this.averageOperationTime,
    required this.failureRate,
    required this.activeConnections,
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.averageAcquireTime,
    required this.averageUsageTime,
  });

  /// 空快照
  static const empty = ConnectionMetricsSnapshot(
    averageOperationTime: Duration.zero,
    failureRate: 0.0,
    activeConnections: 0,
    totalOperations: 0,
    successfulOperations: 0,
    failedOperations: 0,
    averageAcquireTime: Duration.zero,
    averageUsageTime: Duration.zero,
  );

  /// 转换为诊断信息
  Map<String, dynamic> toDiagnostics() => {
        'averageOperationTimeMs': averageOperationTime.inMilliseconds,
        'failureRate': failureRate,
        'activeConnections': activeConnections,
        'totalOperations': totalOperations,
        'successfulOperations': successfulOperations,
        'failedOperations': failedOperations,
        'averageAcquireTimeMs': averageAcquireTime.inMilliseconds,
        'averageUsageTimeMs': averageUsageTime.inMilliseconds,
      };

  @override
  String toString() =>
      'ConnectionMetricsSnapshot(ops: $totalOperations, '
      'failures: ${failureRate.toStringAsFixed(1)}%, '
      'avgTime: ${averageOperationTime.inMilliseconds}ms)';
}

/// 操作记录
class _OperationRecord {
  final String name;
  final Duration duration;
  final bool success;
  final DateTime timestamp;

  _OperationRecord({
    required this.name,
    required this.duration,
    required this.success,
    required this.timestamp,
  });
}

/// 连接指标收集器
///
/// 收集并统计连接池使用指标：
/// 1. 操作执行时间和成功率
/// 2. 连接获取等待时间
/// 3. 连接使用时长
///
/// 使用示例：
/// ```dart
/// final collector = ConnectionMetricsCollector();
///
/// // 记录操作
/// final stopwatch = Stopwatch()..start();
/// try {
///   await db.query('SELECT * FROM table');
///   collector.recordOperation('query', stopwatch.elapsed, true);
/// } catch (e) {
///   collector.recordOperation('query', stopwatch.elapsed, false);
/// }
///
/// // 获取快照
/// final snapshot = collector.snapshot;
/// print('Failure rate: ${snapshot.failureRate}%');
/// ```
class ConnectionMetricsCollector {
  /// 最大历史记录数
  static const int _maxHistorySize = 1000;

  /// 用于计算移动平均的窗口大小
  static const int _windowSize = 100;

  final Queue<_OperationRecord> _operations = Queue<_OperationRecord>();
  final Queue<Duration> _acquireTimes = Queue<Duration>();
  final Queue<Duration> _usageTimes = Queue<Duration>();

  int _activeConnections = 0;
  int _totalOperations = 0;
  int _successfulOperations = 0;
  int _failedOperations = 0;

  /// 当前活跃连接数
  int get activeConnections => _activeConnections;

  /// 获取指标快照
  ConnectionMetricsSnapshot get snapshot {
    return ConnectionMetricsSnapshot(
      averageOperationTime: _calculateAverageOperationTime(),
      failureRate: _calculateFailureRate(),
      activeConnections: _activeConnections,
      totalOperations: _totalOperations,
      successfulOperations: _successfulOperations,
      failedOperations: _failedOperations,
      averageAcquireTime: _calculateAverage(_acquireTimes),
      averageUsageTime: _calculateAverage(_usageTimes),
    );
  }

  /// 记录操作
  ///
  /// [name] 操作名称
  /// [duration] 操作持续时间
  /// [success] 是否成功
  void recordOperation(String name, Duration duration, bool success) {
    _totalOperations++;
    if (success) {
      _successfulOperations++;
    } else {
      _failedOperations++;
    }

    _operations.add(
      _OperationRecord(
        name: name,
        duration: duration,
        success: success,
        timestamp: DateTime.now(),
      ),
    );

    _trimOperations();
  }

  /// 记录连接获取
  ///
  /// [waitTime] 等待获取连接的时间
  void recordConnectionAcquired(Duration waitTime) {
    _activeConnections++;
    _acquireTimes.add(waitTime);
    _trimQueue(_acquireTimes);
  }

  /// 记录连接释放
  ///
  /// [usageTime] 连接使用时长
  void recordConnectionReleased(Duration usageTime) {
    if (_activeConnections > 0) {
      _activeConnections--;
    }
    _usageTimes.add(usageTime);
    _trimQueue(_usageTimes);
  }

  /// 计算平均操作时间
  Duration _calculateAverageOperationTime() {
    if (_operations.isEmpty) {
      return Duration.zero;
    }

    // 只计算最近的操作
    final recentOps = _operations.toList().reversed.take(_windowSize);
    final totalMs = recentOps.fold<int>(
      0,
      (sum, op) => sum + op.duration.inMilliseconds,
    );

    return Duration(milliseconds: totalMs ~/ recentOps.length);
  }

  /// 计算失败率
  double _calculateFailureRate() {
    if (_totalOperations == 0) {
      return 0.0;
    }

    // 计算最近窗口的失败率
    final recentOps = _operations.toList().reversed.take(_windowSize);
    if (recentOps.isEmpty) {
      return 0.0;
    }

    final failures = recentOps.where((op) => !op.success).length;
    return (failures / recentOps.length) * 100;
  }

  /// 计算平均时长
  Duration _calculateAverage(Queue<Duration> queue) {
    if (queue.isEmpty) {
      return Duration.zero;
    }

    final totalMs = queue.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ queue.length);
  }

  /// 修剪操作记录队列
  void _trimOperations() {
    // 移除过期记录（超过1小时）
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    while (_operations.isNotEmpty &&
        _operations.first.timestamp.isBefore(cutoff)) {
      _operations.removeFirst();
    }

    // 限制队列大小
    while (_operations.length > _maxHistorySize) {
      _operations.removeFirst();
    }
  }

  /// 修剪队列
  void _trimQueue(Queue<Duration> queue) {
    while (queue.length > _windowSize) {
      queue.removeFirst();
    }
  }

  /// 清空所有指标
  void clear() {
    _operations.clear();
    _acquireTimes.clear();
    _usageTimes.clear();
    _activeConnections = 0;
    _totalOperations = 0;
    _successfulOperations = 0;
    _failedOperations = 0;
  }

  /// 获取操作统计（按名称分组）
  Map<String, Map<String, dynamic>> getOperationStats() {
    final stats = <String, List<_OperationRecord>>{};

    for (final op in _operations) {
      stats.putIfAbsent(op.name, () => []).add(op);
    }

    return stats.map((name, records) {
      final total = records.length;
      final successes = records.where((r) => r.success).length;
      final avgMs =
          records.fold<int>(0, (sum, r) => sum + r.duration.inMilliseconds) ~/
              total;

      return MapEntry(
        name,
        {
          'total': total,
          'successes': successes,
          'failures': total - successes,
          'averageTimeMs': avgMs,
          'successRate':
              total > 0 ? (successes / total * 100).toStringAsFixed(1) : '0.0',
        },
      );
    });
  }
}
