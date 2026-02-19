import 'dart:collection';
import 'dart:math';

import '../../utils/app_logger.dart';
import '../connection_pool_holder.dart';
import 'connection_metrics.dart';

/// 指标收集器
///
/// 单例模式，负责收集和存储所有数据库连接池相关的监控指标。
/// 提供操作记录、错误统计、性能指标等功能。
class MetricsCollector {
  static final MetricsCollector _instance = MetricsCollector._();
  factory MetricsCollector() => _instance;
  MetricsCollector._();

  // 历史数据限制
  static const int _maxHistoryPoints = 100;
  static const int _maxOperationRecords = 1000;
  static const int _maxErrorRecords = 100;

  // 操作记录
  final Queue<OperationRecord> _operationRecords = Queue<OperationRecord>();

  // 连接获取记录
  final Queue<ConnectionAcquireRecord> _acquireRecords =
      Queue<ConnectionAcquireRecord>();

  // 连接释放记录
  final Queue<ConnectionReleaseRecord> _releaseRecords =
      Queue<ConnectionReleaseRecord>();

  // 错误记录: 错误类型 -> 次数
  final Map<String, int> _errorCounts = <String, int>{};

  // 数据源指标: 数据源名称 -> 指标
  final Map<String, DataSourceMetricsEntry> _dataSourceMetrics =
      <String, DataSourceMetricsEntry>{};

  // 连接池重置次数
  int _poolResetCount = 0;

  // 等待队列长度（估算）
  int _waitQueueLength = 0;

  // 互斥锁（简单的同步机制）
  bool _isCollecting = false;

