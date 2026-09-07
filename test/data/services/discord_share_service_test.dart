import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/services/discord_share_service.dart';

class _MockDio extends Mock implements Dio {}

class _MockSecureStorage extends Mock implements SecureStorageService {}

class _MockLocalStorage extends Mock implements LocalStorageService {}

class _BodyAdapter implements HttpClientAdapter {
  _BodyAdapter(this.body, this.status);
  final String body;
  final int status;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      'retry-after': ['2'],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  late _MockDio dio;
  late _MockSecureStorage secureStorage;
  late _MockLocalStorage localStorage;
  late DiscordShareService service;

  setUp(() {
    dio = _MockDio();
    secureStorage = _MockSecureStorage();
    localStorage = _MockLocalStorage();
    service = DiscordShareService(
      secureStorage: secureStorage,
      localStorage: localStorage,
      dio: dio,
    );
  });

  for (final body in ['<html>Slow down</html>', '{broken json', '']) {
    test('real Dio preserves HTTP 429 before decoding body: $body', () async {
      final transport = Dio(BaseOptions(baseUrl: 'https://relay.test'))
        ..httpClientAdapter = _BodyAdapter(body, 429);
      addTearDown(transport.close);
      final actualService = DiscordShareService(
        secureStorage: secureStorage,
        localStorage: localStorage,
        dio: transport,
      );
      await expectLater(
        _share(actualService),
        throwsA(
          isA<DiscordShareException>()
              .having((e) => e.code, 'code', 'rate_limited')
              .having((e) => e.status, 'status', 429)
              .having((e) => e.retryAfter, 'delay', const Duration(seconds: 2)),
        ),
      );
      verifyNever(() => secureStorage.delete(any()));
    });
  }

