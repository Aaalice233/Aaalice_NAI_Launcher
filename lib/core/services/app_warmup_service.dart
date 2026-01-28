import 'dart:async';

import '../utils/app_logger.dart';
import '../../data/models/warmup/warmup_metrics.dart';

/// 预加载任务
class WarmupTask {
  /// 任务名称（显示用）
  final String name;

  /// 异步任务
  final Future<void> Function() task;

  /// 权重（计算进度）
  final int weight;

  /// 自定义超时时间（可选，默认使用全局超时）
  final Duration? timeout;

  const WarmupTask({
    required this.name,
    required this.task,
    this.weight = 1,
    this.timeout,
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

  /// 任务指标列表
  final List<WarmupTaskMetrics>? metrics;

  const WarmupProgress({
    required this.progress,
    required this.currentTask,
    this.isComplete = false,
    this.error,
    this.metrics,
  });

  factory WarmupProgress.initial() => const WarmupProgress(
        progress: 0.0,
        currentTask: 'warmup_preparing',
      );

  factory WarmupProgress.complete({List<WarmupTaskMetrics>? metrics}) =>
      WarmupProgress(
        progress: 1.0,
        currentTask: 'warmup_complete',
        isComplete: true,
        metrics: metrics,
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
  /// 任务超时时间
  static const _taskTimeout = Duration(seconds: 5);

  /// 网络任务超时时间
  // ignore: unused_field
  static const _networkTimeout = Duration(seconds: 2);

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
    final List<WarmupTaskMetrics> metrics = [];

    yield WarmupProgress.initial();

    for (final task in _tasks) {
      // 报告当前任务
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: task.name,
      );

      // 创建计时器
      final stopwatch = Stopwatch()..start();

      try {
        // 执行任务（使用任务级超时或全局超时）
        final taskTimeout = task.timeout ?? _taskTimeout;
        await task.task().timeout(taskTimeout);

        stopwatch.stop();

        // 记录成功的任务指标
        metrics.add(
          WarmupTaskMetrics.create(
            taskName: task.name,
            durationMs: stopwatch.elapsedMilliseconds,
            status: WarmupTaskStatus.success,
          ),
        );
      } catch (e) {
        stopwatch.stop();

        // 任务失败时继续执行其他任务，但记录错误和指标
        AppLogger.w('Warmup task "${task.name}" failed: $e', 'AppWarmup');

        // 记录失败的任务指标
        metrics.add(
          WarmupTaskMetrics.create(
            taskName: task.name,
            durationMs: stopwatch.elapsedMilliseconds,
            status: WarmupTaskStatus.failed,
            errorMessage: e.toString(),
          ),
        );
      }

      // 更新完成权重
      completedWeight += task.weight;

      // 报告进度
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: task.name,
      );
    }

    // 完成，传递指标
    yield WarmupProgress.complete(metrics: metrics);
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
