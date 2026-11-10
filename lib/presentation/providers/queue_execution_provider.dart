import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive.dart' show HiveError;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/storage/queue_state_storage.dart';
import '../../core/storage/replication_queue_blob_store.dart';
import '../../core/storage/replication_queue_blob_store_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/image/image_params.dart';
import '../../data/models/queue/replication_task.dart';
import '../../data/models/queue/replication_task_generation_snapshot.dart';
import '../../data/models/queue/replication_task_status.dart';
import '../../data/models/queue/failure_handling_strategy.dart';
import 'character_prompt_provider.dart';
import 'generation/generation_error_classifier.dart';
import 'image_generation_provider.dart';
import '../../data/services/auth_provider.dart';
import 'krita/krita_bridge_notifier.dart';
import 'notification_settings_provider.dart';
import 'queued_generation_request.dart';
import 'replication_queue_provider.dart';
import '../../core/services/notification_service.dart';

part 'queue_execution_provider.g.dart';

/// 队列执行状态
enum QueueExecutionStatus {
  /// 空闲，等待用户触发
  idle,

  /// 已填充提示词，等待用户点击生成
  ready,

  /// 正在执行
  running,

  /// 已暂停
  paused,

  /// 已完成
  completed,
}

enum QueueStartResult { started, empty, busy, authRequired }

/// 队列执行状态
class QueueExecutionState {
  final QueueExecutionStatus status;
  final int completedCount;
  final int failedCount;
  final int skippedCount;
  final String? currentTaskId;
  final int retryCount;
  final List<String> failedTaskIds;
  final bool autoExecuteEnabled;
  final double taskIntervalSeconds;
  final FailureHandlingStrategy failureStrategy;
  final bool pausedForFailure;
  final int totalTasksInSession;
  final DateTime? sessionStartTime;

  const QueueExecutionState({
    this.status = QueueExecutionStatus.idle,
    this.completedCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.currentTaskId,
    this.retryCount = 0,
    this.failedTaskIds = const [],
    this.autoExecuteEnabled = false,
    this.taskIntervalSeconds = 0.0,
    this.failureStrategy = FailureHandlingStrategy.skip,
    this.pausedForFailure = false,
    this.totalTasksInSession = 0,
    this.sessionStartTime,
  });

  QueueExecutionState copyWith({
    QueueExecutionStatus? status,
    int? completedCount,
    int? failedCount,
    int? skippedCount,
    String? currentTaskId,
    bool clearCurrentTaskId = false,
    int? retryCount,
    List<String>? failedTaskIds,
    bool? autoExecuteEnabled,
    double? taskIntervalSeconds,
    FailureHandlingStrategy? failureStrategy,
    bool? pausedForFailure,
    int? totalTasksInSession,
    DateTime? sessionStartTime,
  }) {
    return QueueExecutionState(
      status: status ?? this.status,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      currentTaskId: clearCurrentTaskId
          ? null
          : (currentTaskId ?? this.currentTaskId),
      retryCount: retryCount ?? this.retryCount,
      failedTaskIds: failedTaskIds ?? this.failedTaskIds,
      autoExecuteEnabled: autoExecuteEnabled ?? this.autoExecuteEnabled,
      taskIntervalSeconds: taskIntervalSeconds ?? this.taskIntervalSeconds,
      failureStrategy: failureStrategy ?? this.failureStrategy,
      pausedForFailure:
          pausedForFailure ??
          ((status == null || status == QueueExecutionStatus.paused) &&
              this.pausedForFailure),
      totalTasksInSession: totalTasksInSession ?? this.totalTasksInSession,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    );
  }

  bool get isRunning => status == QueueExecutionStatus.running;
  bool get isReady => status == QueueExecutionStatus.ready;
  bool get isPaused => status == QueueExecutionStatus.paused;
  bool get isIdle => status == QueueExecutionStatus.idle;
  bool get isCompleted => status == QueueExecutionStatus.completed;

  /// 获取进度百分比 (0.0 - 1.0)
  double get progress {
    if (totalTasksInSession <= 0) return 0.0;
    return (completedCount + failedCount + skippedCount) / totalTasksInSession;
  }

  /// 是否有失败任务
  bool get hasFailedTasks => failedTaskIds.isNotEmpty;
}

/// 队列设置
class QueueSettings {
  final int retryCount;
  final double retryIntervalSeconds;
  final bool autoExecuteEnabled;
  final double taskIntervalSeconds;
  final FailureHandlingStrategy failureStrategy;

  const QueueSettings({
    this.retryCount = 10,
    this.retryIntervalSeconds = 1.0,
    this.autoExecuteEnabled = false,
    this.taskIntervalSeconds = 0.0,
    this.failureStrategy = FailureHandlingStrategy.skip,
  });

  Duration get retryInterval =>
      Duration(milliseconds: (retryIntervalSeconds * 1000).toInt());

  Duration get taskInterval =>
      Duration(milliseconds: (taskIntervalSeconds * 1000).toInt());

