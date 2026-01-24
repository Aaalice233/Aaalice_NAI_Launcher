import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
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

  @override
  QueueExecutionState build() {
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

  /// 获取队列设置
  QueueSettings _getSettings() {
    final storage = ref.read(localStorageServiceProvider);
    final retryCount = storage.getSetting<int>(
      StorageKeys.queueRetryCount,
      defaultValue: 10,
    ) ?? 10;
    final retryInterval = storage.getSetting<double>(
      StorageKeys.queueRetryInterval,
      defaultValue: 1.0,
    ) ?? 1.0;
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
  void startExecution() {
    if (state.status != QueueExecutionStatus.ready) return;

    state = state.copyWith(status: QueueExecutionStatus.running);
  }

  /// 停止执行队列
  void stopExecution() {
    state = state.copyWith(
      status: QueueExecutionStatus.idle,
      currentTaskId: null,
    );
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
        await ref.read(replicationQueueNotifierProvider.notifier).markCompleted();

        state = state.copyWith(
          failedCount: state.failedCount + 1,
          failedTaskIds: [...state.failedTaskIds, currentTaskId],
          retryCount: 0,
        );
      }

      // 处理下一个任务
      _processNextTask();
    }
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
  }

  /// 重置执行状态
  void reset() {
    state = const QueueExecutionState();
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
    ) ?? 10,
    retryIntervalSeconds: storage.getSetting<double>(
      StorageKeys.queueRetryInterval,
      defaultValue: 1.0,
    ) ?? 1.0,
  );
}
