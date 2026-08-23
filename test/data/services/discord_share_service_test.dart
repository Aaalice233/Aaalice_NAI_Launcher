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

  test(
    'OAuth uses PKCE polling and stores only the resulting session',
    () async {
      Uri? openedUri;
      Map<String, dynamic>? pollBody;
      when(() => secureStorage.write(any(), any())).thenAnswer((_) async {});
      when(
        () => dio.post<Map<String, dynamic>>(
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

  test('clears an expired session after relay rejection', () async {
    when(() => secureStorage.delete(any())).thenAnswer((_) async {});
    when(
      () => dio.get<Map<String, dynamic>>(
        '/v1/session',
        options: any(named: 'options'),
      ),
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
      () => dio.get<Map<String, dynamic>>(
        '/v1/targets',
        options: any(named: 'options'),
      ),
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
        () => dio.post<Map<String, dynamic>>(
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
}

const _session = DiscordShareSession(
  token: 'session-token',
  user: DiscordShareUser(id: '42', username: 'alice'),
);
