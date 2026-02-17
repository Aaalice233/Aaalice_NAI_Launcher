/// 失败处理策略
enum FailureHandlingStrategy {
  /// 自动重试：超过重试次数后移到队尾重新入队
  autoRetry,

  /// 跳过：标记失败并移入失败任务池，继续处理下一个
  skip,

  /// 暂停等待：暂停执行，等待用户手动处理
  pauseAndWait,
}

/// 扩展方法
extension FailureHandlingStrategyExtension on FailureHandlingStrategy {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case FailureHandlingStrategy.autoRetry:
        return '自动重试';
      case FailureHandlingStrategy.skip:
        return '跳过失败';
      case FailureHandlingStrategy.pauseAndWait:
        return '暂停等待';
    }
  }

  /// 获取描述
  String get description {
    switch (this) {
      case FailureHandlingStrategy.autoRetry:
        return '超过重试次数后将任务移到队尾重新尝试';
      case FailureHandlingStrategy.skip:
        return '将失败任务移入失败池，继续处理下一个任务';
      case FailureHandlingStrategy.pauseAndWait:
        return '暂停队列执行，等待手动处理失败任务';
    }
  }
}
