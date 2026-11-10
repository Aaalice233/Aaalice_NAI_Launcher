import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/core/storage/replication_queue_startup_gate.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/core/storage/storage_file_system.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/services/replication_queue_snapshot_migration.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  final source = Uint8List.fromList(List.generate(64, (index) => index));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('queue_startup_test_');
    Hive.init(root.path);
  });

  tearDown(() async {
    ReplicationQueueStartupGate.reset();
    await Hive.close();
    await root.delete(recursive: true);
  });

  ReplicationQueueBlobStore store({
    StorageFileSystem fileSystem = const StorageFileSystem(),
    QueueBlobWorker? worker,
  }) => ReplicationQueueBlobStore(
    resolveDirectory: () async =>
        p.join(root.path, ReplicationQueueBlobStore.directoryName),
    fileSystem: fileSystem,
    worker:
        worker ??
        <T>(FutureOr<T> Function() task, {String? debugName}) async => task(),
  );

  Future<String> writeLegacyQueue() async {
    final index = jsonEncode({
      'tasks': [
        {
          ...ReplicationTask(
            id: 'legacy',
            prompt: 'legacy',
            createdAt: DateTime.utc(2026, 10, 1),
          ).toJson(),
          'generationSnapshot': {
            'schemaVersion': 1,
            'params': const ImageParams(prompt: 'legacy').toJson(),
            'sourceImage': base64Encode(source),
          },
        },
      ],
    });
    final box = await Hive.openBox<String>(StorageKeys.replicationQueueBox);
    await box.put(StorageKeys.replicationQueueData, index);
    await box.close();
    return index;
  }

  ReplicationTask loadQueuedTask() {
    final container = ProviderContainer(
      overrides: [replicationQueueBlobStoreProvider.overrideWithValue(store())],
    );
    addTearDown(container.dispose);
    return container.read(replicationQueueNotifierProvider).tasks.single;
  }

  test('reading the queue before the startup migration ends is an error', () {
    ReplicationQueueStartupGate.close();
    final container = ProviderContainer(
      overrides: [replicationQueueBlobStoreProvider.overrideWithValue(store())],
    );
    addTearDown(container.dispose);

    expect(
      () => ReplicationQueueStorage().load(),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => QueueStateStorage().loadFailedTasks(),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => container.read(replicationQueueNotifierProvider),
      throwsA(
        isA<ProviderException>().having(
          (error) => error.exception,
          'exception',
          isA<AssertionError>(),
        ),
      ),
    );
  });

  test('the queue opens only after its snapshots are migrated', () async {
    await writeLegacyQueue();
    ReplicationQueueStartupGate.close();
    final openWhileMigrating = <bool>[];

    await prepareReplicationQueue(
      hivePath: root.path,
      blobStore: store(
        worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
          openWhileMigrating.add(ReplicationQueueStartupGate.isOpen);
          return task();
        },
      ),
    );

    expect(openWhileMigrating, [false]);
    expect(ReplicationQueueStartupGate.isOpen, isTrue);
    final task = loadQueuedTask();
    expect(
      task.generationSnapshot!['schemaVersion'],
      ReplicationTaskGenerationSnapshot.schemaVersion,
    );
    final params = await ReplicationTaskGenerationSnapshot.decode(
      task.generationSnapshot!,
      store(),
    );
    expect(params.sourceImage, source);
  });

  test('a read while the gate is closed is remembered for the run', () {
    ReplicationQueueStartupGate.close();
    expect(
      () => ReplicationQueueStartupGate.checkReadable('early reader'),
      throwsA(isA<AssertionError>()),
    );
    ReplicationQueueStartupGate.open();
    ReplicationQueueStartupGate.checkReadable('late reader');

    expect(ReplicationQueueStartupGate.readWhileClosed, isTrue);
    ReplicationQueueStartupGate.reset();
    expect(ReplicationQueueStartupGate.readWhileClosed, isFalse);
  });

  for (final readEarly in [true, false]) {
    test('an early read ${readEarly ? 'keeps' : 'does not keep'} images '
        'through the migration sweep and later saves', () async {
      await writeLegacyQueue();
      final blobDirectory = p.join(
        root.path,
        ReplicationQueueBlobStore.directoryName,
      );
      final orphanBytes = Uint8List.fromList(List.filled(9, 7));
      final orphan = sha256.convert(orphanBytes).toString();
      await Directory(blobDirectory).create(recursive: true);
      await File(p.join(blobDirectory, orphan)).writeAsBytes(orphanBytes);
      ReplicationQueueStartupGate.close();
      if (readEarly) {
        expect(
          () => ReplicationQueueStartupGate.checkReadable('early reader'),
          throwsA(isA<AssertionError>()),
        );
      }
      final blobs = store();
      await prepareReplicationQueue(hivePath: root.path, blobStore: blobs);
      final container = ProviderContainer(
        overrides: [replicationQueueBlobStoreProvider.overrideWithValue(blobs)],
      );
      addTearDown(container.dispose);

      // 删除唯一任务的保存会成功，平时随后的清扫会删掉它的图片
      final migrated = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      expect(
        await container
            .read(replicationQueueNotifierProvider.notifier)
            .remove(migrated.id),
        isTrue,
      );
      await blobs.idle;

      final names = Directory(
        blobDirectory,
      ).listSync().map((entity) => p.basename(entity.path)).toSet();
      expect(
        names,
        readEarly ? {orphan, sha256.convert(source).toString()} : isEmpty,
      );
    });
  }

  test('a failed migration still opens the queue as it was', () async {
    final legacy = await writeLegacyQueue();
    ReplicationQueueStartupGate.close();

    await prepareReplicationQueue(
      hivePath: root.path,
      blobStore: store(fileSystem: _FailingWrites()),
    );

    expect(ReplicationQueueStartupGate.isOpen, isTrue);
    expect(
      Hive.box<String>(
        StorageKeys.replicationQueueBox,
      ).get(StorageKeys.replicationQueueData),
      legacy,
    );
    expect(loadQueuedTask().generationSnapshot!['schemaVersion'], 1);
  });
}

class _FailingWrites extends StorageFileSystem {
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      throw FileSystemException('injected write failure', path);
}
