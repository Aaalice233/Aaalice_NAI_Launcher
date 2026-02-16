import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/app_state_storage.dart';
import '../../core/storage/crash_recovery_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/models/queue/replication_task.dart';
import 'image_generation_provider.dart';
import 'pending_prompt_provider.dart';
import 'replication_queue_provider.dart';
import 'character_prompt_provider.dart';

part 'queue_execution_provider.g.dart';

/// 队列执行状态
enum QueueExecutionStatus {
  /// 空闲，等待用户触发
  idle,

  /// 已填充提示词，等待用户点击生成
  ready,

  /// 正在执行
  running,

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

  const QueueExecutionState({
    this.status = QueueExecutionStatus.idle,
    this.completedCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.currentTaskId,
    this.retryCount = 0,
    this.failedTaskIds = const [],
  });

  QueueExecutionState copyWith({
    QueueExecutionStatus? status,
    int? completedCount,
    int? failedCount,
    int? skippedCount,
    String? currentTaskId,
    int? retryCount,
    List<String>? failedTaskIds,
  }) {
    return QueueExecutionState(
      status: status ?? this.status,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      currentTaskId: currentTaskId ?? this.currentTaskId,
      retryCount: retryCount ?? this.retryCount,
      failedTaskIds: failedTaskIds ?? this.failedTaskIds,
    );
  }

  bool get isRunning => status == QueueExecutionStatus.running;
  bool get isReady => status == QueueExecutionStatus.ready;
}

/// 队列设置
class QueueSettings {
  final int retryCount;
  final double retryIntervalSeconds;

  const QueueSettings({
    this.retryCount = 10,
    this.retryIntervalSeconds = 1.0,
  });

  Duration get retryInterval =>
      Duration(milliseconds: (retryIntervalSeconds * 1000).toInt());
}

/// 队列执行引擎 Provider
///
/// 管理复刻队列的自动执行，包括：
/// - 填充提示词到主界面
/// - 监听生成完成事件
/// - 自动处理下一项
/// - 错误重试机制
@Riverpod(keepAlive: true)
class QueueExecutionNotifier extends _$QueueExecutionNotifier {
  // 用于跟踪上一次的生成状态，以检测状态变化
  ImageGenerationState? _lastGenerationState;

  late final AppStateStorage _appStateStorage;
  late final CrashRecoveryService _crashRecoveryService;

  @override
  QueueExecutionState build() {
    // 初始化存储服务
    _appStateStorage = ref.read(appStateStorageProvider);
    _crashRecoveryService = ref.read(crashRecoveryServiceProvider);

    // 异步加载会话状态
    _initializeSessionState();

    // 使用 ref.watch 监听生成状态变化
    // 当状态变化时，provider 会重建，我们会检测到变化并处理
    final generationState = ref.watch(imageGenerationNotifierProvider);

    // 检测状态变化并处理（仅当状态真正改变时）
    if (_lastGenerationState?.status != generationState.status) {
      _onGenerationStateChanged(_lastGenerationState, generationState);
      _lastGenerationState = generationState;
    }

    return const QueueExecutionState();
  }

  /// 初始化会话状态
  ///
  /// 从存储加载上次会话的状态，用于崩溃恢复
  Future<void> _initializeSessionState() async {
    try {
      // 检查是否需要恢复（异常退出后）
      final shouldRecover = await _appStateStorage.shouldRecover();
      if (!shouldRecover) return;

      // 分析崩溃情况
      final analysis = await _crashRecoveryService.analyzeCrash();

      if (!analysis.hasCrashDetected || !analysis.canRecover) {
        // 清除过期的会话状态
        await _appStateStorage.clearQueueExecutionState();
        return;
      }

      final recoveryPoint = analysis.recoveryPoint;
      final sessionState = recoveryPoint?.sessionState;
      if (sessionState == null) return;

      // 如果有活跃的队列执行，恢复状态
      if (sessionState.hasActiveQueueExecution) {
        // 记录恢复尝试
        await _crashRecoveryService.logRecoveryAttempt(
          success: false,
          recoveredState: sessionState,
        );

        // 恢复执行状态
        state = state.copyWith(
          status: QueueExecutionStatus.ready,
          currentTaskId: sessionState.currentTaskId,
          completedCount: sessionState.currentQueueIndex,
        );

        // 填充当前任务的提示词
        if (sessionState.currentTaskId != null) {
          await _recoverCurrentTask(sessionState.currentTaskId!);
        }

        // 记录恢复成功
        await _crashRecoveryService.logRecoveryAttempt(
          success: true,
          recoveredState: sessionState,
        );
      }
    } catch (e) {
      // 初始化失败时静默处理，不影响主流程
    }
  }

