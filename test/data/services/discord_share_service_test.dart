import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';
import 'package:nai_launcher/data/services/discord_share_service.dart';

class _MockDio extends Mock implements Dio {}

class _MockSecureStorage extends Mock implements SecureStorageService {}

class _MockLocalStorage extends Mock implements LocalStorageService {}

void main() {
  late _MockDio dio;
  late DiscordShareService service;

  setUp(() {
    dio = _MockDio();
    service = DiscordShareService(
      secureStorage: _MockSecureStorage(),
      localStorage: _MockLocalStorage(),
      dio: dio,
    );
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
