import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/core/storage/storage_file_system.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/replication_queue_snapshot_migration.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late String blobDirectory;
  late Box<String> queueBox;
  late Box<String> stateBox;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('queue_migration_test_');
    blobDirectory = p.join(root.path, ReplicationQueueBlobStore.directoryName);
    Hive.init(root.path);
    queueBox = await Hive.openBox<String>(StorageKeys.replicationQueueBox);
    stateBox = await Hive.openBox<String>(StorageKeys.queueExecutionStateBox);
  });

  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  ReplicationQueueBlobStore store([
    StorageFileSystem? fileSystem,
    QueueBlobWorker? worker,
  ]) => ReplicationQueueBlobStore(
    resolveDirectory: () async => blobDirectory,
    fileSystem: fileSystem ?? const StorageFileSystem(),
    worker: worker ?? _inline,
  );

  Future<ReplicationQueueMigrationResult?> migrate({
    StorageFileSystem fileSystem = const StorageFileSystem(),
    QueueBlobWorker? worker,
  }) => ReplicationQueueSnapshotMigration(
    queueBox: queueBox,
    stateBox: stateBox,
    blobStore: store(fileSystem, worker),
  ).run();

  Future<String> orphanFile() async {
    final orphan = sha256.convert(_bytes(77, 1)).toString();
    await Directory(blobDirectory).create(recursive: true);
    await File(p.join(blobDirectory, orphan)).writeAsBytes(_bytes(77, 1));
    return orphan;
  }

  List<ReplicationTask> tasksIn(Box<String> box, String key) =>
      ReplicationTaskList.fromJson(
        jsonDecode(box.get(key)!) as Map<String, dynamic>,
      ).tasks;

  List<String> storedNames() => Directory(blobDirectory).existsSync()
      ? (Directory(
          blobDirectory,
        ).listSync().map((entity) => p.basename(entity.path)).toList()..sort())
      : const [];

  test('converts the queue and the failed pool to image files', () async {
    await queueBox.put(
      StorageKeys.replicationQueueData,
      _legacyIndex([_legacyTask('queued', _fullParams)]),
    );
    await stateBox.put(
      StorageKeys.queueFailedTasksData,
      _legacyIndex([_legacyTask('failed', _fullParams)]),
    );

    final result = await ReplicationQueueSnapshotMigration(
      queueBox: queueBox,
      stateBox: stateBox,
      blobStore: ReplicationQueueBlobStore(
        resolveDirectory: () async => blobDirectory,
      ),
    ).run();

    expect(result!.converted, 2);
    expect(result.kept, 0);
    for (final task in [
      ...tasksIn(queueBox, StorageKeys.replicationQueueData),
      ...tasksIn(stateBox, StorageKeys.queueFailedTasksData),
    ]) {
      final snapshot = task.generationSnapshot!;
      expect(snapshot['schemaVersion'], 2);
      final restored = await ReplicationTaskGenerationSnapshot.decode(
        snapshot,
        store(),
      );
      expect(restored.sourceImage, _fullParams.sourceImage);
      expect(restored.maskImage, _fullParams.maskImage);
      expect(
        restored.vibeReferencesV4[0].rawImageData,
        _fullParams.vibeReferencesV4[0].rawImageData,
      );
      expect(
        restored.vibeReferencesV4[1].vibeEncoding,
        _fullParams.vibeReferencesV4[1].vibeEncoding,
      );
      expect(
        restored.preciseReferences.single.image,
        _fullParams.preciseReferences.single.image,
      );
      expect(restored.prompt, _fullParams.prompt);
      expect(ReplicationTaskGenerationSnapshot.decodeBatchSize(snapshot), 2);
    }
    expect(
      storedNames(),
      [
        for (final bytes in [
          _fullParams.sourceImage!,
          _fullParams.maskImage!,
          _fullParams.vibeReferencesV4[0].rawImageData!,
          utf8.encode(_fullParams.vibeReferencesV4[1].vibeEncoding),
          _fullParams.preciseReferences.single.image,
        ])
          sha256.convert(bytes).toString(),
      ]..sort(),
    );
  });

  test('matches the snapshot a new enqueue would write', () async {
    await queueBox.put(
      StorageKeys.replicationQueueData,
      _legacyIndex([_legacyTask('queued', _fullParams)]),
    );

    await migrate();

    final interned = await ReplicationTaskGenerationSnapshot.intern([
      await ReplicationTaskGenerationSnapshot.encode(_fullParams, batchSize: 2),
    ], store());
    interned.release();
    expect(
      jsonEncode(
        tasksIn(
          queueBox,
          StorageKeys.replicationQueueData,
        ).single.generationSnapshot,
      ),
      jsonEncode(interned.snapshots.single),
    );
  });

  test(
    'stores Vibe encodings as their text, apart from base64 images',
    () async {
      // 同一段文本：源图槽位按 base64 解出 "ABC"，Vibe 编码槽位按原文存储
      const text = 'QUJD';
      final params = ImageParams(
        prompt: 'same text',
        action: ImageGenerationAction.img2img,
        sourceImage: base64Decode(text),
        vibeReferencesV4: const [
          VibeReference(
            displayName: 'text',
            vibeEncoding: text,
            sourceType: VibeSourceType.naiv4vibe,
          ),
          VibeReference(
            displayName: 'not base64',
            vibeEncoding: 'not base64\n',
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ],
      );
      await queueBox.put(
        StorageKeys.replicationQueueData,
        _legacyIndex([_legacyTask('queued', params)]),
      );

      expect((await migrate())!.converted, 1);

      expect(
        storedNames(),
        [
          for (final bytes in [
            base64Decode(text),
            utf8.encode(text),
            utf8.encode('not base64\n'),
          ])
            sha256.convert(bytes).toString(),
        ]..sort(),
      );
      final restored = await ReplicationTaskGenerationSnapshot.decode(
        tasksIn(
          queueBox,
          StorageKeys.replicationQueueData,
        ).single.generationSnapshot!,
        store(),
      );
      expect(restored.sourceImage, base64Decode(text));
      expect(restored.vibeReferencesV4.map((vibe) => vibe.vibeEncoding), [
        text,
        'not base64\n',
      ]);
    },
  );

  test('a second run changes nothing and writes nothing', () async {
    await queueBox.put(
      StorageKeys.replicationQueueData,
      _legacyIndex([_legacyTask('queued', _fullParams)]),
    );
    await migrate();
    final migrated = queueBox.get(StorageKeys.replicationQueueData);
    final fileSystem = _FaultyFileSystem();

    final result = await migrate(fileSystem: fileSystem);

    expect(result!.converted, 0);
    expect(queueBox.get(StorageKeys.replicationQueueData), migrated);
    expect(fileSystem.writes, 0);
    expect(storedNames(), hasLength(5));
  });

  test('identical legacy tasks are decoded and written once', () async {
    await queueBox.put(
      StorageKeys.replicationQueueData,
      _legacyIndex([
        for (var index = 0; index < 10; index++)
          _legacyTask('same $index', _fullParams),
      ]),
    );
    final fileSystem = _FaultyFileSystem();

    final result = await migrate(fileSystem: fileSystem);

    expect(result!.converted, 10);
    expect(fileSystem.writes, 5);
  });

  test('a failed file write keeps the legacy index for the next run', () async {
    final legacy = _legacyIndex([_legacyTask('queued', _fullParams)]);
    await queueBox.put(StorageKeys.replicationQueueData, legacy);

    final failed = await migrate(
      fileSystem: _FaultyFileSystem(failWriteNumber: 3),
    );

    expect(failed, isNull);
    expect(queueBox.get(StorageKeys.replicationQueueData), legacy);
    expect(storedNames(), hasLength(2));
    expect(storedNames().where((name) => name.endsWith('.tmp')), isEmpty);

    final retry = _FaultyFileSystem();
    final result = await migrate(fileSystem: retry);
    expect(result!.converted, 1);
    expect(retry.writes, 3);
    expect(storedNames(), hasLength(5));
  });

  test('a failed rename keeps the legacy index readable', () async {
    final legacy = _legacyIndex([_legacyTask('queued', _fullParams)]);
    await queueBox.put(StorageKeys.replicationQueueData, legacy);

    expect(
      await migrate(fileSystem: _FaultyFileSystem(failRenames: true)),
      isNull,
    );
    expect(queueBox.get(StorageKeys.replicationQueueData), legacy);
    expect(
      tasksIn(queueBox, StorageKeys.replicationQueueData).single.prompt,
      'queued',
    );
    expect(storedNames(), isEmpty);
  });

  test(
    'a crashed migration worker keeps both indexes and skips collection',
    () async {
      final legacy = _legacyIndex([_legacyTask('queued', _fullParams)]);
      await queueBox.put(StorageKeys.replicationQueueData, legacy);
      await stateBox.put(StorageKeys.queueFailedTasksData, legacy);
      final orphan = await orphanFile();

      final result = await migrate(
        worker: <T>(FutureOr<T> Function() task, {String? debugName}) async =>
            throw RemoteError('private worker crash', ''),
      );

      expect(result, isNull);
      expect(queueBox.get(StorageKeys.replicationQueueData), legacy);
      expect(stateBox.get(StorageKeys.queueFailedTasksData), legacy);
      expect(storedNames(), [orphan]);
      expect((await migrate())!.converted, 2);
    },
  );

  test(
    'a sweep error does not undo migrated indexes and a later run recovers',
    () async {
      await queueBox.put(
        StorageKeys.replicationQueueData,
        _legacyIndex([_legacyTask('queued', _fullParams)]),
      );
      final orphan = await orphanFile();

      expect(await migrate(fileSystem: _CrashedSweepFileSystem()), isNull);
      expect(
        tasksIn(
          queueBox,
          StorageKeys.replicationQueueData,
        ).single.generationSnapshot!['schemaVersion'],
        2,
      );
      expect(storedNames(), contains(orphan));
      expect((await migrate())!.collected, 1);
      expect(storedNames(), isNot(contains(orphan)));
    },
  );

  test('a corrupt legacy snapshot alone stays as it was', () async {
    final corrupt = _legacyTask('corrupt', _fullParams);
    (corrupt['generationSnapshot'] as Map<String, dynamic>)['maskImage'] =
        'not base64!';
    await queueBox.put(
      StorageKeys.replicationQueueData,
      _legacyIndex([
        _legacyTask('before', _fullParams),
        corrupt,
        _legacyTask('after', _fullParams),
      ]),
    );

    final result = await migrate();

    expect(result!.converted, 2);
    expect(result.kept, 1);
    final tasks = tasksIn(queueBox, StorageKeys.replicationQueueData);
    expect(tasks.map((task) => task.prompt), ['before', 'corrupt', 'after']);
    expect(tasks.map((task) => task.generationSnapshot!['schemaVersion']), [
      2,
      1,
      2,
    ]);
    expect(tasks[1].generationSnapshot!['maskImage'], 'not base64!');
    await expectLater(
      ReplicationTaskGenerationSnapshot.decode(
        tasks[1].generationSnapshot!,
        store(),
      ),
      throwsFormatException,
    );
  });

  test('leaves current, unknown and missing snapshots untouched', () async {
    final current = {
      'id': 'current',
      'prompt': 'current',
      'createdAt': '2026-11-01T00:00:00.000Z',
      'generationSnapshot': {
        'schemaVersion': 2,
        'params': const ImageParams(prompt: 'current').toJson(),
      },
    };
    final unknown = {
      'id': 'unknown',
      'prompt': 'unknown',
      'createdAt': '2026-11-01T00:00:00.000Z',
      'generationSnapshot': {'schemaVersion': 3, 'sourceImage': 'AAAA'},
    };
    final plain = {
      'id': 'plain',
      'prompt': 'plain',
      'createdAt': '2026-11-01T00:00:00.000Z',
    };
    final index = _legacyIndex([current, unknown, plain]);
    await queueBox.put(StorageKeys.replicationQueueData, index);
    await stateBox.put(StorageKeys.queueFailedTasksData, 'not json');

    final orphan = await orphanFile();

    final result = await migrate();

    expect(result!.converted, 0);
    expect(result.collected, 0);
    expect(queueBox.get(StorageKeys.replicationQueueData), index);
    expect(stateBox.get(StorageKeys.queueFailedTasksData), 'not json');
    expect(storedNames(), [orphan]);
  });

  group('skips the sweep when an index cannot be fully read', () {
    test('an unparseable failed pool', () async {
      await stateBox.put(StorageKeys.queueFailedTasksData, '{"tasks": [');
      final orphan = await orphanFile();

      expect((await migrate())!.collected, 0);
      expect(storedNames(), [orphan]);
    });

    test('a snapshot written by a newer version', () async {
      await queueBox.put(
        StorageKeys.replicationQueueData,
        _legacyIndex([
          _legacyTask('legacy', _fullParams),
          {
            'id': 'newer',
            'prompt': 'newer',
            'createdAt': '2026-11-01T00:00:00.000Z',
            'generationSnapshot': {'schemaVersion': 3},
          },
        ]),
      );
      final orphan = await orphanFile();

      final result = await migrate();

      expect(result!.converted, 1);
      expect(result.collected, 0);
      expect(storedNames(), contains(orphan));
    });

    test('an index rewritten while it was migrating', () async {
      await queueBox.put(
        StorageKeys.replicationQueueData,
        _legacyIndex([_legacyTask('queued', _fullParams)]),
      );
      final orphan = await orphanFile();

      final result = await migrate(
        worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
          final result = await task();
          await queueBox.put(StorageKeys.replicationQueueData, '{}');
          return result;
        },
      );

      expect(result!.collected, 0);
      expect(storedNames(), contains(orphan));
    });
  });

  test('defers to an index rewritten while it was migrating', () async {
    await queueBox.put(
      StorageKeys.replicationQueueData,
      _legacyIndex([_legacyTask('queued', _fullParams)]),
    );
    final rewritten = _legacyIndex([_legacyTask('newer', _fullParams)]);

    await migrate(
      worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
        final result = await task();
        if (debugName == 'QueueMigration.index') {
          await queueBox.put(StorageKeys.replicationQueueData, rewritten);
        }
        return result;
      },
    );

    expect(queueBox.get(StorageKeys.replicationQueueData), rewritten);
  });

  test('compacts both boxes down to their live entries', () async {
    final index = _legacyIndex([_legacyTask('queued', _fullParams)]);
    for (var write = 0; write < 20; write++) {
      await queueBox.put(StorageKeys.replicationQueueData, index);
      await stateBox.put(StorageKeys.queueFailedTasksData, index);
    }
    await stateBox.put(StorageKeys.queueExecutionStateData, '{}');

    await migrate();
    final migrated = queueBox.get(StorageKeys.replicationQueueData)!;
    final migratedFailed = stateBox.get(StorageKeys.queueFailedTasksData)!;
    await Hive.close();

    final reference = Directory(p.join(root.path, 'reference'));
    await reference.create();
    Hive.init(reference.path);
    final freshQueue = await Hive.openBox<String>(
      StorageKeys.replicationQueueBox,
    );
    await freshQueue.put(StorageKeys.replicationQueueData, migrated);
    final freshState = await Hive.openBox<String>(
      StorageKeys.queueExecutionStateBox,
    );
    await freshState.put(StorageKeys.queueFailedTasksData, migratedFailed);
    await freshState.put(StorageKeys.queueExecutionStateData, '{}');
    await Hive.close();

    int length(String directory, String box) =>
        File(p.join(directory, '$box.hive')).lengthSync();
    expect(
      length(root.path, StorageKeys.replicationQueueBox),
      length(reference.path, StorageKeys.replicationQueueBox),
    );
    expect(
      length(root.path, StorageKeys.queueExecutionStateBox),
      length(reference.path, StorageKeys.queueExecutionStateBox),
    );
    // 重新打开供 tearDown 关闭
    Hive.init(root.path);
    queueBox = await Hive.openBox<String>(StorageKeys.replicationQueueBox);
    stateBox = await Hive.openBox<String>(StorageKeys.queueExecutionStateBox);
  });

  group('restart after an interrupted enqueue', () {
    // 模拟进程在入队各步骤之间被杀：已落盘的引用、改名前留下的临时文件、改名后未写入索引的孤儿
    test('keeps referenced images and sweeps the leftovers', () async {
      final interned = await ReplicationTaskGenerationSnapshot.intern([
        await ReplicationTaskGenerationSnapshot.encode(_fullParams),
      ], store());
      interned.release();
      final queued = ReplicationTask.create(
        prompt: 'queued',
        generationSnapshot: interned.snapshots.single,
      );
      await queueBox.put(
        StorageKeys.replicationQueueData,
        jsonEncode(ReplicationTaskList(tasks: [queued]).toJson()),
      );
      final orphan = await orphanFile();
      await File(
        p.join(blobDirectory, '$orphan.1-2.tmp'),
      ).writeAsBytes(_bytes(7, 2));

      final result = await migrate();

      expect(result!.collected, 2);
      expect(
        storedNames(),
        ReplicationTaskGenerationSnapshot.blobDigests(
          queued.generationSnapshot!,
        ).toSet().toList()..sort(),
      );
      final restored = await ReplicationTaskGenerationSnapshot.decode(
        tasksIn(
          queueBox,
          StorageKeys.replicationQueueData,
        ).single.generationSnapshot!,
        store(),
      );
      expect(restored.sourceImage, _fullParams.sourceImage);
    });

    Future<void> enqueueThenRestart({
      required StorageFileSystem fileSystem,
      ReplicationQueueStorage? queueStorage,
    }) async {
      final existing = ReplicationTask.create(
        prompt: 'existing',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(prompt: 'existing', sourceImage: _bytes(64, 30)),
        ),
      );
      final setup = ProviderContainer(
        overrides: [
          replicationQueueBlobStoreProvider.overrideWithValue(store()),
        ],
      );
      await setup.read(replicationQueueNotifierProvider.notifier).add(existing);
      await setup.read(replicationQueueBlobStoreProvider).idle;
      setup.dispose();

      final crashing = ProviderContainer(
        overrides: [
          replicationQueueBlobStoreProvider.overrideWithValue(
            store(fileSystem),
          ),
          if (queueStorage != null)
            replicationQueueStorageProvider.overrideWithValue(queueStorage),
        ],
      );
      final result = await crashing
          .read(replicationQueueNotifierProvider.notifier)
          .add(
            ReplicationTask.create(
              prompt: 'interrupted',
              generationSnapshot:
                  await ReplicationTaskGenerationSnapshot.encode(_fullParams),
            ),
          );
      expect(result.outcome, EnqueueOutcome.withdrawn);
      expect(result.failure, isA<ReplicationQueueWriteException>());
      // 不等待清扫，按进程在失败后立刻退出处理
      crashing.dispose();

      await migrate();
      final restarted = ProviderContainer(
        overrides: [
          replicationQueueBlobStoreProvider.overrideWithValue(store()),
        ],
      );
      addTearDown(restarted.dispose);
      final tasks = restarted.read(replicationQueueNotifierProvider).tasks;

      expect(tasks.map((task) => task.prompt), ['existing']);
      expect(storedNames(), [
        ...ReplicationTaskGenerationSnapshot.blobDigests(
          tasks.single.generationSnapshot!,
        ),
      ]);
      final restored = await ReplicationTaskGenerationSnapshot.decode(
        tasks.single.generationSnapshot!,
        store(),
      );
      expect(restored.sourceImage, _bytes(64, 30));
    }

    test('a failed rename leaves neither the task nor its files', () async {
      await enqueueThenRestart(
        fileSystem: _FaultyFileSystem(failRenames: true),
      );
    });

    test(
      'a failed index write leaves neither the task nor its files',
      () async {
        await enqueueThenRestart(
          fileSystem: const StorageFileSystem(),
          queueStorage: _FailingQueueStorage(),
        );
      },
    );
  });
}

