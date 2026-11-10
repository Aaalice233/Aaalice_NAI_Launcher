import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
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
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

import '../../helpers/memory_queue_blob_store.dart';

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
          _MemoryReplicationQueueStorage(),
        ),
        queueStateStorageProvider.overrideWithValue(_MemoryQueueStateStorage()),
        replicationQueueBlobStoreProvider.overrideWithValue(_blobStore),
        notificationSettingsNotifierProvider.overrideWith(
          _DisabledNotificationSettingsNotifier.new,
        ),
        replicationQueueNotifierProvider.overrideWith(
          () => _TestReplicationQueueNotifier([task]),
        ),
        queueExecutionNotifierProvider.overrideWith(
          _TestQueueExecutionNotifier.new,
        ),
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
        characterPromptNotifierProvider.overrideWith(
          () => _TestCharacterPromptNotifier(initialCharacters),
        ),
      ],
    );
  }

  for (final status in [AuthStatus.unauthenticated, AuthStatus.loading]) {
    test('队列在 $status 时保持任务和执行状态不变', () async {
      final task = ReplicationTask.create(prompt: 'keep queued prompt');
      final container = _buildStartContainer(task, status);
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
    final container = _buildStartContainer(task, AuthStatus.authenticated);
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
    final generation = _ControlledImageGenerationNotifier();
    final container = _buildControlledQueueContainer(tasks, generation);
    addTearDown(container.dispose);

    expect(
      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue(),
      QueueStartResult.started,
    );
    await generation.waitForStart(0);

    generation.complete(0);
    await _waitForCurrentTask(container, tasks[1].id);
    expect(generation.startedPrompts, ['first']);

    generation.settle(0);
    await generation.waitForStart(1);
    expect(generation.startedPrompts, ['first', 'second']);

    generation.complete(1);
    generation.settle(1);
    await generation.waitForStart(2);
    expect(generation.startedPrompts, ['first', 'second', 'third']);

    generation.complete(2);
    await _waitForExecutionStatus(container, QueueExecutionStatus.completed);
    generation.settle(2);
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
    final generation = _ControlledImageGenerationNotifier();
    final container = _buildControlledQueueContainer(
      tasks,
      generation,
      localStorage: _NoRetryLocalStorageService(),
    );
    addTearDown(container.dispose);

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await generation.waitForStart(0);
    generation.fail(0);
    await _waitForCurrentTask(container, tasks[1].id);
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
    final generation = _ControlledImageGenerationNotifier();
    final container = _buildControlledQueueContainer(
      tasks,
      generation,
      localStorage: _RetryingLocalStorageService(),
    );
    addTearDown(container.dispose);

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await generation.waitForStart(0);
    generation.fail(
      0,
      message: const EmptyInpaintMaskException().toString(),
    );
    await _waitForCurrentTask(container, tasks[1].id);
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
      final container = _buildControlledQueueContainer(
        [first, next],
        generation,
        localStorage: _RetryingLocalStorageService(),
        overrides: [
          naiImageGenerationApiServiceProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final execution =
          container.read(queueExecutionNotifierProvider.notifier)
              as _TestQueueExecutionNotifier;
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
    final container = _buildControlledQueueContainer(
      [first, next],
      generation,
      overrides: [
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
    expect(container.read(queueExecutionNotifierProvider).currentTaskId, next.id);
  });

  test('取消会释放运行任务但不会启动下一任务', () async {
    final tasks = [
      ReplicationTask.create(prompt: 'cancelled'),
      ReplicationTask.create(prompt: 'untouched'),
      ReplicationTask.create(prompt: 'also untouched'),
    ];
    final generation = _ControlledImageGenerationNotifier();
    final container = _buildControlledQueueContainer(tasks, generation);
    addTearDown(container.dispose);

    await container.read(queueExecutionNotifierProvider.notifier).startQueue();
    await generation.waitForStart(0);
    generation.emitCancelled(0);
    await _waitForExecutionStatus(container, QueueExecutionStatus.idle);
    await _waitForQueueTaskStatus(
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
      final generation = _ControlledImageGenerationNotifier();
      final container = _buildControlledQueueContainer(tasks, generation);

      await container
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue();
      await generation.waitForStart(0);
      generation.complete(0);
      await _waitForCurrentTask(container, tasks[1].id);
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
    final capture = _CapturingImageGenerationNotifier();
    final container = _buildStartContainer(
      task,
      AuthStatus.authenticated,
      generationNotifier: capture,
      generationParamsNotifier: _BatchGenerationParamsNotifier.new,
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
    final capture = _CapturingImageGenerationNotifier();
    final container = _buildStartContainer(
      task,
      AuthStatus.authenticated,
      generationNotifier: capture,
      generationParamsNotifier: _BatchGenerationParamsNotifier.new,
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
    final capture = _CapturingImageGenerationNotifier();
    final container = _buildStartContainer(
      task,
      AuthStatus.authenticated,
      generationNotifier: capture,
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
    final capture = _CapturingImageGenerationNotifier();
    final container = _buildStartContainer(
      original,
      AuthStatus.authenticated,
      generationNotifier: capture,
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
            as _TestReplicationQueueNotifier)
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
      final container = _buildStartContainer(task, AuthStatus.authenticated);
      addTearDown(container.dispose);
      final execution = container.read(queueExecutionNotifierProvider.notifier);
      (execution as _TestQueueExecutionNotifier).setStrategyForTest(strategy);

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
      final capture = _CapturingImageGenerationNotifier();
      final container = _buildControlledQueueContainer(
        [task, next],
        capture,
        localStorage: _RetryingLocalStorageService(),
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
      final capture = _CapturingImageGenerationNotifier();
      final container = _buildStartContainer(
        task,
        AuthStatus.authenticated,
        generationNotifier: capture,
        localStorage: _RetryingLocalStorageService(),
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
      final capture = _CapturingImageGenerationNotifier();
      final container = _buildStartContainer(
        task,
        AuthStatus.authenticated,
        generationNotifier: capture,
        localStorage: _NoRetryLocalStorageService(),
      );
      addTearDown(container.dispose);
      final execution = container.read(queueExecutionNotifierProvider.notifier);
      (execution as _TestQueueExecutionNotifier).setStrategyForTest(
        FailureHandlingStrategy.skip,
      );

      expect(await execution.startQueue(), QueueStartResult.started);
      await _waitForExecutionStatus(container, QueueExecutionStatus.completed);

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
      final capture = _CapturingImageGenerationNotifier();
      final container = _buildStartContainer(
        task,
        AuthStatus.authenticated,
        generationNotifier: capture,
        localStorage: _NoRetryLocalStorageService(),
      );
      addTearDown(container.dispose);
      final execution = container.read(queueExecutionNotifierProvider.notifier);
      (execution as _TestQueueExecutionNotifier).setStrategyForTest(
        FailureHandlingStrategy.pauseAndWait,
      );

      expect(await execution.startQueue(), QueueStartResult.started);
      await _waitForExecutionStatus(container, QueueExecutionStatus.paused);

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
    final noRetry = _ConfiguredLocalStorageService(
      retryCount: 0,
      retryIntervalSeconds: 0,
    );

    test('任务间隔内暂停后不再推进，恢复后接着跑下一条', () {
      fakeAsync((async) {
        final run = _QueueRun(
          async,
          prompts: ['first', 'second', 'third'],
          taskIntervalSeconds: 2,
          localStorage: noRetry,
        );
        try {
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
        } finally {
          run.dispose();
        }
      });
    });

    test('任务间隔内暂停又恢复只推进一次', () {
      fakeAsync((async) {
        final run = _QueueRun(
          async,
          prompts: ['first', 'second', 'third'],
          taskIntervalSeconds: 2,
          localStorage: noRetry,
        );
        try {
          run.completeAndSettle(0);

          run.execution.pause();
          run.execution.resume();
          run.flush();
          expect(run.started, ['first', 'second']);

          run.elapse(const Duration(seconds: 3));
          expect(run.started, ['first', 'second']);
          expect(run.state.status, QueueExecutionStatus.running);
          expect(run.state.currentTaskId, run.tasks[1].id);
        } finally {
          run.dispose();
        }
      });
    });

    test('任务间隔内停止不再推进', () {
      fakeAsync((async) {
        final run = _QueueRun(
          async,
          prompts: ['first', 'second'],
          taskIntervalSeconds: 2,
          localStorage: noRetry,
        );
        try {
          run.completeAndSettle(0);

          run.execution.stopExecution();
          run.elapse(const Duration(seconds: 3));
          expect(run.started, ['first']);
          expect(run.state.status, QueueExecutionStatus.idle);
        } finally {
          run.dispose();
        }
      });
    });

    test('失败结算期间暂停不推进下一条，恢复后继续', () {
      fakeAsync((async) {
        final run = _QueueRun(
          async,
          prompts: ['failed', 'next', 'last'],
          localStorage: noRetry,
        );
        try {
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
        } finally {
          run.dispose();
        }
      });
    });

    test('失败结算期间停止不推进下一条', () {
      fakeAsync((async) {
        final run = _QueueRun(
          async,
          prompts: ['failed', 'next'],
          localStorage: noRetry,
        );
        try {
          final moveGate = run.queue.moveGate = Completer<void>();
          run.generation.fail(0);
          run.flush();

          run.execution.stopExecution();
          moveGate.complete();
          run.generation.settle(0);
          run.flush();
          expect(run.started, ['failed']);
          expect(run.state.status, QueueExecutionStatus.idle);
        } finally {
          run.dispose();
        }
      });
    });

    test('失败后暂停等待策略在期间被停止时不把队列改回暂停', () {
      fakeAsync((async) {
        final run = _QueueRun(
          async,
          prompts: ['failed', 'next'],
          strategy: FailureHandlingStrategy.pauseAndWait,
          localStorage: noRetry,
        );
        try {
          final failGate = run.queue.failGate = Completer<void>();
          run.generation.fail(0);
          run.flush();

          run.execution.stopExecution();
          failGate.complete();
          run.generation.settle(0);
          run.flush();
          expect(run.started, ['failed']);
          expect(run.state.status, QueueExecutionStatus.idle);
        } finally {
          run.dispose();
        }
      });
    });

    test('重试等待中暂停后恢复会重新提交当前任务', () {
      fakeAsync((async) {
        final run = _QueueRun(
          async,
          prompts: ['flaky', 'next'],
          localStorage: _ConfiguredLocalStorageService(
            retryCount: 3,
            retryIntervalSeconds: 1,
          ),
        );
        try {
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
        } finally {
          run.dispose();
        }
      });
    });
  });
}

// 在 fakeAsync 中驱动受控生成的一轮队列执行
class _QueueRun {
  _QueueRun(
    this.async, {
    required List<String> prompts,
    double taskIntervalSeconds = 0,
    FailureHandlingStrategy strategy = FailureHandlingStrategy.skip,
    LocalStorageService? localStorage,
  }) : tasks = [
         for (final prompt in prompts) ReplicationTask.create(prompt: prompt),
       ] {
    container = _buildControlledQueueContainer(
      tasks,
      generation,
      localStorage: localStorage,
      replicationQueue: () => _GatedReplicationQueueNotifier(tasks),
    );
    execution.setStrategyForTest(strategy);
    if (taskIntervalSeconds > 0) execution.setTaskInterval(taskIntervalSeconds);
    execution.startQueue();
    flush();
    expect(started, [prompts.first]);
  }

  final FakeAsync async;
  final List<ReplicationTask> tasks;
  final generation = _ControlledImageGenerationNotifier();
  late final ProviderContainer container;

  _TestQueueExecutionNotifier get execution =>
      container.read(queueExecutionNotifierProvider.notifier)
          as _TestQueueExecutionNotifier;

  _GatedReplicationQueueNotifier get queue =>
      container.read(replicationQueueNotifierProvider.notifier)
          as _GatedReplicationQueueNotifier;

  QueueExecutionState get state =>
      container.read(queueExecutionNotifierProvider);

  List<String> get started => generation.startedPrompts;

  void flush() => async.flushMicrotasks();

  void elapse(Duration duration) {
    async.elapse(duration);
    flush();
  }

  void completeAndSettle(int index) {
    generation.complete(index);
    generation.settle(index);
    flush();
  }

  void dispose() {
    container.dispose();
    flush();
  }
}

ProviderContainer _buildControlledQueueContainer(
  List<ReplicationTask> tasks,
  ImageGenerationNotifier generation, {
  LocalStorageService? localStorage,
  ReplicationQueueNotifier Function()? replicationQueue,
  List<Override> overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      replicationQueueStorageProvider.overrideWithValue(
        _MemoryReplicationQueueStorage(),
      ),
      queueStateStorageProvider.overrideWithValue(_MemoryQueueStateStorage()),
      replicationQueueBlobStoreProvider.overrideWithValue(_blobStore),
      if (localStorage != null)
        localStorageServiceProvider.overrideWithValue(localStorage),
      notificationSettingsNotifierProvider.overrideWith(
        _DisabledNotificationSettingsNotifier.new,
      ),
      authNotifierProvider.overrideWith(
        () => _TestAuthNotifier(AuthStatus.authenticated),
      ),
      replicationQueueNotifierProvider.overrideWith(
        replicationQueue ?? () => _TestReplicationQueueNotifier(tasks),
      ),
      queueExecutionNotifierProvider.overrideWith(
        _TestQueueExecutionNotifier.new,
      ),
      generationParamsNotifierProvider.overrideWith(
        _TestGenerationParamsNotifier.new,
      ),
      characterPromptNotifierProvider.overrideWith(
        () => _TestCharacterPromptNotifier(const []),
      ),
      imageGenerationNotifierProvider.overrideWith(() => generation),
      kritaBridgeNotifierProvider.overrideWith(KritaBridgeNotifier.new),
      ...overrides,
    ],
  );
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

Future<void> _waitForCurrentTask(
  ProviderContainer container,
  String taskId,
) async {
  if (container.read(queueExecutionNotifierProvider).currentTaskId == taskId) {
    return;
  }
  final completer = Completer<void>();
  late final ProviderSubscription<QueueExecutionState> subscription;
  subscription = container.listen(queueExecutionNotifierProvider, (_, next) {
    if (next.currentTaskId == taskId && !completer.isCompleted) {
      completer.complete();
    }
  });
  try {
    await completer.future;
  } finally {
    subscription.close();
  }
}

Future<void> _waitForExecutionStatus(
  ProviderContainer container,
  QueueExecutionStatus status,
) async {
  if (container.read(queueExecutionNotifierProvider).status == status) return;
  final completer = Completer<void>();
  late final ProviderSubscription<QueueExecutionState> subscription;
  subscription = container.listen(queueExecutionNotifierProvider, (_, next) {
    if (next.status == status && !completer.isCompleted) completer.complete();
  });
  try {
    await completer.future;
  } finally {
    subscription.close();
  }
}

Future<void> _waitForQueueTaskStatus(
  ProviderContainer container,
  String taskId,
  ReplicationTaskStatus status,
) async {
  bool hasStatus(ReplicationQueueState queue) =>
      queue.tasks.any((task) => task.id == taskId && task.status == status);
  if (hasStatus(container.read(replicationQueueNotifierProvider))) return;
  final completer = Completer<void>();
  late final ProviderSubscription<ReplicationQueueState> subscription;
  subscription = container.listen(replicationQueueNotifierProvider, (_, next) {
    if (hasStatus(next) && !completer.isCompleted) completer.complete();
  });
  try {
    await completer.future;
  } finally {
    subscription.close();
  }
}

ProviderContainer _buildStartContainer(
  ReplicationTask task,
  AuthStatus authStatus, {
  _TestImageGenerationNotifier? generationNotifier,
  GenerationParamsNotifier Function()? generationParamsNotifier,
  LocalStorageService? localStorage,
}) {
  return ProviderContainer(
    overrides: [
      replicationQueueStorageProvider.overrideWithValue(
        _MemoryReplicationQueueStorage(),
      ),
      queueStateStorageProvider.overrideWithValue(_MemoryQueueStateStorage()),
      replicationQueueBlobStoreProvider.overrideWithValue(_blobStore),
      if (localStorage != null)
        localStorageServiceProvider.overrideWithValue(localStorage),
      notificationSettingsNotifierProvider.overrideWith(
        _DisabledNotificationSettingsNotifier.new,
      ),
      authNotifierProvider.overrideWith(() => _TestAuthNotifier(authStatus)),
      replicationQueueNotifierProvider.overrideWith(
        () => _TestReplicationQueueNotifier([task]),
      ),
      queueExecutionNotifierProvider.overrideWith(
        _TestQueueExecutionNotifier.new,
      ),
      generationParamsNotifierProvider.overrideWith(
        generationParamsNotifier ?? _TestGenerationParamsNotifier.new,
      ),
      characterPromptNotifierProvider.overrideWith(
        () => _TestCharacterPromptNotifier(const []),
      ),
      imageGenerationNotifierProvider.overrideWith(
        () => generationNotifier ?? _TestImageGenerationNotifier(),
      ),
      kritaBridgeNotifierProvider.overrideWith(KritaBridgeNotifier.new),
    ],
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.authStatus);

  final AuthStatus authStatus;

  @override
  AuthState build() => AuthState(status: authStatus);
}

class _MockGenerationApi extends Mock implements NAIImageGenerationApiService {}

class _PreflightImageGenerationNotifier extends ImageGenerationNotifier {
  _PreflightImageGenerationNotifier(this.preflightPrompt, {this.beforeReturn});

  final String preflightPrompt;
  final Future<void>? beforeReturn;
  final preflightResult = Completer<String?>();
  final startedPrompts = <String>[];

  @override
  Future<String?> generate(
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
      preflightResult.complete(result);
      final error = await result;
      await beforeReturn;
      return error;
    }

    startedPrompts.add(params.prompt);
    state = state.copyWith(status: GenerationStatus.generating);
    return null;
  }
}

class _DisabledNotificationSettingsNotifier
    extends NotificationSettingsNotifier {
  @override
  NotificationSettings build() =>
      const NotificationSettings(soundEnabled: false);
}

class _TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  _TestReplicationQueueNotifier(this.tasks);

  final List<ReplicationTask> tasks;

  @override
  ReplicationQueueState build() {
    super.build();
    return ReplicationQueueState(tasks: tasks);
  }

  void replaceTaskForTest(ReplicationTask task) {
    state = state.copyWith(
      tasks: [
        for (final queued in state.tasks) queued.id == task.id ? task : queued,
      ],
    );
  }
}

// 闸门打开前，失败结算卡在对应的队列写入上
class _GatedReplicationQueueNotifier extends _TestReplicationQueueNotifier {
  _GatedReplicationQueueNotifier(super.tasks);

  Completer<void>? moveGate;
  Completer<void>? failGate;

  @override
  Future<void> moveToFailedPool(String taskId) async {
    await moveGate?.future;
    return super.moveToFailedPool(taskId);
  }

  @override
  Future<bool> updateTaskStatus(
    String taskId,
    ReplicationTaskStatus status, {
    String? errorMessage,
  }) async {
    if (status == ReplicationTaskStatus.failed) await failGate?.future;
    return super.updateTaskStatus(taskId, status, errorMessage: errorMessage);
  }
}

class _TestQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() {
    super.build();
    return const QueueExecutionState();
  }

  void setStrategyForTest(FailureHandlingStrategy strategy) {
    state = state.copyWith(failureStrategy: strategy);
  }
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();

  @override
  void updatePrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
  }

  @override
  void updateNegativePrompt(String negativePrompt) {
    state = state.copyWith(negativePrompt: negativePrompt);
  }
}

class _ControlledImageGenerationNotifier extends ImageGenerationNotifier {
  final List<String> startedPrompts = [];
  final List<_ControlledGenerationInvocation> _invocations = [];
  final List<Completer<void>> _startSignals = List.generate(
    10,
    (_) => Completer<void>(),
  );
  _ControlledGenerationInvocation? _activeInvocation;

  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<void> waitUntilGenerationInvocationSettled() =>
      _activeInvocation?.settled.future ?? Future<void>.value();

  @override
  Future<String?> generate(
    ImageParams params, {
    int? batchSizeOverride,
    bool preserveCharacterSnapshot = false,
    GenerationFocusedSnapshot? focusedOverride,
    bool bypassRandomPrompt = false,
  }) async {
    if (_activeInvocation != null) return null;
    final invocation = _ControlledGenerationInvocation();
    _activeInvocation = invocation;
    _invocations.add(invocation);
    final index = _invocations.length - 1;
    startedPrompts.add(params.prompt);
    state = state.copyWith(status: GenerationStatus.generating);
    _startSignals[index].complete();

    await invocation.settled.future;
    if (identical(_activeInvocation, invocation)) {
      _activeInvocation = null;
    }
    await invocation.cleanup.future;
    invocation.cleanupFinished.complete();
    return null;
  }

  Future<void> waitForStart(int index) => _startSignals[index].future;

  void complete(int index) {
    expect(_invocations[index], same(_activeInvocation));
    state = state.copyWith(status: GenerationStatus.completed);
  }

  void fail(int index, {String message = 'controlled failure'}) {
    expect(_invocations[index], same(_activeInvocation));
    state = state.copyWith(
      status: GenerationStatus.error,
      errorMessage: message,
    );
  }

  void emitCancelled(int index) {
    expect(_invocations[index], same(_activeInvocation));
    state = state.copyWith(status: GenerationStatus.cancelled);
  }

  void settle(int index) {
    final invocation = _invocations[index];
    if (identical(_activeInvocation, invocation)) {
      _activeInvocation = null;
    }
    if (!invocation.settled.isCompleted) invocation.settled.complete();
  }

  void finishCleanup(int index, {bool fail = false}) {
    final invocation = _invocations[index];
    invocation.cleanupFailed = fail;
    if (!invocation.cleanup.isCompleted) invocation.cleanup.complete();
  }

  bool cleanupFinished(int index) =>
      _invocations[index].cleanupFinished.isCompleted;

  bool cleanupFailed(int index) => _invocations[index].cleanupFailed;

  Future<void> waitForCleanup(int index) =>
      _invocations[index].cleanupFinished.future;
}

class _ControlledGenerationInvocation {
  final Completer<void> settled = Completer<void>();
  final Completer<void> cleanup = Completer<void>();
  final Completer<void> cleanupFinished = Completer<void>();
  bool cleanupFailed = false;
}

class _NoRetryLocalStorageService extends LocalStorageService {
  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    if (key == StorageKeys.queueRetryCount) return 0 as T;
    if (key == StorageKeys.queueRetryInterval) return 0.0 as T;
    return defaultValue;
  }
}

class _ConfiguredLocalStorageService extends LocalStorageService {
  _ConfiguredLocalStorageService({
    required this.retryCount,
    required this.retryIntervalSeconds,
  });

  final int retryCount;
  final double retryIntervalSeconds;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    if (key == StorageKeys.queueRetryCount) return retryCount as T;
    if (key == StorageKeys.queueRetryInterval) return retryIntervalSeconds as T;
    return defaultValue;
  }
}

class _RetryingLocalStorageService extends LocalStorageService {
  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    if (key == StorageKeys.queueRetryCount) return 3 as T;
    if (key == StorageKeys.queueRetryInterval) return 0.0 as T;
    return defaultValue;
  }
}

class _TestImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<String?> generate(
    ImageParams params, {
    int? batchSizeOverride,
    bool preserveCharacterSnapshot = false,
    GenerationFocusedSnapshot? focusedOverride,
    bool bypassRandomPrompt = false,
  }) async => null;
}

class _CapturingImageGenerationNotifier extends _TestImageGenerationNotifier {
  ImageParams? generated;
  final firstGeneration = Completer<ImageParams>();

  @override
  Future<String?> generate(
    ImageParams params, {
    int? batchSizeOverride,
    bool preserveCharacterSnapshot = false,
    GenerationFocusedSnapshot? focusedOverride,
    bool bypassRandomPrompt = false,
  }) async {
    generated = params;
    if (!firstGeneration.isCompleted) firstGeneration.complete(params);
    return null;
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

class _BatchGenerationParamsNotifier extends _TestGenerationParamsNotifier {
  @override
  ImageParams build() =>
      const ImageParams(negativePrompt: 'main negative', nSamples: 4);
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  _TestCharacterPromptNotifier(this.initialCharacters);

  final List<CharacterPrompt> initialCharacters;

  @override
  CharacterPromptConfig build() =>
      CharacterPromptConfig(characters: initialCharacters);

  @override
  void replaceAll(List<CharacterPrompt> characters) {
    state = state.copyWith(characters: characters);
  }

  @override
  void setGlobalAiChoice(bool value) {
    state = state.copyWith(globalAiChoice: value);
  }
}

class _MemoryReplicationQueueStorage extends ReplicationQueueStorage {
  @override
  List<ReplicationTask> load() => const [];

  @override
  Future<void> save(List<ReplicationTask> tasks) async {}

  @override
  Future<void> clear() async {}
}

class _MemoryQueueStateStorage extends QueueStateStorage {
  @override
  QueueExecutionStateData loadExecutionState() =>
      const QueueExecutionStateData();

  @override
  Future<void> saveExecutionState(QueueExecutionStateData state) async {}

  @override
  List<ReplicationTask> loadFailedTasks() => const [];

  @override
  Future<void> saveFailedTasks(List<ReplicationTask> tasks) async {}
}
