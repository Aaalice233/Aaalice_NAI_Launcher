import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/backend_http.dart';
import 'package:nai_launcher/core/cloud_sync/backend/backend_http_metrics.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';

void main() {
  test('HEAD ignores the declared representation length', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = 4 * 1024 * 1024;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final response = await BackendHttp().request(
      'HEAD',
      Uri.parse('http://127.0.0.1:${server.port}/large-resource'),
      maxResponseBytes: 0,
    );

    expect(response.statusCode, 200);
    expect(response.data, isEmpty);
  });

  test('204 response is treated as bodyless', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final response = await BackendHttp().request(
      'DELETE',
      Uri.parse('http://127.0.0.1:${server.port}/resource'),
      maxResponseBytes: 0,
    );

    expect(response.statusCode, HttpStatus.noContent);
    expect(response.data, isEmpty);
  });

  test('List<int> XML payload is sent as raw bytes instead of JSON', () async {
    final received = Completer<List<int>>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      received.complete(
        await request.fold<List<int>>([], (all, chunk) {
          all.addAll(chunk);
          return all;
        }),
      );
      request.response.statusCode = HttpStatus.multiStatus;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final xml = utf8.encode('<d:propfind xmlns:d="DAV:"/>');

    await BackendHttp().request(
      'PROPFIND',
      Uri.parse('http://127.0.0.1:${server.port}/dav'),
      headers: const {'Content-Type': 'application/xml; charset=utf-8'},
      data: xml,
    );

    expect(await received.future, xml);
  });

  test('safe requests retry transient server failures', () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.statusCode = requests < 3
          ? HttpStatus.serviceUnavailable
          : HttpStatus.ok;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final response = await BackendHttp(
      sleeper: (_) async {},
    ).request('GET', Uri.parse('http://127.0.0.1:${server.port}/transient'));

    expect(response.statusCode, HttpStatus.ok);
    expect(requests, 3);
  });

  test('operation cancellation aborts an in-flight request', () async {
    final requestSeen = Completer<void>();
    final holdResponse = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestSeen.complete();
      await holdResponse.future;
      await request.response.close();
    });
    addTearDown(() async {
      if (!holdResponse.isCompleted) holdResponse.complete();
      await server.close(force: true);
    });
    final operation = OperationToken();
    final request = operation.runInScope(
      () => BackendHttp().request(
        'GET',
        Uri.parse('http://127.0.0.1:${server.port}/cancel-request'),
      ),
    );
    await requestSeen.future;

    operation.cancel();

    await expectLater(
      request.timeout(const Duration(seconds: 1)),
      throwsA(isA<OperationCancelledException>()),
    );
  });

  test('operation cancellation stops retry backoff', () async {
    final requestSeen = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (!requestSeen.isCompleted) requestSeen.complete();
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.headers.set(HttpHeaders.retryAfterHeader, '120');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final operation = OperationToken();
    final request = operation.runInScope(
      () => BackendHttp().request(
        'GET',
        Uri.parse('http://127.0.0.1:${server.port}/cancel-operation-backoff'),
      ),
    );
    await requestSeen.future;

    operation.cancel();

    await expectLater(
      request.timeout(const Duration(seconds: 1)),
      throwsA(isA<OperationCancelledException>()),
    );
  });

  test('retry backoff stops immediately when cancelled', () async {
    final requestSeen = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (!requestSeen.isCompleted) requestSeen.complete();
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.headers.set(HttpHeaders.retryAfterHeader, '120');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final token = CancelToken();
    final request = BackendHttp().request(
      'GET',
      Uri.parse('http://127.0.0.1:${server.port}/cancel-backoff'),
      cancelToken: token,
    );
    await requestSeen.future;
    final stopwatch = Stopwatch()..start();

    token.cancel('test cancellation');

    await expectLater(request, throwsA(isA<DioException>()));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('explicitly retryable PUT replays identical bytes', () async {
    var requests = 0;
    final bodies = <List<int>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      bodies.add(
        await request.fold<List<int>>([], (all, chunk) {
          all.addAll(chunk);
          return all;
        }),
      );
      request.response.statusCode = requests == 1
          ? HttpStatus.serviceUnavailable
          : HttpStatus.created;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final response = await BackendHttp(sleeper: (_) async {}).request(
      'PUT',
      Uri.parse('http://127.0.0.1:${server.port}/immutable'),
      data: const [1, 2, 3],
      retryable: true,
    );

    expect(response.statusCode, HttpStatus.created);
    expect(bodies, [
      [1, 2, 3],
      [1, 2, 3],
    ]);
  });

  test('chunked response stops at cumulative hard limit', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.chunkedTransferEncoding = true;
      request.response.add([1, 2, 3]);
      await request.response.flush();
      request.response.add([4, 5, 6]);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    await expectLater(
      BackendHttp().request(
        'GET',
        Uri.parse('http://127.0.0.1:${server.port}/chunked'),
        maxResponseBytes: 4,
        tooLargeKind: CloudBackendErrorKind.quota,
      ),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.quota,
        ),
      ),
    );
  });

  test('connection failures expose a user-readable message', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);

    await expectLater(
      BackendHttp().request(
        'GET',
        Uri.parse('http://127.0.0.1:$port/unreachable'),
      ),
      throwsA(
        isA<CloudBackendException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudBackendErrorKind.network,
            )
            .having(
              (error) => error.message,
              'message',
              '无法连接服务器，请检查网络、代理和服务地址后重试。',
            ),
      ),
    );
  });

  test(
    'loopback cross-origin redirect never sends Authorization to target',
    () async {
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var targetRequests = 0;
      target.listen((request) async {
        targetRequests++;
        request.response.statusCode = 200;
        await request.response.close();
      });
      final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      source.listen((request) async {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(
            HttpHeaders.locationHeader,
            'http://127.0.0.1:${target.port}/credential-target',
          );
        await request.response.close();
      });
      addTearDown(() async {
        await source.close(force: true);
        await target.close(force: true);
      });

      await expectLater(
        BackendHttp().request(
          'GET',
          Uri.parse('http://127.0.0.1:${source.port}/start'),
          headers: const {'Authorization': 'Bearer must-not-leak'},
        ),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.redirectRejected,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(targetRequests, 0);
    },
  );

  test('observer records redacted deterministic retry metrics', () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.statusCode = requests == 1
          ? HttpStatus.serviceUnavailable
          : HttpStatus.created;
      request.response.add(utf8.encode('ok'));
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    var now = DateTime.utc(2026, 1, 1);
    final sleeps = <Duration>[];
    final metrics = <BackendHttpRequestMetric>[];
    final http = BackendHttp(
      observer: metrics.add,
      clock: () => now,
      jitter: (delay, attempt) => const Duration(milliseconds: 125),
      sleeper: (delay) async {
        sleeps.add(delay);
        now = now.add(delay);
      },
    );

    final response = await http.request(
      'put',
      Uri.parse(
        'http://127.0.0.1:${server.port}/private/account-id?token=secret',
      ),
      headers: const {'Authorization': 'Bearer secret-token'},
      data: const [1, 2, 3],
      retryable: true,
      endpointCategory: BackendHttpEndpointCategory.object,
    );

    expect(response.statusCode, HttpStatus.created);
    expect(sleeps, [const Duration(milliseconds: 125)]);
    expect(metrics, hasLength(2));
    expect(metrics[0].method, 'PUT');
    expect(metrics[0].endpointCategory, BackendHttpEndpointCategory.object);
    expect(metrics[0].attempt, 1);
    expect(metrics[0].statusCode, HttpStatus.serviceUnavailable);
    expect(metrics[0].requestBytes, 3);
    expect(metrics[0].responseBytes, 2);
    expect(metrics[0].retry, isTrue);
    expect(metrics[0].concurrentRequests, 1);
    expect(metrics[0].maxConcurrentRequests, 1);
    expect(metrics[1].attempt, 2);
    expect(metrics[1].statusCode, HttpStatus.created);
    expect(metrics[1].retry, isFalse);
    expect(metrics[1].elapsed, Duration.zero);
    expect(metrics.join(), isNot(contains('secret')));
    expect(metrics.join(), isNot(contains('account-id')));
  });

  test('Retry-After seconds are bounded to 30 seconds', () async {
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.statusCode = requests == 1
          ? HttpStatus.tooManyRequests
          : HttpStatus.ok;
      if (requests == 1) {
        request.response.headers.set(HttpHeaders.retryAfterHeader, '120');
      }
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final sleeps = <Duration>[];
    final response =
        await BackendHttp(sleeper: (delay) async => sleeps.add(delay)).request(
          'GET',
          Uri.parse('http://127.0.0.1:${server.port}/long-retry-after'),
        );

    expect(response.statusCode, HttpStatus.ok);
    expect(sleeps, [const Duration(seconds: 30)]);
  });

  test('HTTP-date retry delay uses the injected clock', () async {
    var requests = 0;
    final now = DateTime.utc(2026, 1, 1, 0, 0, 0);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      if (requests == 1) {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..headers.set(
            HttpHeaders.retryAfterHeader,
            HttpDate.format(now.add(const Duration(seconds: 7))),
          );
      } else {
        request.response.statusCode = HttpStatus.ok;
      }
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final sleeps = <Duration>[];
    final response =
        await BackendHttp(
          clock: () => now,
          sleeper: (delay) async => sleeps.add(delay),
        ).request(
          'GET',
          Uri.parse('http://127.0.0.1:${server.port}/retry-after-date'),
        );

    expect(response.statusCode, HttpStatus.ok);
    expect(sleeps, [const Duration(seconds: 7)]);
  });

  test('observer reports the maximum concurrent logical requests', () async {
    final bothRequestsSeen = Completer<void>();
    final releaseResponses = Completer<void>();
    var requests = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      if (requests == 2) bothRequestsSeen.complete();
      await releaseResponses.future;
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final metrics = <BackendHttpRequestMetric>[];
    final http = BackendHttp(observer: metrics.add);
    final first = http.request(
      'GET',
      Uri.parse('http://127.0.0.1:${server.port}/first'),
    );
    final second = http.request(
      'GET',
      Uri.parse('http://127.0.0.1:${server.port}/second'),
    );
    await bothRequestsSeen.future;
    releaseResponses.complete();
    await Future.wait([first, second]);

    expect(metrics, hasLength(2));
    expect(
      metrics.map((metric) => metric.maxConcurrentRequests),
      everyElement(2),
    );
  });

  test('disabled observer does not read the metrics clock', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final response = await BackendHttp(
      clock: () => throw StateError('metrics clock should stay idle'),
    ).request('GET', Uri.parse('http://127.0.0.1:${server.port}/no-observer'));

    expect(response.statusCode, HttpStatus.ok);
  });
}
