import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';

void main() {
  test(
    'displayed recovery key unlocks committed KEY and is consumed by CAS',
    () async {
      final storage = _Storage();
      final disk = <String, String>{};
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((call) async {
        disk[call.namedArguments[#key] as String] =
            call.namedArguments[#value] as String;
      });
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((call) async => disk[call.namedArguments[#key] as String]);
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((
        call,
      ) async {
        disk.remove(call.namedArguments[#key] as String);
      });
      final secure = SecureStorageService(storage: storage);
      await secure.clearCloudSyncSecrets();
      final backend = _KeyBackend();
      final crypto = CloudCrypto();
      final service = CloudKeyEnvelopeService(
        backend: backend,
        secureStorage: secure,
        crypto: crypto,
      );

      final shown = await service.prepareCreate('first-password');
      expect(backend.value, isNull);
      final committed = await service.commitPrepared();
      final rotated = await service.rotateRecoveryKey(committed);
      expect(rotated.recoveryKey, isNotNull);
      expect(backend.expectedRevisions, [null, committed.revision]);
      expect(
        await rotated.masterKey.extractBytes(),
        await committed.masterKey.extractBytes(),
      );
      await expectLater(
        service.rotateRecoveryKey(committed),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.conflict,
          ),
        ),
      );
      final validRemote = backend.value!;
      final tamperedJson =
          jsonDecode(utf8.decode(validRemote.bytes)) as Map<String, dynamic>;
      final recoveryBytes = base64Decode(tamperedJson['recoveryBox'] as String)
        ..[0] ^= 1;
      tamperedJson['recoveryBox'] = base64Encode(recoveryBytes);
      backend.value = CloudObjectRead(
        bytes: Uint8List.fromList(utf8.encode(jsonEncode(tamperedJson))),
        revision: validRemote.revision,
      );
      await expectLater(service.unlock(), throwsA(isA<CloudCryptoException>()));
      backend.value = validRemote;

      final remote = WrappedMasterKey.decode(backend.value!.bytes);
      await expectLater(
        crypto.recover(shown, 'second-password', remote),
        throwsA(isA<CloudCryptoException>()),
      );
      final recovered = await crypto.recover(
        rotated.recoveryKey!,
        'second-password',
        remote,
      );
      expect(
        await recovered.masterKey.extractBytes(),
        await committed.masterKey.extractBytes(),
      );

      await secure.clearCloudSyncSecrets();
      await expectLater(
        service.unlock(password: 'wrong-password'),
        throwsA(isA<CloudCryptoException>()),
      );
      await service.unlock(password: 'first-password');

      await secure.saveCloudSyncMasterKey(
        base64Encode(List<int>.filled(32, 9)),
      );
      final passwordFallback = await service.unlock(password: 'first-password');
      expect(
        await passwordFallback.masterKey.extractBytes(),
        await committed.masterKey.extractBytes(),
      );

      final consumed = await service.recover(
        rotated.recoveryKey!,
        'second-password',
      );
      expect(consumed.envelope.recoveryBox, isNull);
      expect(WrappedMasterKey.decode(backend.value!.bytes).recoveryBox, isNull);
      await expectLater(
        service.recover(rotated.recoveryKey!, 'third-password'),
        throwsA(isA<CloudCryptoException>()),
      );
    },
  );

  test(
    'scopes master keys by provider account and rotates on recovery',
    () async {
      final storage = _Storage();
      final disk = <String, String>{};
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((call) async {
        disk[call.namedArguments[#key] as String] =
            call.namedArguments[#value] as String;
      });
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((call) async => disk[call.namedArguments[#key] as String]);
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((
        call,
      ) async {
        disk.remove(call.namedArguments[#key] as String);
      });
      final secure = SecureStorageService(storage: storage);
      final backend = _KeyBackend();
      final first = CloudKeyEnvelopeService(
        backend: backend,
        secureStorage: secure,
        providerId: 'onedrive',
        accountId: 'account-a',
      );
      final recovery = await first.prepareCreate('device-secret-a');
      final created = await first.commitPrepared();

      final otherAccount = CloudKeyEnvelopeService(
        backend: backend,
        secureStorage: secure,
        providerId: 'onedrive',
        accountId: 'account-b',
      );
      await expectLater(otherAccount.unlock(), throwsA(isA<StateError>()));

      final recovered = await otherAccount.recoverAndRotate(
        recovery,
        'device-secret-b',
      );
      expect(recovered.recoveryKey, isNotNull);
      expect(recovered.envelope.recoveryBox, isNotNull);
      expect(
        await recovered.masterKey.extractBytes(),
        await created.masterKey.extractBytes(),
      );
      expect(
        disk.keys.where((key) => key.contains('cloud_drive_master_key_v1_')),
        hasLength(2),
      );
    },
  );
}

class _KeyBackend implements CloudKeyEnvelopeBackend {
  CloudObjectRead? value;
  var revision = 0;
  final expectedRevisions = <String?>[];

  @override
  Future<CloudObjectRead?> readKeyEnvelope() async => value;

  @override
  Future<CloudCommitResult> commitKeyEnvelope(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    expectedRevisions.add(expectedRevision);
    if (expectedRevision != value?.revision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'CAS failed',
      );
    }
    final next = 'r${++revision}';
    value = CloudObjectRead(bytes: Uint8List.fromList(bytes), revision: next);
    return CloudCommitResult(revision: next);
  }
}

class _Storage extends Mock implements FlutterSecureStorage {}
