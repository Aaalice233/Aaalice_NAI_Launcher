import 'dart:async';

import '../../utils/app_logger.dart';
import 'connection_metrics.dart';
import 'metrics_collector.dart';

/// 健康状态
enum HealthStatus {
  healthy, // 健康
  degraded, // 降级
  unhealthy, // 不健康
}

/// 指标报告器
///
/// 负责定期生成和输出监控报告，以及检查系统健康状态。
class MetricsReporter {
  Timer? _reportTimer;
  bool _isRunning = false;

  // 健康检查阈值
  static const double _highErrorRateThreshold = 0.1; // 10% 错误率
  static const double _criticalErrorRateThreshold = 0.3; // 30% 错误率
  static const double _highUtilizationThreshold = 0.9; // 90% 利用率
  static const double _criticalUtilizationThreshold = 1.0; // 100% 利用率
  static const int _criticalWaitQueueThreshold = 10; // 10个等待

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 启动定期报告
  ///
  /// [interval] 报告间隔，默认5分钟
  void startReporting({Duration interval = const Duration(minutes: 5)}) {
    if (_isRunning) {
      AppLogger.w('MetricsReporter already running', 'MetricsReporter');
      return;
    }

    _isRunning = true;
    _reportTimer = Timer.periodic(interval, (_) => _generateAndLogReport());

    AppLogger.i(
      'MetricsReporter started with interval ${interval.inMinutes}min',
      'MetricsReporter',
    );

    // 立即生成第一份报告
    _generateAndLogReport();
  }

  /// 停止定期报告
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _isRunning = false;

