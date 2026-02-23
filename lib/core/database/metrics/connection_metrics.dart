/// 连接池监控指标数据模型
///
/// 提供连接池运行状态的全面监控指标，包括连接状态、
/// 操作统计、错误统计和时间序列数据。
class ConnectionPoolMetrics {
  /// 连接池状态指标
  final int availableConnections;
  final int inUseConnections;
  final int totalConnections;
  final int waitQueueLength;

  /// 操作统计
  final int totalOperations;
  final int failedOperations;
  final double averageOperationTime;
  final double p95OperationTime;
  final double p99OperationTime;

  /// 错误统计
  final int connectionErrors;
  final int timeoutErrors;
  final int versionMismatchErrors;

  /// 时间序列数据（最近N个数据点）
  final List<MetricsDataPoint> operationTimeHistory;
  final List<MetricsDataPoint> errorRateHistory;

  const ConnectionPoolMetrics({
    required this.availableConnections,
    required this.inUseConnections,
    required this.totalConnections,
    required this.waitQueueLength,
    required this.totalOperations,
    required this.failedOperations,
    required this.averageOperationTime,
    required this.p95OperationTime,
    required this.p99OperationTime,
    required this.connectionErrors,
    required this.timeoutErrors,
    required this.versionMismatchErrors,
    required this.operationTimeHistory,
    required this.errorRateHistory,
  });

  /// 空指标（初始状态）
  factory ConnectionPoolMetrics.empty() {
    return const ConnectionPoolMetrics(
      availableConnections: 0,
      inUseConnections: 0,
      totalConnections: 0,
      waitQueueLength: 0,
      totalOperations: 0,
      failedOperations: 0,
      averageOperationTime: 0.0,
      p95OperationTime: 0.0,
      p99OperationTime: 0.0,
      connectionErrors: 0,
      timeoutErrors: 0,
      versionMismatchErrors: 0,
      operationTimeHistory: [],
      errorRateHistory: [],
    );
  }

  /// 计算错误率
  double get errorRate =>
      totalOperations > 0 ? failedOperations / totalOperations : 0.0;

  /// 计算连接池使用率
  double get poolUtilization =>
      totalConnections > 0 ? inUseConnections / totalConnections : 0.0;

  /// 计算连接等待率
  double get waitRate =>
      totalOperations > 0 ? waitQueueLength / totalOperations : 0.0;

  /// 转换为 Map（用于导出）
  Map<String, dynamic> toJson() {
    return {
      'availableConnections': availableConnections,
      'inUseConnections': inUseConnections,
      'totalConnections': totalConnections,
      'waitQueueLength': waitQueueLength,
      'totalOperations': totalOperations,
      'failedOperations': failedOperations,
      'averageOperationTime': averageOperationTime,
      'p95OperationTime': p95OperationTime,
      'p99OperationTime': p99OperationTime,
      'connectionErrors': connectionErrors,
      'timeoutErrors': timeoutErrors,
      'versionMismatchErrors': versionMismatchErrors,
      'errorRate': errorRate,
      'poolUtilization': poolUtilization,
      'operationTimeHistory':
          operationTimeHistory.map((e) => e.toJson()).toList(),
      'errorRateHistory': errorRateHistory.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ConnectionPoolMetrics('
        'connections: $inUseConnections/$totalConnections, '
        'waitQueue: $waitQueueLength, '
        'operations: $totalOperations, '
        'failed: $failedOperations, '
        'avgTime: ${averageOperationTime.toStringAsFixed(2)}ms, '
        'p95: ${p95OperationTime.toStringAsFixed(2)}ms, '
        'p99: ${p99OperationTime.toStringAsFixed(2)}ms, '
        'errors: conn=$connectionErrors, timeout=$timeoutErrors, '
        'version=$versionMismatchErrors)';
  }
}

/// 指标数据点
///
/// 用于存储时间序列指标数据
class MetricsDataPoint {
  final DateTime timestamp;
  final double value;

  const MetricsDataPoint({
    required this.timestamp,
    required this.value,
  });

  /// 转换为 Map
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'value': value,
    };
  }

  @override
  String toString() => 'MetricsDataPoint(${timestamp.toIso8601String()}: $value)';
}

/// 数据源指标
///
/// 针对特定数据源的监控指标
class DataSourceMetrics {
  final String name;
  final int operationCount;
  final int errorCount;
  final double averageOperationTime;
  final Map<String, int> errorBreakdown;

  const DataSourceMetrics({
    required this.name,
    required this.operationCount,
    required this.errorCount,
    required this.averageOperationTime,
    required this.errorBreakdown,
  });

  /// 空指标
  factory DataSourceMetrics.empty(String name) {
    return DataSourceMetrics(
      name: name,
      operationCount: 0,
      errorCount: 0,
      averageOperationTime: 0.0,
      errorBreakdown: const {},
    );
  }

  /// 计算错误率
  double get errorRate =>
      operationCount > 0 ? errorCount / operationCount : 0.0;

  /// 转换为 Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'operationCount': operationCount,
      'errorCount': errorCount,
      'errorRate': errorRate,
      'averageOperationTime': averageOperationTime,
      'errorBreakdown': errorBreakdown,
    };
  }

  @override
  String toString() {
    return 'DataSourceMetrics($name: ops=$operationCount, '
        'errors=$errorCount, avgTime=${averageOperationTime.toStringAsFixed(2)}ms)';
  }
}

/// 操作记录
///
/// 单个操作的详细记录，用于内部统计
class OperationRecord {
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final bool success;
  final String? dataSource;
  final String? errorType;

  const OperationRecord({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.success,
    this.dataSource,
    this.errorType,
  });

  /// 操作耗时
  Duration get duration => endTime.difference(startTime);

  /// 操作耗时（毫秒）
  double get durationMs => duration.inMicroseconds / 1000.0;
}

/// 连接获取记录
///
/// 记录连接获取的等待时间和数据源
class ConnectionAcquireRecord {
  final DateTime timestamp;
  final Duration waitTime;
  final String dataSource;

  const ConnectionAcquireRecord({
    required this.timestamp,
    required this.waitTime,
    required this.dataSource,
  });
}

/// 连接释放记录
///
/// 记录连接使用的时长
class ConnectionReleaseRecord {
  final DateTime timestamp;
  final Duration usageTime;

  const ConnectionReleaseRecord({
    required this.timestamp,
    required this.usageTime,
  });
}
