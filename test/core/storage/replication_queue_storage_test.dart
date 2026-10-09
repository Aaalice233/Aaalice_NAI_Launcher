import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/queue/failure_handling_strategy.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = Directory(
      'tool/.tmp/replication_queue_storage_test_'
      '${DateTime.now().microsecondsSinceEpoch}',
    );
    await hiveDirectory.create(recursive: true);
    Hive.init(hiveDirectory.path);
    await Hive.openBox<String>(StorageKeys.replicationQueueBox);
    await Hive.openBox<String>(StorageKeys.queueExecutionStateBox);
    await Hive.openBox<String>(StorageKeys.replicationQueueBlobBox);
  });

  tearDown(() async {
    await Hive.close();
    if (hiveDirectory.existsSync()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('保存后重新打开 Hive 仍可完整恢复队列任务和缩略图地址', () async {
    final createdAt = DateTime.utc(2026, 4, 1, 12, 30);
    final startedAt = DateTime.utc(2026, 4, 1, 12, 31);
    final task = ReplicationTask(
      id: 'persisted-task',
      prompt: '1girl, blue hair',
      negativePrompt: 'lowres',
      applyNegativePrompt: true,
      thumbnailUrl: 'https://cdn.example.com/image.webp',
      source: ReplicationTaskSource.online,
      createdAt: createdAt,
      status: ReplicationTaskStatus.pending,
      seed: 123456,
      sampler: 'k_euler',
      steps: 28,
      cfgScale: 5.5,
      model: 'nai-diffusion-4-full',
      width: 832,
      height: 1216,
      characterPrompts: [
        ReplicationCharacterPromptSnapshot.fromCharacterPrompt(
          const CharacterPrompt(
            id: 'character-1',
            name: 'Alice',
            prompt: '1girl, red hair',
            negativePrompt: 'bad hands',
            positionMode: CharacterPositionMode.custom,
            customPosition: CharacterPosition(
              mode: CharacterPositionMode.custom,
              row: 0.25,
              column: 0.75,
            ),
          ),
        ),
      ],
      retryCount: 1,
      startedAt: startedAt,
      errorMessage: 'retryable error',
    );

    await ReplicationQueueStorage().save([task]);

    await Hive.box<String>(StorageKeys.replicationQueueBox).close();
    await Hive.openBox<String>(StorageKeys.replicationQueueBox);

    final restored = ReplicationQueueStorage().load();

    expect(restored, hasLength(1));
    expect(restored.single, task);
    expect(restored.single.thumbnailUrl, task.thumbnailUrl);
  });

  test('角色快照支持 JSON、copyWith 和值相等', () {
    const snapshot = ReplicationCharacterPromptSnapshot(
      prompt: '1girl, red hair',
      negativePrompt: 'bad hands',
      positionX: 0.75,
      positionY: 0.25,
    );

    final restored = ReplicationCharacterPromptSnapshot.fromJson(
      snapshot.toJson(),
    );
    final disabled = snapshot.copyWith(enabled: false);

    expect(restored, snapshot);
    expect(disabled, isNot(snapshot));
    expect(disabled.enabled, isFalse);
  });

  test('旧任务缺少角色字段时保持 null，显式空列表可区分', () {
    final legacyJson = <String, dynamic>{
      'id': 'legacy-task',
      'prompt': 'legacy prompt',
      'createdAt': DateTime.utc(2026, 4, 1).toIso8601String(),
    };

    final legacyTask = ReplicationTask.fromJson(legacyJson);
    final taskWithEmptyCharacters = legacyTask.copyWith(characterPrompts: []);

    expect(legacyTask.characterPrompts, isNull);
    expect(legacyTask.applyNegativePrompt, isFalse);
    expect(legacyTask.toJson(), isNot(contains('characterPrompts')));
    expect(taskWithEmptyCharacters.characterPrompts, isEmpty);
    expect(taskWithEmptyCharacters.toJson()['characterPrompts'], isEmpty);
    expect(taskWithEmptyCharacters, isNot(legacyTask));
  });

  test('队列执行设置使用预打开的 String Box 持久化', () async {
    const expected = QueueExecutionStateData(
      autoExecuteEnabled: true,
      taskIntervalSeconds: 1.5,
      failureStrategy: FailureHandlingStrategy.pauseAndWait,
    );

    await QueueStateStorage().saveExecutionState(expected);

    await Hive.box<String>(StorageKeys.queueExecutionStateBox).close();
    await Hive.openBox<String>(StorageKeys.queueExecutionStateBox);

    final restored = QueueStateStorage().loadExecutionState();
    expect(restored.autoExecuteEnabled, isTrue);
    expect(restored.taskIntervalSeconds, 1.5);
    expect(restored.failureStrategy, FailureHandlingStrategy.pauseAndWait);
  });

  group('生成快照图像去重', () {
    test('多个任务共用的同一张图只保存一份并可完整恢复', () async {
      final image = _largeImage(seed: 1);
      final tasks = [
        for (var i = 0; i < 40; i++)
          _taskWithSnapshot('task-$i', {
            'sourceImage': image,
            'preciseReferences': [
              {'image': image, 'type': 'character'},
            ],
          }),
      ];

      await ReplicationQueueStorage().save(tasks);
      await _reopenQueueBoxes();
      final restored = ReplicationQueueStorage().load();

      expect(_blobBox.length, 1);
      expect(_queueJson().length, lessThan(image.length));
      expect(restored.map((task) => task.id), [
        for (var i = 0; i < 40; i++) 'task-$i',
      ]);
      for (final task in restored) {
        final snapshot = task.generationSnapshot!;
        expect(snapshot['sourceImage'], image);
        expect((snapshot['preciseReferences'] as List).single['image'], image);
      }
    });

    test('不再被任何任务引用的图像在保存时清理', () async {
      final storage = ReplicationQueueStorage();
      final kept = _taskWithSnapshot('kept', {
        'sourceImage': _largeImage(seed: 2),
      });

      await storage.save([
        _taskWithSnapshot('removed', {'sourceImage': _largeImage(seed: 3)}),
        kept,
      ]);
      expect(_blobBox.length, 2);

      await storage.save([kept]);
      expect(_blobBox.length, 1);
    });

    test('读取旧版内嵌图像的队列并在下次保存时外置', () async {
      final image = _largeImage(seed: 4);
      final legacyTask = _taskWithSnapshot('legacy', {'sourceImage': image});
      await Hive.box<String>(StorageKeys.replicationQueueBox).put(
        StorageKeys.replicationQueueData,
        jsonEncode(ReplicationTaskList(tasks: [legacyTask]).toJson()),
      );

      final storage = ReplicationQueueStorage();
      final restored = storage.load();
      expect(restored.single.generationSnapshot!['sourceImage'], image);

      await storage.save(restored);
      expect(_blobBox.length, 1);
      expect(_queueJson(), isNot(contains(image)));
    });

    test('估算持久化体积时共用图像只计一次', () {
      final shared = {'sourceImage': _largeImage(seed: 6)};
      final other = {'sourceImage': _largeImage(seed: 7)};
      final single = ReplicationQueueStorage.estimatePersistedSnapshotBytes([
        shared,
      ]);

      final repeated = ReplicationQueueStorage.estimatePersistedSnapshotBytes(
        List.filled(40, shared),
      );
      final distinct = ReplicationQueueStorage.estimatePersistedSnapshotBytes([
        shared,
        other,
      ]);

      expect(single, greaterThan(_largeImage(seed: 6).length));
      expect(repeated, lessThan(single * 2));
      expect(distinct, greaterThan(single * 2 - 1024));
    });

    test('引用的图像缺失时只跳过该任务', () async {
      await ReplicationQueueStorage().save([
        _taskWithSnapshot('intact', {'batchSize': 1}),
        _taskWithSnapshot('broken', {'sourceImage': _largeImage(seed: 5)}),
      ]);
      await _blobBox.clear();

      final restored = ReplicationQueueStorage().load();

      expect(restored.map((task) => task.id), ['intact']);
    });
  });
}

Box<String> get _blobBox =>
    Hive.box<String>(StorageKeys.replicationQueueBlobBox);

String _queueJson() => Hive.box<String>(
  StorageKeys.replicationQueueBox,
).get(StorageKeys.replicationQueueData)!;

Future<void> _reopenQueueBoxes() async {
  await Hive.box<String>(StorageKeys.replicationQueueBox).close();
  await _blobBox.close();
  await Hive.openBox<String>(StorageKeys.replicationQueueBox);
  await Hive.openBox<String>(StorageKeys.replicationQueueBlobBox);
}

/// 约 64 KB 的 base64 文本，模拟参考图等大体积快照字段。
String _largeImage({required int seed}) => base64Encode(
  Uint8List.fromList(List.generate(48 * 1024, (i) => (i * seed) % 251)),
);

ReplicationTask _taskWithSnapshot(String id, Map<String, dynamic> snapshot) {
  return ReplicationTask(
    id: id,
    prompt: 'prompt $id',
    createdAt: DateTime.utc(2026, 10, 10),
    generationSnapshot: snapshot,
  );
}