  /// 恢复当前任务的提示词
  ///
  /// 在会话恢复时，根据任务ID填充对应的提示词到主界面
  Future<void> _recoverCurrentTask(String taskId) async {
    try {
      final queueState = ref.read(replicationQueueNotifierProvider);

      // 查找当前任务在队列中的位置
      final taskIndex = queueState.tasks.indexWhere((t) => t.id == taskId);

      if (taskIndex != -1) {
        // 任务仍在队列中，填充提示词
        final task = queueState.tasks[taskIndex];
        _fillPrompt(task);
      } else if (queueState.tasks.isNotEmpty) {
        // 任务可能已完成，填充下一个任务的提示词
        final nextTask = queueState.tasks.first;
        _fillPrompt(nextTask);
        state = state.copyWith(currentTaskId: nextTask.id);
      }
    } catch (e) {
      // 恢复失败时静默处理
    }
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
    );
  }

  /// 准备执行队列（填充第一项提示词）
  ///
  /// 当用户进入主界面且队列非空时调用
  void prepareNextTask() {
    if (state.status == QueueExecutionStatus.running) return;

    final queueState = ref.read(replicationQueueNotifierProvider);
    if (queueState.isEmpty) {
      state = state.copyWith(status: QueueExecutionStatus.idle);
      return;
    }

    final nextTask = queueState.tasks.first;
    _fillPrompt(nextTask);

    state = state.copyWith(
      status: QueueExecutionStatus.ready,
      currentTaskId: nextTask.id,
      retryCount: 0,
    );
  }

  /// 填充提示词到主界面
  void _fillPrompt(ReplicationTask task) {
    // 清空角色提示词
    ref.read(characterPromptNotifierProvider.notifier).clearAll();

    // 设置待填充提示词
    ref.read(pendingPromptNotifierProvider.notifier).set(
          prompt: task.prompt,
          negativePrompt: task.negativePrompt,
        );
  }

  /// 开始执行队列
  ///
  /// 当用户点击生成按钮后，由生成状态监听器自动触发
  Future<void> startExecution() async {
    if (state.status != QueueExecutionStatus.ready) return;

    state = state.copyWith(status: QueueExecutionStatus.running);

    // 记录队列执行开始，用于崩溃恢复
    await _recordQueueExecutionStart();
  }

  /// 停止执行队列
  Future<void> stopExecution() async {
    state = state.copyWith(
      status: QueueExecutionStatus.idle,
      currentTaskId: null,
    );

    // 清除队列执行状态
    await _recordQueueExecutionEnd(success: false);
  }

  /// 监听生成状态变化
  void _onGenerationStateChanged(
    ImageGenerationState? previous,
    ImageGenerationState next,
  ) {
    if (state.status != QueueExecutionStatus.running &&
        state.status != QueueExecutionStatus.ready) {
      return;
    }

    // 检测到开始生成，进入运行状态
    if (previous?.status != GenerationStatus.generating &&
        next.status == GenerationStatus.generating) {
      if (state.status == QueueExecutionStatus.ready) {
        state = state.copyWith(status: QueueExecutionStatus.running);
      }
      return;
    }

    // 生成完成
    if (previous?.status == GenerationStatus.generating &&
        next.status == GenerationStatus.completed) {
      _onTaskCompleted();
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

  /// 任务完成处理
  Future<void> _onTaskCompleted() async {
    // 从队列移除已完成的任务
    await ref.read(replicationQueueNotifierProvider.notifier).markCompleted();

    state = state.copyWith(
      completedCount: state.completedCount + 1,
      retryCount: 0,
    );

    // 记录队列执行进度
    await _recordQueueProgress();

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

      // 检查是否仍在运行
      if (state.status != QueueExecutionStatus.running) return;

      // 重新触发生成（需要用户手动点击或自动触发）
      // 这里我们保持 ready 状态，等待用户再次点击
      state = state.copyWith(status: QueueExecutionStatus.ready);
    } else {
      // 超过重试次数，跳过该任务
      final currentTaskId = state.currentTaskId;
      if (currentTaskId != null) {
        await ref
            .read(replicationQueueNotifierProvider.notifier)
            .markCompleted();

        state = state.copyWith(
          failedCount: state.failedCount + 1,
          failedTaskIds: [...state.failedTaskIds, currentTaskId],
          retryCount: 0,
        );
      }

      // 记录队列执行进度（包含失败）
      await _recordQueueProgress();

      // 处理下一个任务
      _processNextTask();
    }
  }

  /// 处理下一个任务
  Future<void> _processNextTask() async {
    final queueState = ref.read(replicationQueueNotifierProvider);

    if (queueState.isEmpty) {
      // 队列清空，执行完成
      state = state.copyWith(
        status: QueueExecutionStatus.completed,
        currentTaskId: null,
      );

      // 记录队列执行完成
      await _recordQueueExecutionEnd(success: true);
      return;
    }

    // 填充下一个任务的提示词
    final nextTask = queueState.tasks.first;
    _fillPrompt(nextTask);

    state = state.copyWith(
      status: QueueExecutionStatus.ready,
      currentTaskId: nextTask.id,
      retryCount: 0,
    );

    // 记录队列执行进度
    await _recordQueueProgress();
  }

  /// 重置执行状态
  Future<void> reset() async {
    state = const QueueExecutionState();

    // 清除队列执行状态
    await _recordQueueExecutionEnd(success: false);
  }

  // ==================== 会话状态持久化方法 ====================

  /// 记录队列执行开始
  ///
  /// 在队列开始执行时调用，用于崩溃恢复
  Future<void> _recordQueueExecutionStart() async {
    try {
      final currentTaskId = state.currentTaskId;
      if (currentTaskId == null) return;

      final queueState = ref.read(replicationQueueNotifierProvider);

      // 更新应用状态存储
      await _appStateStorage.recordQueueExecutionStart(
        taskId: currentTaskId,
        currentIndex: state.completedCount,
        totalTasks: queueState.count + state.completedCount,
      );

      // 创建崩溃恢复日志
      final sessionState = await _appStateStorage.loadSessionState();
      if (sessionState != null) {
        await _crashRecoveryService.logQueueStart(sessionState);
      }
    } catch (e) {
      // 静默处理，不影响主流程
    }
  }

  /// 记录队列执行进度
  ///
  /// 在每个任务完成时调用
  Future<void> _recordQueueProgress() async {
    try {
      // 更新应用状态存储
      await _appStateStorage.updateQueueExecutionProgress(
        currentIndex: state.completedCount,
        currentTaskId: state.currentTaskId,
      );

      // 记录进度到崩溃恢复日志
      final sessionState = await _appStateStorage.loadSessionState();
      if (sessionState != null) {
        await _crashRecoveryService.logQueueProgress(
          sessionState,
          message: 'Task ${state.completedCount} completed',
        );
      }
    } catch (e) {
      // 静默处理
    }
  }

  /// 记录队列执行结束
  ///
  /// 在队列执行完成或出错时调用
  Future<void> _recordQueueExecutionEnd({required bool success}) async {
    try {
      if (success) {
        await _appStateStorage.clearQueueExecutionState();

        // 记录完成到崩溃恢复日志
        final sessionState = await _appStateStorage.loadSessionState();
        if (sessionState != null) {
          await _crashRecoveryService.logQueueComplete(sessionState);
        }
      }
    } catch (e) {
      // 静默处理
    }
  }

  /// 检查并恢复崩溃前的执行状态
  ///
  /// 在应用启动时调用，检测是否有未完成的队列任务需要恢复
  /// 返回 true 表示成功恢复，false 表示没有可恢复的状态
  Future<bool> checkAndRecover() async {
    try {
      // 分析崩溃情况
      final analysis = await _crashRecoveryService.analyzeCrash();

      if (!analysis.hasCrashDetected || !analysis.canRecover) {
        return false;
      }

      final recoveryPoint = analysis.recoveryPoint;
      final sessionState = recoveryPoint?.sessionState;
      if (sessionState == null) {
        return false;
      }

      // 如果有活跃的队列执行，恢复状态
      if (sessionState.hasActiveQueueExecution) {
        // 记录恢复尝试
        await _crashRecoveryService.logRecoveryAttempt(
          success: false,
          recoveredState: sessionState,
        );

        // 恢复执行状态
        state = state.copyWith(
          status: QueueExecutionStatus.ready,
          currentTaskId: sessionState.currentTaskId,
          completedCount: sessionState.currentQueueIndex,
        );

        // 记录恢复成功
        await _crashRecoveryService.logRecoveryAttempt(
          success: true,
          recoveredState: sessionState,
        );

        return true;
      }

      return false;
    } catch (e) {
      // 恢复失败时返回 false
      return false;
    }
  }
}

/// 队列设置 Provider（从本地存储读取）
@riverpod
QueueSettings queueSettings(Ref ref) {
  final storage = ref.watch(localStorageServiceProvider);
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
  );
}
