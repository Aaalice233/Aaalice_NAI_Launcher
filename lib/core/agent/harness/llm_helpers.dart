import 'dart:async';
import 'dart:math';

import '../agent_types.dart';

/// LLM 类型层助手的 Dart 等价物：uuidv7 / RetryPolicy /
/// retryAssistantCall / completeSimple（经 StreamFn 收敛为一次性调用）。

/// 用户消息内容文本。
String userContentText(List<UserContent> content) {
  return content.whereType<UserTextContent>().map((c) => c.text).join();
}

int _uuidV7Counter = 0;

/// UUID v7（时间戳排序。
String uuidv7() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final ts = now & 0xFFFFFFFFFFFF; // 48-bit ms
  final rnd = Random.secure();
  final randA = rnd.nextInt(0x1000); // 12 bits
  const version = 7;
  final high = (version << 12) | randA;
  final lowBytes = List<int>.generate(8, (_) => rnd.nextInt(256));
  final variant = (lowBytes[0] & 0x3f) | 0x80;
  _uuidV7Counter++;
  final seq = (_uuidV7Counter & 0xFFFF) ^ rnd.nextInt(0x10000);

  String hex(int v, int width) => v.toRadixString(16).padLeft(width, '0');

  return ''
      '${hex(ts, 12)}'
      '${hex(high, 4)}'
      '${hex(variant, 2)}${hex(lowBytes[1], 2)}'
      '${hex(lowBytes[2], 2)}${hex(lowBytes[3], 2)}'
      '${hex(lowBytes[4], 2)}${hex(lowBytes[5], 2)}'
      '${hex(seq, 4)}';
}

/// 重试策略：有界次数 + 指数退避（`baseDelayMs * 2^(attempt-1)`）。
class RetryPolicy {
  const RetryPolicy({
    required this.enabled,
    required this.maxRetries,
    required this.baseDelayMs,
    this.maxAgentDelayMs,
  });

  final bool enabled;

  /// 最大重试次数（0 = 不重试），首次调用不计入。
  final int maxRetries;
  final int baseDelayMs;

  /// 单次退避上限，缺省为 [defaultMaxAgentRetryDelayMs]。
  final int? maxAgentDelayMs;
}

const defaultMaxAgentRetryDelayMs = 60000;

const _maxSafeInteger = 9007199254740991;

int retryDelayMs(RetryPolicy policy, int attempt) {
  final delay = policy.baseDelayMs * pow(2.0, max(0, attempt - 1));
  final safeDelay = delay.isFinite && delay <= _maxSafeInteger
      ? delay.toInt()
      : _maxSafeInteger;
  return min(safeDelay, policy.maxAgentDelayMs ?? defaultMaxAgentRetryDelayMs);
}

/// [retryAssistantCall] 在每次重试前后发出的回调。
class RetryCallbacks {
  const RetryCallbacks({
    this.onRetryScheduled,
    this.onRetryAttemptStart,
    this.onRetryFinished,
  });

  /// 每次重试的退避开始前（attempt 从 1 起）。
  final FutureOr<void> Function(
    int attempt,
    int maxAttempts,
    int delayMs,
    String errorMessage,
  )?
  onRetryScheduled;

  /// 退避结束、重试调用开始前。
  final FutureOr<void> Function()? onRetryAttemptStart;

  /// 重试循环结束时发出一次；success 表示后续某次调用正常完成。
  final FutureOr<void> Function(bool success, int attempt, String? finalError)?
  onRetryFinished;
}

class RetrySleepAbortedException implements Exception {
  const RetrySleepAbortedException();
}

/// 可被 [signal] 打断的退避等待；中止时抛出 [RetrySleepAbortedException]。
Future<void> retrySleep(int ms, AbortSignal? signal) {
  if (signal != null && signal.aborted) {
    return Future.error(const RetrySleepAbortedException());
  }
  final completer = Completer<void>();
  late final Timer timer;
  void onAbort(String? _) {
    timer.cancel();
    if (!completer.isCompleted) {
      completer.completeError(const RetrySleepAbortedException());
    }
  }

  timer = Timer(Duration(milliseconds: ms), () {
    signal?.removeListener(onAbort);
    if (!completer.isCompleted) completer.complete();
  });
  signal?.addListener(onAbort);
  return completer.future;
}

