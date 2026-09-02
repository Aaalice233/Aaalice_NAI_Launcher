import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';

void main() {
  test(
    'cloud secret write failure is visible and does not update cache',
    () async {
      final backend = _Storage();
      when(
        () => backend.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(StateError('simulated Windows delayed write'));
      when(
        () => backend.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      final service = SecureStorageService(storage: backend);
      await service.clearCloudSyncSecrets();

      await expectLater(
        service.saveCloudSyncCredentials('credentials'),
        throwsA(isA<StateError>()),
      );
      expect(await service.getCloudSyncCredentials(), isNull);
    },
  );

  test('cloud secret read failure is visible', () async {
    final backend = _Storage();
    when(() => backend.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(
      () => backend.read(key: any(named: 'key')),
    ).thenThrow(StateError('secure storage unavailable'));
    final service = SecureStorageService(storage: backend);
    await service.clearCloudSyncSecrets();

    await expectLater(
      service.getCloudSyncCredentials(),
      throwsA(isA<StateError>()),
    );
  });

  test('successful cloud secret writes remain readable in-session', () async {
    final backend = _Storage();
    when(() => backend.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(
      () => backend.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => backend.read(key: any(named: 'key')),
    ).thenThrow(StateError('simulated Windows delayed read'));
    final service = SecureStorageService(storage: backend);
    await service.clearCloudSyncSecrets();

    await service.saveCloudSyncCredentials('credentials');

    expect(await service.getCloudSyncCredentials(), 'credentials');
  });
}

class _Storage extends Mock implements FlutterSecureStorage {}
