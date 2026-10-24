import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/prompt_assistant/assistant_execution_settings.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/assistant_request_scheduler.dart';

/// Hands out [values] in order, repeating the last one.
class _ScriptedRandom implements math.Random {
  _ScriptedRandom(this.values);
  final List<double> values;
  int _next = 0;

  @override
  double nextDouble() => values[math.min(_next++, values.length - 1)];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  int nextInt(int max) => throw UnimplementedError();
}

AssistantRequestScheduler _scheduler(
  FakeAsync time, {
  DateTime? start,
  List<double> jitter = const [0],
}) => AssistantRequestScheduler(
  now: time.getClock(start ?? DateTime(2026)).now,
  random: _ScriptedRandom(jitter),
);

/// Retry lines the scheduler writes at the level release builds keep.
List<String> _retryLogsDuring(void Function() body) {
  final lines = <String>[];
  AppLogger.debugSetMinimumLevelForTesting(Level.warning);
  try {
    runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => lines.add(line),
      ),
    );
  } finally {
    AppLogger.debugSetMinimumLevelForTesting(null);
  }
  final retryLine = RegExp(r'\[PromptAssistant\] retry \d');
  return lines.where(retryLine.hasMatch).toList();
}

ProviderConfig provider(String id, {int? manual}) => ProviderConfig(
  id: id,
  name: id,
  baseUrl: 'https://example.invalid',
  concurrency: AssistantConcurrencySettings(
    mode: manual == null
        ? AssistantConcurrencyMode.automatic
        : AssistantConcurrencyMode.manual,
    maxConcurrentRequests: manual ?? 5,
  ),
);

DioException limited({
  int status = 429,
  String? retryAfter,
  Object? detail,
  Map<String, List<String>> headers = const {},
}) {
  final options = RequestOptions(path: '/chat/completions');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        ...headers,
        if (retryAfter != null) 'retry-after': [retryAfter],
      }),
      data: detail,
    ),
    type: DioExceptionType.badResponse,
  );
}

class _UnprintableBody {
  @override
  String toString() => throw StateError('body cannot be rendered');
}

DioException transport(DioExceptionType type, {Object? cause}) => DioException(
  requestOptions: RequestOptions(path: '/chat/completions'),
  type: type,
  error: cause,
);

/// One scheduled request whose attempts throw [failures] in order, then succeed.
class _Probe {
  _Probe(
    AssistantRequestScheduler scheduler,
    ProviderConfig config,
    List<Object> failures, {
    CancelToken? cancelToken,
  }) {
    unawaited(
      scheduler
          .run(
            provider: config,
            cancelToken: cancelToken ?? CancelToken(),
            request: () async {
              final failure = attempts < failures.length
                  ? failures[attempts]
                  : null;
              attempts++;
              if (failure != null) throw failure;
              return 'ok';
            },
          )
          .then<void>(
            (value) => result = value,
            onError: (Object error) => caught = error,
          ),
    );
  }

  int attempts = 0;
  String? result;
  Object? caught;
}

