import 'dart:convert';
import 'dart:typed_data';

import 'package:nai_launcher/core/cloud_sync/crypto.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudCrypto', () {
    late CloudCrypto crypto;

    setUp(() {
      crypto = CloudCrypto();
    });

    test(
      'wraps a random master key and password changes only rewrap it',
      () async {
        final created = await crypto.create('old password');
        final original = await created.masterKey.extractBytes();
        final changed = await crypto.changePassword(
          'old password',
          'new password',
          created.wrapped,
        );
        final independentlyCreated = await crypto.create('old password');

        expect(
          changed.passwordBox.sublist(0, 12),
          isNot(created.wrapped.passwordBox.sublist(0, 12)),
        );
        expect(
          created.wrapped.passwordBox.sublist(0, 12),
          isNot(created.wrapped.recoveryBox!.sublist(0, 12)),
        );
        expect(
          independentlyCreated.wrapped.recoveryBox!.sublist(0, 12),
          isNot(created.wrapped.recoveryBox!.sublist(0, 12)),
        );

        expect(
          await (await crypto.unlock('new password', changed)).extractBytes(),
          original,
        );
        await expectLater(
          crypto.unlock('old password', changed),
          throwsA(isA<CloudCryptoException>()),
        );
        expect(
          WrappedMasterKey.decode(changed.encode()).toJson(),
          changed.toJson(),
        );
      },
    );

    test('recovery is one-time and installs a new password', () async {
      final created = await crypto.create('password');
      final recovered = await crypto.recover(
        created.recoveryKey,
        'replacement',
        created.wrapped,
      );

      expect(recovered.wrapped.recoveryBox, isNull);
      expect(
        await (await crypto.unlock(
          'replacement',
          recovered.wrapped,
        )).extractBytes(),
        await created.masterKey.extractBytes(),
      );
      await expectLater(
        crypto.recover(created.recoveryKey, 'again', recovered.wrapped),
        throwsA(isA<CloudCryptoException>()),
      );
    });

    test('rotating recovery key preserves the snapshot master key', () async {
      final created = await crypto.create('password');
      final encrypted = await crypto.encryptObject(
        utf8.encode('snapshot'),
        created.masterKey,
        objectId: 'snapshot',
        kind: 'json',
      );
      final rotated = await crypto.rotateRecoveryKey(
        created.masterKey,
        created.wrapped,
      );

      expect(rotated.wrapped.kdf.toJson(), created.wrapped.kdf.toJson());
      expect(rotated.wrapped.salt, created.wrapped.salt);
      expect(rotated.wrapped.passwordBox, created.wrapped.passwordBox);
      await expectLater(
        crypto.recover(created.recoveryKey, 'replacement', rotated.wrapped),
        throwsA(isA<CloudCryptoException>()),
      );
      final recovered = await crypto.recover(
        rotated.recoveryKey,
        'replacement',
        rotated.wrapped,
      );
      expect(
        await recovered.masterKey.extractBytes(),
        await created.masterKey.extractBytes(),
      );
      expect(
        await crypto.decryptObject(
          encrypted,
          recovered.masterKey,
          objectId: 'snapshot',
          kind: 'json',
        ),
        utf8.encode('snapshot'),
      );
    });

    test('authenticates every envelope field with the master key', () async {
      final created = await crypto.create('password');
      final original =
          jsonDecode(utf8.decode(created.wrapped.encode()))
              as Map<String, dynamic>;

      for (final field in [
        'salt',
        'passwordBox',
        'recoveryBox',
        'authentication',
      ]) {
        final tampered = _deepCopy(original);
        if (field == 'authentication') {
          final authentication = tampered[field] as Map<String, dynamic>;
          authentication['value'] = _flipBase64(
            authentication['value'] as String,
          );
        } else {
          tampered[field] = _flipBase64(tampered[field] as String);
        }
        final envelope = WrappedMasterKey.decode(
          utf8.encode(jsonEncode(tampered)),
        );
        await expectLater(
          crypto.unlock('password', envelope),
          throwsA(isA<CloudCryptoException>()),
          reason: field,
        );
      }

      final changedKdf = _deepCopy(original);
      (changedKdf['kdf'] as Map<String, dynamic>)['iterations'] = 3;
      expect(
        () => WrappedMasterKey.decode(utf8.encode(jsonEncode(changedKdf))),
        throwsA(isA<CloudFormatException>()),
      );
    });

    test('rejects legacy schema and hostile KDF before Argon2', () async {
      final created = await crypto.create('password');
      final hostile =
          jsonDecode(utf8.decode(created.wrapped.encode()))
              as Map<String, dynamic>;
      (hostile['kdf'] as Map<String, dynamic>)['memory'] = 1024 * 1024;
      expect(
        () => WrappedMasterKey.decode(utf8.encode(jsonEncode(hostile))),
        throwsA(isA<CloudFormatException>()),
      );

      final legacy =
          jsonDecode(utf8.decode(created.wrapped.encode()))
              as Map<String, dynamic>;
      legacy['version'] = 1;
      expect(
        () => WrappedMasterKey.decode(utf8.encode(jsonEncode(legacy))),
        throwsA(isA<CloudFormatException>()),
      );
      await expectLater(
        CloudCrypto(
          kdf: const KdfParameters(memory: 1024 * 1024),
        ).create('password'),
        throwsA(isA<CloudCryptoException>()),
      );
    });

    test(
      'random nonces, AAD, tampering, and truncation are enforced',
      () async {
        final created = await crypto.create('password');
        final clear = utf8.encode('secret');
        final first = await crypto.encryptObject(
          clear,
          created.masterKey,
          objectId: 'one',
          kind: 'json',
        );
        final second = await crypto.encryptObject(
          clear,
          created.masterKey,
          objectId: 'one',
          kind: 'json',
        );
        expect(first, isNot(second));
        await expectLater(
          crypto.decryptObject(
            first,
            created.masterKey,
            objectId: 'two',
            kind: 'json',
          ),
          throwsA(isA<CloudCryptoException>()),
        );
        final tampered = Uint8List.fromList(first)..[15] ^= 1;
        await expectLater(
          crypto.decryptObject(
            tampered,
            created.masterKey,
            objectId: 'one',
            kind: 'json',
          ),
          throwsA(isA<CloudCryptoException>()),
        );
        await expectLater(
          crypto.decryptObject(
            first.sublist(0, 10),
            created.masterKey,
            objectId: 'one',
            kind: 'json',
          ),
          throwsA(isA<CloudCryptoException>()),
        );
      },
    );
  });

  test('strict schemas reject extra fields, bad hashes, and size mismatch', () {
    final record = CloudSyncRecord(
      id: 'record',
      kind: 'json',
      binary: false,
      deleted: false,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    expect(CloudSyncRecord.decode(record.encode()), record);
    final invalid =
        jsonDecode(utf8.decode(record.encode())) as Map<String, dynamic>;
    invalid['extra'] = true;
    expect(
      () => CloudSyncRecord.decode(utf8.encode(jsonEncode(invalid))),
      throwsA(isA<CloudFormatException>()),
    );

    final object = SnapshotObject(
      id: 'object',
      kind: 'json',
      size: 3,
      sha256: '0' * 64,
    );
    expect(() => object.verify([1, 2]), throwsA(isA<CloudFormatException>()));
    expect(
      () => object.verify([1, 2, 3]),
      throwsA(isA<CloudFormatException>()),
    );
    expect(
      () => SnapshotHead.decode(utf8.encode('{"version":1}')),
      throwsA(isA<CloudFormatException>()),
    );
  });
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

String _flipBase64(String value) {
  final bytes = base64Decode(value)..[0] ^= 1;
  return base64Encode(bytes);
}
