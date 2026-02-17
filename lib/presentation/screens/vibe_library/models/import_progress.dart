/// 导入进度模型
/// Import progress model for tracking bulk import operations
class ImportProgress {
  final int current;
  final int total;
  final String message;

  const ImportProgress({
    this.current = 0,
    this.total = 0,
    this.message = '',
  });

  /// 获取进度比例 (0.0 - 1.0), 如果没有任务返回 null
  double? get progress => total > 0 ? current / total : null;

  /// 是否正在进行导入
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
}