class _FailingQueueStorage extends ReplicationQueueStorage {
  @override
  Future<void> save(List<ReplicationTask> tasks) async =>
      throw HiveError('injected index failure');
}

Future<T> _inline<T>(FutureOr<T> Function() task, {String? debugName}) async =>
    task();

Uint8List _bytes(int length, int seed) => Uint8List.fromList([
  for (var index = 0; index < length; index++) (index * 31 + seed) & 0xff,
]);

final _fullParams = ImageParams(
  prompt: 'legacy "quoted"\n中文',
  negativePrompt: 'bad',
  seed: 7,
  action: ImageGenerationAction.infill,
  sourceImage: _bytes(20000, 1),
  maskImage: _bytes(3000, 2),
  vibeReferencesV4: [
    VibeReference(
      displayName: 'raw',
      vibeEncoding: '',
      rawImageData: _bytes(4000, 3),
    ),
    VibeReference(
      displayName: 'encoded',
      vibeEncoding: base64Encode(_bytes(900, 4)),
      sourceType: VibeSourceType.naiv4vibe,
    ),
  ],
  preciseReferences: [
    PreciseReference(image: _bytes(5000, 5), type: PreciseRefType.style),
  ],
);

String _legacyIndex(List<Map<String, dynamic>> tasks) =>
    jsonEncode({'tasks': tasks});

