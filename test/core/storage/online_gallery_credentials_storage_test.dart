import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';

void main() {
  late _MockFlutterSecureStorage backend;
  late Map<String, String> disk;
  late SecureStorageService service;

  setUp(() async {
    backend = _MockFlutterSecureStorage();
    disk = <String, String>{};
    when(
      () => backend.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value == null) {
        disk.remove(key);
      } else {
        disk[key] = value;
      }
    });
    when(() => backend.read(key: any(named: 'key'))).thenAnswer((
      invocation,
    ) async {
      final key = invocation.namedArguments[#key] as String;
      return disk[key];
    });
    when(() => backend.delete(key: any(named: 'key'))).thenAnswer((
      invocation,
    ) async {
      final key = invocation.namedArguments[#key] as String;
      disk.remove(key);
    });

    service = SecureStorageService(storage: backend);
    await service.deleteDanbooruCredentials();
    await service.deleteGelbooruCredentials();
  });

  test('uses independent versioned secure-storage keys', () async {
    await service.saveDanbooruCredentials('danbooru-json');
    await service.saveGelbooruCredentials('gelbooru-json');

    expect(
      disk[StorageKeys.onlineGalleryDanbooruCredentialsV1],
      'danbooru-json',
    );
    expect(
      disk[StorageKeys.onlineGalleryGelbooruCredentialsV1],
      'gelbooru-json',
    );

    await service.deleteDanbooruCredentials();

    expect(await service.getDanbooruCredentials(), isNull);
    expect(await service.getGelbooruCredentials(), 'gelbooru-json');
  });

  test(
    'does not cache an online-gallery credential when disk write fails',
    () async {
      when(
        () => backend.write(
          key: StorageKeys.onlineGalleryDanbooruCredentialsV1,
          value: any(named: 'value'),
        ),
      ).thenThrow(StateError('disk unavailable'));

      await expectLater(
        service.saveDanbooruCredentials('must-not-be-cached'),
        throwsStateError,
      );

      expect(await service.getDanbooruCredentials(), isNull);
    },
  );
}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
