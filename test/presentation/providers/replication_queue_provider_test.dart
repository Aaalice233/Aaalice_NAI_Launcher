import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/replication_queue_persistence.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:path/path.dart' as p;

import '../../helpers/memory_queue_blob_store.dart';

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
          replicationQueueBlobStoreProvider.overrideWithValue(
            memoryQueueBlobStore(),
          ),
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

      expect((await notifier.add(task)).queuedTaskIds, [task.id]);
      expect(
        (await notifier.duplicateTask(task.id)).result,
        DuplicateTaskStatus.added,
      );

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
    expect((await firstWrite).queuedTaskIds, [firstTask.id]);
    expect((await secondWrite).queuedTaskIds, [secondTask.id]);
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
    final blobs = MemoryStorageFileSystem();
    final container = _buildContainer(blobs: blobs);
    addTearDown(container.dispose);
    final notifier = container.read(replicationQueueNotifierProvider.notifier);
    final task = ReplicationTask.create(
      prompt: 'before',
      generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
        ImageParams(
          prompt: 'before',
          strength: 0.37,
          sourceImage: _bytes(2048, 1),
        ),
      ),
    );
    await notifier.add(task);
    final writes = blobs.writes;

    // 改写只动提示词，状态在调用返回前就已更新
    final update = notifier.updateTask(
      container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single
          .copyWith(prompt: 'after'),
    );
    expect(
      container.read(replicationQueueNotifierProvider).tasks.single.prompt,
      'after',
    );
    expect(await update, isTrue);

    final updated = container
        .read(replicationQueueNotifierProvider)
        .tasks
        .single;
    final params = await ReplicationTaskGenerationSnapshot.decode(
      updated.generationSnapshot!,
      container.read(replicationQueueBlobStoreProvider),
    );
    expect(params.prompt, 'after');
    expect(params.strength, 0.37);
    expect(params.sourceImage, _bytes(2048, 1));
    expect(blobs.writes, writes);
  });

  test('a duplicate whose index save fails is rolled back', () async {
    final queueStorage = _MemoryReplicationQueueStorage();
    final container = _buildContainer(queueStorage: queueStorage);
    addTearDown(container.dispose);
    final notifier = container.read(replicationQueueNotifierProvider.notifier);
    final task = ReplicationTask.create(prompt: 'original');
    await notifier.add(task);

    queueStorage.failNextSave = true;
    final outcome = await notifier.duplicateTask(task.id);
    expect(outcome.result, DuplicateTaskStatus.saveFailed);
    expect(outcome.enqueue?.withdrawnTaskIds, hasLength(1));
    expect(outcome.enqueue?.indexSaved, isTrue);

    expect(
      container.read(replicationQueueNotifierProvider).tasks.map((t) => t.id),
      [task.id],
    );
    expect(queueStorage.tasks.map((t) => t.id), [task.id]);
  });

  test('duplicate failures report why', () async {
    final empty = ReplicationTask.create(prompt: '  ');
    final broken = ReplicationTask.create(
      prompt: 'broken',
      generationSnapshot: const {'schemaVersion': 99},
    );
    final container = _buildContainer(
      queueStorage: _MemoryReplicationQueueStorage()..tasks = [empty, broken],
    );
    addTearDown(container.dispose);
    final notifier = container.read(replicationQueueNotifierProvider.notifier);

    expect(
      (await notifier.duplicateTask('missing')).result,
      DuplicateTaskStatus.notFound,
    );
    expect(
      (await notifier.duplicateTask(empty.id)).result,
      DuplicateTaskStatus.nothingToGenerate,
    );
    expect(
      (await notifier.duplicateTask(broken.id)).result,
      DuplicateTaskStatus.invalidSnapshot,
    );
    await notifier.addAll([
      for (var index = 2; index < kMaxQueueCapacity; index++)
        ReplicationTask.create(prompt: 'filler $index'),
    ]);
    expect(
      (await notifier.duplicateTask(broken.id)).result,
      DuplicateTaskStatus.queueFull,
    );
  });

  group('a failed enqueue save', () {
    test('counts as saved when a later save already holds the task', () async {
      final queueStorage = _GatedReplicationQueueStorage()..failSaves = 1;
      final container = _buildContainer(queueStorage: queueStorage);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(prompt: 'kept');

      queueStorage.gate = Completer<void>();
      final adding = notifier.add(task);
      final update = notifier.updateTaskStatus(
        task.id,
        ReplicationTaskStatus.running,
      );
      queueStorage.gate!.complete();

      final result = await adding;
      expect(result.outcome, EnqueueOutcome.saved);
      expect(result.queuedTaskIds, [task.id]);
      expect(await update, isTrue);
      expect(queueStorage.tasks.single.id, task.id);
      expect(
        container.read(replicationQueueNotifierProvider).tasks.single.id,
        task.id,
      );
    });

    test(
      'counts as saved when a later save held the task before it finished',
      () async {
        final queueStorage = _GatedReplicationQueueStorage()..failSaves = 1;
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final task = ReplicationTask.create(prompt: 'finished');

        // 第一次保存失败，第二次带着它落地，第三次落地时它已完成离开队列
        queueStorage.gate = Completer<void>();
        final adding = notifier.add(task);
        final running = notifier.updateTaskStatus(
          task.id,
          ReplicationTaskStatus.running,
        );
        final completing = notifier.markCompleted(task.id);
        queueStorage.gate!.complete();

        final result = await adding;
        expect(result.outcome, EnqueueOutcome.saved);
        expect(result.queuedTaskIds, [task.id]);
        expect(result.failure, isNull);
        expect(await running, isTrue);
        expect(await completing, isTrue);
        expect(queueStorage.tasks, isEmpty);
      },
    );

    test('never withdraws a task the engine already started', () async {
      final queueStorage = _GatedReplicationQueueStorage()..failSaves = 2;
      final container = _buildContainer(queueStorage: queueStorage);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final started = ReplicationTask.create(prompt: 'started');
      final waiting = ReplicationTask.create(prompt: 'waiting');

      queueStorage.gate = Completer<void>();
      final adding = notifier.addAll([started, waiting]);
      final update = expectLater(
        notifier.updateTaskStatus(started.id, ReplicationTaskStatus.running),
        throwsA(isA<ReplicationQueueWriteException>()),
      );
      queueStorage.gate!.complete();

      final result = await adding;
      await update;
      expect(result.outcome, EnqueueOutcome.startedBeforeSaved);
      expect(result.startedTaskIds, [started.id]);
      expect(result.withdrawnTaskIds, [waiting.id]);
      expect(result.queuedTaskIds, isEmpty);
      expect(result.indexSaved, isTrue);
      expect(result.failure, isA<ReplicationQueueWriteException>());
      expect(
        container.read(replicationQueueNotifierProvider).tasks.map((t) => t.id),
        [started.id],
      );
      expect(queueStorage.tasks.map((t) => t.id), [started.id]);
    });

    test(
      'reports an unsaved index when the follow-up save fails too',
      () async {
        final queueStorage = _GatedReplicationQueueStorage()..failSaves = 3;
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final started = ReplicationTask.create(prompt: 'started');

        queueStorage.gate = Completer<void>();
        final adding = notifier.add(started);
        final update = expectLater(
          notifier.updateTaskStatus(started.id, ReplicationTaskStatus.running),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        queueStorage.gate!.complete();

        final result = await adding;
        await update;
        expect(result.outcome, EnqueueOutcome.startedBeforeSaved);
        expect(result.startedTaskIds, [started.id]);
        expect(result.withdrawnTaskIds, isEmpty);
        expect(result.indexSaved, isFalse);
        expect(queueStorage.saveCount, 3);
        expect(queueStorage.tasks, isEmpty);
        expect(
          container.read(replicationQueueNotifierProvider).tasks.single.status,
          ReplicationTaskStatus.running,
        );
      },
    );

    test('reports a withdrawal whose follow-up save failed', () async {
      final queueStorage = _MemoryReplicationQueueStorage()..failSaves = 2;
      final container = _buildContainer(queueStorage: queueStorage);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(prompt: 'withdrawn');

      final result = await notifier.add(task);

      expect(result.outcome, EnqueueOutcome.withdrawn);
      expect(result.withdrawnTaskIds, [task.id]);
      expect(result.indexSaved, isFalse);
      expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
    });

    for (final (label, firstError, resaveError, expectedError) in [
      (
        'the first programming error wins over a resave programming error',
        StateError('private first error'),
        StateError('private resave error'),
        'first',
      ),
      (
        'a resave programming error propagates after a storage failure',
        const FileSystemException('private first error'),
        StateError('private resave error'),
        'resave',
      ),
      (
        'two storage failures return an unsaved index',
        const FileSystemException('private first error'),
        const FileSystemException('private resave error'),
        'none',
      ),
    ]) {
      test(label, () async {
        final firstStack = StackTrace.fromString('first save stack');
        final resaveStack = StackTrace.fromString('resave stack');
        final queueStorage = _MemoryReplicationQueueStorage()
          ..saveErrors.addAll([
            (firstError, firstStack),
            (resaveError, resaveStack),
          ]);
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final task = ReplicationTask.create(prompt: 'withdrawn');

        final adding = notifier.add(task);
        if (expectedError == 'none') {
          final result = await adding;
          expect(result.outcome, EnqueueOutcome.withdrawn);
          expect(result.withdrawnTaskIds, [task.id]);
          expect(result.indexSaved, isFalse);
          expect(result.failure?.causeType, 'FileSystemException');
          expect(result.failure?.stackTrace, same(firstStack));
        } else {
          await adding.then<void>(
            (_) => fail('Expected a programming error'),
            onError: (Object caught, StackTrace stackTrace) {
              expect(
                caught,
                same(expectedError == 'first' ? firstError : resaveError),
              );
              expect(
                stackTrace,
                same(expectedError == 'first' ? firstStack : resaveStack),
              );
            },
          );
        }

        expect(queueStorage.saveCount, 2);
        expect(queueStorage.saveErrors, isEmpty);
        expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
      });
    }

    for (final (label, failSaves, removalSaveFails, indexSaved) in [
      ('the removal is saved', 1, false, true),
      ('the removal save fails too', 2, true, true),
      ('all saves fail', 3, true, false),
    ]) {
      test('a task removed before any save held it is reported as removed '
          'when $label', () async {
        final queueStorage = _GatedReplicationQueueStorage()
          ..failSaves = failSaves;
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final task = ReplicationTask.create(prompt: 'removed');

        queueStorage.gate = Completer<void>();
        final adding = notifier.add(task);
        final removing = notifier.remove(task.id);
        final removed = removalSaveFails
            ? expectLater(
                removing,
                throwsA(isA<ReplicationQueueWriteException>()),
              )
            : removing.then((value) => expect(value, isTrue));
        queueStorage.gate!.complete();

        final result = await adding;
        await removed;
        expect(result.outcome, EnqueueOutcome.withdrawn);
        expect(result.removedTaskIds, [task.id]);
        expect(result.queuedTaskIds, isEmpty);
        expect(result.accepted, 1);
        expect(result.indexSaved, indexSaved);
        expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
        expect(queueStorage.tasks, isEmpty);
      });
    }

    test(
      'a task already in the failed pool is not reported as started',
      () async {
        final queueStorage = _GatedReplicationQueueStorage()..failSaves = 4;
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final task = ReplicationTask.create(prompt: 'invalid snapshot');

        // 无效快照先被标成运行中再进失败池，三次队列保存全部失败
        queueStorage.gate = Completer<void>();
        final adding = notifier.add(task);
        final running = expectLater(
          notifier.updateTaskStatus(task.id, ReplicationTaskStatus.running),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        final failing = expectLater(
          notifier.moveToFailedPool(task.id),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        queueStorage.gate!.complete();

        final result = await adding;
        await running;
        await failing;
        expect(result.outcome, EnqueueOutcome.withdrawn);
        expect(result.failedTaskIds, [task.id]);
        expect(result.startedTaskIds, isEmpty);
        expect(result.indexSaved, isFalse);
        expect(queueStorage.tasks, isEmpty);
        expect(
          container
              .read(replicationQueueNotifierProvider)
              .failedTasks
              .single
              .id,
          task.id,
        );
      },
    );

    test('a task that completed before any save held it is started', () async {
      final queueStorage = _GatedReplicationQueueStorage()..failSaves = 4;
      final container = _buildContainer(queueStorage: queueStorage);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(prompt: 'completed');

      queueStorage.gate = Completer<void>();
      final adding = notifier.add(task);
      final running = expectLater(
        notifier.updateTaskStatus(task.id, ReplicationTaskStatus.running),
        throwsA(isA<ReplicationQueueWriteException>()),
      );
      final completing = expectLater(
        notifier.markCompleted(task.id),
        throwsA(isA<ReplicationQueueWriteException>()),
      );
      queueStorage.gate!.complete();

      final result = await adding;
      await running;
      await completing;
      expect(result.outcome, EnqueueOutcome.startedBeforeSaved);
      expect(result.startedTaskIds, [task.id]);
      expect(result.indexSaved, isFalse);
      expect(queueStorage.tasks, isEmpty);
      expect(
        container
            .read(replicationQueueNotifierProvider)
            .completedTasks
            .single
            .id,
        task.id,
      );
    });

    for (final (label, putBack) in [
      (
        're-queued for a retry',
        (ReplicationQueueNotifier notifier, String id) =>
            notifier.requeueRunningTaskForRetry(id),
      ),
      (
        'reset by a stop',
        (ReplicationQueueNotifier notifier, String id) =>
            notifier.resetRunningTask(id),
      ),
    ]) {
      test('a started task $label is kept and reported as started', () async {
        final queueStorage = _GatedReplicationQueueStorage()..failSaves = 3;
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final task = ReplicationTask.create(prompt: 'put back');

        queueStorage.gate = Completer<void>();
        final adding = notifier.add(task);
        final running = expectLater(
          notifier.updateTaskStatus(task.id, ReplicationTaskStatus.running),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        final puttingBack = expectLater(
          putBack(notifier, task.id),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        queueStorage.gate!.complete();

        final result = await adding;
        await running;
        await puttingBack;
        expect(result.outcome, EnqueueOutcome.startedBeforeSaved);
        expect(result.startedTaskIds, [task.id]);
        expect(result.withdrawnTaskIds, isEmpty);
        expect(result.indexSaved, isTrue);
        final queued = container
            .read(replicationQueueNotifierProvider)
            .tasks
            .single;
        expect(queued.id, task.id);
        expect(queued.status, ReplicationTaskStatus.pending);
        expect(queueStorage.tasks.single.id, task.id);
      });
    }

    test('only tracks status changes while a settlement is open', () async {
      final queueStorage = _MemoryReplicationQueueStorage();
      final container = _buildContainer(queueStorage: queueStorage);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final earlier = ReplicationTask.create(prompt: 'earlier');
      await notifier.add(earlier);
      await notifier.updateTaskStatus(
        earlier.id,
        ReplicationTaskStatus.running,
      );
      await notifier.resetRunningTask(earlier.id);

      // 之前的状态变化不能影响这一次：同 ID 的任务若被记成离开过待执行，就不会撤回
      final task = earlier.copyWith(prompt: 'same id, new enqueue');
      expect(await notifier.remove(earlier.id), isTrue);
      queueStorage.failSaves = 1;
      final result = await notifier.add(task);

      expect(result.outcome, EnqueueOutcome.withdrawn);
      expect(result.withdrawnTaskIds, [task.id]);
    });

    test(
      'a throwing settlement does not retain history for the same ID',
      () async {
        final queueStorage = _GatedReplicationQueueStorage();
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final task = ReplicationTask.create(prompt: 'first enqueue');
        final error = StateError('private save error');
        final originalStack = StackTrace.fromString('original save stack');
        queueStorage
          ..saveErrors.add((error, originalStack))
          ..failSaves = 2
          ..gate = Completer<void>();

        final adding = notifier
            .add(task)
            .then<void>(
              (_) => fail('Expected the original save error'),
              onError: (Object caught, StackTrace stackTrace) {
                expect(caught, same(error));
                expect(stackTrace, same(originalStack));
              },
            );
        final running = expectLater(
          notifier.updateTaskStatus(task.id, ReplicationTaskStatus.running),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        final puttingBack = expectLater(
          notifier.requeueRunningTaskForRetry(task.id),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        queueStorage.gate!.complete();
        await adding;
        await running;
        await puttingBack;
        expect(await notifier.remove(task.id), isTrue);

        queueStorage.failSaves = 1;
        final result = await notifier.add(task.copyWith(prompt: 'same ID'));

        expect(result.outcome, EnqueueOutcome.withdrawn);
        expect(result.startedTaskIds, isEmpty);
        expect(result.withdrawnTaskIds, [task.id]);
        expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
      },
    );

    test(
      'concurrent batches do not share history after one is put back',
      () async {
        final queueStorage = _GatedReplicationQueueStorage()..failSaves = 6;
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final first = ReplicationTask.create(prompt: 'first batch');
        final second = ReplicationTask.create(prompt: 'second batch');
        queueStorage.gate = Completer<void>();

        final addingFirst = notifier.add(first);
        final addingSecond = notifier.add(second);
        final running = expectLater(
          notifier.updateTaskStatus(first.id, ReplicationTaskStatus.running),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        final puttingBack = expectLater(
          notifier.requeueRunningTaskForRetry(first.id),
          throwsA(isA<ReplicationQueueWriteException>()),
        );
        expect(
          container
              .read(replicationQueueNotifierProvider)
              .tasks
              .map((t) => t.id),
          [second.id, first.id],
        );
        expect(
          container
              .read(replicationQueueNotifierProvider)
              .tasks
              .every((task) => task.status == ReplicationTaskStatus.pending),
          isTrue,
        );
        queueStorage.gate!.complete();

        final results = await Future.wait([addingFirst, addingSecond]);
        await running;
        await puttingBack;

        expect(results[0].startedTaskIds, [first.id]);
        expect(results[0].withdrawnTaskIds, isEmpty);
        expect(results[1].startedTaskIds, isEmpty);
        expect(results[1].withdrawnTaskIds, [second.id]);
        expect(results.every((result) => !result.indexSaved), isTrue);
        expect(
          container.read(replicationQueueNotifierProvider).tasks.single.id,
          first.id,
        );
      },
    );

    for (final allSavesFail in [false, true]) {
      test(
        'concurrent failed enqueues track compensating saves (all fail: $allSavesFail)',
        () async {
          final queueStorage = _GatedReplicationQueueStorage()
            ..failSaves = allSavesFail ? 4 : 2;
          final container = _buildContainer(queueStorage: queueStorage);
          addTearDown(container.dispose);
          final notifier = container.read(
            replicationQueueNotifierProvider.notifier,
          );
          final first = ReplicationTask.create(prompt: 'first');
          final second = ReplicationTask.create(prompt: 'second');

          queueStorage.gate = Completer<void>();
          final addingFirst = notifier.add(first);
          final addingSecond = notifier.add(second);
          queueStorage.gate!.complete();

          final results = await Future.wait([addingFirst, addingSecond]);
          expect(results[0].withdrawnTaskIds, [first.id]);
          if (allSavesFail) {
            expect(results[1].withdrawnTaskIds, [second.id]);
            expect(results.every((result) => !result.indexSaved), isTrue);
            expect(
              container.read(replicationQueueNotifierProvider).tasks,
              isEmpty,
            );
            expect(queueStorage.tasks, isEmpty);
          } else {
            // 第一批的补写保存了第二批，第二批不能再按「未加入」撤回
            expect(results[1].queuedTaskIds, [second.id]);
            expect(results.every((result) => result.indexSaved), isTrue);
            expect(
              container.read(replicationQueueNotifierProvider).tasks.single.id,
              second.id,
            );
            expect(queueStorage.tasks.single.id, second.id);
          }
        },
      );
    }

    test(
      'a non-storage save error withdraws the batch and is rethrown',
      () async {
        final queueStorage = _MemoryReplicationQueueStorage();
        final container = _buildContainer(queueStorage: queueStorage);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final kept = ReplicationTask.create(prompt: 'kept');
        await notifier.add(kept);
        // 计算出 NaN 的参数，jsonEncode 抛出的是 Error 而不是存储异常
        final broken = ReplicationTask.create(
          prompt: 'broken',
          generationSnapshot: {
            'schemaVersion': ReplicationTaskGenerationSnapshot.schemaVersion,
            'params': {'scale': double.nan},
          },
        );
        final sibling = ReplicationTask.create(prompt: 'sibling');

        await notifier
            .addAll([broken, sibling])
            .then<void>(
              (_) => fail('Expected the original serialization error'),
              onError: (Object error, StackTrace stackTrace) {
                expect(error, isA<JsonUnsupportedObjectError>());
                expect(error, same(queueStorage.encodingError));
                expect(stackTrace, same(queueStorage.encodingStackTrace));
              },
            );

        expect(
          container
              .read(replicationQueueNotifierProvider)
              .tasks
              .map((t) => t.id),
          [kept.id],
        );
        expect(queueStorage.tasks.map((t) => t.id), [kept.id]);
        final later = ReplicationTask.create(prompt: 'later');
        expect((await notifier.add(later)).outcome, EnqueueOutcome.saved);
        expect(await notifier.remove(kept.id), isTrue);
        expect(queueStorage.tasks.map((t) => t.id), [later.id]);
      },
    );

    test(
      'a synchronous removal before the enqueue save is not counted as saved',
      () async {
        final container = _buildContainer();
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final task = ReplicationTask.create(prompt: 'removed immediately');
        Future<bool>? removing;
        final subscription = container.listen(
          replicationQueueNotifierProvider,
          (_, next) {
            if (removing == null &&
                next.tasks.any((item) => item.id == task.id)) {
              removing = notifier.remove(task.id);
            }
          },
        );
        addTearDown(subscription.close);

        final result = await notifier.add(task);
        await removing;

        expect(result.removedTaskIds, [task.id]);
        expect(result.queuedTaskIds, isEmpty);
        expect(result.failure, isNull);
      },
    );
  });

  group('write failures', () {
    test('surface as typed write errors from every write path', () async {
      final queueStorage = _MemoryReplicationQueueStorage();
      final stateStorage = _MemoryQueueStateStorage();
      final container = _buildContainer(
        queueStorage: queueStorage,
        stateStorage: stateStorage,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(prompt: 'kept');
      await notifier.add(task);
      Matcher typed(String causeType) => throwsA(
        isA<ReplicationQueueWriteException>()
            .having((error) => error.causeType, 'causeType', causeType)
            .having((error) => error.stackTrace, 'stackTrace', isNotNull)
            .having((error) => '$error', 'text', isNot(contains('injected'))),
      );

      queueStorage.failNextSave = true;
      await expectLater(
        notifier.updateTask(task.copyWith(prompt: 'edited')),
        typed('HiveError'),
      );
      queueStorage.failClear = true;
      await expectLater(notifier.clear(), typed('HiveError'));
      stateStorage.failNextSave = true;
      await expectLater(
        notifier.clearFailedTasks(),
        typed('FileSystemException'),
      );
    });

    test('a pending snapshot reaching the index stays a StateError', () async {
      final persistence = ReplicationQueuePersistence(
        queueStorage: _MemoryReplicationQueueStorage(),
        stateStorage: _MemoryQueueStateStorage(),
        blobStore: memoryQueueBlobStore(),
        liveState: () => (tasks: const [], failedTasks: const []),
      );
      final pending = ReplicationTask.create(
        prompt: 'pending',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(prompt: 'pending', sourceImage: _bytes(16, 40)),
        ),
      );

      await expectLater(persistence.saveTasks([pending]), throwsStateError);
      await expectLater(
        persistence.saveFailedTasks([pending]),
        throwsStateError,
      );
    });
  });

  test('duplicating a task shares its image files and writes none', () async {
    final blobs = MemoryStorageFileSystem();
    final container = _buildContainer(blobs: blobs);
    addTearDown(container.dispose);
    final notifier = container.read(replicationQueueNotifierProvider.notifier);
    await notifier.add(
      ReplicationTask.create(
        prompt: 'copy',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(prompt: 'copy', noise: 0.29, sourceImage: _bytes(64, 2)),
        ),
      ),
    );
    final original = container
        .read(replicationQueueNotifierProvider)
        .tasks
        .single;
    final writes = blobs.writes;

    expect(
      (await notifier.duplicateTask(original.id)).result,
      DuplicateTaskStatus.added,
    );

    final tasks = container.read(replicationQueueNotifierProvider).tasks;
    expect(tasks, hasLength(2));
    expect(
      tasks.last.generationSnapshot,
      isNot(same(original.generationSnapshot)),
    );
    expect(
      jsonEncode(tasks.last.generationSnapshot),
      jsonEncode(original.generationSnapshot),
    );
    expect(blobs.writes, writes);
    final params = await ReplicationTaskGenerationSnapshot.decode(
      tasks.last.generationSnapshot!,
      container.read(replicationQueueBlobStoreProvider),
    );
    expect(params.noise, 0.29);
    expect(params.sourceImage, _bytes(64, 2));
  });

  group('enqueue', () {
    test('stores images first; state and index only hold references', () async {
      final blobs = MemoryStorageFileSystem();
      final queueStorage = _MemoryReplicationQueueStorage();
      final container = _buildContainer(
        blobs: blobs,
        queueStorage: queueStorage,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final pending = await ReplicationTaskGenerationSnapshot.encode(
        ImageParams(prompt: 'refs', sourceImage: _bytes(512, 3)),
      );

      expect(
        (await notifier.add(
          ReplicationTask.create(prompt: 'refs', generationSnapshot: pending),
        )).queuedTaskIds,
        hasLength(1),
      );

      final state = container.read(replicationQueueNotifierProvider);
      for (final task in [...state.tasks, ...queueStorage.tasks]) {
        expect(
          ReplicationTaskGenerationSnapshot.isPending(task.generationSnapshot!),
          isFalse,
        );
      }
      expect(queueStorage.encoded, contains('"sha256"'));
      expect(blobs.files, hasLength(1));
      expect(
        await notifier.updateTask(
          state.tasks.single.copyWith(generationSnapshot: pending),
        ),
        isFalse,
      );
    });

    test('fifty identical tasks keep one set of image files', () async {
      final blobs = MemoryStorageFileSystem();
      final container = _buildContainer(blobs: blobs);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final params = ImageParams(
        prompt: 'same',
        sourceImage: _bytes(4096, 4),
        preciseReferences: [
          PreciseReference(image: _bytes(1024, 5), type: PreciseRefType.style),
        ],
      );
      final shared = await ReplicationTaskGenerationSnapshot.encode(params);

      expect(
        (await notifier.addAll([
          for (var index = 0; index < 25; index++)
            ReplicationTask.create(prompt: 'same', generationSnapshot: shared),
        ])).queuedTaskIds,
        hasLength(25),
      );
      for (var index = 0; index < 25; index++) {
        expect(
          (await notifier.add(
            ReplicationTask.create(
              prompt: 'same',
              generationSnapshot:
                  await ReplicationTaskGenerationSnapshot.encode(
                    params.copyWith(
                      sourceImage: Uint8List.fromList(params.sourceImage!),
                    ),
                  ),
            ),
          )).queuedTaskIds,
          hasLength(1),
        );
      }

      expect(container.read(replicationQueueNotifierProvider).count, 50);
      expect(blobs.files, hasLength(2));
      expect(blobs.writes, 2);
    });

    test('an image write failure leaves state and index untouched', () async {
      final blobs = MemoryStorageFileSystem()..failWrites = true;
      final queueStorage = _MemoryReplicationQueueStorage();
      final container = _buildContainer(
        blobs: blobs,
        queueStorage: queueStorage,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );

      final task = ReplicationTask.create(
        prompt: 'fails',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(prompt: 'fails', sourceImage: _bytes(32, 6)),
        ),
      );
      final result = await notifier.add(task);

      expect(result.outcome, EnqueueOutcome.withdrawn);
      expect(result.withdrawnTaskIds, [task.id]);
      expect(result.failure?.causeType, 'QueueBlobWriteException');
      expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
      expect(queueStorage.saveCount, 0);
      expect(blobs.files, isEmpty);
    });

    test('a crashed image worker is reported as a write failure', () async {
      final queueStorage = _MemoryReplicationQueueStorage();
      final container = _buildContainer(
        queueStorage: queueStorage,
        store: ReplicationQueueBlobStore(
          resolveDirectory: () async => memoryQueueBlobDirectory,
          fileSystem: MemoryStorageFileSystem(),
          worker: <T>(FutureOr<T> Function() task, {String? debugName}) async =>
              throw RemoteError('out of memory', ''),
        ),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(
        prompt: 'crashed',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(prompt: 'crashed', sourceImage: _bytes(32, 8)),
        ),
      );

      final result = await notifier.add(task);

      expect(result.outcome, EnqueueOutcome.withdrawn);
      expect(result.withdrawnTaskIds, [task.id]);
      expect(result.failure?.causeType, 'QueueBlobWriteException');
      expect(result.failure?.causeDetail, contains('RemoteError'));
      expect('${result.failure}', isNot(contains('out of memory')));
      expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
      expect(queueStorage.saveCount, 0);
    });

    test(
      'an index save failure rolls the task back and frees its images',
      () async {
        final blobs = MemoryStorageFileSystem();
        final queueStorage = _MemoryReplicationQueueStorage()
          ..failNextSave = true;
        final container = _buildContainer(
          blobs: blobs,
          queueStorage: queueStorage,
        );
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final store = container.read(replicationQueueBlobStoreProvider);

        final result = await notifier.add(
          ReplicationTask.create(
            prompt: 'rolled back',
            generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
              ImageParams(prompt: 'rolled back', sourceImage: _bytes(32, 7)),
            ),
          ),
        );
        await store.idle;

        expect(result.outcome, EnqueueOutcome.withdrawn);
        expect(result.indexSaved, isTrue);

        expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
        expect(queueStorage.tasks, isEmpty);
        expect(queueStorage.saveCount, 2);
        expect(blobs.files, isEmpty);
      },
    );

    test('clearing during an image write withdraws the batch', () async {
      final blobs = MemoryStorageFileSystem();
      final releaseWrite = Completer<void>();
      var writeStarted = false;
      final store = ReplicationQueueBlobStore(
        resolveDirectory: () async => memoryQueueBlobDirectory,
        fileSystem: blobs,
        worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
          if (debugName == 'QueueBlobStore.put') {
            writeStarted = true;
            await releaseWrite.future;
          }
          return task();
        },
      );
      final queueStorage = _MemoryReplicationQueueStorage();
      final container = _buildContainer(
        store: store,
        queueStorage: queueStorage,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      await notifier.add(ReplicationTask.create(prompt: 'already queued'));
      final imageTask = ReplicationTask.create(
        prompt: 'image',
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(prompt: 'image', sourceImage: _bytes(32, 9)),
        ),
      );
      final textTask = ReplicationTask.create(prompt: 'text');

      final adding = notifier.addAll([imageTask, textTask]);
      late final EnqueueResult result;
      try {
        await pumpEventQueue(times: 1);
        expect(writeStarted, isTrue);
        await notifier.clear();
      } finally {
        releaseWrite.complete();
        result = await adding;
        await store.idle;
      }

      expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
      expect(queueStorage.tasks, isEmpty);
      expect(result.outcome, EnqueueOutcome.withdrawn);
      expect(result.withdrawnTaskIds, [imageTask.id, textTask.id]);
      expect(result.indexSaved, isTrue);
      expect(result.failure, isNull);
      expect(blobs.writes, 1);
      expect(blobs.files, isEmpty);
    });

    test(
      'a queue filled while images are stored only takes what fits',
      () async {
        final blobs = MemoryStorageFileSystem();
        final hashing = Completer<void>();
        final release = Completer<void>();
        final store = ReplicationQueueBlobStore(
          resolveDirectory: () async => memoryQueueBlobDirectory,
          fileSystem: blobs,
          worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
            if (debugName == 'QueueBlobStore.put' && !hashing.isCompleted) {
              hashing.complete();
              await release.future;
            }
            return task();
          },
        );
        final container = _buildContainer(store: store);
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );

        final adding = notifier.add(
          ReplicationTask.create(
            prompt: 'late',
            generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
              ImageParams(prompt: 'late', sourceImage: _bytes(32, 8)),
            ),
          ),
        );
        await hashing.future;
        await notifier.addAll([
          for (var index = 0; index < kMaxQueueCapacity; index++)
            ReplicationTask.create(prompt: 'filler $index'),
        ]);
        release.complete();

        final result = await adding;
        expect(result.outcome, EnqueueOutcome.saved);
        expect(result.accepted, 0);
        await store.idle;
        final tasks = container.read(replicationQueueNotifierProvider).tasks;
        expect(tasks, hasLength(kMaxQueueCapacity));
        expect(tasks.where((task) => task.prompt == 'late'), isEmpty);
        expect(blobs.files, isEmpty);
      },
    );
  });

  group('image file collection', () {
    Future<ReplicationTask> imageTask(String prompt, int seed) async =>
        ReplicationTask.create(
          prompt: prompt,
          generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
            ImageParams(prompt: prompt, sourceImage: _bytes(256, seed)),
          ),
        );

    test('removed and completed tasks release their images', () async {
      final blobs = MemoryStorageFileSystem();
      final container = _buildContainer(blobs: blobs);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final store = container.read(replicationQueueBlobStoreProvider);
      await notifier.addAll([
        await imageTask('removed', 10),
        await imageTask('completed', 11),
        await imageTask('kept', 12),
      ]);
      final tasks = container.read(replicationQueueNotifierProvider).tasks;
      expect(blobs.files, hasLength(3));

      await notifier.remove(tasks[0].id);
      await notifier.updateTaskStatus(
        tasks[1].id,
        ReplicationTaskStatus.running,
      );
      await notifier.markCompleted(tasks[1].id);
      await store.idle;

      expect(_storedDigests(blobs), _digestsOf([tasks[2]]));
      final completed = container
          .read(replicationQueueNotifierProvider)
          .completedTasks
          .single;
      expect(
        ReplicationTaskGenerationSnapshot.describe(
          completed.generationSnapshot!,
        ),
        containsPair('has_source_image', true),
      );
    });

    test('failed pool references keep their images', () async {
      final blobs = MemoryStorageFileSystem();
      final container = _buildContainer(blobs: blobs);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final store = container.read(replicationQueueBlobStoreProvider);
      await notifier.addAll([
        await imageTask('failed', 13),
        await imageTask('removed', 14),
      ]);
      final tasks = container.read(replicationQueueNotifierProvider).tasks;

      await notifier.moveToFailedPool(tasks[0].id);
      await notifier.remove(tasks[1].id);
      await store.idle;
      expect(_storedDigests(blobs), _digestsOf([tasks[0]]));

      await notifier.clearFailedTasks();
      await store.idle;
      expect(blobs.files, isEmpty);
    });

    test(
      'an index save in flight keeps the images it may still hold',
      () async {
        final blobs = MemoryStorageFileSystem();
        final queueStorage = _GatedReplicationQueueStorage();
        final failedTask = (await _internedTask(
          blobs,
          await imageTask('failed', 15),
        )).copyWith(status: ReplicationTaskStatus.failed);
        final container = _buildContainer(
          blobs: blobs,
          queueStorage: queueStorage,
          stateStorage: _MemoryQueueStateStorage()..failedTasks = [failedTask],
        );
        addTearDown(container.dispose);
        final notifier = container.read(
          replicationQueueNotifierProvider.notifier,
        );
        final store = container.read(replicationQueueBlobStoreProvider);
        await notifier.add(await imageTask('queued', 16));
        final queued = container
            .read(replicationQueueNotifierProvider)
            .tasks
            .single;

        queueStorage.gate = Completer<void>();
        final removing = notifier.remove(queued.id);
        // 失败池清空触发的清扫发生在队列索引落地之前
        await notifier.clearFailedTasks();
        await store.idle;
        expect(_storedDigests(blobs), _digestsOf([queued]));

        queueStorage.gate!.complete();
        expect(await removing, isTrue);
        await store.idle;
        expect(blobs.files, isEmpty);
      },
    );

    test('re-queueing for retry moves the task in one save', () async {
      final queueStorage = _MemoryReplicationQueueStorage();
      final container = _buildContainer(queueStorage: queueStorage);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final retried = ReplicationTask.create(prompt: 'retry');
      final next = ReplicationTask.create(prompt: 'next');
      await notifier.addAll([retried, next]);
      await notifier.updateTaskStatus(
        retried.id,
        ReplicationTaskStatus.running,
        errorMessage: 'flaky',
      );
      final saves = queueStorage.saveCount;

      expect(await notifier.requeueRunningTaskForRetry(retried.id), isTrue);
      expect(await notifier.requeueRunningTaskForRetry(next.id), isFalse);

      final tasks = container.read(replicationQueueNotifierProvider).tasks;
      expect(tasks.map((task) => task.id), [next.id, retried.id]);
      expect(tasks.last.status, ReplicationTaskStatus.pending);
      expect(tasks.last.errorMessage, isNull);
      expect(tasks.last.retryCount, 0);
      expect(tasks.last.startedAt, isNull);
      expect(queueStorage.saveCount, saves + 1);
      expect(queueStorage.tasks.map((task) => task.id), [next.id, retried.id]);
    });

    test('a failed re-queue save keeps the task and its images', () async {
      final blobs = MemoryStorageFileSystem();
      final queueStorage = _MemoryReplicationQueueStorage();
      final container = _buildContainer(
        blobs: blobs,
        queueStorage: queueStorage,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final store = container.read(replicationQueueBlobStoreProvider);
      await notifier.addAll([
        await imageTask('retry', 17),
        await imageTask('dropped', 19),
      ]);
      final [task, dropped] = container
          .read(replicationQueueNotifierProvider)
          .tasks;
      await notifier.updateTaskStatus(task.id, ReplicationTaskStatus.running);

      queueStorage.failNextSave = true;
      await expectLater(
        notifier.requeueRunningTaskForRetry(task.id),
        throwsA(isA<ReplicationQueueWriteException>()),
      );
      // 删掉另一个任务触发一次清扫
      expect(await notifier.remove(dropped.id), isTrue);
      await store.idle;

      final remaining = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      expect(remaining.id, task.id);
      expect(remaining.status, ReplicationTaskStatus.pending);
      expect(_storedDigests(blobs), _digestsOf([task]));
    });

    test('a sweep at any point of a re-queue keeps its images', () async {
      final blobs = MemoryStorageFileSystem();
      final queueStorage = _GatedReplicationQueueStorage();
      final store = memoryQueueBlobStore(blobs);
      final container = _buildContainer(
        store: store,
        queueStorage: queueStorage,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      await notifier.add(await imageTask('retry', 18));
      final task = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      await notifier.updateTaskStatus(task.id, ReplicationTaskStatus.running);
      final orphan = (await store.put([_bytes(32, 99)]))..release();

      // 重新入队的状态更新同步发生在清扫开始列目录之前；清扫在列目录末尾停住，
      // 放行时重新入队的保存仍未落地
      blobs.listGate = Completer<void>();
      final sweep = store.collect(
        () => {
          for (final queued
              in container.read(replicationQueueNotifierProvider).tasks)
            ...ReplicationTaskGenerationSnapshot.blobDigests(
              queued.generationSnapshot,
            ),
        },
      );
      queueStorage.gate = Completer<void>();
      final requeue = notifier.requeueRunningTaskForRetry(task.id);
      blobs.listGate!.complete();
      expect(await sweep, 1);
      queueStorage.gate!.complete();
      expect(await requeue, isTrue);
      await store.idle;

      expect(_storedDigests(blobs), _digestsOf([task]));
      expect(_storedDigests(blobs), isNot(contains(orphan.refs.single.sha256)));
    });
  });

  group('sweeps are skipped when roots are uncertain', () {
    Future<(MemoryStorageFileSystem, ProviderContainer)> seeded({
      _MemoryReplicationQueueStorage? queueStorage,
      _MemoryQueueStateStorage? stateStorage,
    }) async {
      final blobs = MemoryStorageFileSystem();
      final container = _buildContainer(
        blobs: blobs,
        queueStorage: queueStorage,
        stateStorage: stateStorage,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      await notifier.add(
        ReplicationTask.create(
          prompt: 'dropped',
          generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
            ImageParams(prompt: 'dropped', sourceImage: _bytes(40, 50)),
          ),
        ),
      );
      final dropped = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .last;
      await notifier.remove(dropped.id);
      await container.read(replicationQueueBlobStoreProvider).idle;
      return (blobs, container);
    }

    test('an unreadable failed pool keeps every image', () async {
      final (blobs, _) = await seeded(
        stateStorage: _MemoryQueueStateStorage()..unreadable = true,
      );

      expect(blobs.files, hasLength(1));
    });

    test('a snapshot from a newer version keeps every image', () async {
      final newer = ReplicationTask.create(
        prompt: 'newer',
        generationSnapshot: const {'schemaVersion': 3},
      );
      final (blobs, _) = await seeded(
        queueStorage: _MemoryReplicationQueueStorage()..tasks = [newer],
      );

      expect(blobs.files, hasLength(1));
    });

    test('references in unknown slots count as roots', () async {
      final blobs = MemoryStorageFileSystem();
      final store = memoryQueueBlobStore(blobs);
      final kept = (await store.put([_bytes(24, 51)]))..release();
      final future = ReplicationTask.create(
        prompt: 'future slot',
        generationSnapshot: {
          'schemaVersion': ReplicationTaskGenerationSnapshot.schemaVersion,
          'params': const ImageParams(prompt: 'future slot').toJson(),
          'laterSlots': [
            {'image': kept.refs.single.toJson()},
          ],
        },
      );
      final container = _buildContainer(
        store: store,
        queueStorage: _MemoryReplicationQueueStorage()..tasks = [future],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      await notifier.add(
        ReplicationTask.create(
          prompt: 'dropped',
          generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
            ImageParams(prompt: 'dropped', sourceImage: _bytes(40, 52)),
          ),
        ),
      );
      await notifier.remove(
        container.read(replicationQueueNotifierProvider).tasks.last.id,
      );
      await store.idle;

      expect(_storedDigests(blobs), {kept.refs.single.sha256});
    });
  });

  group('index size', () {
    setUp(() async {
      Hive.init(Directory.systemTemp.path);
      await Hive.openBox<String>(
        StorageKeys.replicationQueueBox,
        bytes: Uint8List(0),
      );
      await Hive.openBox<String>(
        StorageKeys.queueExecutionStateBox,
        bytes: Uint8List(0),
      );
    });

    tearDown(() async {
      await Hive.box<String>(StorageKeys.replicationQueueBox).close();
      await Hive.box<String>(StorageKeys.queueExecutionStateBox).close();
    });

    Future<(String, MemoryStorageFileSystem, ProviderContainer)> savedIndex(
      int imageBytes,
    ) async {
      final blobs = MemoryStorageFileSystem();
      final container = ProviderContainer(
        overrides: [
          replicationQueueBlobStoreProvider.overrideWithValue(
            memoryQueueBlobStore(blobs),
          ),
        ],
      );
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask(
        id: 'fixed-id',
        prompt: 'size',
        createdAt: DateTime.utc(2026, 11, 1),
        generationSnapshot: await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(
            prompt: 'size',
            sourceImage: _bytes(imageBytes, 20),
            maskImage: _bytes(imageBytes, 21),
            vibeReferencesV4: [
              VibeReference(
                displayName: 'vibe',
                vibeEncoding: '',
                rawImageData: _bytes(imageBytes, 22),
              ),
            ],
            preciseReferences: [
              PreciseReference(
                image: _bytes(imageBytes, 23),
                type: PreciseRefType.character,
              ),
            ],
          ),
        ),
      );
      await notifier.add(task);
      final index = Hive.box<String>(
        StorageKeys.replicationQueueBox,
      ).get(StorageKeys.replicationQueueData)!;
      return (index, blobs, container);
    }

    test('does not grow with image size', () async {
      final (small, _, smallContainer) = await savedIndex(1024);
      smallContainer.dispose();
      await Hive.box<String>(StorageKeys.replicationQueueBox).clear();
      final (large, _, largeContainer) = await savedIndex(2 * 1024 * 1024);
      largeContainer.dispose();

      // 只有四个 length 字段从 4 位数变成 7 位数
      expect(utf8.encode(large).length - utf8.encode(small).length, 4 * 3);
      expect(utf8.encode(large).length, lessThan(16 * 1024));
    });

    test('status changes rewrite the index without touching images', () async {
      final (_, blobs, container) = await savedIndex(64 * 1024);
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final writes = blobs.writes;

      await notifier.updateTaskStatus(
        'fixed-id',
        ReplicationTaskStatus.running,
      );
      await notifier.resetRunningTask('fixed-id');
      await notifier.pinToTop('fixed-id');
      await container.read(replicationQueueBlobStoreProvider).idle;

      expect(blobs.writes, writes);
      expect(blobs.deletes, 0);
    });
  });
}

Uint8List _bytes(int length, int seed) => Uint8List.fromList([
  for (var index = 0; index < length; index++) (index * 31 + seed) & 0xff,
]);

Future<ReplicationTask> _internedTask(
  MemoryStorageFileSystem blobs,
  ReplicationTask task,
) async {
  final interned = await ReplicationTaskGenerationSnapshot.intern([
    task.generationSnapshot,
  ], memoryQueueBlobStore(blobs));
  interned.release();
  return task.copyWith(generationSnapshot: interned.snapshots.single);
}

Set<String> _storedDigests(MemoryStorageFileSystem blobs) => {
  for (final path in blobs.files.keys) p.basename(path),
};

Set<String> _digestsOf(List<ReplicationTask> tasks) => {
  for (final task in tasks)
    ...ReplicationTaskGenerationSnapshot.blobDigests(task.generationSnapshot!),
};

ProviderContainer _buildContainer({
  _MemoryReplicationQueueStorage? queueStorage,
  _MemoryQueueStateStorage? stateStorage,
  MemoryStorageFileSystem? blobs,
  ReplicationQueueBlobStore? store,
}) {
  return ProviderContainer(
    overrides: [
      replicationQueueStorageProvider.overrideWithValue(
        queueStorage ?? _MemoryReplicationQueueStorage(),
      ),
      queueStateStorageProvider.overrideWithValue(
        stateStorage ?? _MemoryQueueStateStorage(),
      ),
      replicationQueueBlobStoreProvider.overrideWithValue(
        store ?? memoryQueueBlobStore(blobs),
      ),
    ],
  );
}

class _MemoryReplicationQueueStorage extends ReplicationQueueStorage {
  List<ReplicationTask> tasks = [];
  String encoded = '';
  int saveCount = 0;
  int failSaves = 0;
  bool failClear = false;
  Object? encodingError;
  StackTrace? encodingStackTrace;
  final List<(Object, StackTrace)> saveErrors = [];

  set failNextSave(bool fail) => failSaves = fail ? 1 : 0;

  @override
  List<ReplicationTask> load() => List.of(tasks);

  @override
  Future<void> save(List<ReplicationTask> tasks) async {
    saveCount++;
    if (saveErrors.isNotEmpty) {
      final (error, stackTrace) = saveErrors.removeAt(0);
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (failSaves > 0) {
      failSaves--;
      throw HiveError('injected index failure');
    }
    ReplicationTaskGenerationSnapshot.checkPersistable(
      tasks.map((task) => task.generationSnapshot),
    );
    try {
      encoded = jsonEncode(ReplicationTaskList(tasks: tasks).toJson());
    } on JsonUnsupportedObjectError catch (error, stackTrace) {
      encodingError = error;
      encodingStackTrace = stackTrace;
      rethrow;
    }
    this.tasks = List.of(tasks);
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      failClear = false;
      throw HiveError('injected clear failure');
    }
    tasks = [];
  }
}

class _GatedReplicationQueueStorage extends _MemoryReplicationQueueStorage {
  Completer<void>? gate;

  @override
  Future<void> save(List<ReplicationTask> tasks) async {
    await gate?.future;
    await super.save(tasks);
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
  bool unreadable = false;
  bool failNextSave = false;

  @override
  bool get lastFailedTasksLoadUnreadable => unreadable;

  @override
  List<ReplicationTask> loadFailedTasks() => List.of(failedTasks);

  @override
  Future<void> saveFailedTasks(List<ReplicationTask> tasks) async {
    if (failNextSave) {
      failNextSave = false;
      throw const FileSystemException('injected failed pool failure');
    }
    ReplicationTaskGenerationSnapshot.checkPersistable(
      tasks.map((task) => task.generationSnapshot),
    );
    failedTasks = List.of(tasks);
  }
}
