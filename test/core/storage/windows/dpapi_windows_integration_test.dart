@TestOn('windows')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:flutter_secure_storage_windows/src/flutter_secure_storage_windows_ffi.dart'
    as plugin;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_unavailable_exception.dart';
import 'package:nai_launcher/core/storage/windows/dpapi_cipher.dart';
import 'package:nai_launcher/core/storage/windows/dpapi_json_file_store.dart';
import 'package:nai_launcher/core/storage/windows/launcher_windows_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _options = {'useBackwardCompatibility': 'false'};

const _seed = {
  'account_token_a':
      'pst-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'account_token_b':
      'pst-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  'nai_access_token': 'pst-session',
  'cloud_sync_credentials': '{"provider":"onedrive","note":"中文"}',
};

const _patientRetry = SecureFileRetryPolicy(
  initialDelay: Duration(milliseconds: 5),
  maxDelay: Duration(milliseconds: 40),
  budget: Duration(seconds: 3),
);

const _impatientRetry = SecureFileRetryPolicy(
  initialDelay: Duration(milliseconds: 5),
  maxDelay: Duration(milliseconds: 20),
  budget: Duration(milliseconds: 150),
);

void main() {
  late Directory root;

  DpapiJsonFileStore createStore([
    SecureFileRetryPolicy retryPolicy = _patientRetry,
  ]) => DpapiJsonFileStore(
    directoryResolver: () async => root.path,
    retryPolicy: retryPolicy,
  );

  File storageFile() => File(p.join(root.path, DpapiJsonFileStore.fileName));

  List<String> leftovers() => root
      .listSync()
      .map((entity) => p.basename(entity.path))
      .where((name) => name != DpapiJsonFileStore.fileName)
      .toList();

  // 字节范围锁拦下读取（33），开着的句柄拦下替换（5），与外部扫描进程的效果一致
  Future<_FileHolder> holdFile({required bool lock}) async {
    final file = await storageFile().open(mode: FileMode.append);
    if (lock) await file.lock(FileLock.exclusive);
    final holder = _FileHolder(file, locked: lock);
    addTearDown(holder.release);
    return holder;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('dpapi_windows_');
    PathProviderPlatform.instance = _SupportDirectory(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('与 flutter_secure_storage_windows 的文件格式兼容', () {
    test('插件写入的文件可直接读取', () async {
      await plugin.DpapiJsonFileMapStorage().save(
        Map.of(_seed),
        const <String, String>{},
      );

      expect(await createStore().load(), _seed);
    });

    test('写出的文件插件仍可读取，降级不丢数据', () async {
      await createStore().save(Map.of(_seed));

      expect(
        await plugin.DpapiJsonFileMapStorage().load(const <String, String>{}),
        _seed,
      );
    });
  });

  test('真实 DPAPI 下截断、空文件与随机字节都改名留档', () async {
    final valid = const DpapiCipher().protect(
      Uint8List.fromList(utf8.encode(jsonEncode(_seed))),
    );
    final samples = <String, List<int>>{
      'empty': const [],
      'truncated': valid.sublist(0, valid.length ~/ 2),
      'random': List<int>.generate(300, (i) => (i * 37 + 11) & 0xFF),
    };

    for (final entry in samples.entries) {
      storageFile().writeAsBytesSync(entry.value);

      expect(await createStore().load(), isEmpty, reason: entry.key);
      expect(storageFile().existsSync(), isFalse, reason: entry.key);
    }
    expect(leftovers(), hasLength(DpapiJsonFileStore.maxCorruptBackups));
    expect(
      leftovers(),
      everyElement(startsWith('${DpapiJsonFileStore.fileName}.corrupt-')),
    );
  });

  group('文件被其他句柄占用', () {
    test('读取被锁时重试，释放后读到完整数据', () async {
      await createStore().save(Map.of(_seed));
      final holder = await holdFile(lock: true);

      final releasing = Future<void>.delayed(
        const Duration(milliseconds: 150),
        holder.release,
      );
      final loaded = await createStore().load();
      await releasing;

      expect(loaded, _seed);
    });

    test('锁一直不放时读取报错，文件保持原样', () async {
      await createStore().save(Map.of(_seed));
      final original = storageFile().readAsBytesSync();
      final holder = await holdFile(lock: true);

      await expectLater(
        createStore(_impatientRetry).load(),
        throwsA(
          isA<SecureStorageUnavailableException>()
              .having((e) => e.step, 'step', SecureStorageStep.readFile)
              .having((e) => e.osErrorCode, 'osErrorCode', 33),
        ),
      );

      await holder.release();
      expect(storageFile().readAsBytesSync(), original);
    });

    test('替换被拦时重试，释放后写入成功且不留临时文件', () async {
      final store = createStore();
      await store.save(Map.of(_seed));
      final holder = await holdFile(lock: false);

      final releasing = Future<void>.delayed(
        const Duration(milliseconds: 150),
        holder.release,
      );
      await store.save({..._seed, 'mcp_server_token_v1': 'm'});
      await releasing;

      expect(await store.load(), {..._seed, 'mcp_server_token_v1': 'm'});
      expect(leftovers(), isEmpty);
    });

    test('替换一直被拦时报错，原文件完好且不留临时文件', () async {
      await createStore().save(Map.of(_seed));
      final holder = await holdFile(lock: false);

      await expectLater(
        createStore(_impatientRetry).save({'mcp_server_token_v1': 'm'}),
        throwsA(
          isA<SecureStorageUnavailableException>()
              .having((e) => e.step, 'step', SecureStorageStep.replaceFile)
              .having((e) => e.osErrorCode, 'osErrorCode', 5),
        ),
      );

      await holder.release();
      expect(await createStore().load(), _seed);
      expect(leftovers(), isEmpty);
    });
  });

  test('扫描器持续按 400ms 占用 / 100ms 释放时，默认重试节奏下连续读写都能完成', () async {
    final storage = LauncherWindowsSecureStorage(
      store: createStore(const SecureFileRetryPolicy()),
    );
    for (final entry in _seed.entries) {
      await storage.write(
        key: entry.key,
        value: entry.value,
        options: _options,
      );
    }
    final scanner = _Scanner(storageFile())..start();
    addTearDown(scanner.stop);

    for (var i = 0; i < 5; i++) {
      await storage.write(
        key: 'mcp_server_token_v1',
        value: 'v$i',
        options: _options,
      );
      expect(
        await storage.read(key: 'account_token_a', options: _options),
        _seed['account_token_a'],
      );
    }
    await scanner.stop();

    expect(await storage.readAll(options: _options), {
      ..._seed,
      'mcp_server_token_v1': 'v4',
    });
    expect(leftovers(), isEmpty);
  });

  test('占用期间写入 MCP 令牌，已有账号 Token 全部保留', () async {
    final storage = LauncherWindowsSecureStorage(store: createStore());
    for (final entry in _seed.entries) {
      await storage.write(
        key: entry.key,
        value: entry.value,
        options: _options,
      );
    }
    final holder = await holdFile(lock: true);

    final releasing = Future<void>.delayed(
      const Duration(milliseconds: 300),
      holder.release,
    );
    await storage.write(
      key: 'mcp_server_token_v1',
      value: 'x' * 43,
      options: _options,
    );
    await releasing;

    expect(await storage.readAll(options: _options), {
      ..._seed,
      'mcp_server_token_v1': 'x' * 43,
    });
  });
}

/// 按"独占 400ms、释放 100ms"循环占用文件，模拟 issue 中的杀毒或同步软件扫描
class _Scanner {
  _Scanner(this._file);

  final File _file;
  bool _running = false;
  Future<void>? _loop;

  void start() {
    _running = true;
    _loop = _run();
  }

  Future<void> stop() async {
    _running = false;
    await _loop;
  }

  Future<void> _run() async {
    while (_running) {
      try {
        final handle = await _file.open(mode: FileMode.append);
        await handle.lock(FileLock.exclusive);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await handle.unlock();
        await handle.close();
      } on FileSystemException {
        // 目标恰好在被替换，下一轮再占
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

class _FileHolder {
  _FileHolder(this._file, {required this.locked});

  final RandomAccessFile _file;
  final bool locked;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    if (locked) await _file.unlock();
    await _file.close();
  }
}

class _SupportDirectory extends PathProviderPlatform {
  _SupportDirectory(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
