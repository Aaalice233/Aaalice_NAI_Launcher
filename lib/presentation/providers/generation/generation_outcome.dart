/// 一次 generate() 调用自己的结局，调用方据此结算，不必从共享的生成状态倒推。
sealed class GenerationOutcome {
  const GenerationOutcome();

  /// 状态是否进入过 generating；进入过的结局与状态监听看到的终态一致。
  bool get enteredGeneration => false;
}

/// 已有生成在提交或进行中，这次调用没有开始。
final class GenerationBusy extends GenerationOutcome {
  const GenerationBusy();
}

/// 未登录；生成层已发布登录提示。
final class GenerationAuthRequired extends GenerationOutcome {
  const GenerationAuthRequired();
}

/// 请求发出前被本地拒绝，同一份参数重试结果相同。
final class GenerationRejected extends GenerationOutcome {
  const GenerationRejected(this.errorCode);

  /// 与写入生成状态的错误消息相同。
  final String errorCode;
}

/// 生成间隔冷却未过。
final class GenerationCooldownActive extends GenerationOutcome {
  const GenerationCooldownActive();
}

/// 进入生成前被取消。
final class GenerationCancelledBeforeStart extends GenerationOutcome {
  const GenerationCancelledBeforeStart();
}

/// 进入生成前被取消，且已有更新的调用接管了生成。
final class GenerationSuperseded extends GenerationOutcome {
  const GenerationSuperseded();
}

/// 生成通知器已释放。
final class GenerationDisposed extends GenerationOutcome {
  const GenerationDisposed();
}

/// 已进入生成后结束。
sealed class GenerationRunEnded extends GenerationOutcome {
  const GenerationRunEnded();

  @override
  bool get enteredGeneration => true;
}

final class GenerationRunCompleted extends GenerationRunEnded {
  const GenerationRunCompleted();
}

final class GenerationRunFailed extends GenerationRunEnded {
  const GenerationRunFailed(this.errorMessage);

  /// 与写入生成状态的错误消息相同。
  final String errorMessage;
}

final class GenerationRunCancelled extends GenerationRunEnded {
  const GenerationRunCancelled();
}
