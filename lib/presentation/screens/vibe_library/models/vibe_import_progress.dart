/// Vibe 导入进度模型
///
/// 用于跟踪 vibe 文件导入过程的进度状态
class ImportProgress {
  final int current;
  final int total;
  final String message;

  const ImportProgress({
    this.current = 0,
    this.total = 0,
    this.message = '',
  });

  /// 获取进度比例 (0.0 - 1.0)，如果 total 为 0 则返回 null
  double? get progress => total > 0 ? current / total : null;

  /// 是否处于活动状态（已开始但未完成）
  bool get isActive => total > 0;

  /// 是否已完成
  bool get isComplete => total > 0 && current >= total;

  ImportProgress copyWith({
    int? current,
    int? total,
    String? message,
  }) {
    return ImportProgress(
      current: current ?? this.current,
      total: total ?? this.total,
      message: message ?? this.message,
    );
  }

  @override
  String toString() {
    return 'ImportProgress(current: $current, total: $total, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportProgress &&
        other.current == current &&
        other.total == total &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(current, total, message);
}
