/// 手动压缩上下文的结果，调用方据此决定提示文案。
///
/// 压缩不改变可见记录（时间线读 MessageEntry，压缩写 CompactionEntry），
/// 所以除了提示之外用户没有别的途径判断这次点击是否生效。
sealed class AgentChatCompactionOutcome {
  const AgentChatCompactionOutcome();
}

/// 压缩完成，上下文从 [tokensBefore] 降到 [tokensAfter]。
class AgentChatCompactionDone extends AgentChatCompactionOutcome {
  const AgentChatCompactionDone({
    required this.tokensBefore,
    required this.tokensAfter,
  });

  final int tokensBefore;
  final int tokensAfter;
}

/// 前置条件不满足，或没有可折叠的历史。
class AgentChatCompactionSkipped extends AgentChatCompactionOutcome {
  const AgentChatCompactionSkipped(this.reason);

  final AgentChatCompactionSkipReason reason;
}

/// 摘要生成失败或被中止。
class AgentChatCompactionFailed extends AgentChatCompactionOutcome {
  const AgentChatCompactionFailed(this.message);

  final String message;
}

enum AgentChatCompactionSkipReason {
  /// 会话未就绪，或正在生成回复。
  busy,

  /// 缺少模型路由、会话或可用的上下文窗口。
  unavailable,

  /// 历史仍在保留窗口内，没有可折叠的内容。
  nothingToCompact,
}