Map<String, dynamic> _legacyTask(String prompt, ImageParams params) =>
    jsonDecode(
          jsonEncode({
            ...ReplicationTask(
              id: prompt,
              prompt: prompt,
              createdAt: DateTime.utc(2026, 10, 1),
            ).toJson(),
            'generationSnapshot': _legacySnapshot(params),
          }),
        )
        as Map<String, dynamic>;

// 4.3.1 写入的 v1 快照格式，图片以 base64 内联
Map<String, dynamic> _legacySnapshot(ImageParams params) => {
  'schemaVersion': 1,
  'batchSize': 2,
  'params': params.toJson(),
  'transient': {
    'omitQualityTagHint': params.omitQualityTagHint,
    'omitUcPresetTagHint': params.omitUcPresetTagHint,
    'upscaledEnhance': params.upscaledEnhance,
    'isEnhanceRequest': params.isEnhanceRequest,
    'inpaintMaskClosingIterations': params.inpaintMaskClosingIterations,
    'inpaintMaskExpansionIterations': params.inpaintMaskExpansionIterations,
    'isOutpaint': params.isOutpaint,
  },
  if (params.sourceImage != null)
    'sourceImage': base64Encode(params.sourceImage!),
  if (params.maskImage != null) 'maskImage': base64Encode(params.maskImage!),
  'vibeReferences': [
    for (final reference in params.vibeReferencesV4)
      {
        'value': reference.toJson(),
        if (reference.rawImageData != null)
          'rawImageData': base64Encode(reference.rawImageData!),
      },
  ],
  'preciseReferences': [
    for (final reference in params.preciseReferences)
      {
        'image': base64Encode(reference.image),
        'type': reference.type.name,
        'strength': reference.strength,
        'fidelity': reference.fidelity,
        'enabled': reference.enabled,
      },
  ],
  'characters': [
    for (final character in params.characters)
      {
        'prompt': character.prompt,
        'negativePrompt': character.negativePrompt,
        'positionX': character.positionX,
        'positionY': character.positionY,
        'position': character.position,
      },
  ],
};

class _FaultyFileSystem extends StorageFileSystem {
  _FaultyFileSystem({this.failWriteNumber, this.failRenames = false});

  final int? failWriteNumber;
  final bool failRenames;
  int writes = 0;

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    writes++;
    if (writes == failWriteNumber) {
      throw FileSystemException('injected write failure', path);
    }
    await super.writeBytes(path, bytes);
  }

  @override
  Future<void> rename(String from, String to) async {
    if (failRenames) throw FileSystemException('injected rename failure', from);
    await super.rename(from, to);
  }
}

class _CrashedSweepFileSystem extends StorageFileSystem {
  @override
  Stream<FileSystemEntity> list(String directory) =>
      Stream.error(RemoteError('private sweep error', ''));
}
