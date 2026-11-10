import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/data/models/queue/failure_handling_strategy.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_status.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/krita/krita_bridge_notifier.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

// 队列执行引擎测试共用：受控生成、可插闸门的队列存储与 fakeAsync 驱动

// 用例体失败时也释放容器，免得计时器残留
void driveQueueRun(
  QueueRun Function(FakeAsync async) start,
  void Function(QueueRun run) body,
) {
  fakeAsync((async) {
    final run = start(async);
    try {
      body(run);
    } finally {
      run.dispose();
    }
  });
}

ConfiguredLocalStorageService queueRetries(int count) =>
    ConfiguredLocalStorageService(retryCount: count, retryIntervalSeconds: 1);

// 在 fakeAsync 中驱动受控生成的一轮队列执行
class QueueRun {
  QueueRun(
    this.async, {
    required List<String> prompts,
    double taskIntervalSeconds = 0,
    FailureHandlingStrategy strategy = FailureHandlingStrategy.skip,
    LocalStorageService? localStorage,
    bool autoStart = true,
    List<Override> extraOverrides = const [],
  }) : tasks = [
         for (final prompt in prompts) ReplicationTask.create(prompt: prompt),
       ] {
    container = buildControlledQueueContainer(
      tasks,
      generation,
      localStorage: localStorage,
      replicationQueue: () => GatedReplicationQueueNotifier(tasks),
      extraOverrides: extraOverrides,
    );
    execution.setStrategyForTest(strategy);
    if (taskIntervalSeconds > 0) execution.setTaskInterval(taskIntervalSeconds);
    if (!autoStart) return;
    execution.startQueue();
    flush();
    expect(started, [prompts.first]);
  }

  final FakeAsync async;
  final List<ReplicationTask> tasks;
  final generation = ControlledImageGenerationNotifier();
  late final ProviderContainer container;

  TestQueueExecutionNotifier get execution =>
      container.read(queueExecutionNotifierProvider.notifier)
          as TestQueueExecutionNotifier;

  GatedReplicationQueueNotifier get queue =>
      container.read(replicationQueueNotifierProvider.notifier)
          as GatedReplicationQueueNotifier;

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

/// 队列引擎运行所需、除执行器与生成参数之外的全部替身，挂在应用外壳上的用例自行补那两项。
List<Override> queueEngineOverrides(
  List<ReplicationTask> tasks,
  ImageGenerationNotifier generation, {
  LocalStorageService? localStorage,
  ReplicationQueueNotifier Function()? replicationQueue,
}) => [
  replicationQueueStorageProvider.overrideWithValue(
    MemoryReplicationQueueStorage(),
  ),
  queueStateStorageProvider.overrideWithValue(MemoryQueueStateStorage()),
  if (localStorage != null)
    localStorageServiceProvider.overrideWithValue(localStorage),
  notificationSettingsNotifierProvider.overrideWith(
    DisabledNotificationSettingsNotifier.new,
  ),
  authNotifierProvider.overrideWith(
    () => QueueTestAuthNotifier(AuthStatus.authenticated),
  ),
  replicationQueueNotifierProvider.overrideWith(
    replicationQueue ?? () => TestReplicationQueueNotifier(tasks),
  ),
  characterPromptNotifierProvider.overrideWith(
    () => TestCharacterPromptNotifier(const []),
  ),
  imageGenerationNotifierProvider.overrideWith(() => generation),
  kritaBridgeNotifierProvider.overrideWith(KritaBridgeNotifier.new),
];

ProviderContainer buildControlledQueueContainer(
  List<ReplicationTask> tasks,
  ImageGenerationNotifier generation, {
  LocalStorageService? localStorage,
  ReplicationQueueNotifier Function()? replicationQueue,
  List<Override> extraOverrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      ...queueEngineOverrides(
        tasks,
        generation,
        localStorage: localStorage,
        replicationQueue: replicationQueue,
      ),
      queueExecutionNotifierProvider.overrideWith(
        TestQueueExecutionNotifier.new,
      ),
      generationParamsNotifierProvider.overrideWith(
        QueueTestGenerationParamsNotifier.new,
      ),
      ...extraOverrides,
    ],
  );
}