  QueueSettings copyWith({
    int? retryCount,
    double? retryIntervalSeconds,
    bool? autoExecuteEnabled,
    double? taskIntervalSeconds,
    FailureHandlingStrategy? failureStrategy,
  }) {
    return QueueSettings(
      retryCount: retryCount ?? this.retryCount,
      retryIntervalSeconds: retryIntervalSeconds ?? this.retryIntervalSeconds,
      autoExecuteEnabled: autoExecuteEnabled ?? this.autoExecuteEnabled,
      taskIntervalSeconds: taskIntervalSeconds ?? this.taskIntervalSeconds,
      failureStrategy: failureStrategy ?? this.failureStrategy,
    );
  }
}

/// 队列执行引擎 Provider
///
/// 管理复刻队列的自动执行，包括：
/// - 填充提示词到主界面
/// - 监听生成完成事件
/// - 自动处理下一项
/// - 错误重试机制
/// - 暂停/恢复功能
/// - 失败处理策略
@Riverpod(keepAlive: true)
class QueueExecutionNotifier extends _$QueueExecutionNotifier {
  late final QueueStateStorage _stateStorage;
  bool _generationTriggerPending = false;
  final _attribution = _QueueGenerationAttribution();
  bool _isDisposed = false;
  Future<void> _pendingStateWrite = Future.value();
  int _executionRevision = 0;

  @override
  QueueExecutionState build() {
    _stateStorage = ref.read(queueStateStorageProvider);
    ref.onDispose(() => _isDisposed = true);

    // 使用 ref.listen 监听生成状态变化（不会触发 provider 重建，避免竞态条件）
    ref.listen<ImageGenerationState>(imageGenerationNotifierProvider, (
      previous,
      next,
    ) {
      _onGenerationStateChanged(previous, next);
    });

    // 同步加载持久化状态（Hive Box 已在 main.dart 中预先打开）
    return _loadFromStorageSync();
  }

  /// 同步加载状态
  QueueExecutionState _loadFromStorageSync() {
    try {
      final data = _stateStorage.loadExecutionState();
      final queueState = ref.read(replicationQueueNotifierProvider);
      final currentTaskStillExists =
          data.currentTaskId != null &&
          queueState.tasks.any((task) => task.id == data.currentTaskId);
      final shouldRecoverPaused =
          queueState.tasks.isNotEmpty &&
          (data.isPaused || currentTaskStillExists);
      return QueueExecutionState(
        status: shouldRecoverPaused
            ? QueueExecutionStatus.paused
            : QueueExecutionStatus.idle,
        completedCount: data.completedCount,
        failedCount: data.failedCount,
        skippedCount: data.skippedCount,
        currentTaskId: currentTaskStillExists ? data.currentTaskId : null,
        failedTaskIds: data.failedTaskIds,
        autoExecuteEnabled: data.autoExecuteEnabled,
        taskIntervalSeconds: data.taskIntervalSeconds,
        failureStrategy: data.failureStrategy,
        totalTasksInSession:
            data.completedCount +
            data.failedCount +
            data.skippedCount +
            queueState.count,
      );
    } catch (e) {
      return const QueueExecutionState();
    }
  }

  /// 序列化执行状态写入，确保停止或清空后的状态不会被旧任务覆盖。
  Future<void> _saveToStorage() {
    final snapshot = QueueExecutionStateData(
      completedCount: state.completedCount,
      failedCount: state.failedCount,
      skippedCount: state.skippedCount,
      autoExecuteEnabled: state.autoExecuteEnabled,
      taskIntervalSeconds: state.taskIntervalSeconds,
      failureStrategy: state.failureStrategy,
      isPaused: state.isPaused,
      currentTaskId: state.currentTaskId,
      failedTaskIds: List<String>.unmodifiable(state.failedTaskIds),
    );
    final operation = _pendingStateWrite.then(
      (_) => _stateStorage.saveExecutionState(snapshot),
    );
    _pendingStateWrite = operation.catchError((_) {});
    return operation;
  }

  /// 获取队列设置
  QueueSettings _getSettings() {
    final storage = ref.read(localStorageServiceProvider);
    final retryCount =
        storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10;
    final retryInterval =
        storage.getSetting<double>(
          StorageKeys.queueRetryInterval,
          defaultValue: 1.0,
        ) ??
        1.0;
    return QueueSettings(
      retryCount: retryCount,
      retryIntervalSeconds: retryInterval,
      autoExecuteEnabled: state.autoExecuteEnabled,
      taskIntervalSeconds: state.taskIntervalSeconds,
      failureStrategy: state.failureStrategy,
    );
  }

  /// 设置自动执行模式
  Future<void> setAutoExecute(bool enabled) async {
    state = state.copyWith(autoExecuteEnabled: enabled);
    await _saveToStorage();
  }

  /// 设置任务间隔
  Future<void> setTaskInterval(double seconds) async {
    state = state.copyWith(taskIntervalSeconds: seconds.clamp(0.0, 10.0));
    await _saveToStorage();
  }

  /// 设置失败处理策略
  Future<void> setFailureStrategy(FailureHandlingStrategy strategy) async {
    state = state.copyWith(failureStrategy: strategy);
    await _saveToStorage();
  }

