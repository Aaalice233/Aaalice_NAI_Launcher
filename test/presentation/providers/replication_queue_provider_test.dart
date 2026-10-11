import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

void main() {
  test(
    'character and negative-only codex tasks survive queue operations',
    () async {
      final queueStorage = _MemoryReplicationQueueStorage();
      final stateStorage = _MemoryQueueStateStorage();
      final container = ProviderContainer(
        overrides: [
          replicationQueueStorageProvider.overrideWithValue(queueStorage),
          queueStateStorageProvider.overrideWithValue(stateStorage),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(
        prompt: '',
        negativePrompt: 'lowres',
        applyNegativePrompt: true,
        characterPrompts: const [
          ReplicationCharacterPromptSnapshot(prompt: '1girl, red hair'),
        ],
      );

      expect(await notifier.add(task), isTrue);
      expect(await notifier.duplicateTask(task.id), isTrue);

      var state = container.read(replicationQueueNotifierProvider);
      expect(state.tasks, hasLength(2));
      final duplicate = state.tasks.last;
      expect(duplicate.applyNegativePrompt, isTrue);
      expect(duplicate.negativePrompt, 'lowres');
      expect(duplicate.characterPrompts?.single.prompt, '1girl, red hair');

      await notifier.moveToFailedPool(task.id);
      state = container.read(replicationQueueNotifierProvider);
      expect(state.failedTasks.single.id, task.id);

      await notifier.retryFailedTask(task.id);
      state = container.read(replicationQueueNotifierProvider);
      expect(state.failedTasks, isEmpty);
      expect(state.tasks.first.id, task.id);
    },
  );

  test(
    'running task is locked and completion settles the exact task ID',
    () async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final pendingTask = ReplicationTask.create(prompt: 'pending');
      final runningTask = ReplicationTask.create(prompt: 'running');

      await notifier.addAll([pendingTask, runningTask]);
      await notifier.updateTaskStatus(
        runningTask.id,
        ReplicationTaskStatus.running,
      );

      expect(await notifier.remove(runningTask.id), isFalse);
      expect(
        await notifier.updateTask(runningTask.copyWith(prompt: 'overwritten')),
        isFalse,
      );
      notifier.selectAll();
      expect(container.read(replicationQueueNotifierProvider).selectedTaskIds, {
        pendingTask.id,
      });
      expect(await notifier.markCompleted(pendingTask.id), isFalse);
      expect(await notifier.markCompleted(runningTask.id), isTrue);

      final state = container.read(replicationQueueNotifierProvider);
      expect(state.tasks.map((task) => task.id), [pendingTask.id]);
      expect(state.completedTasks.single.id, runningTask.id);
      expect(
        state.completedTasks.single.status,
        ReplicationTaskStatus.completed,
      );
    },
  );

  test('retrying a failed task never jumps ahead of a running task', () async {
    final failedTask = ReplicationTask.create(
      prompt: 'retry me',
    ).copyWith(status: ReplicationTaskStatus.failed);
    final stateStorage = _MemoryQueueStateStorage()..failedTasks = [failedTask];
    final container = _buildContainer(stateStorage: stateStorage);
    addTearDown(container.dispose);
    final notifier = container.read(replicationQueueNotifierProvider.notifier);
    final runningTask = ReplicationTask.create(prompt: 'in flight');

    await notifier.add(runningTask);
    await notifier.updateTaskStatus(
      runningTask.id,
      ReplicationTaskStatus.running,
    );

    expect(await notifier.retryFailedTask(failedTask.id), isTrue);
    final state = container.read(replicationQueueNotifierProvider);
    expect(state.tasks.map((task) => task.id), [runningTask.id, failedTask.id]);
    expect(state.failedTasks, isEmpty);
  });

  test('serialized writes cannot restore an older queue snapshot', () async {
    final queueStorage = _DelayedFirstReplicationQueueStorage();
    final container = _buildContainer(queueStorage: queueStorage);
    addTearDown(container.dispose);
    final notifier = container.read(replicationQueueNotifierProvider.notifier);
    final firstTask = ReplicationTask.create(prompt: 'first');
    final secondTask = ReplicationTask.create(prompt: 'second');

    final firstWrite = notifier.add(firstTask);
    await queueStorage.firstWriteStarted.future;
    final secondWrite = notifier.add(secondTask);
    expect(queueStorage.saveInvocationCount, 1);

    queueStorage.releaseFirstWrite.complete();
    expect(await firstWrite, isTrue);
    expect(await secondWrite, isTrue);
    expect(queueStorage.tasks.map((task) => task.id), [
      firstTask.id,
      secondTask.id,
    ]);
  });

  test(
    'clear waits for an in-flight save and remains the final state',
    () async {
      final queueStorage = _DelayedFirstReplicationQueueStorage();
      final container = _buildContainer(queueStorage: queueStorage);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );

      final addFuture = notifier.add(ReplicationTask.create(prompt: 'stale'));
      await queueStorage.firstWriteStarted.future;
      final clearFuture = notifier.clear();
      queueStorage.releaseFirstWrite.complete();

      await addFuture;
      await clearFuture;
      expect(queueStorage.tasks, isEmpty);
      expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
    },
  );

  test('editing a task keeps its generation snapshot prompt in sync', () async {
    final container = _buildContainer();
    addTearDown(container.dispose);
    final notifier = container.read(replicationQueueNotifierProvider.notifier);
    final task = ReplicationTask.create(
      prompt: 'before',
      generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
        const ImageParams(prompt: 'before', strength: 0.37),
      ),
    );
    await notifier.add(task);

    expect(await notifier.updateTask(task.copyWith(prompt: 'after')), isTrue);

    final updated = container
        .read(replicationQueueNotifierProvider)
        .tasks
        .single;
    final params = await ReplicationTaskGenerationSnapshot.decode(
      updated.generationSnapshot!,
    );
    expect(params.prompt, 'after');
    expect(params.strength, 0.37);
  });

  test(
    'duplicating a task deep-copies its complete generation snapshot',
    () async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(
        prompt: 'copy',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          const ImageParams(prompt: 'copy', noise: 0.29),
        ),
      );
      await notifier.add(task);

      expect(await notifier.duplicateTask(task.id), isTrue);

      final tasks = container.read(replicationQueueNotifierProvider).tasks;
      expect(tasks, hasLength(2));
      expect(
        tasks.last.generationSnapshot,
        isNot(same(task.generationSnapshot)),
      );
      expect(
        (await ReplicationTaskGenerationSnapshot.decode(
          tasks.last.generationSnapshot!,
        )).noise,
        0.29,
      );
    },
  );

  group('queue changes while a large snapshot is rewritten', () {
    Future<(ProviderContainer, ReplicationQueueNotifier, ReplicationTask)>
    seed() async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(
        prompt: 'before',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(prompt: 'before', sourceImage: Uint8List(128 * 1024)),
        ),
      );
      await notifier.add(task);
      return (container, notifier, task);
    }

    test('an edit does not overwrite a task that started running', () async {
      final (container, notifier, task) = await seed();

      final update = notifier.updateTask(task.copyWith(prompt: 'after'));
      await notifier.updateTaskStatus(task.id, ReplicationTaskStatus.running);

      expect(await update, isFalse);
      final current = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      expect(current.prompt, 'before');
      expect(current.status, ReplicationTaskStatus.running);
      expect(current.generationSnapshot, task.generationSnapshot);
    });

    test('concurrent edits never interleave prompt and snapshot', () async {
      final (container, notifier, task) = await seed();

      final results = await Future.wait([
        notifier.updateTask(task.copyWith(prompt: 'first')),
        notifier.updateTask(task.copyWith(prompt: 'second')),
      ]);

      expect(results.where((updated) => updated), hasLength(1));
      final current = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      final params = await ReplicationTaskGenerationSnapshot.decode(
        current.generationSnapshot!,
      );
      expect(params.prompt, current.prompt);
      expect(current.prompt, results.first ? 'first' : 'second');
    });

    test('duplicating gives up when the queue fills meanwhile', () async {
      final (container, notifier, task) = await seed();

      final duplicated = notifier.duplicateTask(task.id);
      await notifier.addAll([
        for (var index = 1; index < kMaxQueueCapacity; index++)
          ReplicationTask.create(prompt: 'filler $index'),
      ]);

      expect(await duplicated, isFalse);
      final tasks = container.read(replicationQueueNotifierProvider).tasks;
      expect(tasks, hasLength(kMaxQueueCapacity));
      expect(tasks.where((queued) => queued.prompt == 'before'), hasLength(1));
    });

    test('duplicating gives up when the source is removed meanwhile', () async {
      final (container, notifier, task) = await seed();

      final duplicated = notifier.duplicateTask(task.id);
      await notifier.remove(task.id);

      expect(await duplicated, isFalse);
      expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
    });
  });
}