Future<void> waitForCurrentTask(
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

Future<void> waitForExecutionStatus(
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

Future<void> waitForQueueTaskStatus(
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

ProviderContainer buildQueueStartContainer(
  ReplicationTask task,
  AuthStatus authStatus, {
  TestImageGenerationNotifier? generationNotifier,
  GenerationParamsNotifier Function()? generationParamsNotifier,
  LocalStorageService? localStorage,
  List<Override> extraOverrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      replicationQueueStorageProvider.overrideWithValue(
        MemoryReplicationQueueStorage(),
      ),
      queueStateStorageProvider.overrideWithValue(MemoryQueueStateStorage()),
      if (localStorage != null)
        localStorageServiceProvider.overrideWithValue(localStorage),
      notificationSettingsNotifierProvider.overrideWith(
        DisabledNotificationSettingsNotifier.new,
      ),
      authNotifierProvider.overrideWith(
        () => QueueTestAuthNotifier(authStatus),
      ),
      replicationQueueNotifierProvider.overrideWith(
        () => TestReplicationQueueNotifier([task]),
      ),
      queueExecutionNotifierProvider.overrideWith(
        TestQueueExecutionNotifier.new,
      ),
      generationParamsNotifierProvider.overrideWith(
        generationParamsNotifier ?? QueueTestGenerationParamsNotifier.new,
      ),
      characterPromptNotifierProvider.overrideWith(
        () => TestCharacterPromptNotifier(const []),
      ),
      imageGenerationNotifierProvider.overrideWith(
        () => generationNotifier ?? TestImageGenerationNotifier(),
      ),
      kritaBridgeNotifierProvider.overrideWith(KritaBridgeNotifier.new),
      ...extraOverrides,
    ],
  );
}

class QueueTestAuthNotifier extends AuthNotifier {
  QueueTestAuthNotifier(this.authStatus);

  final AuthStatus authStatus;

  @override
  AuthState build() => AuthState(status: authStatus);

  void signOutForTest() =>
      state = const AuthState(status: AuthStatus.unauthenticated);
}

/// 冷却由用例直接开关，等待按真实实现的节拍轮询。
class ScriptedCooldownNotifier extends GenerationCooldownNotifier {
  @override
  GenerationCooldownState build() => const GenerationCooldownState();

  void hold() => state = const GenerationCooldownState(remainingSeconds: 1);

  void release() => state = const GenerationCooldownState();

  @override
  bool tryStartGeneration() => !state.isActive;

  @override
  Future<void> waitUntilAvailable() async {
    while (state.isActive) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

class DisabledNotificationSettingsNotifier
    extends NotificationSettingsNotifier {
  @override
  NotificationSettings build() =>
      const NotificationSettings(soundEnabled: false);
}

class TestReplicationQueueNotifier extends ReplicationQueueNotifier {
  TestReplicationQueueNotifier(this.tasks);

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

// 与真实实现一致先改内存，闸门与错误作用在随后的保存上：闸门打开前写入卡住，设了错误就在保存时抛出
class GatedReplicationQueueNotifier extends TestReplicationQueueNotifier {
  GatedReplicationQueueNotifier(super.tasks);

  Completer<void>? moveGate;
  Completer<void>? failGate;

  /// 确定性错误结算先把原因写到运行中的任务上，这次写入受它控制
  Completer<void>? unretryableGate;
  Object? unretryableError;

  Object? markCompletedError;
  Object? moveToFailedPoolError;

  /// 任务被标为运行中时的写入
  Object? runningStatusError;

  MemoryReplicationQueueStorage get _storage =>
      ref.read(replicationQueueStorageProvider)
          as MemoryReplicationQueueStorage;

  Future<T> _write<T>(
    Future<T> Function() write, {
    Completer<void>? gate,
    Object? error,
  }) {
    if (gate != null || error != null) {
      _storage.armNextSave(gate: gate, error: error);
    }
    return write();
  }

  @override
  Future<bool> markCompleted(String taskId) =>
      _write(() => super.markCompleted(taskId), error: markCompletedError);

  @override
  Future<void> moveToFailedPool(String taskId) => _write(
    () => super.moveToFailedPool(taskId),
    gate: moveGate,
    error: moveToFailedPoolError,
  );

  @override
  Future<bool> updateTaskStatus(
    String taskId,
    ReplicationTaskStatus status, {
    String? errorMessage,
  }) {
    final unretryable =
        status == ReplicationTaskStatus.running && errorMessage != null;
    return _write(
      () => super.updateTaskStatus(taskId, status, errorMessage: errorMessage),
      gate: status == ReplicationTaskStatus.failed
          ? failGate
          : unretryable
          ? unretryableGate
          : null,
      error: unretryable
          ? unretryableError
          : status == ReplicationTaskStatus.running
          ? runningStatusError
          : null,
    );
  }
}

class TestQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() {
    super.build();
    return const QueueExecutionState();
  }

  void setStrategyForTest(FailureHandlingStrategy strategy) {
    state = state.copyWith(failureStrategy: strategy);
  }
}

class QueueTestGenerationParamsNotifier extends GenerationParamsNotifier {
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

  @override
  Future<void> saveGenerationState() async {}
}

class ControlledImageGenerationNotifier extends ImageGenerationNotifier {
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
  Future<void> flushGenerationHistory() async {}

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
    if (state.isBusy || _activeInvocation != null) return null;
    final invocation = _ControlledGenerationInvocation();
    _activeInvocation = invocation;
    _invocations.add(invocation);
    final index = _invocations.length - 1;
    // 与真实生成层一致：先带着上一次的终态同步置为提交中，准备完才进入 generating
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: state.errorMessage,
    );
    await Future<void>.value();
    await preparationGate?.future;
    final endPreparation = endNextPreparation;
    if (endPreparation != null) {
      endNextPreparation = null;
      try {
        endPreparation();
      } finally {
        if (identical(_activeInvocation, invocation)) {
          _activeInvocation = null;
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: state.errorMessage,
          );
        }
        invocation.settled.complete();
      }
      return null;
    }
    startedPrompts.add(params.prompt);
    state = state.copyWith(status: GenerationStatus.generating);
    _startSignals[index].complete();

    await invocation.settled.future;
    if (identical(_activeInvocation, invocation)) {
      _activeInvocation = null;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: state.errorMessage,
      );
    }
    await invocation.cleanup.future;
    invocation.cleanupFinished.complete();
    return null;
  }

  Future<void> waitForStart(int index) => _startSignals[index].future;

  /// 下一次 generate() 在准备阶段如何结束、不进入 generating；为 null 时照常生成
  void Function()? endNextPreparation;

  /// 设置后 generate() 停在准备阶段，闸门打开才继续
  Completer<void>? preparationGate;

  void failPreparation(String message) => state = state.copyWith(
    status: GenerationStatus.error,
    errorMessage: message,
  );

  // 与真实 cancel() 一致：上一次已完成的结果不改标成已取消
  void cancelPreparation() {
    _activeInvocation = null;
    state = state.copyWith(
      status: state.status == GenerationStatus.completed
          ? state.status
          : GenerationStatus.cancelled,
      isSubmitting: false,
    );
  }

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
    state = state.copyWith(
      status: GenerationStatus.cancelled,
      isSubmitting: false,
    );
  }

  void settle(int index) {
    final invocation = _invocations[index];
    if (identical(_activeInvocation, invocation)) {
      _activeInvocation = null;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: state.errorMessage,
      );
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

class NoRetryLocalStorageService extends LocalStorageService {
  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    if (key == StorageKeys.queueRetryCount) return 0 as T;
    if (key == StorageKeys.queueRetryInterval) return 0.0 as T;
    return defaultValue;
  }
}

