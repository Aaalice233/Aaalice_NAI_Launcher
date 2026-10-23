import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_unavailable_exception.dart';
import 'package:nai_launcher/core/storage/windows/dpapi_json_file_store.dart';
import 'package:nai_launcher/core/storage/windows/launcher_windows_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fake_secure_blob_cipher.dart';

const _options = {'useBackwardCompatibility': 'false'};

const _seed = {
  'account_token_a': 'pst-a',
  'account_token_b': 'pst-b',
  'account_token_c': 'pst-c',
  'nai_access_token': 'pst-session',
};

void main() {
  late Directory root;
  late FakeSecureBlobCipher cipher;
  late LauncherWindowsSecureStorage storage;

  File storageFile() => File(p.join(root.path, DpapiJsonFileStore.fileName));

  Future<void> seed() async {
    for (final entry in _seed.entries) {
      await storage.write(
        key: entry.key,
        value: entry.value,
        options: _options,
      );
    }
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('launcher_secure_storage_');
    cipher = FakeSecureBlobCipher();
    storage = LauncherWindowsSecureStorage(
      store: DpapiJsonFileStore(
        directoryResolver: () async => root.path,
        cipher: cipher,
      ),
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('并发写入全部落盘', () async {
    await seed();

    await Future.wait([
      storage.write(
        key: 'nai_access_token',
        value: 'pst-new',
        options: _options,
      ),
      storage.write(
        key: 'nai_token_expiry',
        value: '2036-01-01',
        options: _options,
      ),
      storage.write(
        key: 'nai_user_email',
        value: 'u@example.invalid',
        options: _options,
      ),
    ]);

    expect(await storage.readAll(options: _options), {
      ..._seed,
      'nai_access_token': 'pst-new',
      'nai_token_expiry': '2036-01-01',
      'nai_user_email': 'u@example.invalid',
    });
  });

  test('并发删除全部生效', () async {
    await seed();

    await Future.wait([
      for (final key in [
        'account_token_a',
        'account_token_b',
        'nai_access_token',
      ])
        storage.delete(key: key, options: _options),
    ]);

    expect(await storage.readAll(options: _options), {
      'account_token_c': 'pst-c',
    });
  });

  test('读写交错时读到的总是完整数据', () async {
    await seed();

    final reads = await Future.wait([
      for (var i = 0; i < 20; i++) ...[
        storage
            .write(key: 'mcp_server_token_v1', value: 'v$i', options: _options)
            .then((_) => null),
        storage.read(key: 'account_token_a', options: _options),
      ],
    ]);

    expect(reads.whereType<String>(), everyElement('pst-a'));
    expect(reads.whereType<String>(), hasLength(20));
    expect(await storage.readAll(options: _options), {
      ..._seed,
      'mcp_server_token_v1': 'v19',
    });
  });

  test('读不到文件时写入报错，原有条目一个不丢', () async {
    await seed();
    final original = storageFile().readAsBytesSync();
    cipher.unprotectUnavailable = true;

    await expectLater(
      storage.write(key: 'mcp_server_token_v1', value: 'm', options: _options),
      throwsA(isA<SecureStorageUnavailableException>()),
    );
    await expectLater(
      storage.read(key: 'account_token_a', options: _options),
      throwsA(isA<SecureStorageUnavailableException>()),
    );

    expect(storageFile().readAsBytesSync(), original);
    cipher.unprotectUnavailable = false;
    expect(await storage.readAll(options: _options), _seed);
  });

  test('写入相同值或删除不存在的键不重写文件', () async {
    await seed();
    final protects = cipher.protectCalls;

    await storage.write(
      key: 'account_token_a',
      value: 'pst-a',
      options: _options,
    );
    await storage.delete(key: 'missing', options: _options);

    expect(cipher.protectCalls, protects);
  });

  test('containsKey、readAll 与 deleteAll', () async {
    await seed();

    expect(
      await storage.containsKey(key: 'account_token_b', options: _options),
      isTrue,
    );
    expect(
      await storage.containsKey(key: 'missing', options: _options),
      isFalse,
    );

    final snapshot = await storage.readAll(options: _options);
    snapshot['injected'] = 'x';
    expect(
      await storage.containsKey(key: 'injected', options: _options),
      isFalse,
    );

    await storage.deleteAll(options: _options);
    expect(storageFile().existsSync(), isFalse);
    expect(await storage.readAll(options: _options), isEmpty);
  });

  test('拒绝需要 Credential Manager 迁移的旧选项', () {
    const legacy = {'useBackwardCompatibility': 'true'};

    expect(
      () => storage.read(key: 'k', options: legacy),
      throwsUnsupportedError,
    );
    expect(
      () => storage.write(key: 'k', value: 'v', options: legacy),
      throwsUnsupportedError,
    );
  });
}