void main() {
  test('automatic starts at five and grows only with queued work', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final config = provider('auto');
      final active = <Completer<String>>[];
      final results = <String>[];
      for (var i = 0; i < 20; i++) {
        final future = scheduler.run(
          provider: config,
          cancelToken: CancelToken(),
          request: () {
            final result = Completer<String>();
            active.add(result);
            return result.future;
          },
        );
        unawaited(future.then(results.add, onError: (Object _) {}));
      }
      expect(active.length, 5);
      for (final item in active.take(5).toList()) {
        item.complete('ok');
      }
      time.flushMicrotasks();
      expect(results.length, 5);
      expect(scheduler.concurrencyFor(config), 6);
      expect(active.length, 11);
      scheduler.dispose();
      for (final item in active.where((item) => !item.isCompleted)) {
        item.complete('cancelled');
      }
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('manual limits are provider-wide and independent between providers', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final started = <String>[];
      final tokens = <CancelToken>[];
      for (final config in [
        provider('a', manual: 2),
        provider('b', manual: 3),
      ]) {
        for (var i = 0; i < 6; i++) {
          final token = CancelToken();
          tokens.add(token);
          unawaited(
            scheduler
                .run(
                  provider: config,
                  cancelToken: token,
                  request: () async {
                    started.add(config.id);
                    throw await token.whenCancel;
                  },
                )
                .then<void>((_) {}, onError: (Object _) {}),
          );
        }
      }
      expect(started.where((id) => id == 'a').length, 2);
      expect(started.where((id) => id == 'b').length, 3);
      scheduler.dispose();
      time.flushMicrotasks();
      expect(started.length, 5);
      expect(tokens.every((token) => token.isCancelled), isTrue);
    });
  });

  test('a burst of rate limits halves once and honors Retry-After', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final config = provider('auto');
      var attempts = 0;
      final results = <String>[];
      for (var i = 0; i < 5; i++) {
        unawaited(
          scheduler
              .run(
                provider: config,
                cancelToken: CancelToken(),
                request: () async {
                  attempts++;
                  if (attempts <= 5) throw limited(retryAfter: '10');
                  return 'ok';
                },
              )
              .then(results.add),
        );
      }
      time.flushMicrotasks();
      expect(attempts, 5);
      expect(scheduler.concurrencyFor(config), 2);
      time.elapse(const Duration(seconds: 9));
      expect(attempts, 5);
      time.elapse(const Duration(seconds: 1));
      expect(attempts, 10);
      expect(results.length, 5);
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test(
    'persistent overload terminates with original error, manual count retained',
    () {
      fakeAsync((time) {
        final scheduler = _scheduler(time);
        final config = provider('manual', manual: 7);
        final failure = limited(status: 503);
        Object? caught;
        var attempts = 0;
        unawaited(
          scheduler
              .run(
                provider: config,
                cancelToken: CancelToken(),
                request: () async {
                  attempts++;
                  throw failure;
                },
              )
              .then<void>(
                (_) {},
                onError: (Object error) {
                  caught = error;
                },
              ),
        );
        time.elapse(const Duration(seconds: 20));
        expect(attempts, 3);
        expect(caught, same(failure));
        expect(scheduler.concurrencyFor(config), 7);
        scheduler.dispose();
        time.flushMicrotasks();
        expect(time.pendingTimers, isEmpty);
      });
    },
  );

  test('authentication and exhausted quota are not retried', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      var attempts = 0;
      final failures = [
        limited(status: 401),
        limited(detail: 'insufficient_quota'),
      ];
      final caught = <Object>[];
      for (final failure in failures) {
        unawaited(
          scheduler
              .run(
                provider: provider('a'),
                cancelToken: CancelToken(),
                request: () async {
                  attempts++;
                  throw failure;
                },
              )
              .then<void>(
                (_) {},
                onError: (Object error) {
                  caught.add(error);
                },
              ),
        );
      }
      time.elapse(const Duration(minutes: 1));
      expect(attempts, 2);
      expect(caught, failures);
      scheduler.dispose();
      time.flushMicrotasks();
    });
  });

  test('cancel during cooldown removes queued retries immediately', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final token = CancelToken();
      var attempts = 0;
      Object? caught;
      unawaited(
        scheduler
            .run(
              provider: provider('a'),
              cancelToken: token,
              request: () async {
                attempts++;
                throw limited(retryAfter: '120');
              },
            )
            .then<void>(
              (_) {},
              onError: (Object error) {
                caught = error;
              },
            ),
      );
      time.flushMicrotasks();
      token.cancel('user');
      time.flushMicrotasks();
      expect(caught, isA<DioException>());
      expect(time.pendingTimers, isEmpty);
      time.elapse(const Duration(minutes: 3));
      expect(attempts, 1);
      scheduler.dispose();
      time.flushMicrotasks();
    });
  });

  test('a dropped connection is retried without throttling', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final config = provider('auto');
      final probe = _Probe(scheduler, config, [
        transport(DioExceptionType.connectionError),
      ]);
      time.flushMicrotasks();
      expect(probe.attempts, 1);
      expect(scheduler.concurrencyFor(config), 5);
      time.elapse(const Duration(milliseconds: 999));
      expect(probe.attempts, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(probe.attempts, 2);
      expect(probe.result, 'ok');
      expect(probe.caught, isNull);
      expect(scheduler.concurrencyFor(config), 5);
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  for (final status in [502, 504]) {
    test('persistent HTTP $status ends with the original error', () {
      fakeAsync((time) {
        final scheduler = _scheduler(time);
        final failure = limited(status: status);
        final probe = _Probe(scheduler, provider('a'), [
          failure,
          failure,
          failure,
        ]);
        time.flushMicrotasks();
        expect(probe.attempts, 1);
        time.elapse(const Duration(seconds: 1));
        expect(probe.attempts, 2);
        time.elapse(const Duration(seconds: 2));
        expect(probe.attempts, 3);
        time.elapse(const Duration(minutes: 1));
        expect(probe.attempts, 3);
        expect(probe.caught, same(failure));
        expect(time.pendingTimers, isEmpty);
        scheduler.dispose();
        time.flushMicrotasks();
      });
    });
  }

  test('every approved transport failure and overload status is retried', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final failures = <Object>[
        transport(DioExceptionType.connectionError),
        transport(
          DioExceptionType.connectionError,
          cause: const HttpException(
            'Connection closed before full header was received',
          ),
        ),
        transport(DioExceptionType.connectionTimeout),
        transport(DioExceptionType.sendTimeout),
        transport(
          DioExceptionType.unknown,
          cause: const SocketException('Connection reset by peer'),
        ),
        transport(
          DioExceptionType.unknown,
          cause: const HttpException('Connection closed while receiving data'),
        ),
        transport(
          DioExceptionType.unknown,
          cause: const HandshakeException(
            'Connection terminated during handshake',
          ),
        ),
        limited(status: 429),
        limited(status: 502),
        limited(status: 503),
        limited(status: 504),
        limited(status: 529),
      ];
      final probes = [
        for (var i = 0; i < failures.length; i++)
          _Probe(scheduler, provider('p$i', manual: 1), [failures[i]]),
      ];
      time.elapse(const Duration(seconds: 1));
      for (var i = 0; i < failures.length; i++) {
        expect(probes[i].attempts, 2, reason: '${failures[i]}');
        expect(probes[i].result, 'ok');
      }
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('receive timeout, HTTP 500, cancellation and bad TLS fail at once', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final failures = <Object>[
        transport(DioExceptionType.receiveTimeout),
        transport(DioExceptionType.cancel),
        transport(DioExceptionType.badCertificate),
        transport(
          DioExceptionType.unknown,
          cause: const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ),
        transport(DioExceptionType.unknown),
        transport(
          DioExceptionType.unknown,
          cause: const HttpException(
            'Header value exceeds the 1048576 size limit',
          ),
        ),
        transport(
          DioExceptionType.unknown,
          cause: const HttpException(
            'Invalid proxy configuration PROXY 127.0.0.1',
          ),
        ),
        limited(status: 500),
        limited(status: 400),
        TimeoutException('local'),
        StateError('parse'),
      ];
      final probes = [
        for (final failure in failures)
          _Probe(scheduler, provider('a', manual: 20), [failure]),
      ];
      time.elapse(const Duration(minutes: 2));
      for (var i = 0; i < failures.length; i++) {
        expect(probes[i].attempts, 1, reason: '${failures[i]}');
        expect(probes[i].caught, same(failures[i]));
      }
      expect(time.pendingTimers, isEmpty);
      scheduler.dispose();
      time.flushMicrotasks();
    });
  });

  test('transient backoff frees its slot and keeps the provider open', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final config = provider('manual', manual: 1);
      final failing = _Probe(scheduler, config, [limited(status: 502)]);
      final queued = _Probe(scheduler, config, const []);
      time.flushMicrotasks();
      expect(failing.attempts, 1);
      expect(queued.attempts, 1);
      expect(queued.result, 'ok');
      time.elapse(const Duration(seconds: 1));
      expect(failing.attempts, 2);
      expect(failing.result, 'ok');
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('cancel during transient backoff ends without another attempt', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final token = CancelToken();
      final probe = _Probe(scheduler, provider('a'), [
        transport(DioExceptionType.connectionTimeout),
      ], cancelToken: token);
      time.flushMicrotasks();
      expect(time.pendingTimers, isNotEmpty);
      token.cancel('user');
      time.flushMicrotasks();
      expect(probe.caught, isA<DioException>());
      expect(time.pendingTimers, isEmpty);
      time.elapse(const Duration(minutes: 1));
      expect(probe.attempts, 1);
      scheduler.dispose();
      time.flushMicrotasks();
    });
  });

  test('dispose during transient backoff fails the request', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final probe = _Probe(scheduler, provider('a'), [limited(status: 504)]);
      time.flushMicrotasks();
      scheduler.dispose();
      time.flushMicrotasks();
      expect(probe.caught, isA<DioException>());
      expect(time.pendingTimers, isEmpty);
      time.elapse(const Duration(minutes: 1));
      expect(probe.attempts, 1);
    });
  });

  test('Retry-After beyond sixty seconds waits sixty seconds', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time, start: DateTime.utc(2026));
      final seconds = _Probe(scheduler, provider('seconds'), [
        limited(retryAfter: '3600'),
      ]);
      final date = _Probe(scheduler, provider('date'), [
        limited(
          retryAfter: HttpDate.format(
            DateTime.utc(2026).add(const Duration(hours: 2)),
          ),
        ),
      ]);
      time.elapse(const Duration(seconds: 59));
      expect([seconds.attempts, date.attempts], [1, 1]);
      time.elapse(const Duration(seconds: 1));
      expect([seconds.attempts, date.attempts], [2, 2]);
      expect([seconds.result, date.result], ['ok', 'ok']);
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('retry-after-ms takes precedence and 529 throttles like 429', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final config = provider('auto');
      final options = RequestOptions(path: '/v1/messages');
      final overloaded = DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 529,
          headers: Headers.fromMap({
            'retry-after-ms': ['1500'],
            'retry-after': ['30'],
          }),
        ),
        type: DioExceptionType.badResponse,
      );
      final probe = _Probe(scheduler, config, [overloaded]);
      time.flushMicrotasks();
      expect(scheduler.concurrencyFor(config), 2);
      time.elapse(const Duration(milliseconds: 1499));
      expect(probe.attempts, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(probe.attempts, 2);
      expect(probe.result, 'ok');
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('HTTP 502 waits its Retry-After without throttling the provider', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final config = provider('auto');
      final probe = _Probe(scheduler, config, [
        limited(status: 502, retryAfter: '5'),
      ]);
      time.flushMicrotasks();
      expect(probe.attempts, 1);
      expect(scheduler.concurrencyFor(config), 5);
      time.elapse(const Duration(milliseconds: 4999));
      expect(probe.attempts, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(probe.attempts, 2);
      expect(probe.result, 'ok');
      expect(scheduler.concurrencyFor(config), 5);
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('repeated retry headers still retry and settle the request', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final rateLimited = _Probe(scheduler, provider('a'), [
        limited(
          headers: {
            'retry-after': ['5', '7'],
          },
        ),
      ]);
      final gateway = _Probe(scheduler, provider('b'), [
        limited(
          status: 502,
          headers: {
            'retry-after-ms': ['1', '2'],
          },
        ),
      ]);
      final unreadableRateLimit = _Probe(scheduler, provider('c'), [
        limited(
          headers: {
            'retry-after': ['soon', 'later'],
          },
        ),
      ]);
      final unreadableGateway = _Probe(scheduler, provider('d'), [
        limited(
          status: 502,
          headers: {
            'retry-after-ms': ['soon', 'later'],
          },
        ),
      ]);
      final defaults = [unreadableRateLimit, unreadableGateway];
      time.flushMicrotasks();
      time.elapse(const Duration(milliseconds: 1));
      expect(gateway.attempts, 2);
      time.elapse(const Duration(milliseconds: 998));
      expect(defaults.map((probe) => probe.attempts), [1, 1]);
      time.elapse(const Duration(milliseconds: 1));
      expect(defaults.map((probe) => probe.attempts), [2, 2]);
      time.elapse(const Duration(milliseconds: 3999));
      expect(rateLimited.attempts, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(rateLimited.attempts, 2);
      for (final probe in [rateLimited, gateway, ...defaults]) {
        expect(probe.result, 'ok');
        expect(probe.caught, isNull);
      }
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test(
    'a failure that cannot be inspected settles with the original error',
    () {
      fakeAsync((time) {
        final scheduler = _scheduler(time);
        final failure = limited(detail: _UnprintableBody());
        final probe = _Probe(scheduler, provider('a'), [failure]);
        final next = _Probe(scheduler, provider('a'), const []);
        time.flushMicrotasks();
        expect(probe.attempts, 1);
        expect(probe.caught, same(failure));
        expect(next.result, 'ok');
        time.elapse(const Duration(minutes: 1));
        expect(probe.attempts, 1);
        expect(time.pendingTimers, isEmpty);
        scheduler.dispose();
        time.flushMicrotasks();
      });
    },
  );

  test('malformed Retry-After falls back to the default backoff', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time);
      final probe = _Probe(scheduler, provider('a'), [
        limited(status: 503, retryAfter: 'soon'),
      ]);
      time.elapse(const Duration(seconds: 1));
      expect(probe.attempts, 2);
      expect(probe.result, 'ok');
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('default transient backoff is stretched by the injected jitter', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time, jitter: [0.5, 0.9]);
      final failure = limited(status: 502);
      final probe = _Probe(scheduler, provider('a'), [failure, failure]);
      time.flushMicrotasks();
      time.elapse(const Duration(milliseconds: 1249));
      expect(probe.attempts, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(probe.attempts, 2);
      time.elapse(const Duration(milliseconds: 2899));
      expect(probe.attempts, 2);
      time.elapse(const Duration(milliseconds: 1));
      expect(probe.attempts, 3);
      expect(probe.result, 'ok');
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('batches failing together retry at different moments', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time, jitter: [0, 0.4, 0.8]);
      final config = provider('tags');
      final batches = [
        for (var i = 0; i < 3; i++)
          _Probe(scheduler, config, [limited(status: 502)]),
      ];
      List<int> attempts() => [for (final batch in batches) batch.attempts];
      time.flushMicrotasks();
      expect(attempts(), [1, 1, 1]);
      time.elapse(const Duration(milliseconds: 1000));
      expect(attempts(), [2, 1, 1]);
      time.elapse(const Duration(milliseconds: 200));
      expect(attempts(), [2, 2, 1]);
      time.elapse(const Duration(milliseconds: 200));
      expect(attempts(), [2, 2, 2]);
      expect(batches.map((batch) => batch.result), everyElement('ok'));
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('a rate limit without Retry-After pauses for the jittered backoff', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time, jitter: [0.5]);
      final probe = _Probe(scheduler, provider('a'), [limited()]);
      time.elapse(const Duration(milliseconds: 1249));
      expect(probe.attempts, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(probe.attempts, 2);
      expect(probe.result, 'ok');
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('server-requested waits are honored without jitter', () {
    fakeAsync((time) {
      final scheduler = _scheduler(time, jitter: [0.9]);
      final gateway = _Probe(scheduler, provider('a'), [
        limited(status: 502, retryAfter: '5'),
      ]);
      final rateLimited = _Probe(scheduler, provider('b'), [
        limited(retryAfter: '3'),
      ]);
      time.elapse(const Duration(milliseconds: 2999));
      expect([gateway.attempts, rateLimited.attempts], [1, 1]);
      time.elapse(const Duration(milliseconds: 1));
      expect([gateway.attempts, rateLimited.attempts], [1, 2]);
      time.elapse(const Duration(milliseconds: 1999));
      expect(gateway.attempts, 1);
      time.elapse(const Duration(milliseconds: 1));
      expect(gateway.attempts, 2);
      expect([gateway.result, rateLimited.result], ['ok', 'ok']);
      scheduler.dispose();
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test('each retry is logged with its cause, attempt and wait only', () {
    const relay = ProviderConfig(
      id: 'relay',
      name: 'relay',
      baseUrl: 'https://relay.invalid/v1?key=sk-secret',
    );
    const leaks = ['sk-secret', 'relay.invalid', 'body-secret', 'completions'];
    late _Probe flaky;
    late _Probe rateLimited;
    late _Probe exhausted;
    final logs = _retryLogsDuring(() {
      fakeAsync((time) {
        final scheduler = _scheduler(time, jitter: [0.5, 0, 0.5, 0]);
        flaky = _Probe(scheduler, relay, [
          limited(status: 502, detail: 'body-secret'),
          transport(DioExceptionType.connectionError),
        ]);
        rateLimited = _Probe(scheduler, provider('limited'), [
          limited(retryAfter: '10', detail: 'body-secret'),
        ]);
        exhausted = _Probe(scheduler, provider('down', manual: 1), [
          for (var i = 0; i < 3; i++) limited(status: 504),
        ]);
        time.elapse(const Duration(minutes: 1));
        scheduler.dispose();
        time.flushMicrotasks();
      });
    });
    expect(flaky.result, 'ok');
    expect(rateLimited.result, 'ok');
    expect(exhausted.attempts, 3);
    expect(exhausted.caught, isA<DioException>());
    expect(logs, hasLength(5));
    expect(logs.where((log) => log.contains('provider=relay ')), [
      contains(
        'retry 1/2 in 1250ms: transient status=502 type=badResponse '
        'provider=relay protocol=openaiChatCompletions',
      ),
      contains(
        'retry 2/2 in 2000ms: transient status=none type=connectionError '
        'provider=relay protocol=openaiChatCompletions',
      ),
    ]);
    expect(logs.where((log) => log.contains('provider=limited ')), [
      contains(
        'retry 1/2 in 10000ms: congestion status=429 type=badResponse '
        'provider=limited',
      ),
    ]);
    expect(logs.where((log) => log.contains('provider=down ')), [
      contains('retry 1/2 in 1000ms: transient status=504'),
      contains('retry 2/2 in 2500ms: transient status=504'),
    ]);
    for (final log in logs) {
      for (final leak in leaks) {
        expect(log, isNot(contains(leak)));
      }
    }
  });

  test('a rate-limit retry logs the longer pause already in force', () {
    final logs = _retryLogsDuring(() {
      fakeAsync((time) {
        final scheduler = _scheduler(time);
        final config = provider('shared');
        _Probe(scheduler, config, [limited(retryAfter: '10')]);
        _Probe(scheduler, config, [limited(retryAfter: '2')]);
        time.elapse(const Duration(seconds: 10));
        scheduler.dispose();
        time.flushMicrotasks();
      });
    });
    expect(logs, [
      contains('retry 1/2 in 10000ms: congestion'),
      contains('retry 1/2 in 10000ms: congestion'),
    ]);
  });
}