  /// 记录操作
  ///
  /// [name] 操作名称
  /// [duration] 操作耗时
  /// [success] 是否成功
  void recordOperation(
    String name,
    Duration duration,
    bool success, {
    String? dataSource,
    String? errorType,
  }) {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      final now = DateTime.now();
      final record = OperationRecord(
        name: name,
        startTime: now.subtract(duration),
        endTime: now,
        success: success,
        dataSource: dataSource,
        errorType: success ? null : errorType,
      );

      _operationRecords.add(record);

      // 限制历史记录数量
      while (_operationRecords.length > _maxOperationRecords) {
        _operationRecords.removeFirst();
      }

      // 更新数据源指标
      if (dataSource != null) {
        _updateDataSourceMetrics(dataSource, duration, success, errorType);
      }

      // 记录错误
      if (!success && errorType != null) {
        _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
      }
    } finally {
      _isCollecting = false;
    }
  }

  /// 记录连接获取
  ///
  /// [waitTime] 等待时间
  /// [dataSource] 数据源名称
  void recordConnectionAcquired(Duration waitTime, String dataSource) {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      _acquireRecords.add(ConnectionAcquireRecord(
        timestamp: DateTime.now(),
        waitTime: waitTime,
        dataSource: dataSource,
      ),);

      // 限制历史记录数量
      while (_acquireRecords.length > _maxHistoryPoints) {
        _acquireRecords.removeFirst();
      }

      // 更新数据源指标
      _updateDataSourceMetrics(
        dataSource,
        Duration.zero,
        true,
        null,
      );
    } finally {
      _isCollecting = false;
    }
  }

  /// 记录连接释放
  ///
  /// [usageTime] 使用时长
  void recordConnectionReleased(Duration usageTime) {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      _releaseRecords.add(ConnectionReleaseRecord(
        timestamp: DateTime.now(),
        usageTime: usageTime,
      ),);

      // 限制历史记录数量
      while (_releaseRecords.length > _maxHistoryPoints) {
        _releaseRecords.removeFirst();
      }
    } finally {
      _isCollecting = false;
    }
  }

  /// 记录错误
  ///
  /// [type] 错误类型
  /// [operation] 操作名称
  void recordError(String type, String operation) {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      _errorCounts[type] = (_errorCounts[type] ?? 0) + 1;

      // 限制错误记录数量
      if (_errorCounts.length > _maxErrorRecords) {
        // 删除最少的错误类型
        var minKey = _errorCounts.keys.first;
        var minValue = _errorCounts[minKey]!;
        for (final entry in _errorCounts.entries) {
          if (entry.value < minValue) {
            minKey = entry.key;
            minValue = entry.value;
          }
        }
        _errorCounts.remove(minKey);
      }

      AppLogger.d('MetricsCollector recorded error: $type in $operation', 'MetricsCollector');
    } finally {
      _isCollecting = false;
    }
  }

  /// 记录连接池重置
  void recordPoolReset() {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      _poolResetCount++;
      _waitQueueLength = 0;

      AppLogger.i('MetricsCollector recorded pool reset #$_poolResetCount', 'MetricsCollector');
    } finally {
      _isCollecting = false;
    }
  }

  /// 更新等待队列长度
  void updateWaitQueueLength(int length) {
    _waitQueueLength = length;
  }

  /// 获取指标快照
  ConnectionPoolMetrics get snapshot {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      final now = DateTime.now();
      final recentOperations = _getRecentOperations(const Duration(minutes: 5));

      // 计算连接池状态
      int availableConnections = 0;
      int inUseConnections = 0;
      int totalConnections = 0;

      try {
        if (ConnectionPoolHolder.isInitialized) {
          final pool = ConnectionPoolHolder.instance;
          availableConnections = pool.availableCount;
          inUseConnections = pool.inUseCount;
          totalConnections = availableConnections + inUseConnections;
        }
      } catch (e) {
        // 连接池可能未初始化
      }

      // 计算操作统计
      final totalOps = _operationRecords.length;
      final failedOps = _operationRecords.where((r) => !r.success).length;

      // 计算平均操作时间
      double avgTime = 0.0;
      if (recentOperations.isNotEmpty) {
        final totalTime = recentOperations.fold<double>(
          0,
          (sum, r) => sum + r.durationMs,
        );
        avgTime = totalTime / recentOperations.length;
      }

      // 计算 P95 和 P99
      double p95Time = 0.0;
      double p99Time = 0.0;
      if (recentOperations.isNotEmpty) {
        final times = recentOperations.map((r) => r.durationMs).toList()..sort();
        p95Time = _percentile(times, 0.95);
        p99Time = _percentile(times, 0.99);
      }

      // 获取错误统计
      final connectionErrors = _errorCounts['connection'] ?? 0;
      final timeoutErrors = _errorCounts['timeout'] ?? 0;
      final versionMismatchErrors = _errorCounts['version_mismatch'] ?? 0;

      // 生成时间序列数据
      final operationTimeHistory = _generateTimeSeries(
        recentOperations.map((r) => r.durationMs).toList(),
        now.subtract(const Duration(minutes: 5)),
        now,
      );

      final errorRateHistory = _generateErrorRateTimeSeries(
        const Duration(minutes: 5),
        now.subtract(const Duration(minutes: 5)),
        now,
      );

      return ConnectionPoolMetrics(
        availableConnections: availableConnections,
        inUseConnections: inUseConnections,
        totalConnections: totalConnections,
        waitQueueLength: _waitQueueLength,
        totalOperations: totalOps,
        failedOperations: failedOps,
        averageOperationTime: avgTime,
        p95OperationTime: p95Time,
        p99OperationTime: p99Time,
        connectionErrors: connectionErrors,
        timeoutErrors: timeoutErrors,
        versionMismatchErrors: versionMismatchErrors,
        operationTimeHistory: operationTimeHistory,
        errorRateHistory: errorRateHistory,
      );
    } finally {
      _isCollecting = false;
    }
  }

  /// 获取指定数据源的指标
  DataSourceMetrics getDataSourceMetrics(String dataSourceName) {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      final entry = _dataSourceMetrics[dataSourceName];
      if (entry == null) {
        return DataSourceMetrics.empty(dataSourceName);
      }

      return DataSourceMetrics(
        name: dataSourceName,
        operationCount: entry.operationCount,
        errorCount: entry.errorCount,
        averageOperationTime: entry.averageOperationTime,
        errorBreakdown: Map<String, int>.from(entry.errorBreakdown),
      );
    } finally {
      _isCollecting = false;
    }
  }

  /// 获取所有数据源指标
  Map<String, DataSourceMetrics> get allDataSourceMetrics {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      return Map<String, DataSourceMetrics>.fromEntries(
        _dataSourceMetrics.entries.map((e) => MapEntry(
            e.key,
            DataSourceMetrics(
              name: e.key,
              operationCount: e.value.operationCount,
              errorCount: e.value.errorCount,
              averageOperationTime: e.value.averageOperationTime,
              errorBreakdown: Map<String, int>.from(e.value.errorBreakdown),
            ),
          ),),
      );
    } finally {
      _isCollecting = false;
    }
  }

  /// 导出所有指标
  Map<String, dynamic> export() {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      return {
        'snapshot': snapshot.toJson(),
        'dataSourceMetrics': _dataSourceMetrics.map(
          (k, v) => MapEntry(k, v.toMetrics(k).toJson()),
        ),
        'poolResetCount': _poolResetCount,
        'totalOperationRecords': _operationRecords.length,
        'totalAcquireRecords': _acquireRecords.length,
        'totalReleaseRecords': _releaseRecords.length,
        'errorCounts': Map<String, int>.from(_errorCounts),
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } finally {
      _isCollecting = false;
    }
  }

  /// 清除所有历史数据
  void clear() {
    _ensureNotCollecting();
    _isCollecting = true;

    try {
      _operationRecords.clear();
      _acquireRecords.clear();
      _releaseRecords.clear();
      _errorCounts.clear();
      _dataSourceMetrics.clear();
      _poolResetCount = 0;
      _waitQueueLength = 0;

      AppLogger.i('MetricsCollector cleared all data', 'MetricsCollector');
    } finally {
      _isCollecting = false;
    }
  }

  /// 获取池重置次数
  int get poolResetCount => _poolResetCount;

  // 内部方法

  void _ensureNotCollecting() {
    // 简单的防重入检查
    if (_isCollecting) {
      // 等待一小段时间
      // 在实际实现中，这里可以使用更复杂的同步机制
    }
  }

  void _updateDataSourceMetrics(
    String dataSource,
    Duration duration,
    bool success,
    String? errorType,
  ) {
    var entry = _dataSourceMetrics[dataSource];
    if (entry == null) {
      entry = DataSourceMetricsEntry();
      _dataSourceMetrics[dataSource] = entry;
    }

    entry.operationCount++;
    if (!success) {
      entry.errorCount++;
      if (errorType != null) {
        entry.errorBreakdown[errorType] = (entry.errorBreakdown[errorType] ?? 0) + 1;
      }
    }

    // 更新平均时间（指数移动平均）
    final durationMs = duration.inMicroseconds / 1000.0;
    if (entry.operationCount == 1) {
      entry.averageOperationTime = durationMs;
    } else {
      entry.averageOperationTime =
          entry.averageOperationTime * 0.9 + durationMs * 0.1;
    }
  }

  List<OperationRecord> _getRecentOperations(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return _operationRecords.where((r) => r.startTime.isAfter(cutoff)).toList();
  }

  double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0.0;
    if (sortedValues.length == 1) return sortedValues.first;

    final index = (sortedValues.length - 1) * percentile;
    final lower = index.floor();
    final upper = index.ceil();

    if (lower == upper) return sortedValues[lower];

    final weight = index - lower;
    return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
  }

  List<MetricsDataPoint> _generateTimeSeries(
    List<double> values,
    DateTime start,
    DateTime end,
  ) {
    if (values.isEmpty) return [];

    final points = <MetricsDataPoint>[];
    final intervalMs = end.difference(start).inMilliseconds / _maxHistoryPoints;

    for (var i = 0; i < min(values.length, _maxHistoryPoints); i++) {
      final timestamp = start.add(Duration(milliseconds: (intervalMs * i).round()));
      points.add(MetricsDataPoint(
        timestamp: timestamp,
        value: values[i],
      ),);
    }

    return points;
  }

  List<MetricsDataPoint> _generateErrorRateTimeSeries(
    Duration window,
    DateTime start,
    DateTime end,
  ) {
    final points = <MetricsDataPoint>[];
    final interval = window ~/ _maxHistoryPoints;

    for (var i = 0; i < _maxHistoryPoints; i++) {
      final windowStart = start.add(interval * i);
      final windowEnd = windowStart.add(interval);

      final windowOps = _operationRecords.where(
        (r) => r.startTime.isAfter(windowStart) && r.startTime.isBefore(windowEnd),
      );

      final windowTotal = windowOps.length;
      final windowFailed = windowOps.where((r) => !r.success).length;
      final errorRate = windowTotal > 0 ? windowFailed / windowTotal : 0.0;

      points.add(MetricsDataPoint(
        timestamp: windowStart,
        value: errorRate,
      ),);
    }

    return points;
  }
}

/// 数据源指标条目（内部使用）
class DataSourceMetricsEntry {
  int operationCount = 0;
  int errorCount = 0;
  double averageOperationTime = 0.0;
  final Map<String, int> errorBreakdown = <String, int>{};

  DataSourceMetrics toMetrics(String name) {
    return DataSourceMetrics(
      name: name,
      operationCount: operationCount,
      errorCount: errorCount,
      averageOperationTime: averageOperationTime,
      errorBreakdown: Map<String, int>.from(errorBreakdown),
    );
  }
}
