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

/// 重试策略。
class RetryPolicy {
  const RetryPolicy({
    this.enabled = false,
    this.maxRetries = 0,
    this.baseDelayMs = 1000,
  });

  final bool enabled;
  final int maxRetries;
  final int baseDelayMs;
}

/// 重试回调。
class RetryCallbacks {
  const RetryCallbacks({this.onRetry});

  final void Function(int attempt, String error, int delayMs)? onRetry;
}

/// 带重试的助手调用：
/// 瞬时失败（error 且可重试）按指数退避重试，直到成功/中止/次数耗尽。
Future<AssistantMessage> retryAssistantCall(
  Future<AssistantMessage> Function() call,
  RetryPolicy? retry,
  AbortSignal? signal, [
  RetryCallbacks? callbacks,
]) async {
  final maxAttempts = (retry?.enabled == true) ? 1 + (retry!.maxRetries) : 1;
  var attempt = 0;
  while (true) {
    attempt++;
    final message = await call();
    final transient =
        message.stopReason == StopReason.error &&
        _isTransientError(message.errorMessage);
    final aborted =
        message.stopReason == StopReason.aborted ||
        (signal != null && signal.aborted);
    if (!transient || aborted || attempt >= maxAttempts) {
      return message;
    }
    final delayMs = (retry?.baseDelayMs ?? 1000) * attempt;
    callbacks?.onRetry?.call(attempt, message.errorMessage ?? '', delayMs);
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (signal != null && signal.aborted) {
      return message;
    }
  }
}

bool _isTransientError(String? message) {
  if (message == null) {
    return false;
  }
  final lowered = message.toLowerCase();
  return lowered.contains('429') ||
      lowered.contains('overloaded') ||
      lowered.contains('rate limit') ||
      lowered.contains('timeout') ||
      lowered.contains('timed out') ||
      lowered.contains(' 5') ||
      lowered.contains('502') ||
      lowered.contains('503') ||
      lowered.contains('504') ||
      lowered.contains('529');
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
