import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/storage/queue_state_storage.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/queue/replication_task.dart';
import '../../data/models/queue/replication_task_status.dart';
import '../../data/models/queue/failure_handling_strategy.dart';
import 'image_generation_provider.dart';
import 'notification_settings_provider.dart';
import 'replication_queue_provider.dart';
import 'fixed_tags_provider.dart';
import 'quality_preset_provider.dart';
import 'uc_preset_provider.dart';
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
    this.totalTasksInSession = 0,
    this.sessionStartTime,
  });

  QueueExecutionState copyWith({
    QueueExecutionStatus? status,
    int? completedCount,
    int? failedCount,
    int? skippedCount,
    String? currentTaskId,
    int? retryCount,
    List<String>? failedTaskIds,
    bool? autoExecuteEnabled,
    double? taskIntervalSeconds,
    FailureHandlingStrategy? failureStrategy,
    int? totalTasksInSession,
    DateTime? sessionStartTime,
  }) {
    return QueueExecutionState(
      status: status ?? this.status,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      currentTaskId: currentTaskId ?? this.currentTaskId,
      retryCount: retryCount ?? this.retryCount,
      failedTaskIds: failedTaskIds ?? this.failedTaskIds,
      autoExecuteEnabled: autoExecuteEnabled ?? this.autoExecuteEnabled,
      taskIntervalSeconds: taskIntervalSeconds ?? this.taskIntervalSeconds,
      failureStrategy: failureStrategy ?? this.failureStrategy,
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

  @override
  QueueExecutionState build() {
    _stateStorage = ref.read(queueStateStorageProvider);

    // 使用 ref.listen 监听生成状态变化（不会触发 provider 重建，避免竞态条件）
    ref.listen<ImageGenerationState>(
      imageGenerationNotifierProvider,
      (previous, next) {
        _onGenerationStateChanged(previous, next);
      },
    );

    // 同步加载持久化状态（Hive Box 已在 main.dart 中预先打开）
    return _loadFromStorageSync();
  }

  /// 同步加载状态
  QueueExecutionState _loadFromStorageSync() {
    try {
      final data = _stateStorage.loadExecutionState();
      return QueueExecutionState(
        autoExecuteEnabled: data.autoExecuteEnabled,
        taskIntervalSeconds: data.taskIntervalSeconds,
        failureStrategy: data.failureStrategy,
      );
    } catch (e) {
      return const QueueExecutionState();
    }
  }

  /// 保存状态到存储
  Future<void> _saveToStorage() async {
    await _stateStorage.saveExecutionState(
      QueueExecutionStateData(
        completedCount: state.completedCount,
        failedCount: state.failedCount,
        skippedCount: state.skippedCount,
        autoExecuteEnabled: state.autoExecuteEnabled,
        taskIntervalSeconds: state.taskIntervalSeconds,
        failureStrategy: state.failureStrategy,
        isPaused: state.isPaused,
        currentTaskId: state.currentTaskId,
        failedTaskIds: state.failedTaskIds,
      ),
    );
  }

  /// 获取队列设置
  QueueSettings _getSettings() {
    final storage = ref.read(localStorageServiceProvider);
    final retryCount = storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10;
    final retryInterval = storage.getSetting<double>(
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
      state = state.copyWith(status: QueueExecutionStatus.idle);
      return;
    }

    // 恢复到 ready 状态，等待用户点击生成或自动执行
    state = state.copyWith(status: QueueExecutionStatus.ready);
    await _saveToStorage();

    // 如果是自动执行模式，自动开始
    if (state.autoExecuteEnabled) {
      _triggerAutoGenerate();
    }
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

    // 记录会话开始，先更新状态为 ready
    // 重要：必须在 _fillPrompt 之前更新状态，
    // 这样 prompt_input 才能检测到队列正在执行，从而跳过同步
    final isNewSession = state.totalTasksInSession == 0;
    state = state.copyWith(
      status: QueueExecutionStatus.ready,
      currentTaskId: nextTask.id,
      retryCount: 0,
      totalTasksInSession:
          isNewSession ? queueState.count : state.totalTasksInSession,
      sessionStartTime: isNewSession ? DateTime.now() : state.sessionStartTime,
    );

    // 填充提示词（此时状态已是 ready，prompt_input 不会同步）
    _fillPrompt(nextTask);

    // 注意：这里不更新任务状态，任务保持 pending 状态
    // 只有在实际开始生成时（startExecution）才更新为 running
  }

  /// 填充提示词到主界面
  void _fillPrompt(ReplicationTask task) {
    // 1. 应用固定词到队列任务的正面提示词
    final fixedTagsState = ref.read(fixedTagsNotifierProvider);
    String finalPrompt = fixedTagsState.entries.applyToPrompt(task.prompt);

    // 2. 应用质量词（如果启用）
    final model = ref.read(generationParamsNotifierProvider).model;
    final qualityContent = ref
        .read(qualityPresetNotifierProvider.notifier)
        .getEffectiveContent(model);
    if (qualityContent != null && qualityContent.isNotEmpty) {
      finalPrompt = finalPrompt.isEmpty
          ? qualityContent
          : '$finalPrompt, $qualityContent';
    }

    // 3. 获取主界面负面提示词（UC预设内容）
    final ucContent =
        ref.read(ucPresetNotifierProvider.notifier).getEffectiveContent(model);
    final finalNegativePrompt = ucContent ?? '';

    // 4. 直接更新生成参数（确保生成时使用正确的提示词）
    // 注意：不再更新 pendingPromptNotifier，保持UI提示词不变
    // 这样用户可以在队列运行时继续编写新的提示词
    ref.read(generationParamsNotifierProvider.notifier)
      ..updatePrompt(finalPrompt)
      ..updateNegativePrompt(finalNegativePrompt);
  }

  /// 触发自动生成（自动执行模式下使用）
  void _triggerAutoGenerate() {
    // 这里需要通过生成按钮或其他方式触发生成
    // 由于生成逻辑在 ImageGenerationNotifier 中，我们只需要设置状态
    // 实际的触发需要在 UI 层监听 ready 状态并自动点击生成
  }

  /// 开始执行队列
  ///
  /// 当用户点击生成按钮后，由生成状态监听器自动触发
  void startExecution() {
    if (state.status != QueueExecutionStatus.ready) return;

    state = state.copyWith(status: QueueExecutionStatus.running);

    // 实际开始执行时，更新当前任务状态为 running
    if (state.currentTaskId != null) {
      ref.read(replicationQueueNotifierProvider.notifier).updateTaskStatus(
            state.currentTaskId!,
            ReplicationTaskStatus.running,
          );
    }
  }

  /// 停止执行队列
  void stopExecution() {
    state = state.copyWith(
      status: QueueExecutionStatus.idle,
      currentTaskId: null,
    );
    _saveToStorage();
  }

  /// 监听生成状态变化
  void _onGenerationStateChanged(
    ImageGenerationState? previous,
    ImageGenerationState next,
  ) {
    // 检测生成完成（优先处理，无论队列模式还是普通模式）
    if (previous?.status == GenerationStatus.generating &&
        next.status == GenerationStatus.completed) {
      // 判断是否为队列模式
      final isQueueMode = state.status == QueueExecutionStatus.running ||
          state.status == QueueExecutionStatus.ready;

      if (isQueueMode) {
        // 队列模式：不播放单张完成音效，等队列全部完成后播放
        _onTaskCompleted();
      } else {
        // 非队列模式：立即播放生成完成音效
        _triggerSingleGenerationNotification();
      }
      return;
    }

    // 以下逻辑仅在队列模式下执行
    if (state.status != QueueExecutionStatus.running &&
        state.status != QueueExecutionStatus.ready) {
      return;
    }

    // 检测到开始生成，进入运行状态
    if (previous?.status != GenerationStatus.generating &&
        next.status == GenerationStatus.generating) {
      if (state.status == QueueExecutionStatus.ready) {
        startExecution(); // 调用 startExecution 来同时更新队列状态和任务状态
      }
      return;
    }

    // 生成错误
    if (previous?.status == GenerationStatus.generating &&
        next.status == GenerationStatus.error) {
      _onTaskError();
      return;
    }

    // 生成取消
    if (next.status == GenerationStatus.cancelled) {
      stopExecution();
      return;
    }
  }

  /// 触发单张生成完成音效（非队列模式）
  void _triggerSingleGenerationNotification() {
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
  Future<void> _onTaskCompleted() async {
    final currentTaskId = state.currentTaskId;

    // 更新任务状态为 completed
    if (currentTaskId != null) {
      ref.read(replicationQueueNotifierProvider.notifier).updateTaskStatus(
            currentTaskId,
            ReplicationTaskStatus.completed,
          );
    }

    // 从队列移除已完成的任务
    await ref.read(replicationQueueNotifierProvider.notifier).markCompleted();

    state = state.copyWith(
      completedCount: state.completedCount + 1,
      retryCount: 0,
    );

    await _saveToStorage();

    // 检查是否暂停
    if (state.isPaused) {
      return;
    }

    // 等待任务间隔
    if (state.taskIntervalSeconds > 0) {
      await Future.delayed(
        Duration(
          milliseconds: (state.taskIntervalSeconds * 1000).toInt(),
        ),
      );
    }

    // 处理下一个任务
    _processNextTask();
  }

  /// 任务错误处理
  Future<void> _onTaskError() async {
    final settings = _getSettings();

    if (state.retryCount < settings.retryCount) {
      // 重试
      state = state.copyWith(retryCount: state.retryCount + 1);

      // 等待重试间隔
      await Future.delayed(settings.retryInterval);

      // 检查是否仍在运行或暂停
      if (state.status != QueueExecutionStatus.running) return;

      // 重新设置为 ready 状态，等待用户再次点击或自动执行
      state = state.copyWith(status: QueueExecutionStatus.ready);

      // 自动执行模式下自动重试
      if (state.autoExecuteEnabled) {
        _triggerAutoGenerate();
      }
    } else {
      // 超过重试次数，根据策略处理
      await _handleFailedTask();
    }
  }

  /// 处理失败任务
  Future<void> _handleFailedTask() async {
    final currentTaskId = state.currentTaskId;
    if (currentTaskId == null) {
      _processNextTask();
      return;
    }

    final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);
    final task = ref.read(replicationQueueNotifierProvider).tasks.firstWhere(
          (t) => t.id == currentTaskId,
          orElse: () => ReplicationTask.create(prompt: ''),
        );

    switch (state.failureStrategy) {
      case FailureHandlingStrategy.autoRetry:
        // 重新入队到末尾
        await queueNotifier.remove(currentTaskId);
        await queueNotifier.add(
          task.copyWith(
            status: ReplicationTaskStatus.pending,
            retryCount: 0,
            errorMessage: null,
          ),
        );
        break;

      case FailureHandlingStrategy.skip:
        // 更新任务状态为 failed 并移入失败池
        await queueNotifier.moveToFailedPool(currentTaskId);
        break;

      case FailureHandlingStrategy.pauseAndWait:
        // 更新任务状态为 failed
        await queueNotifier.updateTaskStatus(
          currentTaskId,
          ReplicationTaskStatus.failed,
        );
        // 暂停执行
        state = state.copyWith(
          status: QueueExecutionStatus.paused,
          failedCount: state.failedCount + 1,
          failedTaskIds: [...state.failedTaskIds, currentTaskId],
          retryCount: 0,
        );
        await _saveToStorage();
        return;
    }

    state = state.copyWith(
      failedCount: state.failedCount + 1,
      failedTaskIds: [...state.failedTaskIds, currentTaskId],
      retryCount: 0,
    );

    await _saveToStorage();

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
        currentTaskId: null,
      );
      _saveToStorage();

      // 触发队列完成通知
      _triggerQueueCompletionNotification();
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

    // 注意：这里不更新任务状态，任务保持 pending 状态
    // 只有在自动执行模式下自动触发生成时才更新为 running

    // 自动执行模式下自动触发
    if (state.autoExecuteEnabled) {
      _triggerAutoGenerate();
    }
  }

  /// 手动重试指定的失败任务
  Future<void> retryFailedTask(String taskId) async {
    final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);
    await queueNotifier.retryFailedTask(taskId);

    // 移除出失败列表
    state = state.copyWith(
      failedTaskIds: state.failedTaskIds.where((id) => id != taskId).toList(),
    );
    await _saveToStorage();
  }

  /// 将失败任务重新入队
  Future<void> requeueFailedTask(String taskId) async {
    final queueNotifier = ref.read(replicationQueueNotifierProvider.notifier);
    await queueNotifier.requeueFailedTask(taskId);

    // 移除出失败列表
    state = state.copyWith(
      failedTaskIds: state.failedTaskIds.where((id) => id != taskId).toList(),
    );
    await _saveToStorage();
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

  /// 触发队列完成音效
  void _triggerQueueCompletionNotification() {
    final settings = ref.read(notificationSettingsNotifierProvider);
    if (!settings.soundEnabled) return;

    // 使用 Future.microtask 避免在同步方法中直接 await
    Future.microtask(() async {
      await NotificationService.instance.notifyGenerationComplete(
        playSound: settings.soundEnabled,
        customSoundPath: settings.customSoundPath,
      );
    });
  }
}

/// 队列设置 Provider（从本地存储读取）
@riverpod
QueueSettings queueSettings(Ref ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final executionState = ref.watch(queueExecutionNotifierProvider);

  return QueueSettings(
    retryCount: storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10,
    retryIntervalSeconds: storage.getSetting<double>(
          StorageKeys.queueRetryInterval,
          defaultValue: 1.0,
        ) ??
        1.0,
    autoExecuteEnabled: executionState.autoExecuteEnabled,
    taskIntervalSeconds: executionState.taskIntervalSeconds,
    failureStrategy: executionState.failureStrategy,
  );
}