/// 对单次产出助手消息的调用做有界重试：成功与中止直接返回，不可重试错误
/// 立即返回，其余按 [retryDelayMs] 退避重试；退避期间中止归一为 aborted 消息。
Future<AssistantMessage> retryAssistantCall(
  Future<AssistantMessage> Function() produce,
  RetryPolicy? policy,
  AbortSignal? signal, [
  RetryCallbacks? callbacks,
]) async {
  final maxAttempts = policy != null && policy.enabled ? policy.maxRetries : 0;
  var attempt = 0;
  ({int attempt, String errorMessage})? lastRetry;
  for (;;) {
    final response = await produce();
    if (response.stopReason == StopReason.aborted) {
      if (lastRetry != null) {
        await callbacks?.onRetryFinished?.call(false, lastRetry.attempt, null);
      }
      return response;
    }
    if (response.stopReason != StopReason.error) {
      if (lastRetry != null) {
        await callbacks?.onRetryFinished?.call(true, lastRetry.attempt, null);
      }
      return response;
    }
    if (attempt >= maxAttempts || !isRetryableAssistantError(response)) {
      if (lastRetry != null) {
        await callbacks?.onRetryFinished?.call(
          false,
          lastRetry.attempt,
          response.errorMessage,
        );
      }
      return response;
    }
    attempt++;
    final errorMessage = response.errorMessage?.isNotEmpty == true
        ? response.errorMessage!
        : 'Unknown error';
    lastRetry = (attempt: attempt, errorMessage: errorMessage);
    final delayMs = retryDelayMs(policy!, attempt);
    await callbacks?.onRetryScheduled?.call(
      attempt,
      maxAttempts,
      delayMs,
      errorMessage,
    );
    try {
      await retrySleep(delayMs, signal);
    } on RetrySleepAbortedException {
      await callbacks?.onRetryFinished?.call(false, attempt, errorMessage);
      return AssistantMessage(
        content: response.content,
        stopReason: StopReason.aborted,
        usage: response.usage,
        provider: response.provider,
        model: response.model,
        timestamp: response.timestamp,
      );
    }
    await callbacks?.onRetryAttemptStart?.call();
  }
}

// 订阅额度、计费耗尽同样返回 429，但要数小时后才恢复，重试只会白白消耗。
final _nonRetryableProviderLimitErrorPattern = _providerErrorPattern(const [
  'GoUsageLimitError',
  'FreeUsageLimitError',
  'Monthly usage limit reached',
  'available balance',
  'insufficient_quota',
  'out of budget',
  'quota exceeded',
  'billing',
  'subscription_sharing_usage_limit_exceeded',
  'subscription_sharing_workplace_individual_usage_limit_exceeded',
]);

final _retryableProviderErrorPattern = _providerErrorPattern(const [
  'overloaded',
  'server_busy',
  'servers are currently busy',
  'currently experiencing high demand',
  'model is at capacity',
  'rate.?limit',
  'too many requests',
  // 状态码不能是更长单词或数字的一部分，例如请求 id、字节数。
  r'(?<![a-z0-9])(?:429|500|502|503|504|520|524)(?![a-z0-9])',
  'service.?(?:is.?)?(?:temporarily.?)?unavailable',
  'server.?error',
  'internal.?error',
  'provider.?returned.?(?:an.?)?error',
  'exceeded request buffer limit while retrying upstream',
  'unable to forward upstream',
  'upstream.?request.?failed',
  'upstream_stream_read_error',
  'stream was interrupted',
  'http/?2 stream failed',
  'network.?error',
  'connection.?error',
  'connection.?refused',
  'connection.?lost',
  'other side closed',
  'fetch failed',
  r'request to \S+ failed, reason:',
  'getaddrinfo',
  'ENOTFOUND',
  'EAI_AGAIN',
  'upstream.?connect',
  'reset before headers',
  'socket hang up',
  'socket connection was closed',
  'timed? out',
  'timeout',
  'terminated',
  'websocket.?closed',
  'websocket.?error',
  'ended without',
  'stream ended before message_stop',
  'stream ended before a terminal response event',
  'http2 request did not get a response',
  'stream disconnected before completion',
  'pending stream has been canceled',
  'retry delay',
  'you can retry your request',
  'try your request again',
  'please retry your request',
  'ResourceExhausted',
  'subscription_sharing_usage_unavailable',
  'subscription_sharing_user_unavailable',
]);

RegExp _providerErrorPattern(List<String> patterns) =>
    RegExp(patterns.join('|'), caseSensitive: false);

/// 失败的助手消息是否像瞬时的服务端或传输错误。不含重试策略；上下文溢出
/// 应由调用方先行处理。
bool isRetryableAssistantError(AssistantMessage message) {
  final errorMessage = message.errorMessage;
  if (message.stopReason != StopReason.error ||
      errorMessage == null ||
      errorMessage.isEmpty) {
    return false;
  }
  if (_nonRetryableProviderLimitErrorPattern.hasMatch(errorMessage)) {
    return false;
  }
  return _retryableProviderErrorPattern.hasMatch(errorMessage);
}

/// Models.completeSimple 的函数形态（应用经 StreamFn 收敛提供）。
typedef CompleteSimpleFn =
    Future<AssistantMessage> Function(
      Model model,
      Context context, [
      SimpleStreamOptions? options,
    ]);

/// 经 StreamFn 实现 completeSimple：消费事件流、返回最终消息。
/// 契约
Future<AssistantMessage> completeSimpleViaStreamFn(
  StreamFn streamFn,
  Model model,
  Context context, [
  SimpleStreamOptions? options,
]) async {
  AssistantMessageEventStream stream;
  try {
    stream = streamFn(model, context, options);
  } catch (e) {
    return AssistantMessage(
      content: const [],
      stopReason: StopReason.error,
      errorMessage: e.toString(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
  try {
    await for (final _ in stream.stream) {
      // 只需排空事件；最终结果在 result()。
    }
    return await stream.result();
  } catch (e) {
    return AssistantMessage(
      content: const [],
      stopReason: StopReason.error,
      errorMessage: e.toString(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
