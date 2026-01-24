import 'dart:async';

import '../utils/app_logger.dart';

/// 预加载任务
class WarmupTask {
  /// 任务名称（显示用）
  final String name;

  /// 异步任务
  final Future<void> Function() task;

  /// 权重（计算进度）
  final int weight;

  const WarmupTask({
    required this.name,
    required this.task,
    this.weight = 1,
  });
}

/// 预加载进度
class WarmupProgress {
  /// 当前进度 (0.0 - 1.0)
  final double progress;

  /// 当前任务名称
  final String currentTask;

  /// 是否完成
  final bool isComplete;

  /// 错误信息
  final String? error;

  const WarmupProgress({
    required this.progress,
    required this.currentTask,
    this.isComplete = false,
    this.error,
  });

  factory WarmupProgress.initial() => const WarmupProgress(
        progress: 0.0,
        currentTask: 'warmup_preparing',
      );

  factory WarmupProgress.complete() => const WarmupProgress(
        progress: 1.0,
        currentTask: 'warmup_complete',
        isComplete: true,
      );

  factory WarmupProgress.error(String message) => WarmupProgress(
        progress: 0.0,
        currentTask: message,
        error: message,
      );
}

/// 应用预加载服务
/// 管理预加载任务的注册和执行
class AppWarmupService {
  final List<WarmupTask> _tasks = [];

  /// 注册预加载任务
  void registerTask(WarmupTask task) {
    _tasks.add(task);
  }

  /// 注册多个预加载任务
  void registerTasks(List<WarmupTask> tasks) {
    _tasks.addAll(tasks);
  }

  /// 清空所有任务
  void clearTasks() {
    _tasks.clear();
  }

  /// 获取总权重
  int get _totalWeight => _tasks.fold(0, (sum, task) => sum + task.weight);

  /// 执行所有预加载任务
  /// 返回进度流
  Stream<WarmupProgress> run() async* {
    if (_tasks.isEmpty) {
      yield WarmupProgress.complete();
      return;
    }

    final totalWeight = _totalWeight;
    int completedWeight = 0;

    yield WarmupProgress.initial();

    for (final task in _tasks) {
      // 报告当前任务
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: task.name,
      );

      try {
        // 执行任务
        await task.task();
      } catch (e) {
        // 任务失败时继续执行其他任务，但记录错误
        // 可以根据需求改为失败时停止
        AppLogger.w('Warmup task "${task.name}" failed: $e', 'AppWarmup');
      }

      // 更新完成权重
      completedWeight += task.weight;

      // 报告进度
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: task.name,
      );
    }

    // 完成
    yield WarmupProgress.complete();
  }

  /// 同步执行所有预加载任务（不返回进度）
  Future<void> runSync() async {
    for (final task in _tasks) {
      try {
        await task.task();
      } catch (e) {
        AppLogger.w('Warmup task "${task.name}" failed: $e', 'AppWarmup');
      }
    }
  }
}