    AppLogger.i('MetricsReporter stopped', 'MetricsReporter');
  }

  /// 生成报告
  String generateReport() {
    final metrics = MetricsCollector().snapshot;
    final dataSourceMetrics = MetricsCollector().allDataSourceMetrics;
    final health = checkHealth();

    final buffer = StringBuffer();
    buffer.writeln('=' * 60);
    buffer.writeln('Connection Pool Metrics Report');
    buffer.writeln('Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Health Status: ${_healthStatusString(health)}');
    buffer.writeln('=' * 60);

    // 连接池状态
    buffer.writeln('\n--- Connection Pool Status ---');
    buffer.writeln('Available Connections: ${metrics.availableConnections}');
    buffer.writeln('In-Use Connections: ${metrics.inUseConnections}');
    buffer.writeln('Total Connections: ${metrics.totalConnections}');
    buffer.writeln('Pool Utilization: ${(metrics.poolUtilization * 100).toStringAsFixed(1)}%');
    buffer.writeln('Wait Queue Length: ${metrics.waitQueueLength}');

    // 操作统计
    buffer.writeln('\n--- Operation Statistics ---');
    buffer.writeln('Total Operations: ${metrics.totalOperations}');
    buffer.writeln('Failed Operations: ${metrics.failedOperations}');
    buffer.writeln('Error Rate: ${(metrics.errorRate * 100).toStringAsFixed(2)}%');
    buffer.writeln('Average Operation Time: ${metrics.averageOperationTime.toStringAsFixed(2)} ms');
    buffer.writeln('P95 Operation Time: ${metrics.p95OperationTime.toStringAsFixed(2)} ms');
    buffer.writeln('P99 Operation Time: ${metrics.p99OperationTime.toStringAsFixed(2)} ms');

    // 错误统计
    buffer.writeln('\n--- Error Statistics ---');
    buffer.writeln('Connection Errors: ${metrics.connectionErrors}');
    buffer.writeln('Timeout Errors: ${metrics.timeoutErrors}');
    buffer.writeln('Version Mismatch Errors: ${metrics.versionMismatchErrors}');

    // 数据源指标
    if (dataSourceMetrics.isNotEmpty) {
      buffer.writeln('\n--- Data Source Metrics ---');
      for (final entry in dataSourceMetrics.entries) {
        final ds = entry.value;
        buffer.writeln('${ds.name}: '
            'ops=${ds.operationCount}, '
            'errors=${ds.errorCount}, '
            'avg=${ds.averageOperationTime.toStringAsFixed(2)}ms, '
            'rate=${(ds.errorRate * 100).toStringAsFixed(2)}%');
      }
    }

    // 其他统计
    buffer.writeln('\n--- Other Statistics ---');
    buffer.writeln('Pool Reset Count: ${MetricsCollector().poolResetCount}');

    buffer.writeln('\n${'=' * 60}');

    return buffer.toString();
  }

  /// 检查健康状态
  HealthStatus checkHealth() {
    final metrics = MetricsCollector().snapshot;

    // 检查关键指标
    var healthScore = 100;

    // 错误率检查
    if (metrics.errorRate >= _criticalErrorRateThreshold) {
      healthScore -= 50;
    } else if (metrics.errorRate >= _highErrorRateThreshold) {
      healthScore -= 25;
    }

    // 连接池利用率检查
    if (metrics.poolUtilization >= _criticalUtilizationThreshold) {
      healthScore -= 30;
    } else if (metrics.poolUtilization >= _highUtilizationThreshold) {
      healthScore -= 15;
    }

    // 等待队列检查
    if (metrics.waitQueueLength >= _criticalWaitQueueThreshold) {
      healthScore -= 20;
    } else if (metrics.waitQueueLength > 0) {
      healthScore -= 5;
    }

    // 确定健康状态
    if (healthScore >= 80) {
      return HealthStatus.healthy;
    } else if (healthScore >= 50) {
      return HealthStatus.degraded;
    } else {
      return HealthStatus.unhealthy;
    }
  }

  /// 获取健康状态详情
  HealthCheckDetails getHealthDetails() {
    final metrics = MetricsCollector().snapshot;
    final status = checkHealth();
    final issues = <String>[];
    final recommendations = <String>[];

    // 错误率检查
    if (metrics.errorRate >= _criticalErrorRateThreshold) {
      issues.add('Critical error rate: ${(metrics.errorRate * 100).toStringAsFixed(1)}%');
      recommendations.add('Investigate error logs and check database connectivity');
    } else if (metrics.errorRate >= _highErrorRateThreshold) {
      issues.add('High error rate: ${(metrics.errorRate * 100).toStringAsFixed(1)}%');
      recommendations.add('Monitor error trends and review recent changes');
    }

    // 连接池利用率检查
    if (metrics.poolUtilization >= _criticalUtilizationThreshold) {
      issues.add('Connection pool fully utilized');
      recommendations.add('Consider increasing max connections or optimizing queries');
    } else if (metrics.poolUtilization >= _highUtilizationThreshold) {
      issues.add('Connection pool nearly full: ${(metrics.poolUtilization * 100).toStringAsFixed(0)}%');
      recommendations.add('Monitor for connection leaks');
    }

    // 等待队列检查
    if (metrics.waitQueueLength >= _criticalWaitQueueThreshold) {
      issues.add('Long wait queue: ${metrics.waitQueueLength} requests');
      recommendations.add('Increase connection pool size or reduce query time');
    }

    // 操作时间检查
    if (metrics.p99OperationTime > 5000) {
      // 5秒
      issues.add('High P99 latency: ${metrics.p99OperationTime.toStringAsFixed(0)}ms');
      recommendations.add('Optimize slow queries and add indexes');
    }

    return HealthCheckDetails(
      status: status,
      score: _calculateHealthScore(metrics),
      issues: issues,
      recommendations: recommendations,
      metrics: metrics,
    );
  }

  // 内部方法

  void _generateAndLogReport() {
    try {
      final report = generateReport();
      AppLogger.i('\n$report', 'MetricsReporter');

      // 如果健康状态不佳，输出警告
      final health = checkHealth();
      if (health == HealthStatus.degraded) {
        AppLogger.w('Connection pool health is DEGRADED', 'MetricsReporter');
      } else if (health == HealthStatus.unhealthy) {
        AppLogger.e(
          'Connection pool health is UNHEALTHY - immediate attention required',
          null,
          null,
          'MetricsReporter',
        );
      }
    } catch (e, stack) {
      AppLogger.e('Failed to generate metrics report', e, stack, 'MetricsReporter');
    }
  }

  String _healthStatusString(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return 'HEALTHY ✓';
      case HealthStatus.degraded:
        return 'DEGRADED ⚠';
      case HealthStatus.unhealthy:
        return 'UNHEALTHY ✗';
    }
  }

  int _calculateHealthScore(ConnectionPoolMetrics metrics) {
    var score = 100;

    if (metrics.errorRate >= _criticalErrorRateThreshold) {
      score -= 50;
    } else if (metrics.errorRate >= _highErrorRateThreshold) {
      score -= 25;
    }

    if (metrics.poolUtilization >= _criticalUtilizationThreshold) {
      score -= 30;
    } else if (metrics.poolUtilization >= _highUtilizationThreshold) {
      score -= 15;
    }

    if (metrics.waitQueueLength >= _criticalWaitQueueThreshold) {
      score -= 20;
    } else if (metrics.waitQueueLength > 0) {
      score -= 5;
    }

    if (metrics.p99OperationTime > 5000) {
      score -= 10;
    }

    return score.clamp(0, 100);
  }
}

/// 健康检查详情
class HealthCheckDetails {
  final HealthStatus status;
  final int score;
  final List<String> issues;
  final List<String> recommendations;
  final ConnectionPoolMetrics metrics;

  const HealthCheckDetails({
    required this.status,
    required this.score,
    required this.issues,
    required this.recommendations,
    required this.metrics,
  });

  /// 是否健康
  bool get isHealthy => status == HealthStatus.healthy;

  /// 是否需要关注
  bool get needsAttention => status != HealthStatus.healthy;

  /// 格式化输出
  String format() {
    final buffer = StringBuffer();
    buffer.writeln('Health Check Result');
    buffer.writeln('Status: $status (Score: $score/100)');

    if (issues.isNotEmpty) {
      buffer.writeln('\nIssues:');
      for (var i = 0; i < issues.length; i++) {
        buffer.writeln('  ${i + 1}. ${issues[i]}');
      }
    }

    if (recommendations.isNotEmpty) {
      buffer.writeln('\nRecommendations:');
      for (var i = 0; i < recommendations.length; i++) {
        buffer.writeln('  ${i + 1}. ${recommendations[i]}');
      }
    }

    return buffer.toString();
  }
}
