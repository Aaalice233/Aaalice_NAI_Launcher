import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/core/storage/storage_file_system.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'
    show MissingPlatformDirectoryException;

void main() {
  late Directory root;
  late String blobDirectory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('queue_blob_store_test_');
    blobDirectory = p.join(root.path, ReplicationQueueBlobStore.directoryName);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  ReplicationQueueBlobStore storeWith({
    StorageFileSystem fileSystem = const StorageFileSystem(),
    QueueBlobWorker? worker,
  }) => ReplicationQueueBlobStore(
    resolveDirectory: () async => blobDirectory,
    fileSystem: fileSystem,
    worker: worker ?? _inline,
  );

  List<String> storedNames() => Directory(
    blobDirectory,
  ).listSync().map((entity) => p.basename(entity.path)).toList()..sort();

  test(
    'stores content-addressed files and reads them back across isolates',
    () async {
      final store = ReplicationQueueBlobStore(
        resolveDirectory: () async => blobDirectory,
      );
      final first = _bytes(4096, 1);
      final second = _bytes(17, 2);

      final lease = await store.put([first, second]);
      lease.release();

      expect(lease.refs, [
        QueueBlobRef(sha256.convert(first).toString(), first.length),
        QueueBlobRef(sha256.convert(second).toString(), second.length),
      ]);
      expect(
        storedNames(),
        ([for (final ref in lease.refs) ref.sha256]..sort()),
      );
      final restored = await store.read([
        lease.refs[1],
        lease.refs[0],
        lease.refs[1],
      ]);
      expect(restored[0], second);
      expect(restored[1], first);
      expect(restored[2], second);
    },
  );

  test('identical content is written once', () async {
    final fileSystem = _CountingFileSystem();
    final store = storeWith(fileSystem: fileSystem);
    final bytes = _bytes(1024, 3);

    final first = await store.put([bytes, Uint8List.fromList(bytes)]);
    final second = await store.put([Uint8List.fromList(bytes)]);
    first.release();
    second.release();

    expect(fileSystem.writes, 1);
    expect(first.refs[0], first.refs[1]);
    expect(second.refs.single, first.refs.first);
    expect(storedNames(), [first.refs.first.sha256]);
  });

  test('a truncated file is rewritten instead of reused', () async {
    final store = storeWith();
    final bytes = _bytes(2048, 4);
    final digest = sha256.convert(bytes).toString();
    await Directory(blobDirectory).create(recursive: true);
    await File(
      p.join(blobDirectory, digest),
    ).writeAsBytes(bytes.sublist(0, 10));

    (await store.put([bytes])).release();

    expect(await File(p.join(blobDirectory, digest)).readAsBytes(), bytes);
  });

  group('read verification', () {
    test('a missing file is reported as missing', () async {
      final store = storeWith();
      final ref = QueueBlobRef('a' * 64, 3);

      await expectLater(
        store.read([ref]),
        throwsA(
          isA<QueueBlobMissingException>()
              .having((error) => error, 'type', isA<FormatException>())
              .having((error) => '$error', 'message', contains('missing')),
        ),
      );
    });

    test('internal read failures are not reported as missing images', () async {
      final store = ReplicationQueueBlobStore(
        resolveDirectory: () async => throw StateError('no plugin'),
        worker: _inline,
      );
      final failingWorker = storeWith(
        worker: <T>(FutureOr<T> Function() task, {String? debugName}) async =>
            throw StateError('isolate failed'),
      );

      for (final candidate in [store, failingWorker]) {
        await expectLater(
          candidate.read([QueueBlobRef('d' * 64, 1)]),
          throwsA(
            isA<QueueBlobReadFailedException>()
                .having((error) => error, 'type', isNot(isA<FormatException>()))
                .having((error) => '$error', 'message', contains('StateError')),
          ),
        );
      }
    });

    test(
      'a locked file is a retryable read failure, not a missing image',
      () async {
        final store = storeWith(fileSystem: _LockedReadFileSystem());
        final lease = await store.put([_bytes(48, 17)]);
        lease.release();

        await expectLater(
          store.read([lease.refs.single]),
          throwsA(
            isA<QueueBlobReadFailedException>()
                .having((error) => error, 'type', isNot(isA<FormatException>()))
                .having((error) => '$error', 'message', contains('os error 32'))
                .having(
                  (error) => '$error',
                  'message',
                  isNot(contains(root.path)),
                ),
          ),
        );
        await store.idle;
        expect(storedNames(), [lease.refs.single.sha256]);
      },
    );

    test('length or content mismatches are reported as corrupt', () async {
      final store = storeWith();
      final lease = await store.put([_bytes(64, 5)]);
      lease.release();
      final ref = lease.refs.single;
      final path = p.join(blobDirectory, ref.sha256);

      await File(path).writeAsBytes(_bytes(63, 5));
      await expectLater(
        store.read([ref]),
        throwsA(isA<QueueBlobCorruptException>()),
      );
      await store.idle;

      await File(path).writeAsBytes(_bytes(64, 6));
      await expectLater(
        store.read([ref]),
        throwsA(
          isA<QueueBlobCorruptException>().having(
            (error) => '$error',
            'message',
            contains('corrupt'),
          ),
        ),
      );
      await store.idle;
    });

    test('length-only reads skip hashing but still catch truncation', () async {
      final store = storeWith();
      final lease = await store.put([_bytes(64, 15)]);
      lease.release();
      final ref = lease.refs.single;
      final path = p.join(blobDirectory, ref.sha256);
      await File(path).writeAsBytes(_bytes(64, 16));

      expect(
        await store.read([ref], verify: QueueBlobVerification.lengthOnly),
        [_bytes(64, 16)],
      );
      await File(path).writeAsBytes(_bytes(10, 16));
      await expectLater(
        store.read([ref], verify: QueueBlobVerification.lengthOnly),
        throwsA(isA<QueueBlobCorruptException>()),
      );
      await store.idle;
    });

    test(
      'a corrupt file of the right length is replaced on the next store',
      () async {
        final store = storeWith();
        final bytes = _bytes(64, 13);
        final first = await store.put([bytes]);
        first.release();
        final ref = first.refs.single;
        await File(
          p.join(blobDirectory, ref.sha256),
        ).writeAsBytes(_bytes(64, 14));

        await expectLater(
          store.read([ref]),
          throwsA(isA<QueueBlobCorruptException>()),
        );
        await store.idle;
        expect(storedNames(), isEmpty);

        (await store.put([bytes])).release();
        expect(await store.read([ref]), [bytes]);
      },
    );

    test(
      'a corrupt file under a lease survives until the lease ends',
      () async {
        final store = storeWith();
        final bytes = _bytes(64, 24);
        final lease = await store.put([bytes]);
        final ref = lease.refs.single;
        final path = p.join(blobDirectory, ref.sha256);
        // 同长度的错误内容：复查仍判损坏，只有租约能挡住删除
        await File(path).writeAsBytes(_bytes(64, 25));

        await expectLater(
          store.read([ref]),
          throwsA(isA<QueueBlobCorruptException>()),
        );
        await store.idle;
        expect(storedNames(), [ref.sha256]);

        lease.release();
        await expectLater(
          store.read([ref]),
          throwsA(isA<QueueBlobCorruptException>()),
        );
        await store.idle;
        expect(storedNames(), isEmpty);
      },
    );

    group('a corrupt read racing a store of the same content', () {
      // 读取看到截断的文件后先停住，等同内容入队把文件重写好再放行损坏异常
      Future<(ReplicationQueueBlobStore, QueueBlobLease, Future<void>)> race(
        Uint8List bytes,
      ) async {
        final readDone = Completer<void>();
        final releaseRead = Completer<void>();
        final store = storeWith(
          worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
            if (debugName != 'QueueBlobStore.read' || readDone.isCompleted) {
              return task();
            }
            try {
              return await task();
            } finally {
              readDone.complete();
              await releaseRead.future;
            }
          },
        );
        final digest = sha256.convert(bytes).toString();
        await Directory(blobDirectory).create(recursive: true);
        await File(
          p.join(blobDirectory, digest),
        ).writeAsBytes(bytes.sublist(0, 5));

        final reading = expectLater(
          store.read([QueueBlobRef(digest, bytes.length)]),
          throwsA(isA<QueueBlobCorruptException>()),
        );
        await readDone.future;
        final lease = await store.put([bytes]);
        releaseRead.complete();
        return (store, lease, reading);
      }

      test('keeps the file while the new store still leases it', () async {
        final bytes = _bytes(64, 18);
        final (store, lease, reading) = await race(bytes);

        await reading;
        await store.idle;
        expect(await store.read(lease.refs), [bytes]);
        lease.release();
      });

      test('keeps the rewritten file after the lease is released', () async {
        final bytes = _bytes(64, 19);
        final (store, lease, reading) = await race(bytes);
        lease.release();

        await reading;
        await store.idle;
        expect(await store.read(lease.refs), [bytes]);
      });
    });
  });

  group('collect', () {
    test('removes unreferenced images and temporary files only', () async {
      final store = storeWith();
      final kept = await store.put([_bytes(10, 1)]);
      final dropped = await store.put([_bytes(10, 2)]);
      kept.release();
      dropped.release();
      final stray = p.join(blobDirectory, '${'b' * 64}.123-ab.tmp');
      final foreign = p.join(blobDirectory, 'notes.txt');
      await File(stray).writeAsString('partial');
      await File(foreign).writeAsString('not ours');

      final removed = await store.collect(() => {kept.refs.single.sha256});

      expect(removed, 2);
      expect(storedNames(), [kept.refs.single.sha256, 'notes.txt']..sort());
    });

    test('keeps leased images until the lease is released', () async {
      final store = storeWith();
      final lease = await store.put([_bytes(10, 7)]);

      await store.collect(() => const {});
      expect(storedNames(), [lease.refs.single.sha256]);

      lease.release();
      await store.collect(() => const {});
      expect(storedNames(), isEmpty);
    });

    test(
      'waits behind an in-flight write and never removes its result',
      () async {
        final hashing = Completer<void>();
        final release = Completer<void>();
        final store = storeWith(
          worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
            if (debugName == 'QueueBlobStore.put') {
              hashing.complete();
              await release.future;
            }
            return task();
          },
        );

        final put = store.put([_bytes(32, 8)]);
        await hashing.future;
        var collected = false;
        final collect = store
            .collect(() => const {})
            .whenComplete(() => collected = true);
        await Future<void>.delayed(Duration.zero);
        expect(collected, isFalse);

        release.complete();
        final lease = await put;
        await collect;
        expect(storedNames(), [lease.refs.single.sha256]);
        lease.release();
      },
    );

    test('a lease released mid-sweep still protects its image', () async {
      final fileSystem = _PausingDeleteFileSystem();
      final store = storeWith(fileSystem: fileSystem);
      (await store.put([_bytes(16, 20)])).release();
      final lease = await store.put([_bytes(16, 21)]);
      fileSystem.listedLast = lease.refs.single.sha256;

      // 根集合已取、正在删排在前面的孤儿时，任务进入状态并释放租约
      final sweep = store.collect(() => const {});
      await fileSystem.deleting.future;
      lease.release();
      fileSystem.resume.complete();

      expect(await sweep, 1);
      expect(storedNames(), [lease.refs.single.sha256]);
    });

    test('evaluates live digests only after listing; null aborts', () async {
      final fileSystem = _ObservedListFileSystem();
      final store = storeWith(fileSystem: fileSystem);
      final lease = await store.put([_bytes(12, 9)]);
      lease.release();
      final listedWhenEvaluated = <bool>[];

      expect(
        await store.collect(() {
          listedWhenEvaluated.add(fileSystem.listingDone);
          return null;
        }),
        0,
      );
      expect(listedWhenEvaluated, [true]);
      expect(storedNames(), [lease.refs.single.sha256]);
    });

    test('tolerates locked files and removes them on a later run', () async {
      final fileSystem = _FailingDeleteFileSystem();
      final store = storeWith(fileSystem: fileSystem);
      final lease = await store.put([_bytes(12, 10)]);
      lease.release();

      fileSystem.failDeletes = true;
      expect(await store.collect(() => const {}), 0);
      expect(storedNames(), [lease.refs.single.sha256]);

      fileSystem.failDeletes = false;
      expect(await store.collect(() => const {}), 1);
      expect(storedNames(), isEmpty);
    });

    test('returns zero before the directory exists', () async {
      expect(await storeWith().collect(() => const {}), 0);
    });
  });

  group('write failures', () {
    test('a failed rename surfaces and leaves no file behind', () async {
      final store = storeWith(fileSystem: _FailingRenameFileSystem());

      await expectLater(
        store.put([_bytes(40, 11)]),
        throwsA(
          isA<QueueBlobWriteException>().having(
            (error) => '$error',
            'message',
            isNot(contains(root.path)),
          ),
        ),
      );
      expect(storedNames(), isEmpty);
    });

    test('a failed write does not wedge later operations', () async {
      final fileSystem = _FailingRenameFileSystem();
      final store = storeWith(fileSystem: fileSystem);
      await expectLater(store.put([_bytes(40, 12)]), throwsException);

      fileSystem.failRenames = false;
      final lease = await store.put([_bytes(40, 12)]);
      lease.release();
      expect(storedNames(), [lease.refs.single.sha256]);
    });

    test('a crashed worker is a write failure without its error text', () {
      final crashed = storeWith(
        worker: <T>(FutureOr<T> Function() task, {String? debugName}) async =>
            throw RemoteError('out of memory', ''),
      );

      return expectLater(
        crashed.put([_bytes(40, 22)]),
        throwsA(
          isA<QueueBlobWriteException>()
              .having(
                (error) => error.message,
                'message',
                contains('RemoteError'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('out of memory')),
              ),
        ),
      );
    });

    for (final error in [
      StateError('no plugin'),
      ArgumentError('invalid worker argument'),
      TypeError(),
      AssertionError('invalid worker state'),
      const FormatException('not a storage failure'),
    ]) {
      test(
        'directory and worker preserve ${error.runtimeType} and its stack',
        () async {
          final originalStack = StackTrace.fromString('original put stack');
          final noDirectory = ReplicationQueueBlobStore(
            resolveDirectory: () async =>
                Error.throwWithStackTrace(error, originalStack),
            worker: _inline,
          );
          final failingWorker = storeWith(
            worker:
                <T>(FutureOr<T> Function() task, {String? debugName}) async =>
                    Error.throwWithStackTrace(error, originalStack),
          );

          for (final store in [noDirectory, failingWorker]) {
            await store
                .put([_bytes(40, 22)])
                .then<void>(
                  (_) => fail('Expected the original programming error'),
                  onError: (Object caught, StackTrace stackTrace) {
                    expect(caught, same(error));
                    expect(stackTrace, same(originalStack));
                  },
                );
          }
        },
      );
    }

    for (final error in [
      const FileSystemException('private directory error'),
      PlatformException(code: 'directory_unavailable', message: 'private'),
      MissingPluginException('private plugin error'),
      MissingPlatformDirectoryException('private directory error'),
    ]) {
      test('a directory ${error.runtimeType} is a write failure', () async {
        final store = ReplicationQueueBlobStore(
          resolveDirectory: () async => throw error,
          worker: _inline,
        );

        await expectLater(
          store.put([_bytes(40, 22)]),
          throwsA(
            isA<QueueBlobWriteException>()
                .having(
                  (failure) => failure.message,
                  'message',
                  contains('${error.runtimeType}'),
                )
                .having(
                  (failure) => failure.message,
                  'message',
                  isNot(contains('private')),
                ),
          ),
        );
      });
    }

    test('a crashed worker leaves no lease behind', () async {
      var crash = true;
      final store = storeWith(
        worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
          if (crash && debugName == 'QueueBlobStore.put') {
            throw RemoteError('isolate exited', '');
          }
          return task();
        },
      );
      final bytes = _bytes(24, 23);

      await expectLater(
        store.put([bytes]),
        throwsA(isA<QueueBlobWriteException>()),
      );
      crash = false;
      (await store.put([bytes])).release();
      expect(await store.collect(() => const {}), 1);
      expect(storedNames(), isEmpty);
    });

    test(
      'a crashed reader is transient and does not delete the image',
      () async {
        final store = storeWith();
        final lease = await store.put([_bytes(24, 26)]);
        lease.release();
        final reader = storeWith(
          worker: <T>(FutureOr<T> Function() task, {String? debugName}) async =>
              throw RemoteError('private worker error', ''),
        );

        await expectLater(
          reader.read(lease.refs),
          throwsA(
            isA<QueueBlobReadFailedException>()
                .having(
                  (error) => error.message,
                  'message',
                  contains('RemoteError'),
                )
                .having(
                  (error) => error.message,
                  'message',
                  isNot(contains('private')),
                ),
          ),
        );
        await reader.idle;
        expect(storedNames(), [lease.refs.single.sha256]);
        expect(await store.read(lease.refs), [_bytes(24, 26)]);
      },
    );

    test(
      'a crashed corruption recheck leaves the file for a later read',
      () async {
        final setup = storeWith();
        final lease = await setup.put([_bytes(24, 27)]);
        lease.release();
        await File(
          p.join(blobDirectory, lease.refs.single.sha256),
        ).writeAsBytes(_bytes(24, 28));
        final reader = storeWith(
          worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
            if (debugName == 'QueueBlobStore.recheck') {
              throw RemoteError('private', '');
            }
            return task();
          },
        );

        await expectLater(
          reader.read(lease.refs),
          throwsA(isA<QueueBlobCorruptException>()),
        );
        await reader.idle;
        expect(storedNames(), [lease.refs.single.sha256]);
      },
    );
  });

  test('parses only exact references', () {
    final digest = 'c' * 64;
    expect(
      QueueBlobRef.parse({'sha256': digest, 'length': 5}),
      QueueBlobRef(digest, 5),
    );
    for (final invalid in <Object?>[
      null,
      'c' * 64,
      {'sha256': digest},
      {'sha256': digest, 'length': -1},
      {'sha256': 'C' * 64, 'length': 1},
      {'sha256': '../$digest', 'length': 1},
      {'sha256': digest, 'length': 1, 'extra': true},
    ]) {
      expect(
        () => QueueBlobRef.parse(invalid),
        throwsFormatException,
        reason: '$invalid',
      );
      expect(QueueBlobRef.tryParse(invalid), isNull, reason: '$invalid');
    }
    expect(
      QueueBlobRef.tryParse({'sha256': digest, 'length': 0}),
      QueueBlobRef(digest, 0),
    );
  });
}

