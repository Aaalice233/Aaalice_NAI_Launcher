/// 数据库连接池监控指标系统
///
/// 提供连接池状态监控、操作统计、错误追踪和健康检查功能。
///
/// 使用示例：
/// ```dart
/// // 记录操作
/// MetricsCollector().recordOperation('query', duration, success);
///
/// // 获取指标快照
/// final metrics = MetricsCollector().snapshot;
/// print('Pool utilization: ${metrics.poolUtilization}');
///
/// // 启动定期报告
/// MetricsReporter().startReporting(interval: Duration(minutes: 5));
///
/// // 检查健康状态
/// final health = MetricsReporter().checkHealth();
/// ```
library;

export 'connection_metrics.dart';
export 'metrics_collector.dart';
export 'metrics_reporter.dart';
