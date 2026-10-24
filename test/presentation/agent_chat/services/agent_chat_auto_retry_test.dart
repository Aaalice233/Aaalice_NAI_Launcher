import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/llm_helpers.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_state.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_auto_retry.dart';

AssistantMessage _failure([String errorMessage = 'overloaded_error']) =>
    AssistantMessage(
      content: const [],
      stopReason: StopReason.error,
      errorMessage: errorMessage,
    );

AssistantMessage _success() => AssistantMessage(
  content: const [AssistantTextContent('done')],
  stopReason: StopReason.stop,
);

class _Harness {
  _Harness({
    RetryPolicy policy = const RetryPolicy(
      enabled: true,
      maxRetries: 3,
      baseDelayMs: 1,
    ),
  }) {
    retry = AgentChatAutoRetry(
      onRetryStart: started.add,
      onRetryEnd: ended.add,
      omitFailedAttempt: omitted.add,
      now: () => 1000,
      policy: policy,
    );
  }

  late final AgentChatAutoRetry retry;
  final started = <AgentChatRetryStatus>[];
  final ended = <AgentChatRetryEnd>[];
  final omitted = <AssistantMessage>[];

  Future<bool> fail([String errorMessage = 'overloaded_error']) {
    retry.recordAssistantMessage(_failure(errorMessage));
    return retry.takeRetry();
  }
}