Future<T> _inline<T>(FutureOr<T> Function() task, {String? debugName}) async =>
    task();

Uint8List _bytes(int length, int seed) => Uint8List.fromList([
  for (var index = 0; index < length; index++) (index * 31 + seed) & 0xff,
]);

class _CountingFileSystem extends StorageFileSystem {
  int writes = 0;

  @override
  Future<void> writeBytes(String path, Uint8List bytes) {
    writes++;
    return super.writeBytes(path, bytes);
  }
}

class _FailingRenameFileSystem extends StorageFileSystem {
  bool failRenames = true;

  @override
  Future<void> rename(String from, String to) async {
    if (failRenames) {
      throw FileSystemException('injected rename failure', from);
    }
    await super.rename(from, to);
  }
}

class _ObservedListFileSystem extends StorageFileSystem {
  bool listingDone = false;

  @override
  Stream<FileSystemEntity> list(String directory) async* {
    listingDone = false;
    yield* super.list(directory);
    listingDone = true;
  }
}

class _LockedReadFileSystem extends StorageFileSystem {
  @override
  Future<Uint8List> readBytes(String path) async => throw FileSystemException(
    'injected sharing violation',
    path,
    const OSError('locked', 32),
  );
}

class _PausingDeleteFileSystem extends StorageFileSystem {
  final Completer<void> deleting = Completer<void>();
  final Completer<void> resume = Completer<void>();
  String? listedLast;

  @override
  Stream<FileSystemEntity> list(String directory) async* {
    final entities = await super.list(directory).toList();
    final last = entities.where((e) => p.basename(e.path) == listedLast);
    yield* Stream.fromIterable([
      ...entities.where((e) => p.basename(e.path) != listedLast),
      ...last,
    ]);
  }

  @override
  Future<void> delete(String path) async {
    if (!deleting.isCompleted) {
      deleting.complete();
      await resume.future;
    }
    await super.delete(path);
  }
}

class _FailingDeleteFileSystem extends StorageFileSystem {
  bool failDeletes = false;

  @override
  Future<void> delete(String path) async {
    if (failDeletes) throw FileSystemException('injected lock', path);
    await super.delete(path);
  }
}
