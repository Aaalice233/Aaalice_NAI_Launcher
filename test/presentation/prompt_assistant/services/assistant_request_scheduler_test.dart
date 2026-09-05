import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/assistant_execution_settings.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/assistant_request_scheduler.dart';

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

DioException limited({int status = 429, String? retryAfter, String? detail}) {
  final options = RequestOptions(path: '/chat/completions');
  return DioException(
    requestOptions: options,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        if (retryAfter != null) 'retry-after': [retryAfter],
      }),
      data: detail,
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  test('automatic starts at five and grows only with queued work', () {
    fakeAsync((time) {
      final scheduler = AssistantRequestScheduler(
        now: time.getClock(DateTime(2026)).now,
      );
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
      final scheduler = AssistantRequestScheduler(
        now: time.getClock(DateTime(2026)).now,
      );
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
      final scheduler = AssistantRequestScheduler(
        now: time.getClock(DateTime(2026)).now,
      );
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
        final scheduler = AssistantRequestScheduler(
          now: time.getClock(DateTime(2026)).now,
        );
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
      final scheduler = AssistantRequestScheduler(
        now: time.getClock(DateTime(2026)).now,
      );
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
      final scheduler = AssistantRequestScheduler(
        now: time.getClock(DateTime(2026)).now,
      );
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
}
