import '../../../core/agent/agent.dart';
import '../../../core/agent/harness/context_overflow.dart';
import '../../../core/agent/harness/llm_helpers.dart';
import '../providers/agent_chat_state.dart';

/// 智能体回合的自动重试：瞬时错误退避后，剔除失败回合并从之前的状态续跑。

const agentChatRetryPolicy = RetryPolicy(
  enabled: true,
  maxRetries: 3,
  baseDelayMs: 2000,
  maxAgentDelayMs: defaultMaxAgentRetryDelayMs,
);

class AgentChatRetryEnd {
  const AgentChatRetryEnd({
    required this.success,
    required this.attempt,
    this.finalError,
    this.cancelled = false,
  });

  final bool success;
  final int attempt;
  final String? finalError;
  final bool cancelled;
}

class AgentChatAutoRetry {
  AgentChatAutoRetry({
    required void Function(AgentChatRetryStatus status) onRetryStart,
    required void Function(AgentChatRetryEnd end) onRetryEnd,
    required void Function(AssistantMessage failed) omitFailedAttempt,
    int Function()? contextWindow,
    int Function()? now,
    this.policy = agentChatRetryPolicy,
  }) : _onRetryStart = onRetryStart,
       _onRetryEnd = onRetryEnd,
       _omitFailedAttempt = omitFailedAttempt,
       _contextWindow = contextWindow ?? (() => 0),
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final RetryPolicy policy;
  final void Function(AgentChatRetryStatus) _onRetryStart;
  final void Function(AgentChatRetryEnd) _onRetryEnd;
  final void Function(AssistantMessage) _omitFailedAttempt;
  final int Function() _contextWindow;
  final int Function() _now;

  int _attempt = 0;
  bool _abortRequested = false;
  AssistantMessage? _lastAssistantMessage;
  AbortController? _sleepController;

  /// 当前已进行的重试次数（未重试为 0）。
  int get attempt => _attempt;
  bool get abortRequested => _abortRequested;
  bool get isRetrying => _sleepController != null;

  void beginRun() {
    _abortRequested = false;
    _lastAssistantMessage = null;
  }

  void requestAbort() {
    _abortRequested = true;
    _sleepController?.abort();
  }

  // 上下文溢出交给压缩处理，重发同样的上下文只会再次溢出。
  bool isRetryable(AssistantMessage message) =>
      !isContextOverflow(message, _contextWindow()) &&
      isRetryableAssistantError(message);

  /// run 结束事件处是否将接着重试；与 [takeRetry] 的判定一致。
  bool willRetryAfter(List<AgentMessage> messages) {
    if (_abortRequested) return false;
    if (!policy.enabled || _attempt >= policy.maxRetries) return false;
    for (final message in messages.reversed) {
      if (message is AssistantMessage) return isRetryable(message);
    }
    return false;
  }

  void recordAssistantMessage(AssistantMessage message) {
    _lastAssistantMessage = message;
    // 成功响应立即清零，避免同一回合内多次 LLM 调用累计重试次数。
    if (message.stopReason != StopReason.error && _attempt > 0) {
      final attempt = _attempt;
      _attempt = 0;
      _onRetryEnd(AgentChatRetryEnd(success: true, attempt: attempt));
    }
  }

  /// 一次 run 结束后调用；返回 true 表示失败回合已剔除、退避已完成，应续跑。
  Future<bool> takeRetry() async {
    final message = _lastAssistantMessage;
    _lastAssistantMessage = null;
    if (_abortRequested) {
      _finishCancelledRetry();
      return false;
    }
    if (message == null) return false;
    if (isRetryable(message) && await _prepareRetry(message)) {
      if (_abortRequested) {
        _finishCancelledRetry();
        return false;
      }
      return true;
    }
    if (_abortRequested) {
      _finishCancelledRetry();
      return false;
    }
    if (message.stopReason == StopReason.error && _attempt > 0) {
      final attempt = _attempt;
      _attempt = 0;
      _onRetryEnd(
        AgentChatRetryEnd(
          success: false,
          attempt: attempt,
          finalError: message.errorMessage,
        ),
      );
    }
    return false;
  }

  void endRun() {
    if (_abortRequested) _finishCancelledRetry();
    _lastAssistantMessage = null;
  }

  Future<bool> _prepareRetry(AssistantMessage message) async {
    if (!policy.enabled) return false;
    _attempt++;
    if (_attempt > policy.maxRetries) {
      // 保留已完成的次数，由收尾流程报告最终失败。
      _attempt--;
      return false;
    }
    final delayMs = retryDelayMs(policy, _attempt);
    final errorMessage = message.errorMessage?.isNotEmpty == true
        ? message.errorMessage!
        : 'Unknown error';
    _onRetryStart(
      AgentChatRetryStatus(
        attempt: _attempt,
        maxAttempts: policy.maxRetries,
        delayMs: delayMs,
        errorMessage: errorMessage,
        resumesAtMs: _now() + delayMs,
      ),
    );
    _omitFailedAttempt(message);
    final controller = AbortController();
    _sleepController = controller;
    try {
      await retrySleep(delayMs, controller.signal);
    } on RetrySleepAbortedException {
      _finishCancelledRetry();
      return false;
    } finally {
      _sleepController = null;
    }
    return true;
  }

  void _finishCancelledRetry() {
    if (_attempt == 0) return;
    final attempt = _attempt;
    _attempt = 0;
    _onRetryEnd(
      AgentChatRetryEnd(
        success: false,
        attempt: attempt,
        finalError: 'Retry cancelled',
        cancelled: true,
      ),
    );
  }
}