  /// 暂停执行
  ///
  /// 已经提交给 NovelAI 的当前任务不会被取消；暂停会在该任务完成后生效。
  Future<void> pause() async {
    if (state.status != QueueExecutionStatus.running &&
        state.status != QueueExecutionStatus.ready) {
      return;
    }
    state = state.copyWith(status: QueueExecutionStatus.paused);
    await _saveToStorage();
  }

  /// 恢复执行
  Future<void> resume() async {
    if (state.status != QueueExecutionStatus.paused) return;

    final queueState = ref.read(replicationQueueNotifierProvider);
    if (queueState.isEmpty) {
      state = state.copyWith(
        status: QueueExecutionStatus.idle,
        clearCurrentTaskId: true,
      );
      return;
    }

    if (!requireAuthenticatedAction(ref, AuthPromptReason.queueExecution)) {
      return;
    }

    final firstTask = queueState.tasks.first;
    if (state.currentTaskId == null || state.currentTaskId != firstTask.id) {
      _processNextTask();
    } else if (firstTask.status == ReplicationTaskStatus.running) {
      // 当前请求仍在飞行时，恢复只解除“完成后暂停”，不能再次提交同一任务。
      state = state.copyWith(status: QueueExecutionStatus.running);
    } else {
      state = state.copyWith(status: QueueExecutionStatus.ready);
      _fillPrompt(firstTask);
    }
    await _saveToStorage();
    if (state.status == QueueExecutionStatus.ready) {
      _triggerAutoGenerate();
    }
  }

  /// 从任意页面启动队列。
  Future<QueueStartResult> startQueue() async {
    final queueState = ref.read(replicationQueueNotifierProvider);
    if (queueState.isEmpty) return QueueStartResult.empty;

    if (!requireAuthenticatedAction(ref, AuthPromptReason.queueExecution)) {
      return QueueStartResult.authRequired;
    }

    final generationState = ref.read(imageGenerationNotifierProvider);
    final isKritaGenerating =
        PlatformCapabilities.current.supportsKritaBridge &&
        ref.read(kritaBridgeNotifierProvider).isBridgeGenerating;
    if (generationState.isBusy || isKritaGenerating) {
      return QueueStartResult.busy;
    }

    prepareNextTask();
    _triggerAutoGenerate();
    return QueueStartResult.started;
  }

  /// 准备执行队列（填充第一项提示词）
  ///
  /// 当用户进入主界面且队列非空时调用
  void prepareNextTask() {
    if (state.status == QueueExecutionStatus.running ||
        state.status == QueueExecutionStatus.paused) {
      return;
    }

    final queueState = ref.read(replicationQueueNotifierProvider);
    if (queueState.isEmpty) {
      state = state.copyWith(status: QueueExecutionStatus.idle);
      return;
    }

    final nextTask = queueState.tasks.first;

    // 记录会话开始，先更新状态为 ready。完成后的新一轮队列必须重置
    // 统计，否则进度会继续沿用上一轮结果。
    final isNewSession = state.isIdle || state.isCompleted;
    state = state.copyWith(
      status: QueueExecutionStatus.ready,
      currentTaskId: nextTask.id,
      retryCount: 0,
      completedCount: isNewSession ? 0 : state.completedCount,
      failedCount: isNewSession ? 0 : state.failedCount,
      skippedCount: isNewSession ? 0 : state.skippedCount,
      failedTaskIds: isNewSession ? const [] : state.failedTaskIds,
      totalTasksInSession: isNewSession
          ? queueState.count
          : state.totalTasksInSession,
      sessionStartTime: isNewSession ? DateTime.now() : state.sessionStartTime,
    );

    // 填充提示词（此时状态已是 ready，prompt_input 不会同步）
    _fillPrompt(nextTask);

    // 注意：这里不更新任务状态，任务保持 pending 状态
    // 只有在实际开始生成时（startExecution）才更新为 running
  }

  /// 填充提示词到主界面
  void _fillPrompt(ReplicationTask task) {
    // 队列任务只回填用户基础提示词；固定词、质量词和 UC 预设仍由生成链路统一组装。
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    paramsNotifier.updatePrompt(task.prompt);
    if (task.applyNegativePrompt) {
      paramsNotifier.updateNegativePrompt(task.negativePrompt);
    }

    final characterPrompts = task.characterPrompts;
    if (characterPrompts != null) {
      final notifier = ref.read(characterPromptNotifierProvider.notifier);
      notifier.replaceAll([
        for (var index = 0; index < characterPrompts.length; index++)
          characterPrompts[index].toCharacterPrompt(
            id: '${task.id}-character-$index',
            index: index,
          ),
      ]);
      notifier.setGlobalAiChoice(
        !characterPrompts.any(
          (character) =>
              character.positionX != null && character.positionY != null,
        ),
      );
    }
  }

  /// 触发队列当前任务生成。
  ///
  /// 执行入口必须由队列引擎持有，不能依赖生成页 Widget 是否挂载。
  void _triggerAutoGenerate() {
    if (_generationTriggerPending) return;
    _generationTriggerPending = true;
    _runSettlement(_generateReadyTask);
  }