void main() {
  test('pi defaults: three retries starting at two seconds', () {
    expect(agentChatRetryPolicy.enabled, isTrue);
    expect(agentChatRetryPolicy.maxRetries, 3);
    expect(agentChatRetryPolicy.baseDelayMs, 2000);
    expect(
      [for (var i = 1; i <= 3; i++) retryDelayMs(agentChatRetryPolicy, i)],
      [2000, 4000, 8000],
    );
  });

  test('retries a transient failure and reports success', () async {
    final harness = _Harness();
    harness.retry.beginRun();
    final failure = _failure();
    harness.retry.recordAssistantMessage(failure);

    expect(harness.retry.willRetryAfter([failure]), isTrue);
    expect(await harness.retry.takeRetry(), isTrue);
    expect(harness.omitted.single, same(failure));
    final status = harness.started.single;
    expect(status.attempt, 1);
    expect(status.maxAttempts, 3);
    expect(status.delayMs, 1);
    expect(status.errorMessage, 'overloaded_error');
    expect(status.resumesAtMs, 1001);
    expect(harness.retry.isRetrying, isFalse);

    harness.retry.recordAssistantMessage(_success());
    expect(harness.ended.single.success, isTrue);
    expect(harness.ended.single.attempt, 1);
    expect(harness.retry.attempt, 0);
    expect(await harness.retry.takeRetry(), isFalse);
  });

  test('exhausts the budget and reports the final failure', () async {
    final harness = _Harness(
      policy: const RetryPolicy(enabled: true, maxRetries: 2, baseDelayMs: 1),
    );
    harness.retry.beginRun();

    expect(await harness.fail(), isTrue);
    expect(await harness.fail(), isTrue);
    final last = _failure('overloaded again');
    harness.retry.recordAssistantMessage(last);
    expect(harness.retry.willRetryAfter([last]), isFalse);
    expect(harness.retry.attempt, 2);
    expect(await harness.retry.takeRetry(), isFalse);

    expect(harness.started.map((status) => status.attempt), [1, 2]);
    final end = harness.ended.single;
    expect(end.success, isFalse);
    expect(end.cancelled, isFalse);
    expect(end.attempt, 2);
    expect(end.finalError, 'overloaded again');
    expect(harness.retry.attempt, 0);
  });

  test('caps the doubling delay', () async {
    final harness = _Harness(
      policy: const RetryPolicy(
        enabled: true,
        maxRetries: 5,
        baseDelayMs: 1,
        maxAgentDelayMs: 5,
      ),
    );
    harness.retry.beginRun();
    for (var i = 0; i < 4; i++) {
      expect(await harness.fail(), isTrue);
    }
    expect(harness.started.map((status) => status.delayMs), [1, 2, 4, 5]);
  });

  test('a non-transient failure after retries ends the sequence', () async {
    final harness = _Harness();
    harness.retry.beginRun();
    expect(await harness.fail(), isTrue);
    expect(await harness.fail('401 invalid api key'), isFalse);
    expect(harness.ended.single.success, isFalse);
    expect(harness.ended.single.attempt, 1);
    expect(harness.ended.single.finalError, '401 invalid api key');
  });

  test('non-retryable and overflow failures never retry', () async {
    final harness = _Harness();
    harness.retry.beginRun();
    for (final errorMessage in [
      'insufficient_quota',
      'HTTP 500: prompt is too long: 213462 tokens > 200000 maximum',
    ]) {
      final failure = _failure(errorMessage);
      expect(harness.retry.willRetryAfter([failure]), isFalse);
      harness.retry.recordAssistantMessage(failure);
      expect(await harness.retry.takeRetry(), isFalse);
    }
    expect(harness.started, isEmpty);
    expect(harness.ended, isEmpty);
    expect(harness.omitted, isEmpty);
  });

  test('aborting during backoff cancels the retry', () async {
    final harness = _Harness(
      policy: const RetryPolicy(
        enabled: true,
        maxRetries: 3,
        baseDelayMs: 60000,
      ),
    );
    harness.retry.beginRun();
    final pending = harness.fail();
    await Future<void>.delayed(Duration.zero);
    expect(harness.retry.isRetrying, isTrue);

    harness.retry.requestAbort();

    expect(await pending.timeout(const Duration(seconds: 5)), isFalse);
    expect(harness.retry.isRetrying, isFalse);
    final end = harness.ended.single;
    expect(end.cancelled, isTrue);
    expect(end.success, isFalse);
    expect(end.attempt, 1);
    expect(harness.retry.attempt, 0);
  });

  test('an abort requested before the run ends prevents retrying', () async {
    final harness = _Harness();
    harness.retry.beginRun();
    final failure = _failure();
    harness.retry.recordAssistantMessage(failure);
    harness.retry.requestAbort();

    expect(harness.retry.willRetryAfter([failure]), isFalse);
    expect(await harness.retry.takeRetry(), isFalse);
    expect(harness.started, isEmpty);

    harness.retry.beginRun();
    expect(harness.retry.willRetryAfter([failure]), isTrue);
  });

  test('an interrupted retry ends the sequence without retrying', () async {
    final harness = _Harness();
    harness.retry.beginRun();
    expect(await harness.fail(), isTrue);
    harness.retry.requestAbort();
    harness.retry.recordAssistantMessage(
      AssistantMessage(content: const [], stopReason: StopReason.aborted),
    );
    expect(await harness.retry.takeRetry(), isFalse);
    harness.retry.endRun();

    expect(harness.started, hasLength(1));
    expect(harness.ended.single.attempt, 1);
    expect(harness.retry.attempt, 0);
  });

  test('success between failures resets the per-turn budget', () async {
    final harness = _Harness(
      policy: const RetryPolicy(enabled: true, maxRetries: 1, baseDelayMs: 1),
    );
    harness.retry.beginRun();
    expect(await harness.fail(), isTrue);
    harness.retry.recordAssistantMessage(_success());
    expect(await harness.fail(), isTrue);
    expect(harness.started.map((status) => status.attempt), [1, 1]);
  });

  test('a disabled policy never retries', () async {
    final harness = _Harness(
      policy: const RetryPolicy(enabled: false, maxRetries: 3, baseDelayMs: 1),
    );
    harness.retry.beginRun();
    final failure = _failure();
    expect(harness.retry.willRetryAfter([failure]), isFalse);
    harness.retry.recordAssistantMessage(failure);
    expect(await harness.retry.takeRetry(), isFalse);
    expect(harness.started, isEmpty);
  });
}
