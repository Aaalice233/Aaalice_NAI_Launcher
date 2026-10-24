import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/llm_helpers.dart';

AssistantMessage _message(
  String text, {
  StopReason stopReason = StopReason.stop,
  String? errorMessage,
}) => AssistantMessage(
  content: [AssistantTextContent(text)],
  stopReason: stopReason,
  errorMessage: errorMessage,
);

AssistantMessage _error(String errorMessage) =>
    _message('', stopReason: StopReason.error, errorMessage: errorMessage);

bool _retryable(String errorMessage) =>
    isRetryableAssistantError(_error(errorMessage));

void main() {
  group('provider retry classification', () {
    test('matches explicit provider retry guidance', () {
      expect(
        _retryable(
          'An error occurred while processing your request. You can retry '
          'your request, or contact us through our help center.',
        ),
        isTrue,
      );
      expect(
        _retryable(
          '{"message":"The system encountered an unexpected error during '
          'processing. Try your request again."}',
        ),
        isTrue,
      );
      expect(
        _retryable(
          'ResourceExhausted: Worker local total request limit reached '
          '(288/48)',
        ),
        isTrue,
      );
    });

    test('matches socket drop and upstream buffer wording', () {
      expect(
        _retryable(
          'The socket connection was closed unexpectedly. For more '
          'information, pass `verbose: true` in the second argument to fetch()',
        ),
        isTrue,
      );
      expect(
        _retryable(
          'Error: exceeded request buffer limit while retrying upstream',
        ),
        isTrue,
      );
    });

    for (final errorMessage in [
      'The pending stream has been canceled (caused by: getaddrinfo '
          'ENOTFOUND bedrock-runtime.us-east-1.amazonaws.com)',
      'connect ENOTFOUND api.example.com',
      'EAI_AGAIN api.example.com',
      'getaddrinfo failed for api.example.com',
      'The pending stream has been canceled',
      'The service is temporarily unavailable. Please retry later.',
      'Service unavailable: The service is temporarily unavailable.',
      'request to https://oauth2.googleapis.com/token failed, reason:',
      'unknown: Unable to forward upstream stream',
      'upstream_error: Upstream request failed',
      'upstream_stream_read_error: Upstream response stream was interrupted',
      'Upstream HTTP/2 stream failed',
      'OpenAI Responses stream ended before a terminal response event',
      'The system is currently experiencing high demand and cannot process '
          'your request.',
      'subscription_sharing_usage_unavailable: Usage cannot be checked.',
      'subscription_sharing_user_unavailable: User cannot be loaded.',
      'overloaded_error',
      '520 status code (no body)',
      '524 status code (no body)',
    ]) {
      test('retries transient failure: $errorMessage', () {
        expect(_retryable(errorMessage), isTrue);
      });
    }

    for (final errorMessage in [
      '429 quota exceeded',
      'OpenAI API error (429): {"code":"subscription_sharing_usage_limit_'
          'exceeded","message":"Usage limit reached."}',
      'OpenAI API error (429): {"code":"subscription_sharing_workplace_'
          'individual_usage_limit_exceeded","message":"Usage limit reached."}',
      '401 {"type":"error","error":{"type":"authentication_error","message":'
          '"invalid x-api-key"},"request_id":"req_011CU503xyz"}',
      '400 image exceeds 5 MB maximum: 5316784 bytes > 5242880 bytes',
    ]) {
      test('keeps deterministic failure non-retryable: $errorMessage', () {
        expect(_retryable(errorMessage), isFalse);
      });
    }

    test('only failed messages with an error text are retryable', () {
      expect(isRetryableAssistantError(_message('not an error')), isFalse);
      expect(
        isRetryableAssistantError(
          _message('', stopReason: StopReason.error, errorMessage: ''),
        ),
        isFalse,
      );
      expect(
        isRetryableAssistantError(
          _message(
            '',
            stopReason: StopReason.aborted,
            errorMessage: 'overloaded',
          ),
        ),
        isFalse,
      );
    });
  });

  test('retryDelayMs doubles from the base and honours the cap', () {
    const policy = RetryPolicy(
      enabled: true,
      maxRetries: 3,
      baseDelayMs: 2000,
    );
    expect(
      [for (var attempt = 1; attempt <= 3; attempt++) retryDelayMs(policy, attempt)],
      [2000, 4000, 8000],
    );
    expect(retryDelayMs(policy, 6), 60000);
    expect(
      retryDelayMs(
        const RetryPolicy(
          enabled: true,
          maxRetries: 3,
          baseDelayMs: 2000,
          maxAgentDelayMs: 5000,
        ),
        5,
      ),
      5000,
    );
    expect(
      retryDelayMs(
        const RetryPolicy(
          enabled: true,
          maxRetries: 3,
          baseDelayMs: 2000,
          maxAgentDelayMs: 0,
        ),
        5,
      ),
      0,
    );
    expect(retryDelayMs(policy, 2000), 60000);
  });

  group('retryAssistantCall', () {
    const disabled = RetryPolicy(
      enabled: false,
      maxRetries: 3,
      baseDelayMs: 0,
    );
    const enabled = RetryPolicy(enabled: true, maxRetries: 3, baseDelayMs: 0);

    test('returns a successful response immediately', () async {
      var calls = 0;
      final result = await retryAssistantCall(() async {
        calls++;
        return _message('ok');
      }, enabled, null);
      expect(result.text, 'ok');
      expect(calls, 1);
    });

    test('does not retry an aborted message', () async {
      var calls = 0;
      var scheduled = 0;
      final result = await retryAssistantCall(
        () async {
          calls++;
          return _message('', stopReason: StopReason.aborted);
        },
        enabled,
        null,
        RetryCallbacks(onRetryScheduled: (_, _, _, _) => scheduled++),
      );
      expect(result.stopReason, StopReason.aborted);
      expect(calls, 1);
      expect(scheduled, 0);
    });

    test('does not retry quota exhaustion', () async {
      var calls = 0;
      var scheduled = 0;
      var finished = 0;
      final result = await retryAssistantCall(
        () async {
          calls++;
          return _error('insufficient_quota');
        },
        enabled,
        null,
        RetryCallbacks(
          onRetryScheduled: (_, _, _, _) => scheduled++,
          onRetryFinished: (_, _, _) => finished++,
        ),
      );
      expect(result.stopReason, StopReason.error);
      expect(calls, 1);
      expect(scheduled, 0);
      expect(finished, 0);
    });

    test('retries up to maxRetries then returns the final error', () async {
      var calls = 0;
      var scheduled = 0;
      final finished = <(bool, int, String?)>[];
      final result = await retryAssistantCall(
        () async {
          calls++;
          return _error('terminated');
        },
        enabled,
        null,
        RetryCallbacks(
          onRetryScheduled: (_, _, _, _) => scheduled++,
          onRetryFinished: (success, attempt, finalError) =>
              finished.add((success, attempt, finalError)),
        ),
      );
      expect(result.stopReason, StopReason.error);
      expect(calls, 4);
      expect(scheduled, 3);
      expect(finished, [(false, 3, 'terminated')]);
    });

    test('reports capped retry delays', () async {
      var calls = 0;
      final delays = <int>[];
      await retryAssistantCall(
        () async {
          calls++;
          return calls < 5 ? _error('terminated') : _message('recovered');
        },
        const RetryPolicy(
          enabled: true,
          maxRetries: 4,
          baseDelayMs: 10,
          maxAgentDelayMs: 15,
        ),
        null,
        RetryCallbacks(
          onRetryScheduled: (_, _, delayMs, _) => delays.add(delayMs),
        ),
      );
      expect(delays, [10, 15, 15, 15]);
    });

    test('stops retrying once a call succeeds', () async {
      var calls = 0;
      final finished = <(bool, int, String?)>[];
      final result = await retryAssistantCall(
        () async {
          calls++;
          return calls < 3 ? _error('terminated') : _message('recovered');
        },
        enabled,
        null,
        RetryCallbacks(
          onRetryFinished: (success, attempt, finalError) =>
              finished.add((success, attempt, finalError)),
        ),
      );
      expect(result.text, 'recovered');
      expect(calls, 3);
      expect(finished, [(true, 2, null)]);
    });

    test('reports an aborted retried call as unsuccessful', () async {
      var calls = 0;
      final finished = <(bool, int, String?)>[];
      final result = await retryAssistantCall(
        () async {
          calls++;
          return calls == 1
              ? _error('terminated')
              : _message('', stopReason: StopReason.aborted);
        },
        enabled,
        null,
        RetryCallbacks(
          onRetryFinished: (success, attempt, finalError) =>
              finished.add((success, attempt, finalError)),
        ),
      );
      expect(result.stopReason, StopReason.aborted);
      expect(calls, 2);
      expect(finished, [(false, 1, null)]);
    });

    test('does not retry when the policy is disabled', () async {
      var calls = 0;
      var scheduled = 0;
      final result = await retryAssistantCall(
        () async {
          calls++;
          return _error('terminated');
        },
        disabled,
        null,
        RetryCallbacks(onRetryScheduled: (_, _, _, _) => scheduled++),
      );
      expect(result.stopReason, StopReason.error);
      expect(calls, 1);
      expect(scheduled, 0);
    });

    test('announces each attempt after its backoff', () async {
      final events = <String>[];
      var calls = 0;
      final result = await retryAssistantCall(
        () async {
          events.add('produce:$calls');
          calls++;
          return calls < 3 ? _error('terminated') : _message('recovered');
        },
        enabled,
        null,
        RetryCallbacks(
          onRetryScheduled: (attempt, _, _, _) => events.add('retry:$attempt'),
          onRetryAttemptStart: () => events.add('attempt-start'),
        ),
      );
      expect(result.text, 'recovered');
      expect(events, [
        'produce:0',
        'retry:1',
        'attempt-start',
        'produce:1',
        'retry:2',
        'attempt-start',
        'produce:2',
      ]);
    });

    test('abort during backoff returns an aborted message', () async {
      final controller = AbortController();
      final produced = Completer<void>();
      var calls = 0;
      final finished = <(bool, int, String?)>[];
      final pending = retryAssistantCall(
        () async {
          calls++;
          if (!produced.isCompleted) produced.complete();
          return _error('terminated');
        },
        const RetryPolicy(enabled: true, maxRetries: 5, baseDelayMs: 10000),
        controller.signal,
        RetryCallbacks(
          onRetryFinished: (success, attempt, finalError) =>
              finished.add((success, attempt, finalError)),
        ),
      );
      await produced.future;
      await Future<void>.delayed(Duration.zero);
      controller.abort();
      final result = await pending.timeout(const Duration(seconds: 5));
      expect(result.stopReason, StopReason.aborted);
      expect(result.errorMessage, isNull);
      expect(calls, 1);
      expect(finished, [(false, 1, 'terminated')]);
    });
  });

  test('retrySleep completes after the delay and aborts promptly', () async {
    await retrySleep(1, null);
    final controller = AbortController();
    final sleep = retrySleep(60000, controller.signal);
    controller.abort();
    await expectLater(
      sleep.timeout(const Duration(seconds: 5)),
      throwsA(isA<RetrySleepAbortedException>()),
    );
    await expectLater(
      retrySleep(1, controller.signal),
      throwsA(isA<RetrySleepAbortedException>()),
    );
  });
}