  test(
    'OAuth uses PKCE polling and stores only the resulting session',
    () async {
      Uri? openedUri;
      Map<String, dynamic>? pollBody;
      when(() => secureStorage.write(any(), any())).thenAnswer((_) async {});
      when(
        () => dio.post<Object?>(
          '/v1/oauth/result',
          data: any(named: 'data'),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((invocation) async {
        pollBody = Map<String, dynamic>.from(
          invocation.namedArguments[#data] as Map,
        );
        return Response(
          requestOptions: RequestOptions(path: '/v1/oauth/result'),
          statusCode: 200,
          data: {
            'ok': true,
            'token': 'verified-session',
            'user': {'id': '42', 'username': 'alice'},
          },
        );
      });
      service = DiscordShareService(
        secureStorage: secureStorage,
        localStorage: localStorage,
        dio: dio,
        externalUrlLauncher: (uri) async {
          openedUri = uri;
          return true;
        },
      );

      final session = await service.authenticate(
        timeout: const Duration(seconds: 2),
      );

      expect(session.token, 'verified-session');
      expect(openedUri!.queryParameters['challenge'], isNotEmpty);
      expect(openedUri!.queryParameters, isNot(contains('verifier')));
      expect(pollBody!['verifier'], isNotEmpty);
      expect(
        pollBody!['verifier'],
        isNot(openedUri!.queryParameters['challenge']),
      );
      verify(
        () => secureStorage.write(
          StorageKeys.discordShareSession,
          any(that: contains('verified-session')),
        ),
      ).called(1);
    },
  );

  test('maps OAuth polling transport failures to a domain error', () async {
    when(
      () => dio.post<Object?>(
        '/v1/oauth/result',
        data: any(named: 'data'),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/v1/oauth/result'),
        message: 'Failed host lookup: private-relay.test',
        type: DioExceptionType.connectionError,
      ),
    );
    service = DiscordShareService(
      secureStorage: secureStorage,
      localStorage: localStorage,
      dio: dio,
      externalUrlLauncher: (_) async => true,
    );

    await expectLater(
      service.authenticate(timeout: const Duration(seconds: 2)),
      throwsA(
        isA<DiscordShareException>().having(
          (error) => error.code,
          'code',
          'network_error',
        ),
      ),
    );
  });

  test('clears an expired session after relay rejection', () async {
    when(() => secureStorage.delete(any())).thenAnswer((_) async {});
    when(
      () => dio.get<Object?>('/v1/session', options: any(named: 'options')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/v1/session'),
        statusCode: 401,
        data: const {'code': 'session_expired', 'message': 'Session expired.'},
      ),
    );

    await expectLater(
      service.verifySession(_session),
      throwsA(
        isA<DiscordShareException>().having(
          (error) => error.code,
          'code',
          'session_expired',
        ),
      ),
    );
    verify(
      () => secureStorage.delete(StorageKeys.discordShareSession),
    ).called(1);
  });

  test('loads valid selectable Discord targets', () async {
    when(
      () => dio.get<Object?>('/v1/targets', options: any(named: 'options')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/v1/targets'),
        statusCode: 200,
        data: {
          'targets': [
            {
              'id': 'showcase',
              'label': 'Showcase',
              'default': true,
              'prefer_prompt_file': false,
            },
            {'id': '', 'label': 'Invalid'},
          ],
        },
      ),
    );

    final targets = await service.loadTargets(_session);

    expect(targets, hasLength(1));
    expect(targets.single.id, 'showcase');
    expect(targets.single.selectedByDefault, isTrue);
  });

  test(
    'persists an intentionally empty channel selection and categories',
    () async {
      when(
        () => localStorage.getSetting<List<dynamic>>(
          StorageKeys.discordShareTargetIds,
        ),
      ).thenReturn(const []);
      when(
        () => localStorage.setSetting<List<String>>(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => localStorage.setSetting<bool>(any(), any()),
      ).thenAnswer((_) async {});

      final selected = service.loadSelectedTargetIds(const [
        DiscordShareTarget(
          id: 'showcase',
          label: 'Showcase',
          selectedByDefault: true,
          preferPromptFile: false,
        ),
      ]);
      await service.savePreferences(
        targetIds: const {},
        promptCategoryIds: const {'main', 'fixed'},
        includeMetadata: true,
        longPromptAsFile: true,
      );

      expect(selected, isEmpty);
      verify(
        () => localStorage.setSetting<List<String>>(
          StorageKeys.discordShareTargetIds,
          any(),
        ),
      ).called(1);
      verify(
        () => localStorage.setSetting<List<String>>(
          StorageKeys.discordSharePromptCategories,
          any(that: unorderedEquals(['main', 'fixed'])),
        ),
      ).called(1);
    },
  );

  test(
    'sends caption and every selected target as repeated form fields',
    () async {
      FormData? captured;
      when(
        () => dio.post<Object?>(
          '/v1/share',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#data] as FormData;
        return Response(
          requestOptions: RequestOptions(path: '/v1/share'),
          statusCode: 200,
          data: {
            'delivered_targets': [
              {'id': 'art', 'label': 'Art'},
              {'id': 'showcase', 'label': 'Showcase'},
            ],
            'failed_targets': <Map<String, dynamic>>[],
          },
        );
      });

      final result = await service.share(
        session: _session,
        image: SanitizedShareImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'result.png',
          mimeType: 'image/png',
        ),
        targetIds: {'art', 'showcase'},
        prompt: 'scene\n\n| character',
        caption: 'Finished render',
        width: 832,
        height: 1216,
        longPromptAsFile: true,
      );

      final fields = captured!.fields;
      expect(
        fields
            .where((entry) => entry.key == 'target')
            .map((entry) => entry.value),
        unorderedEquals(['art', 'showcase']),
      );
      expect(
        fields.singleWhere((entry) => entry.key == 'caption').value,
        'Finished render',
      );
      expect(captured!.files.single.key, 'image');
      expect(result.deliveredTargets, ['Art', 'Showcase']);
      expect(result.isPartial, isFalse);
    },
  );

  for (final payload in <Object?>[null, '<html>Too many requests</html>', {}]) {
    test(
      'HTTP 429 without a business code remains rate limited: $payload',
      () async {
        when(
          () => dio.post<Object?>(
            '/v1/share',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/v1/share'),
            type: DioExceptionType.badResponse,
            response: Response<Object?>(
              requestOptions: RequestOptions(path: '/v1/share'),
              statusCode: 429,
              data: payload,
            ),
          ),
        );
        await expectLater(
          _share(service),
          throwsA(
            isA<DiscordShareException>()
                .having((e) => e.code, 'code', 'rate_limited')
                .having((e) => e.retryAfter, 'retryAfter', isNull),
          ),
        );
        verifyNever(() => secureStorage.delete(any()));
      },
    );
  }

  test('invalid Retry-After falls back to the valid payload delay', () async {
    when(
      () => dio.post<Object?>(
        '/v1/share',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/v1/share'),
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['invalid'],
        }),
        data: {'retry_after_seconds': 'NaN', 'retry_after': 2.5},
      ),
    );
    await expectLater(
      _share(service),
      throwsA(
        isA<DiscordShareException>().having(
          (e) => e.retryAfter,
          'retryAfter',
          const Duration(milliseconds: 2500),
        ),
      ),
    );
  });

  test('uses Retry-After from a relay 429 response', () async {
    when(
      () => dio.post<Object?>(
        '/v1/share',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/v1/share'),
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['12.5'],
        }),
        data: const {
          'code': 'rate_limited',
          'message': 'Wait before sharing again.',
          'retry_after_seconds': 60,
        },
      ),
    );

    await expectLater(
      _share(service),
      throwsA(
        isA<DiscordShareException>()
            .having((error) => error.status, 'status', 429)
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(milliseconds: 12500),
            ),
      ),
    );
  });

  test(
    'rejects a concurrent share without a duplicate relay request',
    () async {
      final response = Completer<Response<Map<String, dynamic>>>();
      when(
        () => dio.post<Object?>(
          '/v1/share',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) => response.future);

      final first = _share(service);
      final duplicate = _share(service);
      await expectLater(
        duplicate,
        throwsA(
          isA<DiscordShareException>().having(
            (error) => error.code,
            'code',
            'share_in_progress',
          ),
        ),
      );

      response.complete(
        Response(
          requestOptions: RequestOptions(path: '/v1/share'),
          statusCode: 200,
          data: const {
            'delivered_targets': <Map<String, dynamic>>[],
            'failed_targets': <Map<String, dynamic>>[],
          },
        ),
      );
      await first;

      verify(
        () => dio.post<Object?>(
          '/v1/share',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).called(1);
    },
  );

  test('releases the concurrent-share guard after a failed request', () async {
    var attempts = 0;
    when(
      () => dio.post<Object?>(
        '/v1/share',
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      attempts++;
      if (attempts == 1) {
        throw DioException(
          requestOptions: RequestOptions(path: '/v1/share'),
          type: DioExceptionType.connectionError,
          error: 'offline',
        );
      }
      return Response(
        requestOptions: RequestOptions(path: '/v1/share'),
        statusCode: 200,
        data: const {
          'delivered_targets': <Map<String, dynamic>>[],
          'failed_targets': <Map<String, dynamic>>[],
        },
      );
    });

    await expectLater(_share(service), throwsA(isA<DiscordShareException>()));
    await expectLater(_share(service), completes);
    expect(attempts, 2);
  });
}

Future<DiscordShareResult> _share(DiscordShareService service) {
  return service.share(
    session: _session,
    image: SanitizedShareImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'result.png',
      mimeType: 'image/png',
    ),
    targetIds: const {'showcase'},
    prompt: 'scene',
    caption: '',
    width: 832,
    height: 1216,
    longPromptAsFile: true,
  );
}

const _session = DiscordShareSession(
  token: 'session-token',
  user: DiscordShareUser(id: '42', username: 'alice'),
);