  Future<void> _generateReadyTask() async {
    final ImageGenerationNotifier generationNotifier;
    final _QueuedSubmission? submission;
    try {
      try {
        await ref
            .read(generationCooldownProvider.notifier)
            .waitUntilAvailable();

        generationNotifier = ref.read(imageGenerationNotifierProvider.notifier);
        // completed/error 会先于生成调用的 finally 对外可见。等待旧调用释放
        // invocation 所有权，避免下一任务因 generate() 的并发保护而被静默丢弃。
        await generationNotifier.waitUntilGenerationInvocationSettled();

        if (!_canGenerateReadyTask()) return;
        final current = _currentQueueTask();
        if (current == null) return;
        submission = await _prepareSubmission(current);
      } finally {
        // 快照失败结算可能立即重试或推进下一项，必须先释放触发锁。
        _generationTriggerPending = false;
      }
    } on QueueBlobReadFailedException catch (error) {
      AppLogger.w(error.message, 'QueueExecution');
      await _retryAfterTransientSnapshotFailure();
      return;
    } on FormatException catch (error, stackTrace) {
      await _settleInvalidSnapshot(error, stackTrace);
      return;
    }
    if (submission == null || _isDisposed) return;
    // 准备参数也跨了 await，期间队列可能被暂停、被别处占用或当前任务被编辑
    if (!_canGenerateReadyTask()) return;
    if (!identical(_currentQueueTask(), submission.task)) {
      _triggerAutoGenerate();
      return;
    }

    if (await _submitToGeneration(generationNotifier, submission)) {
      _triggerAutoGenerate();
    }
  }

  Future<_QueuedSubmission?> _prepareSubmission(ReplicationTask current) async {
    final ready = current.generationSnapshot == null
        ? (current, null)
        : await _decodeReadyTask(current);
    if (ready == null) return null;
    final (task, snapshotParams) = ready;

    final snapshot = task.generationSnapshot;
    return (
      task: task,
      params: resolveQueuedTaskParams(
        task,
        base: ref.read(generationParamsNotifierProvider),
        snapshotParams: snapshotParams,
      ),
      batchSizeOverride: snapshot == null
          ? null
          : ReplicationTaskGenerationSnapshot.decodeBatchSize(snapshot),
      focusedOverride: queuedFocusedOverride(
        snapshot == null
            ? null
            : ReplicationTaskGenerationSnapshot.decodeFocused(snapshot),
      ),
      preserveCharacterSnapshot: snapshot != null,
    );
  }

  Future<void> _settleInvalidSnapshot(
    FormatException error,
    StackTrace stackTrace,
  ) async {
    final taskId = state.currentTaskId;
    AppLogger.e(
      'Queued generation snapshot is invalid (${error.runtimeType})',
      null,
      stackTrace,
      'QueueExecution',
    );
    if (taskId != null) {
      await _handleFailedTask(
        revision: _executionRevision,
        errorMessage: 'Invalid generation snapshot: ${error.message}',
        retryable: false,
      );
    } else {
      state = state.copyWith(
        status: QueueExecutionStatus.idle,
        clearCurrentTaskId: true,
      );
      await _saveToStorage();
    }
  }

