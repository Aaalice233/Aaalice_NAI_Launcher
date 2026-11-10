import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart' show HiveError;
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/core/utils/focused_inpaint_input_exception.dart';
import 'package:nai_launcher/core/utils/inpaint_mask_utils.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageGenerationAction, ImageParams;
import 'package:nai_launcher/data/models/queue/failure_handling_strategy.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

import '../../helpers/memory_queue_blob_store.dart';
import '../../helpers/queue_execution_harness.dart';

void main() {
  const existingCharacter = CharacterPrompt(
    id: 'existing-character',
    name: 'Existing',
    prompt: 'existing prompt',
  );

  ProviderContainer buildContainer(
    ReplicationTask task, {
    List<CharacterPrompt> initialCharacters = const [existingCharacter],
  }) {
    return ProviderContainer(
      overrides: [
        replicationQueueStorageProvider.overrideWithValue(
          MemoryReplicationQueueStorage(),
        ),
        queueStateStorageProvider.overrideWithValue(MemoryQueueStateStorage()),
        _blobStoreOverride,
        notificationSettingsNotifierProvider.overrideWith(
          DisabledNotificationSettingsNotifier.new,
        ),
        replicationQueueNotifierProvider.overrideWith(
          () => TestReplicationQueueNotifier([task]),
        ),
        queueExecutionNotifierProvider.overrideWith(
          TestQueueExecutionNotifier.new,
        ),
        generationParamsNotifierProvider.overrideWith(
          QueueTestGenerationParamsNotifier.new,
        ),
        characterPromptNotifierProvider.overrideWith(
          () => TestCharacterPromptNotifier(initialCharacters),
        ),
      ],
    );
  }

  for (final status in [AuthStatus.unauthenticated, AuthStatus.loading]) {
    test('队列在 $status 时保持任务和执行状态不变', () async {
      final task = ReplicationTask.create(prompt: 'keep queued prompt');
      final container = buildQueueStartContainer(task, status);
      addTearDown(container.dispose);
      final beforeQueue = container.read(replicationQueueNotifierProvider);
      final beforeExecution = container.read(queueExecutionNotifierProvider);

      final result = await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue();

      expect(result, QueueStartResult.authRequired);
      expect(
        container.read(replicationQueueNotifierProvider),
        same(beforeQueue),
      );
      expect(
        container.read(queueExecutionNotifierProvider).status,
        beforeExecution.status,
      );
      expect(
        container.read(queueExecutionNotifierProvider).currentTaskId,
        beforeExecution.currentTaskId,
      );
      expect(
        container.read(authPromptRequestProvider)?.reason,
        AuthPromptReason.queueExecution,
      );
    });
  }

  test('登录后队列保留启动路径', () async {
    final task = ReplicationTask.create(prompt: 'queued prompt');
    final container = buildQueueStartContainer(task, AuthStatus.authenticated);
    addTearDown(container.dispose);

    final result = await container
        .read(queueExecutionNotifierProvider.notifier)
        .startQueue();

    expect(result, QueueStartResult.started);
    expect(container.read(queueExecutionNotifierProvider).isReady, isTrue);
    expect(
      container.read(queueExecutionNotifierProvider).currentTaskId,
      task.id,
    );
    expect(container.read(authPromptRequestProvider), isNull);
  });

  test('三任务在旧生成完成事件先于调用释放时仍逐项立即推进', () async {
    final tasks = [
      ReplicationTask.create(prompt: 'first'),
      ReplicationTask.create(prompt: 'second'),
      ReplicationTask.create(prompt: 'third'),
    ];
    final generation = ControlledImageGenerationNotifier();
    final container = buildControlledQueueContainer(tasks, generation);
    addTearDown(container.dispose);

    expect(
      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue(),
      QueueStartResult.started,
    );
    await generation.waitForStart(0);

    generation.complete(0);
    await container.pump();
    expect(generation.startedPrompts, ['first']);
    expect(
      container.read(queueExecutionNotifierProvider).currentTaskId,
      tasks[0].id,
    );

    generation.settle(0);
    await generation.waitForStart(1);
    expect(generation.startedPrompts, ['first', 'second']);

    generation.complete(1);
    generation.settle(1);
    await generation.waitForStart(2);
    expect(generation.startedPrompts, ['first', 'second', 'third']);

    generation.complete(2);
    generation.settle(2);
    await waitForExecutionStatus(container, QueueExecutionStatus.completed);
    for (var index = 0; index < tasks.length; index++) {
      generation.finishCleanup(index);
      await generation.waitForCleanup(index);
    }
    final execution = container.read(queueExecutionNotifierProvider);
    expect(execution.completedCount, 3);
    expect(execution.failedCount, 0);
    expect(container.read(replicationQueueNotifierProvider).tasks, isEmpty);
  });

  test('失败结算在旧调用释放后继续下一任务', () async {
    final tasks = [
      ReplicationTask.create(prompt: 'failed'),
      ReplicationTask.create(prompt: 'next'),
      ReplicationTask.create(prompt: 'last'),
    ];
    final generation = ControlledImageGenerationNotifier();
    final container = buildControlledQueueContainer(
      tasks,
      generation,
      localStorage: NoRetryLocalStorageService(),
    );
    addTearDown(container.dispose);

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await generation.waitForStart(0);
    generation.fail(0);
    await waitForCurrentTask(container, tasks[1].id);
    expect(generation.startedPrompts, ['failed']);

    generation.settle(0);
    await generation.waitForStart(1);
    expect(container.read(queueExecutionNotifierProvider).failedCount, 1);
    expect(generation.startedPrompts, ['failed', 'next']);
  });

  test('空 latent 蒙版失败不重试且原因留在失败任务上', () async {
    final tasks = [
      ReplicationTask.create(prompt: 'thin mask'),
      ReplicationTask.create(prompt: 'next'),
    ];
    final generation = ControlledImageGenerationNotifier();
    final container = buildControlledQueueContainer(
      tasks,
      generation,
      localStorage: RetryingLocalStorageService(),
    );
    addTearDown(container.dispose);

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await generation.waitForStart(0);
    generation.fail(0, message: const EmptyInpaintMaskException().toString());
    await waitForCurrentTask(container, tasks[1].id);
    generation.settle(0);
    await generation.waitForStart(1);

    expect(generation.startedPrompts, ['thin mask', 'next']);
    final failedTask = container
        .read(replicationQueueNotifierProvider)
        .failedTasks
        .single;
    expect(failedTask.id, tasks[0].id);
    expect(EmptyInpaintMaskException.matches(failedTask.errorMessage), isTrue);
    expect(container.read(queueExecutionNotifierProvider).failedCount, 1);
  });

  for (final (fixedFrame, expectedError) in [
    (false, startsWith('GENERATION_ERROR_INVALID_RESOLUTION|1664|2432|')),
    (true, equals(FocusedInpaintInputException.invalidCropCode)),
  ]) {
    final reason = fixedFrame ? '固定取景框无效' : '整图尺寸非法';
    test('$reason在预检失败后跳过重试并开始下一项', () async {
      final first = fixedFrame
          ? await _taskWithEmptyFixedFrame()
          : ReplicationTask.create(
              prompt: 'invalid dimensions',
              width: 1664,
              height: 2432,
            );
      final next = ReplicationTask.create(prompt: 'next');
      final api = _MockGenerationApi();
      final generation = _PreflightImageGenerationNotifier(first.prompt);
      final container = buildControlledQueueContainer(
        [first, next],
        generation,
        localStorage: RetryingLocalStorageService(),
        extraOverrides: [
          _blobStoreOverride,
          naiImageGenerationApiServiceProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final execution =
          container.read(queueExecutionNotifierProvider.notifier)
              as TestQueueExecutionNotifier;
      execution.setStrategyForTest(FailureHandlingStrategy.autoRetry);

      expect(await execution.startQueue(), QueueStartResult.started);
      await expectLater(
        generation.preflightResult.future,
        completion(expectedError),
      );
      await pumpEventQueue(times: 1);

      final queue = container.read(replicationQueueNotifierProvider);
      expect(queue.failedTasks, hasLength(1));
      final failed = queue.failedTasks.single;
      expect(failed.id, first.id);
      expect(failed.status, ReplicationTaskStatus.failed);
      expect(failed.errorMessage, expectedError);
      expect(queue.tasks.single.id, next.id);
      expect(queue.tasks.single.status, ReplicationTaskStatus.running);
      expect(container.read(queueExecutionNotifierProvider).failedCount, 1);
      expect(generation.startedPrompts, [next.prompt]);
      verifyZeroInteractions(api);
    });
  }

  test('旧预检拒绝不会结算已切换的队列任务', () async {
    final first = ReplicationTask.create(
      prompt: 'invalid dimensions',
      width: 1664,
      height: 2432,
    );
    final next = ReplicationTask.create(prompt: 'next');
    final releaseResult = Completer<void>();
    final generation = _PreflightImageGenerationNotifier(
      first.prompt,
      beforeReturn: releaseResult.future,
    );
    final container = buildControlledQueueContainer(
      [first, next],
      generation,
      extraOverrides: [
        naiImageGenerationApiServiceProvider.overrideWithValue(
          _MockGenerationApi(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final execution = container.read(queueExecutionNotifierProvider.notifier);
    final queue = container.read(replicationQueueNotifierProvider.notifier);

    expect(await execution.startQueue(), QueueStartResult.started);
    try {
      expect(await generation.preflightResult.future, isNotNull);
      expect(await queue.remove(first.id), isTrue);
      execution.prepareNextTask();
    } finally {
      releaseResult.complete();
    }
    await pumpEventQueue(times: 1);

    final queued = container.read(replicationQueueNotifierProvider);
    expect(queued.failedTasks, isEmpty);
    expect(queued.tasks.single.id, next.id);
    expect(queued.tasks.single.status, ReplicationTaskStatus.pending);
    expect(
      container.read(queueExecutionNotifierProvider).currentTaskId,
      next.id,
    );
  });

  test('取消会释放运行任务但不会启动下一任务', () async {
    final tasks = [
      ReplicationTask.create(prompt: 'cancelled'),
      ReplicationTask.create(prompt: 'untouched'),
      ReplicationTask.create(prompt: 'also untouched'),
    ];
    final generation = ControlledImageGenerationNotifier();
    final container = buildControlledQueueContainer(tasks, generation);
    addTearDown(container.dispose);

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await generation.waitForStart(0);
    generation.emitCancelled(0);
    await waitForExecutionStatus(container, QueueExecutionStatus.idle);
    await waitForQueueTaskStatus(
      container,
      tasks.first.id,
      ReplicationTaskStatus.pending,
    );
    generation.settle(0);

    expect(generation.startedPrompts, ['cancelled']);
    expect(
      container.read(replicationQueueNotifierProvider).tasks.first.status,
      ReplicationTaskStatus.pending,
    );
  });

  test('调用释放后慢或失败的扣费后工作不阻塞下一任务', () async {
    for (final cleanupError in [false, true]) {
      final tasks = [
        ReplicationTask.create(prompt: 'billing-$cleanupError'),
        ReplicationTask.create(prompt: 'next-$cleanupError'),
        ReplicationTask.create(prompt: 'last-$cleanupError'),
      ];
      final generation = ControlledImageGenerationNotifier();
      final container = buildControlledQueueContainer(tasks, generation);

      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue();
      await generation.waitForStart(0);
      generation.complete(0);
      generation.settle(0);
      await generation.waitForStart(1);

      expect(generation.cleanupFinished(0), isFalse);
      generation.finishCleanup(0, fail: cleanupError);
      await generation.waitForCleanup(0);
      expect(generation.cleanupFailed(0), cleanupError);
      container.dispose();
    }
  });

  test('队列执行固定为单批并应用任务参数', () async {
    final task = ReplicationTask.create(
      prompt: 'queued prompt',
      negativePrompt: 'queued negative',
      applyNegativePrompt: true,
      width: 832,
      height: 1216,
      steps: 23,
      cfgScale: 4.5,
      seed: 123,
      generationSnapshot: await _stored(
        const ImageParams(
          prompt: 'queued prompt',
          negativePrompt: 'queued negative',
          width: 832,
          height: 1216,
          steps: 23,
          scale: 4.5,
          seed: 123,
          nSamples: 4,
          strength: 0.42,
          noise: 0.17,
        ),
      ),
    );
    final capture = CapturingImageGenerationNotifier();
    final container = buildQueueStartContainer(
      task,
      AuthStatus.authenticated,
      generationNotifier: capture,
      generationParamsNotifier: BatchGenerationParamsNotifier.new,
      extraOverrides: [_blobStoreOverride],
    );
    addTearDown(container.dispose);

    expect(
      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue(),
      QueueStartResult.started,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(capture.generated, isNotNull);
    expect(capture.generated!.nSamples, 1);
    expect(capture.generated!.width, 832);
    expect(capture.generated!.height, 1216);
    expect(capture.generated!.steps, 23);
    expect(capture.generated!.scale, 4.5);
    expect(capture.generated!.seed, 123);
    expect(capture.generated!.negativePrompt, 'queued negative');
    expect(capture.generated!.strength, 0.42);
    expect(capture.generated!.noise, 0.17);
  });

  test('完整快照仍遵循任务的负向提示词开关', () async {
    final task = ReplicationTask.create(
      prompt: 'edited prompt',
      negativePrompt: 'snapshot negative',
      applyNegativePrompt: false,
      generationSnapshot: await _stored(
        const ImageParams(
          prompt: 'old prompt',
          negativePrompt: 'snapshot negative',
          strength: 0.42,
        ),
      ),
    );
    final capture = CapturingImageGenerationNotifier();
    final container = buildQueueStartContainer(
      task,
      AuthStatus.authenticated,
      generationNotifier: capture,
      generationParamsNotifier: BatchGenerationParamsNotifier.new,
      extraOverrides: [_blobStoreOverride],
    );
    addTearDown(container.dispose);

    expect(
      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue(),
      QueueStartResult.started,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(capture.generated?.prompt, 'edited prompt');
    expect(capture.generated?.negativePrompt, 'main negative');
    expect(capture.generated?.strength, 0.42);
  });

  test('引用的图片在后台读取校验后照常提交生成', () async {
    final sourceImage = Uint8List.fromList(
      List.generate(128 * 1024, (index) => index & 0xff),
    );
    final task = ReplicationTask.create(
      prompt: 'large',
      generationSnapshot: await _stored(
        ImageParams(prompt: 'large', strength: 0.42, sourceImage: sourceImage),
      ),
    );
    final capture = CapturingImageGenerationNotifier();
    final container = buildQueueStartContainer(
      task,
      AuthStatus.authenticated,
      generationNotifier: capture,
      extraOverrides: [_blobStoreOverride],
    );
    addTearDown(container.dispose);

    expect(
      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue(),
      QueueStartResult.started,
    );
    final generated = await capture.firstGeneration.future;

    expect(generated.prompt, 'large');
    expect(generated.strength, 0.42);
    expect(generated.sourceImage, sourceImage);
  });

  test('后台读取图片期间编辑当前任务时按最新快照生成', () async {
    final original = ReplicationTask.create(
      prompt: 'original',
      generationSnapshot: await _stored(
        ImageParams(
          prompt: 'original',
          strength: 0.3,
          sourceImage: Uint8List(128 * 1024),
        ),
      ),
    );
    final edited = original.copyWith(
      prompt: 'edited',
      generationSnapshot: await _stored(
        ImageParams(
          prompt: 'edited',
          strength: 0.6,
          sourceImage: Uint8List(128 * 1024),
        ),
      ),
    );
    final capture = CapturingImageGenerationNotifier();
    final container = buildQueueStartContainer(
      original,
      AuthStatus.authenticated,
      generationNotifier: capture,
      extraOverrides: [_blobStoreOverride],
    );
    addTearDown(container.dispose);
    final readGate = _readGate = Completer<void>();
    addTearDown(() {
      if (!readGate.isCompleted) readGate.complete();
      _readGate = null;
    });

    expect(
      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue(),
      QueueStartResult.started,
    );
    await pumpEventQueue();
    (container.read(replicationQueueNotifierProvider.notifier)
            as TestReplicationQueueNotifier)
        .replaceTaskForTest(edited);
    readGate.complete();
    final generated = await capture.firstGeneration.future;

    expect(generated.prompt, 'edited');
    expect(generated.strength, 0.6);
  });

  for (final strategy in FailureHandlingStrategy.values) {
    test('损坏的完整快照按 $strategy 结算且保留错误', () async {
      final snapshot = await _stored(
        const ImageParams(prompt: 'invalid snapshot'),
      );
      (snapshot['transient']
              as Map<String, dynamic>)['inpaintMaskClosingIterations'] =
          'invalid';
      final task = ReplicationTask.create(
        prompt: 'invalid snapshot',
        generationSnapshot: snapshot,
      );
      final container = buildQueueStartContainer(
        task,
        AuthStatus.authenticated,
        extraOverrides: [_blobStoreOverride],
      );
      addTearDown(container.dispose);
      final execution = container.read(queueExecutionNotifierProvider.notifier);
      (execution as TestQueueExecutionNotifier).setStrategyForTest(strategy);

      expect(await execution.startQueue(), QueueStartResult.started);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final queue = container.read(replicationQueueNotifierProvider);
      switch (strategy) {
        case FailureHandlingStrategy.autoRetry:
          expect(queue.tasks, isEmpty);
          expect(
            queue.failedTasks.single.errorMessage,
            contains('Invalid generation snapshot'),
          );
          break;
        case FailureHandlingStrategy.skip:
          expect(queue.tasks, isEmpty);
          expect(
            queue.failedTasks.single.errorMessage,
            contains('Invalid generation snapshot'),
          );
          break;
        case FailureHandlingStrategy.pauseAndWait:
          expect(queue.tasks.single.status, ReplicationTaskStatus.failed);
          expect(
            queue.tasks.single.errorMessage,
            contains('Invalid generation snapshot'),
          );
          break;
      }
      expect(container.read(queueExecutionNotifierProvider).failedCount, 1);
    });
  }

  for (final (label, damage, expected) in [
    ('缺失', (String path) => _blobFiles.files.remove(path), 'missing'),
    (
      '损坏',
      (String path) =>
          _blobFiles.files[path] = Uint8List(_blobFiles.files[path]!.length),
      'corrupt',
    ),
  ]) {
    test('引用的图片$label时进失败池并提交下一项', () async {
      final sourceImage = Uint8List.fromList(
        List.generate(4096, (index) => (index * 7 + label.length) & 0xff),
      );
      final task = ReplicationTask.create(
        prompt: 'dangling',
        generationSnapshot: await _stored(
          ImageParams(prompt: 'dangling', sourceImage: sourceImage),
        ),
      );
      final digest =
          (task.generationSnapshot!['sourceImage'] as Map)['sha256'] as String;
      damage(
        _blobFiles.files.keys.singleWhere((path) => path.endsWith(digest)),
      );
      final next = ReplicationTask.create(prompt: 'next');
      final capture = CapturingImageGenerationNotifier();
      final container = buildControlledQueueContainer(
        [task, next],
        capture,
        localStorage: RetryingLocalStorageService(),
        extraOverrides: [_blobStoreOverride],
      );
      addTearDown(container.dispose);

      expect(
        await container
            .read(queueExecutionNotifierProvider.notifier)
            .startQueue(),
        QueueStartResult.started,
      );
      await pumpEventQueue(times: 1);

      final queue = container.read(replicationQueueNotifierProvider);
      expect(queue.failedTasks.single.id, task.id);
      expect(
        queue.failedTasks.single.errorMessage,
        allOf(contains('Invalid generation snapshot'), contains(expected)),
      );
      expect(queue.tasks.single.id, next.id);
      expect(capture.firstGeneration.isCompleted, isTrue);
      expect((await capture.firstGeneration.future).prompt, next.prompt);
    });
  }

  group('暂时读不出图片', () {
    late ReplicationTask task;
    late Uint8List sourceImage;

    setUp(() async {
      sourceImage = Uint8List.fromList(
        List.generate(2048, (index) => (index * 5 + 3) & 0xff),
      );
      task = ReplicationTask.create(
        prompt: 'locked',
        generationSnapshot: await _stored(
          ImageParams(prompt: 'locked', sourceImage: sourceImage),
        ),
      );
      _failedReads = 1;
      addTearDown(() => _failedReads = 0);
    });

    test('按重试处理，之后照常提交生成', () async {
      final capture = CapturingImageGenerationNotifier();
      final container = buildQueueStartContainer(
        task,
        AuthStatus.authenticated,
        generationNotifier: capture,
        localStorage: RetryingLocalStorageService(),
        extraOverrides: [_blobStoreOverride],
      );
      addTearDown(container.dispose);

      expect(
        await container
            .read(queueExecutionNotifierProvider.notifier)
            .startQueue(),
        QueueStartResult.started,
      );
      final generated = await capture.firstGeneration.future;

      expect(generated.sourceImage, sourceImage);
      expect(_failedReads, 0);
      expect(
        container.read(replicationQueueNotifierProvider).failedTasks,
        isEmpty,
      );
    });

    test('重试用尽后按失败策略结算，不当作无效快照', () async {
      final capture = CapturingImageGenerationNotifier();
      final container = buildQueueStartContainer(
        task,
        AuthStatus.authenticated,
        generationNotifier: capture,
        localStorage: NoRetryLocalStorageService(),
        extraOverrides: [_blobStoreOverride],
      );
      addTearDown(container.dispose);
      final execution = container.read(queueExecutionNotifierProvider.notifier);
      (execution as TestQueueExecutionNotifier).setStrategyForTest(
        FailureHandlingStrategy.skip,
      );

      expect(await execution.startQueue(), QueueStartResult.started);
      await waitForExecutionStatus(container, QueueExecutionStatus.completed);

      final queue = container.read(replicationQueueNotifierProvider);
      expect(capture.generated, isNull);
      expect(queue.tasks, isEmpty);
      expect(queue.failedTasks.single.id, task.id);
      expect(
        queue.failedTasks.single.errorMessage,
        QueueBlobReadFailedException.errorCode,
      );
      expect(container.read(queueExecutionNotifierProvider).failedCount, 1);
    });

    test('暂停策略下停在失败任务上，并附带同一原因', () async {
      final capture = CapturingImageGenerationNotifier();
      final container = buildQueueStartContainer(
        task,
        AuthStatus.authenticated,
        generationNotifier: capture,
        localStorage: NoRetryLocalStorageService(),
        extraOverrides: [_blobStoreOverride],
      );
      addTearDown(container.dispose);
      final execution = container.read(queueExecutionNotifierProvider.notifier);
      (execution as TestQueueExecutionNotifier).setStrategyForTest(
        FailureHandlingStrategy.pauseAndWait,
      );

      expect(await execution.startQueue(), QueueStartResult.started);
      await waitForExecutionStatus(container, QueueExecutionStatus.paused);

      final paused = container
          .read(replicationQueueNotifierProvider)
          .tasks
          .single;
      expect(capture.generated, isNull);
      expect(paused.status, ReplicationTaskStatus.failed);
      expect(paused.errorMessage, QueueBlobReadFailedException.errorCode);
    });
  });

  test('旧任务没有角色快照时保留当前角色', () {
    final task = ReplicationTask.create(prompt: 'queued prompt');
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    expect(container.read(characterPromptNotifierProvider).characters, const [
      existingCharacter,
    ]);
    expect(
      container.read(generationParamsNotifierProvider).prompt,
      'queued prompt',
    );
  });

  test('法典队列任务显式应用负向提示词', () {
    final task = ReplicationTask.create(
      prompt: 'queued prompt',
      negativePrompt: 'lowres, bad hands',
      applyNegativePrompt: true,
    );
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    expect(
      container.read(generationParamsNotifierProvider).negativePrompt,
      'lowres, bad hands',
    );
  });

  test('显式空角色快照会清空当前角色', () {
    final task = ReplicationTask.create(
      prompt: 'queued prompt',
      characterPrompts: const [],
    );
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    expect(container.read(characterPromptNotifierProvider).characters, isEmpty);
  });

  test('显式角色快照会按 CharacterPrompt 语义替换当前角色', () {
    final snapshot = ReplicationCharacterPromptSnapshot.fromCharacterPrompt(
      const CharacterPrompt(
        id: 'source-character',
        name: 'Source',
        prompt: '1girl, red hair',
        negativePrompt: 'bad hands',
        positionMode: CharacterPositionMode.custom,
        customPosition: CharacterPosition(
          mode: CharacterPositionMode.custom,
          row: 0.2,
          column: 0.8,
        ),
        enabled: false,
      ),
    );
    final task = ReplicationTask.create(
      prompt: 'queued prompt',
      characterPrompts: [snapshot],
    );
    final container = buildContainer(task);
    addTearDown(container.dispose);

    container.read(queueExecutionNotifierProvider.notifier).prepareNextTask();

    final restored = container
        .read(characterPromptNotifierProvider)
        .characters
        .single;
    expect(restored.id, '${task.id}-character-0');
    expect(restored.name, 'Character 1');
    expect(restored.prompt, '1girl, red hair');
    expect(restored.negativePrompt, 'bad hands');
    expect(restored.enabled, isFalse);
    expect(restored.positionMode, CharacterPositionMode.custom);
    expect(restored.customPosition?.row, 0.2);
    expect(restored.customPosition?.column, 0.8);
  });

  group('等待结束后复查暂停与停止', () {
    final noRetry = ConfiguredLocalStorageService(
      retryCount: 0,
      retryIntervalSeconds: 0,
    );

    test('任务间隔内暂停后不再推进，恢复后接着跑下一条', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second', 'third'],
          taskIntervalSeconds: 2,
          localStorage: noRetry,
        ),
        (run) {
          run.completeAndSettle(0);

          run.execution.pause();
          run.elapse(const Duration(seconds: 3));
          expect(run.started, ['first']);
          expect(run.state.status, QueueExecutionStatus.paused);

          run.execution.resume();
          run.flush();
          expect(run.started, ['first', 'second']);
          expect(run.state.status, QueueExecutionStatus.running);

          run.elapse(const Duration(seconds: 3));
          expect(run.started, ['first', 'second']);
        },
      );
    });

    test('任务间隔内暂停又恢复只推进一次', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second', 'third'],
          taskIntervalSeconds: 2,
          localStorage: noRetry,
        ),
        (run) {
          run.completeAndSettle(0);

          run.execution.pause();
          run.execution.resume();
          run.flush();
          expect(run.started, ['first', 'second']);

          run.elapse(const Duration(seconds: 3));
          expect(run.started, ['first', 'second']);
          expect(run.state.status, QueueExecutionStatus.running);
          expect(run.state.currentTaskId, run.tasks[1].id);
        },
      );
    });

    test('任务间隔内停止不再推进', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          taskIntervalSeconds: 2,
          localStorage: noRetry,
        ),
        (run) {
          run.completeAndSettle(0);

          run.execution.stopExecution();
          run.elapse(const Duration(seconds: 3));
          expect(run.started, ['first']);
          expect(run.state.status, QueueExecutionStatus.idle);
        },
      );
    });

    test('失败结算期间暂停不推进下一条，恢复后继续', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['failed', 'next', 'last'],
          localStorage: noRetry,
        ),
        (run) {
          final moveGate = run.queue.moveGate = Completer<void>();
          run.generation.fail(0);
          run.flush();

          run.execution.pause();
          moveGate.complete();
          run.generation.settle(0);
          run.flush();
          expect(run.started, ['failed']);
          expect(run.state.status, QueueExecutionStatus.paused);
          expect(run.state.failedCount, 1);

          run.execution.resume();
          run.flush();
          expect(run.started, ['failed', 'next']);
          expect(run.state.status, QueueExecutionStatus.running);
        },
      );
    });

    test('失败结算期间停止不推进下一条', () {
      driveQueueRun(
        (async) =>
            QueueRun(async, prompts: ['failed', 'next'], localStorage: noRetry),
        (run) {
          final moveGate = run.queue.moveGate = Completer<void>();
          run.generation.fail(0);
          run.flush();

          run.execution.stopExecution();
          moveGate.complete();
          run.generation.settle(0);
          run.flush();
          expect(run.started, ['failed']);
          expect(run.state.status, QueueExecutionStatus.idle);
        },
      );
    });

    test('失败后暂停等待策略在期间被停止时不把队列改回暂停', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['failed', 'next'],
          strategy: FailureHandlingStrategy.pauseAndWait,
          localStorage: noRetry,
        ),
        (run) {
          final failGate = run.queue.failGate = Completer<void>();
          run.generation.fail(0);
          run.flush();

          run.execution.stopExecution();
          failGate.complete();
          run.generation.settle(0);
          run.flush();
          expect(run.started, ['failed']);
          expect(run.state.status, QueueExecutionStatus.idle);
        },
      );
    });

    test('重试等待中暂停后恢复会重新提交当前任务', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['flaky', 'next'],
          localStorage: ConfiguredLocalStorageService(
            retryCount: 3,
            retryIntervalSeconds: 1,
          ),
        ),
        (run) {
          run.generation.fail(0);
          run.generation.settle(0);
          run.flush();

          run.execution.pause();
          run.elapse(const Duration(seconds: 2));
          expect(run.started, ['flaky']);
          expect(run.state.status, QueueExecutionStatus.paused);

          run.execution.resume();
          run.flush();
          expect(run.started, ['flaky', 'flaky']);
          expect(run.state.status, QueueExecutionStatus.running);
        },
      );
    });
  });

  group('暂停期间的生成事件', () {
    ReplicationTaskStatus? taskStatus(QueueRun run, String taskId) {
      for (final task
          in run.container.read(replicationQueueNotifierProvider).tasks) {
        if (task.id == taskId) return task.status;
      }
      return null;
    }

    void pauseThenFail(QueueRun run, {String? message}) {
      run.execution.pause();
      run.flush();
      if (message == null) {
        run.generation.fail(0);
      } else {
        run.generation.fail(0, message: message);
      }
      run.generation.settle(0);
      run.elapse(const Duration(seconds: 2));
      expect(run.state.status, QueueExecutionStatus.paused);
    }

    void resumeOnce(QueueRun run, List<String> expectedStarted) {
      run.execution.resume();
      run.flush();
      expect(run.started, expectedStarted);
      expect(run.state.status, QueueExecutionStatus.running);
      run.elapse(const Duration(seconds: 3));
      expect(run.started, expectedStarted);
    }

    test('可重试的失败计入重试次数，恢复后重新提交一次', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['flaky', 'next'],
          localStorage: queueRetries(3),
        ),
        (run) {
          pauseThenFail(run);
          expect(run.state.retryCount, 1);
          expect(
            taskStatus(run, run.tasks[0].id),
            ReplicationTaskStatus.pending,
          );

          resumeOnce(run, ['flaky', 'flaky']);
        },
      );
    });

    test('重试用尽且跳过时进失败池，恢复后跑下一条', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['flaky', 'next'],
          localStorage: queueRetries(0),
        ),
        (run) {
          pauseThenFail(run);
          expect(run.state.failedCount, 1);
          expect(
            run.container
                .read(replicationQueueNotifierProvider)
                .failedTasks
                .single
                .id,
            run.tasks[0].id,
          );

          resumeOnce(run, ['flaky', 'next']);
        },
      );
    });

    test('重试用尽且自动重试时回到队尾，恢复后跑下一条', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['flaky', 'next'],
          strategy: FailureHandlingStrategy.autoRetry,
          localStorage: queueRetries(0),
        ),
        (run) {
          pauseThenFail(run);
          expect(
            run.container
                .read(replicationQueueNotifierProvider)
                .tasks
                .map((task) => task.prompt),
            ['next', 'flaky'],
          );

          resumeOnce(run, ['flaky', 'next']);
        },
      );
    });

    test('重试用尽且失败后暂停等待时标记失败，恢复后重跑该条', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['flaky', 'next'],
          strategy: FailureHandlingStrategy.pauseAndWait,
          localStorage: queueRetries(0),
        ),
        (run) {
          pauseThenFail(run);
          expect(run.state.failedCount, 1);
          expect(
            taskStatus(run, run.tasks[0].id),
            ReplicationTaskStatus.failed,
          );

          resumeOnce(run, ['flaky', 'flaky']);
        },
      );
    });

    test('确定性错误不重试直接进失败池，恢复后跑下一条', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['thin mask', 'next'],
          localStorage: queueRetries(3),
        ),
        (run) {
          pauseThenFail(
            run,
            message: const EmptyInpaintMaskException().toString(),
          );
          expect(run.state.retryCount, 0);
          expect(
            run.container
                .read(replicationQueueNotifierProvider)
                .failedTasks
                .single
                .id,
            run.tasks[0].id,
          );

          resumeOnce(run, ['thin mask', 'next']);
        },
      );
    });

    test('暂停中请求被取消时停止队列，任务改回待执行且不再恢复', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['cancelled', 'next'],
          localStorage: queueRetries(3),
        ),
        (run) {
          run.execution.pause();
          run.flush();
          run.generation.emitCancelled(0);
          run.generation.settle(0);
          run.elapse(const Duration(seconds: 2));

          expect(run.state.status, QueueExecutionStatus.idle);
          expect(run.state.currentTaskId, isNull);
          expect(
            taskStatus(run, run.tasks[0].id),
            ReplicationTaskStatus.pending,
          );

          run.execution.resume();
          run.elapse(const Duration(seconds: 2));
          expect(run.started, ['cancelled']);
          expect(run.state.status, QueueExecutionStatus.idle);
        },
      );
    });

    // 两种停下后没有队列请求在跑、但 currentTaskId 仍指着任务的状态
    final idlePauses = <String, void Function(QueueRun run)>{
      '失败后暂停等待': (run) {
        run.execution.setStrategyForTest(FailureHandlingStrategy.pauseAndWait);
        run.generation.fail(0);
        run.generation.settle(0);
        run.elapse(const Duration(seconds: 2));
        expect(taskStatus(run, run.tasks[0].id), ReplicationTaskStatus.failed);
      },
      '重试等待中被暂停': (run) {
        run.generation.fail(0);
        run.generation.settle(0);
        run.flush();
        run.execution.pause();
        run.elapse(const Duration(seconds: 2));
        expect(taskStatus(run, run.tasks[0].id), ReplicationTaskStatus.pending);
      },
    };

    for (final pauseKind in idlePauses.entries) {
      for (final outcome in ['成功', '失败', '取消']) {
        test('${pauseKind.key}后手动生成$outcome不影响队列', () {
          driveQueueRun(
            (async) => QueueRun(
              async,
              prompts: ['queued', 'next'],
              localStorage: queueRetries(pauseKind.key == '失败后暂停等待' ? 0 : 3),
            ),
            (run) {
              pauseKind.value(run);
              final before = run.state;
              expect(before.status, QueueExecutionStatus.paused);
              final queueBefore = run.container
                  .read(replicationQueueNotifierProvider)
                  .tasks
                  .map((task) => (task.id, task.status))
                  .toList();

              unawaited(
                run.generation.generate(const ImageParams(prompt: 'manual')),
              );
              run.flush();
              switch (outcome) {
                case '成功':
                  run.generation.complete(1);
                case '失败':
                  run.generation.fail(1);
                default:
                  run.generation.emitCancelled(1);
              }
              run.generation.settle(1);
              run.elapse(const Duration(seconds: 3));

              final after = run.state;
              expect(after.status, QueueExecutionStatus.paused);
              expect(after.currentTaskId, before.currentTaskId);
              expect(after.completedCount, before.completedCount);
              expect(after.failedCount, before.failedCount);
              expect(after.retryCount, before.retryCount);
              expect(
                run.container
                    .read(replicationQueueNotifierProvider)
                    .tasks
                    .map((task) => (task.id, task.status))
                    .toList(),
                queueBefore,
              );

              resumeOnce(run, ['queued', 'manual', 'queued']);
            },
          );
        });
      }
    }
    test('恢复时被手动生成占用的队列在手动生成结束后接着提交', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['queued', 'next'],
          strategy: FailureHandlingStrategy.pauseAndWait,
          localStorage: queueRetries(0),
        ),
        (run) {
          run.generation.fail(0);
          run.generation.settle(0);
          run.elapse(const Duration(seconds: 2));
          expect(run.state.status, QueueExecutionStatus.paused);

          unawaited(
            run.generation.generate(const ImageParams(prompt: 'manual')),
          );
          run.flush();
          run.execution.resume();
          run.flush();
          expect(run.state.status, QueueExecutionStatus.ready);
          expect(run.started, ['queued', 'manual']);

          run.generation.complete(1);
          run.generation.settle(1);
          run.flush();
          expect(run.started, ['queued', 'manual', 'queued']);
          expect(run.state.status, QueueExecutionStatus.running);
          expect(run.state.completedCount, 0);
        },
      );
    });

    test('提交后进入生成前被暂停，完成后停在暂停且任务已结算，恢复后跑下一条', () {
      driveQueueRun(
        (async) {
          final run = QueueRun(
            async,
            prompts: ['first', 'second'],
            localStorage: queueRetries(0),
            autoStart: false,
          );
          run.generation.preparationGate = Completer<void>();
          run.execution.startQueue();
          run.flush();
          return run;
        },
        (run) {
          expect(run.started, isEmpty);
          run.execution.pause();
          run.flush();

          run.generation.preparationGate!.complete();
          run.flush();
          expect(run.started, ['first']);
          expect(
            taskStatus(run, run.tasks[0].id),
            ReplicationTaskStatus.running,
          );

          run.completeAndSettle(0);
          run.elapse(const Duration(seconds: 2));
          expect(run.state.status, QueueExecutionStatus.paused);
          expect(run.state.completedCount, 1);
          expect(taskStatus(run, run.tasks[0].id), isNull);
          expect(
            taskStatus(run, run.tasks[1].id),
            ReplicationTaskStatus.pending,
          );

          resumeOnce(run, ['first', 'second']);
        },
      );
    });
  });

  group('上一次生成留下的终态', () {
    void finish(QueueRun run, int index, String outcome) {
      switch (outcome) {
        case '成功':
          run.generation.complete(index);
        case '失败':
          run.generation.fail(index);
        default:
          run.generation.emitCancelled(index);
      }
      run.generation.settle(index);
      run.elapse(const Duration(seconds: 2));
    }

    for (final outcome in ['取消', '失败', '成功']) {
      test('手动生成$outcome后开始队列，队列正常提交并结算且只生成一次', () {
        driveQueueRun(
          (async) => QueueRun(
            async,
            prompts: ['first', 'second'],
            localStorage: queueRetries(0),
            autoStart: false,
          ),
          (run) {
            unawaited(
              run.generation.generate(const ImageParams(prompt: 'manual')),
            );
            run.flush();
            finish(run, 0, outcome);

            run.execution.startQueue();
            run.flush();
            expect(run.started, ['manual', 'first']);
            expect(run.state.status, QueueExecutionStatus.running);

            run.completeAndSettle(1);
            expect(run.state.completedCount, 1);
            expect(run.started, ['manual', 'first', 'second']);
            expect(run.state.currentTaskId, run.tasks[1].id);
          },
        );
      });
    }

    test('队列自己的生成被取消后重新开始，队列正常提交并结算', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          localStorage: queueRetries(0),
        ),
        (run) {
          finish(run, 0, '取消');
          expect(run.state.status, QueueExecutionStatus.idle);

          run.execution.startQueue();
          run.flush();
          expect(run.started, ['first', 'first']);
          expect(run.state.status, QueueExecutionStatus.running);

          run.completeAndSettle(1);
          expect(run.state.completedCount, 1);
          expect(run.started, ['first', 'first', 'second']);
        },
      );
    });

    test('失败后暂停等待的队列恢复时带着上一次的失败提交，只生成一次', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          strategy: FailureHandlingStrategy.pauseAndWait,
          localStorage: queueRetries(0),
        ),
        (run) {
          finish(run, 0, '失败');
          expect(run.state.status, QueueExecutionStatus.paused);

          run.execution.resume();
          run.flush();
          expect(run.started, ['first', 'first']);
          expect(run.state.status, QueueExecutionStatus.running);

          run.completeAndSettle(1);
          expect(run.state.completedCount, 1);
          expect(run.started, ['first', 'first', 'second']);
        },
      );
    });
  });

  test('快照解码期间被别处的生成占用，占用结束后队列补一次提交', () async {
    final task = ReplicationTask.create(
      prompt: 'snapshot',
      generationSnapshot: await _stored(
        ImageParams(prompt: 'snapshot', sourceImage: Uint8List(128 * 1024)),
      ),
    );
    final generation = ControlledImageGenerationNotifier();
    final container = buildControlledQueueContainer(
      [task],
      generation,
      extraOverrides: [_blobStoreOverride],
    );
    addTearDown(container.dispose);
    final readGate = _readGate = Completer<void>();
    addTearDown(() {
      if (!readGate.isCompleted) readGate.complete();
      _readGate = null;
    });

    expect(
      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue(),
      QueueStartResult.started,
    );
    await pumpEventQueue();
    unawaited(generation.generate(const ImageParams(prompt: 'manual')));
    await generation.waitForStart(0);
    readGate.complete();
    await pumpEventQueue();
    expect(generation.startedPrompts, ['manual']);
    expect(
      container.read(queueExecutionNotifierProvider).status,
      QueueExecutionStatus.ready,
    );

    generation.complete(0);
    generation.settle(0);
    await generation.waitForStart(1).timeout(const Duration(seconds: 5));
    expect(generation.startedPrompts, ['manual', 'snapshot']);
  });

  group('生成在准备阶段就结束的队列提交', () {
    QueueRun startWith(
      FakeAsync async, {
      required GenerationOutcome? Function(QueueRun run) endPreparation,
      int retries = 3,
      List<Override> extraOverrides = const [],
    }) {
      final run = QueueRun(
        async,
        prompts: ['first', 'second'],
        localStorage: queueRetries(retries),
        autoStart: false,
        extraOverrides: extraOverrides,
      );
      run.generation.endNextPreparation = () => endPreparation(run);
      run.execution.startQueue();
      run.flush();
      return run;
    }

    test('确定性的本地拒绝直接进失败池并跑下一条', () {
      driveQueueRun(
        (async) => startWith(
          async,
          endPreparation: (run) => run.generation.rejectPreparation(
            const EmptyInpaintMaskException().toString(),
          ),
        ),
        (run) {
          expect(
            run.container
                .read(replicationQueueNotifierProvider)
                .failedTasks
                .single
                .id,
            run.tasks[0].id,
          );
          expect(run.started, ['second']);
        },
      );
    });

    const localRejections = {
      '分辨率不合规': 'GENERATION_ERROR_INVALID_RESOLUTION|513|768|512|768',
      '不支持的随机模型': 'GENERATION_ERROR_UNSUPPORTED_RANDOM_MODEL|future-model',
    };
    for (final rejection in localRejections.entries) {
      for (final strategy in FailureHandlingStrategy.values) {
        test('${rejection.key}按确定性错误结算，$strategy 下不重试', () {
          driveQueueRun(
            (async) {
              final run = QueueRun(
                async,
                prompts: ['first', 'second'],
                strategy: strategy,
                localStorage: queueRetries(3),
                autoStart: false,
              );
              run.generation.endNextPreparation = () =>
                  run.generation.rejectPreparation(rejection.value);
              run.execution.startQueue();
              run.flush();
              return run;
            },
            (run) {
              final queue = run.container.read(
                replicationQueueNotifierProvider,
              );
              expect(run.state.retryCount, 0);
              expect(run.state.failedCount, 1);
              switch (strategy) {
                case FailureHandlingStrategy.skip:
                case FailureHandlingStrategy.autoRetry:
                  expect(queue.failedTasks.single.id, run.tasks[0].id);
                  expect(queue.tasks.map((task) => task.id), [run.tasks[1].id]);
                  expect(run.started, ['second']);
                case FailureHandlingStrategy.pauseAndWait:
                  expect(queue.failedTasks, isEmpty);
                  expect(
                    queue.tasks.first.status,
                    ReplicationTaskStatus.failed,
                  );
                  expect(queue.tasks.first.errorMessage, rejection.value);
                  expect(run.state.status, QueueExecutionStatus.paused);
                  expect(run.started, isEmpty);
              }
            },
          );
        });
      }
    }

    for (final thrown in <Object>[
      StateError('preparation crashed'),
      const FormatException('preparation could not parse'),
    ]) {
      test('准备阶段抛出 ${thrown.runtimeType} 按可重试错误处理', () {
        driveQueueRun(
          (async) => startWith(async, endPreparation: (run) => throw thrown),
          (run) {
            expect(run.state.retryCount, 1);
            expect(
              run.container.read(replicationQueueNotifierProvider).failedTasks,
              isEmpty,
            );

            run.elapse(const Duration(seconds: 2));
            expect(run.started, ['first']);
          },
        );
      });
    }

    test('准备阶段冷却未过时等冷却结束再提交', () {
      driveQueueRun(
        (async) => startWith(
          async,
          extraOverrides: [
            generationCooldownProvider.overrideWith(
              ScriptedCooldownNotifier.new,
            ),
          ],
          endPreparation: (run) {
            (run.container.read(generationCooldownProvider.notifier)
                    as ScriptedCooldownNotifier)
                .hold();
            return const GenerationCooldownActive();
          },
        ),
        (run) {
          run.elapse(const Duration(seconds: 1));
          expect(run.started, isEmpty);
          expect(run.state.status, QueueExecutionStatus.ready);

          (run.container.read(generationCooldownProvider.notifier)
                  as ScriptedCooldownNotifier)
              .release();
          run.elapse(const Duration(seconds: 1));
          expect(run.started, ['first']);
          expect(run.state.retryCount, 0);
        },
      );
    });

    for (final stale in ['取消', '成功']) {
      test('上一次以$stale结束后在准备阶段被取消，与运行中被取消一样停止队列', () {
        driveQueueRun(
          (async) {
            final run = QueueRun(
              async,
              prompts: ['first', 'second'],
              localStorage: queueRetries(3),
              autoStart: false,
            );
            unawaited(
              run.generation.generate(const ImageParams(prompt: 'manual')),
            );
            run.flush();
            if (stale == '取消') {
              run.generation.emitCancelled(0);
            } else {
              run.generation.complete(0);
            }
            run.generation.settle(0);
            run.flush();
            run.generation.endNextPreparation = () {
              run.generation.cancel();
              return null;
            };
            run.execution.startQueue();
            run.flush();
            return run;
          },
          (run) {
            expect(run.state.status, QueueExecutionStatus.idle);
            expect(
              run.container
                  .read(replicationQueueNotifierProvider)
                  .tasks
                  .first
                  .status,
              ReplicationTaskStatus.pending,
            );
            run.elapse(const Duration(seconds: 2));
            expect(run.started, ['manual']);
          },
        );
      });
    }
  });

  group('未登录时只出现一个登录提示', () {
    List<AuthPromptReason> recordPrompts(QueueRun run) {
      final reasons = <AuthPromptReason>[];
      run.container.listen<AuthPromptRequest?>(authPromptRequestProvider, (
        _,
        next,
      ) {
        if (next != null) reasons.add(next.reason);
      });
      return reasons;
    }

    void signOut(QueueRun run) =>
        (run.container.read(authNotifierProvider.notifier)
                as QueueTestAuthNotifier)
            .signOutForTest();

    test('下一条提交前已登出：队列自己暂停并提示，不调用生成', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          localStorage: queueRetries(3),
        ),
        (run) {
          final prompts = recordPrompts(run);
          signOut(run);
          run.completeAndSettle(0);
          run.elapse(const Duration(seconds: 2));

          expect(prompts, [AuthPromptReason.queueExecution]);
          expect(run.started, ['first']);
          expect(run.generation.outcomes, isEmpty);
          expect(run.state.status, QueueExecutionStatus.paused);
          expect(run.state.currentTaskId, run.tasks[1].id);
        },
      );
    });

    test('查过登录后、生成调用里才发现登出：只有生成的登录提示，队列只暂停', () {
      driveQueueRun(
        (async) {
          final run = QueueRun(
            async,
            prompts: ['first', 'second'],
            localStorage: queueRetries(3),
            autoStart: false,
          );
          run.generation.beforeNextAuthCheck = () => signOut(run);
          return run;
        },
        (run) {
          final prompts = recordPrompts(run);
          run.execution.startQueue();
          run.elapse(const Duration(seconds: 2));

          expect(prompts, [AuthPromptReason.imageGeneration]);
          expect(run.generation.outcomes.single, isA<GenerationAuthRequired>());
          expect(run.state.status, QueueExecutionStatus.paused);
          expect(run.state.retryCount, 0);
          expect(
            run.container
                .read(replicationQueueNotifierProvider)
                .tasks
                .first
                .status,
            ReplicationTaskStatus.pending,
          );
        },
      );
    });
  });

  test('准备阶段取消后手动生成，退忙时不会补交被取消的队列任务', () {
    driveQueueRun(
      (async) => QueueRun(
        async,
        prompts: ['queued'],
        autoStart: false,
        localStorage: NoRetryLocalStorageService(),
        extraOverrides: [_blobStoreOverride],
      ),
      (run) {
        final queuePreparation = Completer<void>();
        run.generation.preparationGate = queuePreparation;
        run.execution.startQueue();
        run.flush();
        expect(
          run.container.read(imageGenerationNotifierProvider).isPreparing,
          isTrue,
        );

        run.generation.cancel();
        final statusAtCancel = run.state.status;
        run.generation.preparationGate = null;
        unawaited(run.generation.generate(const ImageParams(prompt: 'manual')));
        run.flush();
        queuePreparation.complete();
        run.flush();
        expect(run.generation.outcomes.single, isA<GenerationSuperseded>());

        run.completeAndSettle(1);
        run.generation.finishCleanup(1);
        run.flush();
        expect(run.started, ['manual']);
        expect(statusAtCancel, QueueExecutionStatus.idle);
        expect(run.state.status, QueueExecutionStatus.idle);
        expect(
          run.container.read(replicationQueueNotifierProvider).tasks,
          run.tasks,
        );
      },
    );
  });

  group('开了生成间隔时准备阶段的结局', () {
    // 这次提交的冷却在准备开始前就已计时，结局不能从冷却是否在计时倒推
    QueueRun afterManualRun(
      FakeAsync async,
      String previous, {
      int retries = 3,
    }) {
      final run = QueueRun(
        async,
        prompts: ['first', 'second'],
        localStorage: queueRetries(retries),
        autoStart: false,
        extraOverrides: protectedGenerationInterval(async),
      );
      unawaited(run.generation.generate(const ImageParams(prompt: 'manual')));
      run.flush();
      if (previous == '取消') {
        run.generation.emitCancelled(0);
      } else {
        run.generation.complete(0);
      }
      run.generation.settle(0);
      run.generation.finishCleanup(0);
      run.elapse(const Duration(seconds: 6));
      return run;
    }

    for (final previous in ['成功', '取消']) {
      test('上一次以$previous结束，准备阶段取消后队列停止，冷却结束也不再提交', () {
        driveQueueRun(
          (async) {
            final run = afterManualRun(async, previous);
            run.generation.preparationGate = Completer<void>();
            run.execution.startQueue();
            run.flush();
            return run;
          },
          (run) {
            expect(
              run.container.read(generationCooldownProvider).isActive,
              isTrue,
            );
            run.generation.cancel();
            run.generation.preparationGate!.complete();
            run.flush();

            expect(
              run.generation.outcomes.last,
              isA<GenerationCancelledBeforeStart>(),
            );
            expect(run.state.status, QueueExecutionStatus.idle);
            run.elapse(const Duration(seconds: 10));
            expect(run.started, ['manual']);
            expect(
              run.container
                  .read(replicationQueueNotifierProvider)
                  .tasks
                  .first
                  .status,
              ReplicationTaskStatus.pending,
            );
          },
        );
      });
    }

    test('冷却计时中被本地拒绝时按失败结算，不再每隔一个间隔空转', () {
      driveQueueRun(
        (async) {
          final run = afterManualRun(async, '成功');
          run.generation.endNextPreparation = () => run.generation
              .rejectPreparation('GENERATION_ERROR_UNSUPPORTED_RANDOM_MODEL|x');
          run.execution.startQueue();
          run.flush();
          return run;
        },
        (run) {
          expect(
            run.container
                .read(replicationQueueNotifierProvider)
                .failedTasks
                .single
                .id,
            run.tasks[0].id,
          );
          run.elapse(const Duration(seconds: 6));
          expect(run.started, ['manual', 'second']);
        },
      );
    });
  });

  group('结算时队列写入失败', () {
    List<ReplicationTask> queued(QueueRun run) =>
        run.container.read(replicationQueueNotifierProvider).tasks;

    test('完成结算写入失败时停止队列，不再推进', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          localStorage: queueRetries(0),
        ),
        (run) {
          run.queue.markCompletedError = HiveError('queue save failed');
          run.completeAndSettle(0);
          run.elapse(const Duration(seconds: 2));

          expect(run.state.status, QueueExecutionStatus.idle);
          expect(run.started, ['first']);
          // 内存里已结算为完成，只是没能落盘
          expect(queued(run).map((task) => task.id), [run.tasks[1].id]);
          expect(
            run.container
                .read(replicationQueueNotifierProvider)
                .completedTasks
                .single
                .id,
            run.tasks[0].id,
          );
        },
      );
    });

    test('失败结算写入失败时停止队列，不再推进', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          localStorage: queueRetries(0),
        ),
        (run) {
          run.queue.moveToFailedPoolError = const FileSystemException('full');
          run.generation.fail(0);
          run.generation.settle(0);
          run.elapse(const Duration(seconds: 2));

          expect(run.state.status, QueueExecutionStatus.idle);
          expect(run.started, ['first']);
        },
      );
    });

    test('结算里的编程错误停止队列后照常上报', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          localStorage: queueRetries(0),
        ),
        (run) {
          final reported = <Object>[];
          run.queue.markCompletedError = StateError('settlement bug');
          runZonedGuarded(() {
            run.completeAndSettle(0);
            run.elapse(const Duration(seconds: 2));
          }, (error, _) => reported.add(error));

          expect(run.state.status, QueueExecutionStatus.idle);
          expect(run.started, ['first']);
          expect(reported, [isA<StateError>()]);
        },
      );
    });

    test('任务标为运行中的写入失败时停止队列，不成为未处理异常', () {
      driveQueueRun(
        (async) => QueueRun(
          async,
          prompts: ['first', 'second'],
          localStorage: queueRetries(0),
          autoStart: false,
        ),
        (run) {
          final reported = <Object>[];
          run.queue.runningStatusError = HiveError('queue save failed');
          runZonedGuarded(() {
            run.execution.startQueue();
            run.flush();
            run.elapse(const Duration(seconds: 2));
          }, (error, _) => reported.add(error));

          expect(run.started, ['first']);
          expect(run.state.status, QueueExecutionStatus.idle);
          expect(reported, isEmpty);
        },
      );
    });
  });

  group('确定性错误结算中途被停止', () {
    String emptyMask() => const EmptyInpaintMaskException().toString();

    QueueRun failDeterministically(FakeAsync async, {Object? writeError}) {
      final run = QueueRun(
        async,
        prompts: ['thin mask', 'next'],
        localStorage: queueRetries(3),
      );
      run.queue
        ..unretryableGate = Completer<void>()
        ..unretryableError = writeError;
      run.generation.fail(0, message: emptyMask());
      run.flush();
      return run;
    }

    test('写入期间停止后队列保持空闲，不再提交', () {
      driveQueueRun(failDeterministically, (run) {
        run.execution.stopExecution();
        run.flush();
        run.queue.unretryableGate!.complete();
        run.generation.settle(0);
        run.elapse(const Duration(seconds: 3));

        expect(run.started, ['thin mask']);
        expect(run.state.status, QueueExecutionStatus.idle);
        expect(run.state.currentTaskId, isNull);
        expect(
          run.container.read(replicationQueueNotifierProvider).failedTasks,
          isEmpty,
        );
      });
    });

    test('停止后立刻重新开始，旧结算不动新会话正在跑的任务', () {
      driveQueueRun(failDeterministically, (run) {
        run.generation.settle(0);
        run.flush();
        run.execution.stopExecution();
        run.flush();
        run.execution.startQueue();
        run.flush();
        expect(run.started, ['thin mask', 'thin mask']);

        run.queue.unretryableGate!.complete();
        run.elapse(const Duration(seconds: 3));

        final queue = run.container.read(replicationQueueNotifierProvider);
        expect(queue.failedTasks, isEmpty);
        expect(queue.tasks.first.id, run.tasks[0].id);
        expect(queue.tasks.first.status, ReplicationTaskStatus.running);
        expect(run.state.status, QueueExecutionStatus.running);
        expect(run.state.currentTaskId, run.tasks[0].id);
        expect(run.state.failedCount, 0);

        run.completeAndSettle(1);
        expect(run.state.completedCount, 1);
        expect(run.started, ['thin mask', 'thin mask', 'next']);
      });
    });

    test('旧结算的写入失败不停止重新开始的新会话', () {
      driveQueueRun(
        (async) => failDeterministically(
          async,
          writeError: HiveError('queue save failed'),
        ),
        (run) {
          run.generation.settle(0);
          run.flush();
          run.execution.stopExecution();
          run.flush();
          run.execution.startQueue();
          run.flush();

          run.queue.unretryableGate!.complete();
          run.elapse(const Duration(seconds: 3));

          expect(run.state.status, QueueExecutionStatus.running);
          expect(run.state.currentTaskId, run.tasks[0].id);
          run.completeAndSettle(1);
          expect(run.state.completedCount, 1);
        },
      );
    });
  });
}

