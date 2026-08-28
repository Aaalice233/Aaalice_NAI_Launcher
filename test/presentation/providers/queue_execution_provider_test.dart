import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/data/models/queue/failure_handling_strategy.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

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
      generationSnapshot: ReplicationTaskGenerationSnapshot.encode(
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
      generationSnapshot: ReplicationTaskGenerationSnapshot.encode(
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

  for (final strategy in FailureHandlingStrategy.values) {
    test('损坏的完整快照按 $strategy 结算且保留错误', () async {
      final snapshot = ReplicationTaskGenerationSnapshot.encode(
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
}

ProviderContainer _buildStartContainer(
  ReplicationTask task,
  AuthStatus authStatus, {
  _TestImageGenerationNotifier? generationNotifier,
  GenerationParamsNotifier Function()? generationParamsNotifier,
}) {
  return ProviderContainer(
    overrides: [
      replicationQueueStorageProvider.overrideWithValue(
        _MemoryReplicationQueueStorage(),
      ),
      queueStateStorageProvider.overrideWithValue(_MemoryQueueStateStorage()),
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
      kritaBridgeNotifierProvider.overrideWith((ref) => KritaBridgeNotifier()),
    ],
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.authStatus);

  final AuthStatus authStatus;

  @override
  AuthState build() => AuthState(status: authStatus);
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

class _TestImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();

  @override
  Future<void> generate(ImageParams params, {int? batchSizeOverride}) async {}
}

class _CapturingImageGenerationNotifier extends _TestImageGenerationNotifier {
  ImageParams? generated;

  @override
  Future<void> generate(ImageParams params, {int? batchSizeOverride}) async {
    generated = params;
  }
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