class ConfiguredLocalStorageService extends LocalStorageService {
  ConfiguredLocalStorageService({
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

class RetryingLocalStorageService extends LocalStorageService {
  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    if (key == StorageKeys.queueRetryCount) return 3 as T;
    if (key == StorageKeys.queueRetryInterval) return 0.0 as T;
    return defaultValue;
  }
}

class TestImageGenerationNotifier extends ImageGenerationNotifier {
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

class CapturingImageGenerationNotifier extends TestImageGenerationNotifier {
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

class BatchGenerationParamsNotifier extends QueueTestGenerationParamsNotifier {
  @override
  ImageParams build() =>
      const ImageParams(negativePrompt: 'main negative', nSamples: 4);
}

class TestCharacterPromptNotifier extends CharacterPromptNotifier {
  TestCharacterPromptNotifier(this.initialCharacters);

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

class MemoryReplicationQueueStorage extends ReplicationQueueStorage {
  Completer<void>? _nextSaveGate;
  Object? _nextSaveError;

  /// 下一次保存先等 [gate] 打开，再抛出 [error]
  void armNextSave({Completer<void>? gate, Object? error}) {
    _nextSaveGate = gate;
    _nextSaveError = error;
  }

  @override
  List<ReplicationTask> load() => const [];

  @override
  Future<void> save(List<ReplicationTask> tasks) async {
    final gate = _nextSaveGate;
    final error = _nextSaveError;
    _nextSaveGate = null;
    _nextSaveError = null;
    await gate?.future;
    if (error != null) throw error;
  }

  @override
  Future<void> clear() async {}
}

class MemoryQueueStateStorage extends QueueStateStorage {
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
