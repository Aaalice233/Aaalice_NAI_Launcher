import 'data_source.dart';

// 重新导出类型，方便其他文件导入
export 'data_source.dart' show HealthStatus, DataSourceHealth;

/// 健康检查结果（用于非数据源组件）
class HealthCheckResult {
  final HealthStatus status;
  final String message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  HealthCheckResult({
    required this.status,
    required this.message,
    this.details,
    required this.timestamp,
  });
}
