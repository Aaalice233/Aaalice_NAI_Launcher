/// 复刻任务执行状态
enum ReplicationTaskStatus {
  /// 等待中
  pending,

  /// 执行中
  running,

  /// 已完成
  completed,

  /// 失败
  failed,

  /// 已跳过
  skipped,
}

/// 扩展方法
extension ReplicationTaskStatusExtension on ReplicationTaskStatus {
  /// 是否为终态（不会再变化）
  bool get isTerminal =>
      this == ReplicationTaskStatus.completed ||
      this == ReplicationTaskStatus.failed ||
      this == ReplicationTaskStatus.skipped;

  /// 是否可以重试
  bool get canRetry =>
      this == ReplicationTaskStatus.failed ||
      this == ReplicationTaskStatus.skipped;

  /// 获取显示名称
  String get displayName {
    switch (this) {
      case ReplicationTaskStatus.pending:
        return '等待中';
      case ReplicationTaskStatus.running:
        return '执行中';
      case ReplicationTaskStatus.completed:
        return '已完成';
      case ReplicationTaskStatus.failed:
        return '失败';
      case ReplicationTaskStatus.skipped:
        return '已跳过';
    }
  }
}