  /// 提交一次队列生成并等它结束；返回是否需要重新触发提交。
  Future<bool> _submitToGeneration(
    ImageGenerationNotifier generationNotifier,
    _QueuedSubmission submission,
  ) async {
    final revision = _executionRevision;
    final taskId = submission.task.id;
    final serial = _attribution.openSubmission(taskId);
    final Future<GenerationOutcome> generation;
    try {
      generation = generationNotifier.generate(
        submission.params,
        batchSizeOverride: submission.batchSizeOverride,
        preserveCharacterSnapshot: submission.preserveCharacterSnapshot,
        focusedOverride: submission.focusedOverride,
      );
    } finally {
      _attribution.closeSubmissionWindow();
    }
    GenerationOutcome? outcome;
    try {
      outcome = await generation;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Queued generation threw ${error.runtimeType}',
        null,
        stackTrace,
        'QueueExecution',
      );
    }
    if (_isDisposed || !_attribution.releaseUnentered(serial)) return false;
    if (outcome is GenerationRejected &&
        !identical(_currentQueueTask(), submission.task)) {
      return false;
    }
    // 期间被停止时这次提交已与队列无关；若又重新开始，新会话可能因这次占用没能提交
    if (revision != _executionRevision) return state.isReady;
    if (state.currentTaskId != taskId || !(state.isReady || state.isPaused)) {
      return false;
    }
    if (outcome == null) {
      _settleTaskFailure(null);
      return false;
    }
    return _settleUnenteredOutcome(outcome);
  }

  /// 没进入生成就结束的提交按调用结局结算；返回是否需要重新触发提交。
  bool _settleUnenteredOutcome(GenerationOutcome outcome) {
    switch (outcome) {
      case GenerationBusy():
      case GenerationDisposed():
        return false;
      case GenerationAuthRequired():
        _runSettlement(pause);
        publishAuthPrompt(ref, AuthPromptReason.queueExecution);
        return false;
      case GenerationRejected(:final errorCode):
        _settleTaskFailure(errorCode);
        return false;
      case GenerationCooldownActive():
        // 冷却由提交前的等待负责，这里只需重新提交
        return true;
      case GenerationCancelledBeforeStart():
      case GenerationSuperseded():
        _runSettlement(stopExecution);
        return false;
      case GenerationRunEnded():
        // 进入过生成的提交由状态监听在终态转换时结算
        return false;
    }
  }

  void _settleTaskFailure(String? errorMessage) {
    startExecution();
    if (errorMessage != null && isDeterministicGenerationError(errorMessage)) {
      _runSettlement(
        () => _handleFailedTask(
          revision: _executionRevision,
          errorMessage: errorMessage,
          retryable: false,
        ),
      );
    } else {
      _runSettlement(_onTaskError);
    }
  }

  /// 读图片的暂时性失败按一次失败的执行结算，沿用重试次数、重试间隔与失败策略。
  Future<void> _retryAfterTransientSnapshotFailure() async {
    if (state.currentTaskId == null ||
        state.status != QueueExecutionStatus.ready) {
      return;
    }
    startExecution(errorMessage: QueueBlobReadFailedException.errorCode);
    await _onTaskError(errorMessage: QueueBlobReadFailedException.errorCode);
  }

  /// 快照在后台解码，期间通知器可能被释放、队列可能暂停或被手动生成占用，
  /// 当前任务也可能被编辑；结算后重新核对，任务被替换时改用最新任务。
  Future<(ReplicationTask, ImageParams?)?> _decodeReadyTask(
    ReplicationTask task,
  ) async {
    final blobStore = ref.read(replicationQueueBlobStoreProvider);
    var current = task;
    while (true) {
      final snapshot = current.generationSnapshot;
      if (snapshot == null) return (current, null);
      final decoding = ReplicationTaskGenerationSnapshot.decode(
        snapshot,
        blobStore,
      );
      // 先等结算再核对，只抛出仍是当前任务的快照读取错误。
      await decoding.then<void>((_) {}, onError: (Object _) {});
      if (_isDisposed || !_canGenerateReadyTask()) return null;
      final latest = _currentQueueTask();
      if (latest == null) return null;
      if (identical(latest, current)) return (current, await decoding);
      current = latest;
    }
  }

  bool _canGenerateReadyTask() =>
      state.status == QueueExecutionStatus.ready &&
      !ref.read(imageGenerationNotifierProvider).isBusy &&
      !(PlatformCapabilities.current.supportsKritaBridge &&
          ref.read(kritaBridgeNotifierProvider).isBridgeGenerating);

  ReplicationTask? _currentQueueTask() {
    final currentTaskId = state.currentTaskId;
    for (final candidate in ref.read(replicationQueueNotifierProvider).tasks) {
      if (candidate.id == currentTaskId) return candidate;
    }
    return null;
  }

  /// 开始执行队列
  ///
  /// 当用户点击生成按钮后，由生成状态监听器自动触发
  void startExecution({String? errorMessage}) {
    if (state.status != QueueExecutionStatus.ready) return;

    state = state.copyWith(status: QueueExecutionStatus.running);

    // 实际开始执行时，更新当前任务状态为 running
    final taskId = state.currentTaskId;
    if (taskId != null) {
      _runSettlement(
        () => ref
            .read(replicationQueueNotifierProvider.notifier)
            .updateTaskStatus(
              taskId,
              ReplicationTaskStatus.running,
              errorMessage: errorMessage,
            ),
      );
    }
  }

  /// 停止执行队列。已提交的生成请求继续完成，但不再推进队列。
  Future<void> stopExecution() => _stopExecution();

  Future<void> _stopExecution({bool completeCurrentTask = false}) async {
    _executionRevision++;
    _generationTriggerPending = false;
    final currentTaskId = state.currentTaskId;
    state = state.copyWith(
      status: QueueExecutionStatus.idle,
      clearCurrentTaskId: true,
      completedCount: completeCurrentTask ? state.completedCount + 1 : null,
      retryCount: completeCurrentTask ? 0 : null,
    );
    if (currentTaskId != null) {
      final queue = ref.read(replicationQueueNotifierProvider.notifier);
      if (completeCurrentTask) {
        await queue.markCompleted(currentTaskId);
      } else {
        await queue.resetRunningTask(currentTaskId);
      }
    }
    if (_isDisposed) return;
    await _saveToStorage();
  }

  /// 原子停止执行状态后再清空待处理任务，避免运行中的回调复活旧队列。
  Future<void> clearQueue() async {
    await stopExecution();
    await ref.read(replicationQueueNotifierProvider.notifier).clear();
  }

  // 提交后、进入生成前被暂停时请求照常发出，任务仍要锁成运行中，完成才能按任务结算
  void _markOwnedTaskRunning(String taskId) {
    if (state.currentTaskId != taskId) return;
    if (state.isReady) {
      startExecution();
    } else if (state.isPaused) {
      _runSettlement(
        () => ref
            .read(replicationQueueNotifierProvider.notifier)
            .updateTaskStatus(taskId, ReplicationTaskStatus.running),
      );
    }
  }

  /// 监听生成状态变化；完成、失败、取消只归属队列自己提交且进入过生成的那一次
  void _onGenerationStateChanged(
    ImageGenerationState? previous,
    ImageGenerationState next,
  ) {
    if (next.preparationCancelled) {
      final taskId = _attribution.releasePreparing();
      if (taskId != null && taskId == state.currentTaskId) {
        _runSettlement(stopExecution);
        return;
      }
    }
    if (previous?.isBusy != true && next.isBusy) {
      _attribution.onBusyStarted();
    } else if (previous?.isBusy == true &&
        !next.isBusy &&
        !_attribution.ownsBusySession &&
        state.isReady) {
      // 就绪的队列可能因这次别处发起的生成占用而没能提交，占用结束后补一次
      _triggerAutoGenerate();
    }
    final wasGenerating = previous?.status == GenerationStatus.generating;

    if (!wasGenerating && next.status == GenerationStatus.generating) {
      final taskId = _attribution.onEnteredGenerating();
      if (taskId != null) _markOwnedTaskRunning(taskId);
      return;
    }
    if (!wasGenerating ||
        (next.status != GenerationStatus.completed &&
            next.status != GenerationStatus.error &&
            next.status != GenerationStatus.cancelled)) {
      return;
    }

    final taskId = _attribution.releaseEntered();
    if (taskId == null || !_hasQueueTask || state.currentTaskId != taskId) {
      if (next.status == GenerationStatus.completed) {
        _triggerGenerationNotification();
      }
      return;
    }

    switch (next.status) {
      case GenerationStatus.completed:
        final outcome = ref
            .read(imageGenerationNotifierProvider.notifier)
            .waitUntilGenerationInvocationSettled();
        _runSettlement(() => _onTaskCompleted(outcome));
      case GenerationStatus.error:
        _settleTaskFailure(next.errorMessage);
      default:
        _runSettlement(stopExecution);
    }
  }

  // 结算里的队列写入失败时不能停在运行中；只记异常类型，异常文本可能带着任务内容
  void _runSettlement(Future<void> Function() settlement) {
    final revision = _executionRevision;
    unawaited(
      settlement().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) async {
          AppLogger.e(
            'Queue settlement failed with ${error.runtimeType}',
            null,
            stackTrace,
            'QueueExecution',
          );
          // 期间已被停止或重新开始时，旧结算的失败不能停掉用户的新会话
          if (!_isDisposed && revision == _executionRevision) {
            await _stopAfterSettlementFailure();
          }
          if (!_isQueueStorageWriteFailure(error)) {
            Error.throwWithStackTrace(error, stackTrace);
          }
        },
      ),
    );
  }

  Future<void> _stopAfterSettlementFailure() async {
    try {
      await stopExecution();
    } catch (stopError, stopStackTrace) {
      AppLogger.e(
        'Stopping the queue failed with ${stopError.runtimeType}',
        null,
        stopStackTrace,
        'QueueExecution',
      );
    }
  }

  bool get _hasQueueTask =>
      state.currentTaskId != null &&
      (state.isRunning || state.isReady || state.isPaused);

  /// 触发生成完成音效
  void _triggerGenerationNotification() {
    final settings = ref.read(notificationSettingsNotifierProvider);
    if (!settings.soundEnabled) return;

    Future.microtask(() async {
      await NotificationService.instance.notifyGenerationComplete(
        playSound: settings.soundEnabled,
        customSoundPath: settings.customSoundPath,
      );
    });
  }

  /// 任务完成处理
  Future<void> _onTaskCompleted(Future<GenerationRunEnded?> outcome) async {
    final revision = _executionRevision;
    final currentTaskId = state.currentTaskId;
    if (currentTaskId == null) {
      AppLogger.e(
        'Queue completion received without a current task ID',
        null,
        null,
        'QueueExecution',
      );
      await stopExecution();
      return;
    }

    // 取消后处理也会发布原图完成事件，调用结束时才能决定队列是否继续。
    final ended = await outcome;
    if (_isDisposed || revision != _executionRevision) return;
    if (ended is! GenerationRunCompleted) {
      await _stopExecution(completeCurrentTask: true);
      return;
    }

    final completed = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .markCompleted(currentTaskId);
    if (revision != _executionRevision) return;
    if (!completed) {
      AppLogger.e(
        'Queue completion target no longer exists: $currentTaskId',
        null,
        null,
        'QueueExecution',
      );
      await stopExecution();
      return;
    }

    state = state.copyWith(
      completedCount: state.completedCount + 1,
      retryCount: 0,
      clearCurrentTaskId: state.isPaused,
    );
    await _saveToStorage();

    // 运行中点击暂停表示“当前任务完成后暂停”。
    if (state.isPaused) return;

    // 等待任务间隔
    if (state.taskIntervalSeconds > 0) {
      await Future.delayed(
        Duration(milliseconds: (state.taskIntervalSeconds * 1000).toInt()),
      );
    }
    if (!_canAdvanceFrom(currentTaskId, revision)) return;

    _processNextTask();
  }

  // 等待期间可能被暂停、停止，或已由 resume 推进到下一条，这些情况都不能再由原流程推进
  bool _canAdvanceFrom(String settledTaskId, int revision) =>
      revision == _executionRevision &&
      (state.isRunning || state.isReady) &&
      state.currentTaskId == settledTaskId;

  /// 任务错误处理
  Future<void> _onTaskError({String? errorMessage}) async {
    final settings = _getSettings();
    final revision = _executionRevision;

    if (state.retryCount < settings.retryCount) {
      final taskId = state.currentTaskId;
      // 重试
      state = state.copyWith(retryCount: state.retryCount + 1);

      // 等待重试间隔
      await Future.delayed(settings.retryInterval);
      if (revision != _executionRevision) return;

      if (state.isPaused && taskId != null && state.currentTaskId == taskId) {
        // 失败后已无在途请求，任务改回待执行，resume 才会重新提交而不是当作仍在生成
        await ref
            .read(replicationQueueNotifierProvider.notifier)
            .resetRunningTask(taskId);
        return;
      }
      if (state.status != QueueExecutionStatus.running) return;

      // 重新设置为 ready 状态，等待用户再次点击或自动执行
      state = state.copyWith(status: QueueExecutionStatus.ready);

      _triggerAutoGenerate();
    } else {
      // 超过重试次数，根据策略处理
      await _handleFailedTask(errorMessage: errorMessage, revision: revision);
    }
  }

  /// 处理失败任务
  Future<void> _handleFailedTask({
    required int revision,
    String? errorMessage,
    bool retryable = true,
  }) async {
    // 结算前已被停止时任务已改回待执行，当前任务也可能属于重新开始的新会话
    if (revision != _executionRevision) return;
    final currentTaskId = state.currentTaskId;
    if (currentTaskId == null) {
      _processNextTask();
      return;
    }

    final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);
    if (!retryable) {
      // 失败池保留任务上的错误原因，写入期间已换任务时不继续结算。
      await queueNotifier.updateTaskStatus(
        currentTaskId,
        ReplicationTaskStatus.running,
        errorMessage: errorMessage,
      );
      if (_isDisposed ||
          revision != _executionRevision ||
          state.currentTaskId != currentTaskId) {
        return;
      }
    }

    switch (state.failureStrategy) {
      case FailureHandlingStrategy.autoRetry:
        if (!retryable) {
          await queueNotifier.moveToFailedPool(currentTaskId);
          break;
        }
        // 重新入队到末尾。执行中的任务只能通过专用结算入口移动。
        final requeued = await queueNotifier.requeueRunningTaskForRetry(
          currentTaskId,
        );
        if (revision != _executionRevision) return;
        if (!requeued) {
          AppLogger.e(
            'Queue retry target no longer exists: $currentTaskId',
            null,
            null,
            'QueueExecution',
          );
          await stopExecution();
          return;
        }
        break;

      case FailureHandlingStrategy.skip:
        // 更新任务状态为 failed 并移入失败池
        await queueNotifier.moveToFailedPool(currentTaskId);
        break;

      case FailureHandlingStrategy.pauseAndWait:
        // 写盘期间窗口也可能恢复，先由失败策略接管暂停原因。
        state = state.copyWith(pausedForFailure: true);
        await queueNotifier.updateTaskStatus(
          currentTaskId,
          ReplicationTaskStatus.failed,
          errorMessage: errorMessage,
        );
        if (revision != _executionRevision) return;
        state = state.copyWith(
          status: QueueExecutionStatus.paused,
          failedCount: state.failedCount + 1,
          failedTaskIds: [...state.failedTaskIds, currentTaskId],
          retryCount: 0,
        );
        await _saveToStorage();
        return;
    }
    if (revision != _executionRevision) return;

    state = state.copyWith(
      failedCount: state.failedCount + 1,
      failedTaskIds: [...state.failedTaskIds, currentTaskId],
      retryCount: 0,
    );

    await _saveToStorage();
    if (!_canAdvanceFrom(currentTaskId, revision)) return;

    // 处理下一个任务
    _processNextTask();
  }

  /// 处理下一个任务
  void _processNextTask() {
    final queueState = ref.read(replicationQueueNotifierProvider);

    if (queueState.isEmpty) {
      // 队列清空，执行完成
      state = state.copyWith(
        status: QueueExecutionStatus.completed,
        clearCurrentTaskId: true,
      );
      _runSettlement(_saveToStorage);

      // 触发队列完成通知
      _triggerGenerationNotification();
      return;
    }

    // 先更新状态为 ready
    // 重要：必须在 _fillPrompt 之前更新状态，
    // 这样 prompt_input 才能检测到队列正在执行，从而跳过同步
    final nextTask = queueState.tasks.first;
    state = state.copyWith(
      status: QueueExecutionStatus.ready,
      currentTaskId: nextTask.id,
      retryCount: 0,
    );

    // 填充下一个任务的提示词（此时状态已是 ready）
    _fillPrompt(nextTask);

    // 注意：这里不更新任务状态，任务保持 pending 状态；生成状态切换后
    // startExecution() 会将当前任务标记为 running。
    _triggerAutoGenerate();
  }

  /// 手动重试指定的失败任务
  Future<bool> retryFailedTask(String taskId) async {
    final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);
    final requeued = await queueNotifier.retryFailedTask(taskId);
    if (!requeued) return false;

    state = state.copyWith(
      failedTaskIds: state.failedTaskIds.where((id) => id != taskId).toList(),
    );
    await _saveToStorage();
    return true;
  }

  /// 将失败任务重新入队
  Future<bool> requeueFailedTask(String taskId) async {
    final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);
    final requeued = await queueNotifier.requeueFailedTask(taskId);
    if (!requeued) return false;

    state = state.copyWith(
      failedTaskIds: state.failedTaskIds.where((id) => id != taskId).toList(),
    );
    await _saveToStorage();
    return true;
  }

  /// 清除所有失败任务
  Future<void> clearFailedTasks() async {
    final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);
    await queueNotifier.clearFailedTasks();

    state = state.copyWith(failedTaskIds: []);
    await _saveToStorage();
  }

  /// 重置执行状态
  void reset() {
    state = const QueueExecutionState();
    _saveToStorage();
  }

  /// 开始新的执行会话
  void startNewSession() {
    final queueState = ref.read(replicationQueueNotifierProvider);
    state = state.copyWith(
      completedCount: 0,
      failedCount: 0,
      skippedCount: 0,
      failedTaskIds: [],
      totalTasksInSession: queueState.count,
      sessionStartTime: DateTime.now(),
    );
    _saveToStorage();
  }
}

