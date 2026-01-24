import 'package:freezed_annotation/freezed_annotation.dart';

part 'warmup_metrics.freezed.dart';
part 'warmup_metrics.g.dart';

/// 预热任务执行结果
enum WarmupTaskStatus {
  /// 执行成功
  success,

  /// 执行失败
  failed,

  /// 被跳过
  skipped,
}

/// 预热任务指标
@freezed
class WarmupTaskMetrics with _$WarmupTaskMetrics {
  const WarmupTaskMetrics._();

  const factory WarmupTaskMetrics({
    /// 任务名称（例如：warmup_loadingTranslation）
    required String taskName,

    /// 任务执行时长（毫秒）
    required int durationMs,

    /// 执行状态
    required WarmupTaskStatus status,

    /// 错误消息（失败时记录）
    String? errorMessage,

    /// 执行时间戳
    required DateTime timestamp,
  }) = _WarmupTaskMetrics;

  factory WarmupTaskMetrics.fromJson(Map<String, dynamic> json) =>
      _$WarmupTaskMetricsFromJson(json);

  /// 创建新的任务指标记录
  factory WarmupTaskMetrics.create({
    required String taskName,
    required int durationMs,
    required WarmupTaskStatus status,
    String? errorMessage,
  }) {
    return WarmupTaskMetrics(
      taskName: taskName,
      durationMs: durationMs,
      status: status,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
  }

  /// 是否成功
  bool get isSuccess => status == WarmupTaskStatus.success;

  /// 是否失败
  bool get isFailed => status == WarmupTaskStatus.failed;

  /// 是否被跳过
  bool get isSkipped => status == WarmupTaskStatus.skipped;

  /// 获取格式化的时长字符串
  String get formattedDuration {
    if (durationMs < 1000) {
      return '${durationMs}ms';
    } else if (durationMs < 60000) {
      final seconds = (durationMs / 1000).toStringAsFixed(1);
      return '${seconds}s';
    } else {
      final minutes = (durationMs / 60000).toStringAsFixed(1);
      return '${minutes}m';
    }
  }
}
