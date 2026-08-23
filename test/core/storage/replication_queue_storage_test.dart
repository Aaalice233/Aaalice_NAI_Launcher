import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
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
}