/// 队列提交的生成归属：只认队列自己在 generate() 同步置忙窗口内发起的那一次；
/// 进入过生成的由状态终态结算，没进入的由调用结局结算，同一次提交只会被释放一次。
class _QueueGenerationAttribution {
  int _serial = 0;
  int? _submitting;
  String? _submittingTaskId;
  int? _owned;
  String? _ownedTaskId;
  bool _entered = false;
  bool _ownsBusySession = false;

  /// 当前忙碌区间是否由队列的提交开启。
  bool get ownsBusySession => _ownsBusySession;

  /// 调用 generate() 之前登记，返回这次提交的编号。
  int openSubmission(String taskId) {
    _submitting = ++_serial;
    _submittingTaskId = taskId;
    return _serial;
  }

  /// generate() 同步返回后结束登记窗口。
  void closeSubmissionWindow() {
    _submitting = null;
    _submittingTaskId = null;
  }

  /// 生成从空闲变为忙碌；只有落在登记窗口内的才归属队列。
  void onBusyStarted() {
    _owned = _submitting;
    _ownedTaskId = _submittingTaskId;
    _entered = false;
    _ownsBusySession = _submitting != null;
  }

  /// 状态进入 generating；归属队列时返回提交的任务。
  String? onEnteredGenerating() {
    if (_owned == null) return null;
    _entered = true;
    return _ownedTaskId;
  }

