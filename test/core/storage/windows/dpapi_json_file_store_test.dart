import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_unavailable_exception.dart';
import 'package:nai_launcher/core/storage/windows/dpapi_json_file_store.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fake_secure_blob_cipher.dart';

void main() {
  late Directory root;
  late FakeSecureBlobCipher cipher;
  late DateTime now;

  DpapiJsonFileStore createStore() => DpapiJsonFileStore(
    directoryResolver: () async => root.path,
    cipher: cipher,
    clock: () => now,
  );

  File storageFile() => File(p.join(root.path, DpapiJsonFileStore.fileName));

  List<String> entryNames() =>
      root.listSync().map((entity) => p.basename(entity.path)).toList()..sort();

  List<String> backupNames() => entryNames()
      .where(
        (name) => name.startsWith('${DpapiJsonFileStore.fileName}.corrupt-'),
      )
      .toList();

  void writeEncrypted(Object json) {
    storageFile().writeAsBytesSync(
      cipher.protect(Uint8List.fromList(utf8.encode(jsonEncode(json)))),
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('dpapi_json_file_store_');
    cipher = FakeSecureBlobCipher();
    now = DateTime.utc(2026, 10, 23, 8, 0, 0, 5);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('缺失文件读成空表，保存后目录里只有目标文件', () async {
    final store = createStore();

    expect(await store.load(), isEmpty);
    await store.save({'account_token_a': 'pst-a', 'mcp_server_token_v1': 'm'});

    expect(entryNames(), [DpapiJsonFileStore.fileName]);
    expect(await createStore().load(), {
      'account_token_a': 'pst-a',
      'mcp_server_token_v1': 'm',
    });
  });

  test('update 只在内容变化时写回', () async {
    final store = createStore();
    await store.save({'k': 'v'});
    final protects = cipher.protectCalls;

    await store.update((data) => false);
    expect(cipher.protectCalls, protects);

    await store.update((data) {
      data['added'] = 'x';
      return true;
    });
    expect(cipher.protectCalls, protects + 1);
    expect(await store.load(), {'k': 'v', 'added': 'x'});
  });

  test('保存会创建尚不存在的应用数据目录', () async {
    final nested = Directory(p.join(root.path, 'missing', 'support'));
    final store = DpapiJsonFileStore(
      directoryResolver: () async => nested.path,
      cipher: cipher,
    );

    await store.save({'k': 'v'});

    expect(await store.load(), {'k': 'v'});
  });

  test('非字符串条目按插件语义丢弃', () async {
    writeEncrypted({
      'kept': 'value',
      'number': 1,
      'nested': <String, String>{},
    });

    expect(await createStore().load(), {'kept': 'value'});
  });

  test('无法解密的内容原样改名留档并读成空表', () async {
    final garbage = Uint8List.fromList(List<int>.generate(64, (i) => i * 7));
    storageFile().writeAsBytesSync(garbage);

    expect(await createStore().load(), isEmpty);

    expect(storageFile().existsSync(), isFalse);
    expect(backupNames(), [
      '${DpapiJsonFileStore.fileName}.corrupt-20261023T080000005Z',
    ]);
    final backup = File(p.join(root.path, backupNames().single));
    expect(backup.readAsBytesSync(), garbage);
  });

  test('空文件按损坏处理', () async {
    storageFile().writeAsBytesSync(const []);

    expect(await createStore().load(), isEmpty);

    expect(storageFile().existsSync(), isFalse);
    expect(backupNames(), hasLength(1));
  });

  test('解密成功但不是 JSON 对象时改名留档', () async {
    writeEncrypted(['not', 'an', 'object']);

    expect(await createStore().load(), isEmpty);
    expect(backupNames(), hasLength(1));
  });

  test('解密成功但不是合法 UTF-8 JSON 时改名留档', () async {
    storageFile().writeAsBytesSync(
      cipher.protect(Uint8List.fromList(const [0xFF, 0xFE, 0x7B])),
    );

    expect(await createStore().load(), isEmpty);
    expect(backupNames(), hasLength(1));
  });

  test('只保留最新的若干份损坏备份', () async {
    final stamps = <String>[];
    for (var i = 0; i < DpapiJsonFileStore.maxCorruptBackups + 2; i++) {
      now = DateTime.utc(2026, 10, 23, 8, 0, i);
      stamps.add('20261023T0800${i.toString().padLeft(2, '0')}000Z');
      storageFile().writeAsBytesSync(const [1, 2, 3]);
      await createStore().load();
    }

    expect(backupNames(), [
      for (final stamp in stamps.skip(2))
        '${DpapiJsonFileStore.fileName}.corrupt-$stamp',
    ]);
  });

  test('同一时刻的两份损坏备份互不覆盖', () async {
    storageFile().writeAsBytesSync(const [1]);
    await createStore().load();
    storageFile().writeAsBytesSync(const [2]);
    await createStore().load();

    final names = backupNames();
    expect(names, hasLength(2));
    expect(
      names.map((name) => File(p.join(root.path, name)).readAsBytesSync()),
      unorderedEquals([
        [1],
        [2],
      ]),
    );
  });

  test('首次访问只清理本文件残留的临时文件', () async {
    final stale = File(
      p.join(root.path, '${DpapiJsonFileStore.fileName}.0011aabb.tmp'),
    )..writeAsBytesSync(const [0]);
    final unrelated = File(p.join(root.path, 'other.dat.0011aabb.tmp'))
      ..writeAsBytesSync(const [0]);
    final backup = File(
      p.join(root.path, '${DpapiJsonFileStore.fileName}.corrupt-x'),
    )..writeAsBytesSync(const [0]);

    await createStore().load();

    expect(stale.existsSync(), isFalse);
    expect(unrelated.existsSync(), isTrue);
    expect(backup.existsSync(), isTrue);
  });

  test('系统暂时无法解密时报错且不改动文件', () async {
    writeEncrypted({'account_token_a': 'pst-a'});
    final original = storageFile().readAsBytesSync();
    cipher.unprotectUnavailable = true;

    await expectLater(
      createStore().load(),
      throwsA(
        isA<SecureStorageUnavailableException>().having(
          (error) => error.step,
          'step',
          SecureStorageStep.decrypt,
        ),
      ),
    );

    expect(storageFile().readAsBytesSync(), original);
    expect(backupNames(), isEmpty);
  });

  test('加密失败时不写任何文件', () async {
    final store = createStore();
    await store.save({'account_token_a': 'pst-a'});
    final original = storageFile().readAsBytesSync();
    cipher.protectUnavailable = true;

    await expectLater(
      store.save({'account_token_a': 'pst-a', 'extra': 'x'}),
      throwsA(
        isA<SecureStorageUnavailableException>().having(
          (error) => error.step,
          'step',
          SecureStorageStep.encrypt,
        ),
      ),
    );

    expect(storageFile().readAsBytesSync(), original);
    expect(entryNames(), [DpapiJsonFileStore.fileName]);
  });

  test('清空会删除文件，文件不存在时也成功', () async {
    final store = createStore();
    await store.save({'k': 'v'});

    await store.clear();
    await store.clear();

    expect(storageFile().existsSync(), isFalse);
    expect(await store.load(), isEmpty);
  });

  test('异常文本不含路径', () {
    const error = SecureStorageUnavailableException(
      SecureStorageStep.replaceFile,
      osErrorCode: 5,
    );

    expect(
      error.toString(),
      'SecureStorageUnavailableException(replaceFile, os error 0x5)',
    );
  });
}