Future<ReplicationTask> _taskWithEmptyFixedFrame() async {
  final source = img.Image(width: 128, height: 128);
  final mask = img.Image(width: 128, height: 128)
    ..setPixelRgb(100, 100, 255, 255, 255);
  return ReplicationTask.create(
    prompt: 'empty fixed frame',
    generationSnapshot: await _stored(
      ImageParams(
        width: 128,
        height: 128,
        action: ImageGenerationAction.infill,
        sourceImage: img.encodePng(source),
        maskImage: img.encodePng(mask),
      ),
      focused: const QueuedFocusedInpaint(
        enabled: true,
        contextPadding: 96,
        contextCrop: Rect.fromLTWH(0, 0, 64, 64),
      ),
    ),
  );
}

class _MockGenerationApi extends Mock implements NAIImageGenerationApiService {}

class _PreflightImageGenerationNotifier extends ImageGenerationNotifier {
  _PreflightImageGenerationNotifier(this.preflightPrompt, {this.beforeReturn});

  final String preflightPrompt;
  final Future<void>? beforeReturn;
  final preflightResult = Completer<String?>();
  final startedPrompts = <String>[];

  @override
  Future<GenerationOutcome> generate(
    ImageParams params, {
    int? batchSizeOverride,
    bool preserveCharacterSnapshot = false,
    GenerationFocusedSnapshot? focusedOverride,
    bool bypassRandomPrompt = false,
  }) async {
    if (params.prompt == preflightPrompt) {
      final result = super.generate(
        params,
        batchSizeOverride: batchSizeOverride,
        preserveCharacterSnapshot: preserveCharacterSnapshot,
        focusedOverride: focusedOverride,
        bypassRandomPrompt: bypassRandomPrompt,
      );
      preflightResult.complete(
        result.then(
          (outcome) => outcome is GenerationRejected ? outcome.errorCode : null,
        ),
      );
      final outcome = await result;
      await beforeReturn;
      return outcome;
    }

    startedPrompts.add(params.prompt);
    state = state.copyWith(status: GenerationStatus.generating);
    return const GenerationRunCompleted();
  }
}