  /// 进入过生成的提交到达终态；归属队列时释放并返回任务。
  String? releaseEntered() {
    if (_owned == null || !_entered) return null;
    final taskId = _ownedTaskId;
    _release();
    return taskId;
  }

  /// 编号为 [serial] 的提交没进入生成就结束；仍归属队列时释放并返回 true。
  bool releaseUnentered(int serial) {
    if (_owned != serial || _entered) return false;
    _release();
    return true;
  }

  String? releasePreparing() {
    if (_entered) return null;
    final taskId = _ownedTaskId;
    _release();
    return taskId;
  }

  void _release() {
    _owned = null;
    _ownedTaskId = null;
    _entered = false;
  }
}

typedef _QueuedSubmission = ({
  ReplicationTask task,
  ImageParams params,
  int? batchSizeOverride,
  GenerationFocusedSnapshot? focusedOverride,
  bool preserveCharacterSnapshot,
});

/// 队列设置 Provider（从本地存储读取）
@riverpod
QueueSettings queueSettings(Ref ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final executionState = ref.watch(queueExecutionNotifierProvider);

  return QueueSettings(
    retryCount:
        storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10,
    retryIntervalSeconds:
        storage.getSetting<double>(
          StorageKeys.queueRetryInterval,
          defaultValue: 1.0,
        ) ??
        1.0,
    autoExecuteEnabled: executionState.autoExecuteEnabled,
    taskIntervalSeconds: executionState.taskIntervalSeconds,
    failureStrategy: executionState.failureStrategy,
  );
}

// 队列索引写入失败由持久化层包装，执行状态仍由 Hive 直接写入。
bool _isQueueStorageWriteFailure(Object error) =>
    error is ReplicationQueueWriteException ||
    error is HiveError ||
    error is FileSystemException;