ProviderContainer _buildContainer({
  _MemoryReplicationQueueStorage? queueStorage,
  _MemoryQueueStateStorage? stateStorage,
}) {
  return ProviderContainer(
    overrides: [
      replicationQueueStorageProvider.overrideWithValue(
        queueStorage ?? _MemoryReplicationQueueStorage(),
      ),
      queueStateStorageProvider.overrideWithValue(
        stateStorage ?? _MemoryQueueStateStorage(),
      ),
    ],
  );
}

class _MemoryReplicationQueueStorage extends ReplicationQueueStorage {
  List<ReplicationTask> tasks = [];

  @override
  List<ReplicationTask> load() => List.of(tasks);

  @override
  Future<void> save(List<ReplicationTask> tasks) async {
    this.tasks = List.of(tasks);
  }

  @override
  Future<void> clear() async {
    tasks = [];
  }
}

class _DelayedFirstReplicationQueueStorage
    extends _MemoryReplicationQueueStorage {
  final Completer<void> firstWriteStarted = Completer<void>();
  final Completer<void> releaseFirstWrite = Completer<void>();
  int saveInvocationCount = 0;

  @override
  Future<void> save(List<ReplicationTask> tasks) async {
    saveInvocationCount++;
    if (saveInvocationCount == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    await super.save(tasks);
  }
}

class _MemoryQueueStateStorage extends QueueStateStorage {
  List<ReplicationTask> failedTasks = [];

  @override
  List<ReplicationTask> loadFailedTasks() => List.of(failedTasks);

  @override
  Future<void> saveFailedTasks(List<ReplicationTask> tasks) async {
    failedTasks = List.of(tasks);
  }
}