final _blobFiles = MemoryStorageFileSystem();

// 置为未完成时图片读取停在后台，测试得以在读取期间改动队列
Completer<void>? _readGate;

// 大于 0 时接下来这么多次读取按文件被占用失败
int _failedReads = 0;

final _blobStore = ReplicationQueueBlobStore(
  resolveDirectory: () async => memoryQueueBlobDirectory,
  fileSystem: _blobFiles,
  worker: <T>(FutureOr<T> Function() task, {String? debugName}) async {
    if (debugName == 'QueueBlobStore.read') {
      await _readGate?.future;
      if (_failedReads > 0) {
        _failedReads--;
        throw const FileSystemException(
          'injected sharing violation',
          null,
          OSError('locked', 32),
        );
      }
    }
    return task();
  },
);

final _blobStoreOverride = replicationQueueBlobStoreProvider.overrideWithValue(
  _blobStore,
);

/// 与入队后状态里的形态一致：图片已落盘，快照只存引用。
Future<Map<String, dynamic>> _stored(
  ImageParams params, {
  QueuedFocusedInpaint? focused,
}) async {
  final interned = await ReplicationTaskGenerationSnapshot.intern([
    await ReplicationTaskGenerationSnapshot.encode(params, focused: focused),
  ], _blobStore);
  interned.release();
  return interned.snapshots.single!;
}
