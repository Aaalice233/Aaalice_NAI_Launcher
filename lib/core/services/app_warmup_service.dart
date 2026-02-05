import 'dart:async';

import 'package:path_provider/path_provider.dart';

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

  /// 任务所属的组（用于并行执行，null表示串行）
  final String? group;

  const WarmupTask({
    required this.name,
    required this.task,
    this.weight = 1,
    this.timeout,
    this.group,
  });
}

/// 任务组配置
class WarmupTaskGroup {
  /// 组名称
  final String name;

  /// 组内任务
  final List<WarmupTask> tasks;

  /// 是否并行执行
  final bool parallel;

  /// 组权重（用于进度计算）
  int get weight => tasks.fold(0, (sum, t) => sum + t.weight);

  const WarmupTaskGroup({
    required this.name,
    required this.tasks,
    this.parallel = true,
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

/// 系统资源信息
class SystemResources {
  /// 可用内存（字节）
  final int? availableMemory;

  /// 总内存（字节）
  final int? totalMemory;

  /// 磁盘可用空间（字节）
  final int? freeDiskSpace;

  /// 是否内存充足
  bool get hasEnoughMemory =>
      availableMemory == null || (availableMemory ?? 0) > 100 * 1024 * 1024; // >100MB

  /// 是否磁盘空间充足
  bool get hasEnoughDiskSpace =>
      freeDiskSpace == null || (freeDiskSpace ?? 0) > 500 * 1024 * 1024; // >500MB

  const SystemResources({
    this.availableMemory,
    this.totalMemory,
    this.freeDiskSpace,
  });

  factory SystemResources.unknown() => const SystemResources();
}

/// 预热健康检查器
class WarmupHealthChecker {
  /// 检查系统资源
  static Future<SystemResources> checkResources() async {
    try {
      // 获取应用文档目录以检查磁盘空间
      final appDir = await getApplicationSupportDirectory();
      // 检查目录是否存在以验证磁盘可访问
      await appDir.exists();

      // 注意：Flutter 无法直接获取内存信息，这里提供框架
      // 如果需要精确内存信息，需要使用 platform channel 或 ffi
      return const SystemResources(
        freeDiskSpace: 1024 * 1024 * 1024, // 假设1GB（需要实际实现）
      );
    } catch (e) {
      AppLogger.w('Failed to check system resources: $e', 'WarmupHealth');
      return SystemResources.unknown();
    }
  }

  /// 预估剩余时间
  static Duration estimateRemainingTime(
    List<WarmupTaskMetrics> completed,
    int remainingWeight,
  ) {
    if (completed.isEmpty || remainingWeight <= 0) {
      return Duration.zero;
    }

    // 计算已完成任务的平均耗时
    final totalDurationMs = completed.fold<int>(
      0,
      (sum, m) => sum + m.durationMs,
    );
    final totalWeight = completed.fold<int>(
      0,
      (sum, m) {
        // 从任务名称推断权重（简单估计）
        // 实际实现应该在 metrics 中包含权重信息
        return sum + 1;
      },
    );

    if (totalWeight == 0) return Duration.zero;

    final avgMsPerWeight = totalDurationMs / totalWeight;
    final estimatedRemainingMs = avgMsPerWeight * remainingWeight;

    return Duration(milliseconds: estimatedRemainingMs.ceil());
  }

  /// 格式化时长显示
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}秒';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}分${duration.inSeconds % 60}秒';
    } else {
      return '${duration.inHours}小时${duration.inMinutes % 60}分';
    }
  }
}

/// 应用预加载服务
/// 管理预加载任务的注册和执行
class AppWarmupService {
  /// 任务超时时间
  static const _taskTimeout = Duration(seconds: 5);

  /// 网络任务超时时间（用于网络相关任务）
  static const networkTimeout = Duration(seconds: 3);

  /// 并行组超时时间
  static const _parallelGroupTimeout = Duration(seconds: 10);

  final List<WarmupTask> _tasks = [];
  final List<WarmupTaskGroup> _groups = [];

  /// 注册预加载任务
  void registerTask(WarmupTask task) {
    _tasks.add(task);
  }

  /// 注册多个预加载任务
  void registerTasks(List<WarmupTask> tasks) {
    _tasks.addAll(tasks);
  }

  /// 注册任务组（并行执行）
  void registerGroup(WarmupTaskGroup group) {
    _groups.add(group);
  }

  /// 清空所有任务
  void clearTasks() {
    _tasks.clear();
    _groups.clear();
  }

  /// 获取总权重（任务 + 组）
  int get _totalWeight {
    final taskWeight = _tasks.fold(0, (sum, task) => sum + task.weight);
    final groupWeight = _groups.fold(0, (sum, g) => sum + g.weight);
    return taskWeight + groupWeight;
  }

  /// 执行所有预加载任务
  /// 返回进度流
  Stream<WarmupProgress> run() async* {
    final allTasks = [..._tasks];
    // 将组内任务也加入列表
    for (final group in _groups) {
      allTasks.addAll(group.tasks);
    }

    if (allTasks.isEmpty) {
      yield WarmupProgress.complete();
      return;
    }

    final totalWeight = _totalWeight;
    int completedWeight = 0;
    final List<WarmupTaskMetrics> metrics = [];

    yield WarmupProgress.initial();

    // 1. 先执行串行任务
    for (final task in _tasks) {
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: task.name,
      );

      final taskMetrics = await _runTask(task);
      metrics.add(taskMetrics);

      completedWeight += task.weight;
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: task.name,
      );
    }

    // 2. 执行并行组
    for (final group in _groups) {
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: 'warmup_group_${group.name}',
      );

      if (group.parallel) {
        // 并行执行组内任务
        final groupMetrics = await _runTaskGroupParallel(group);
        metrics.addAll(groupMetrics);
      } else {
        // 串行执行组内任务
        for (final task in group.tasks) {
          final taskMetrics = await _runTask(task);
          metrics.add(taskMetrics);
        }
      }

      completedWeight += group.weight;
      yield WarmupProgress(
        progress: completedWeight / totalWeight,
        currentTask: 'warmup_group_${group.name}_complete',
      );
    }

    yield WarmupProgress.complete(metrics: metrics);
  }

  /// 执行单个任务
  Future<WarmupTaskMetrics> _runTask(WarmupTask task) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 如果 task.timeout 为 null，则使用默认超时
      // 如果 task.timeout 为 Duration.zero，则不设置超时（无限等待）
      final taskTimeout = task.timeout ?? _taskTimeout;
      if (taskTimeout == Duration.zero) {
        await task.task();
      } else {
        await task.task().timeout(taskTimeout);
      }

      stopwatch.stop();
      return WarmupTaskMetrics.create(
        taskName: task.name,
        durationMs: stopwatch.elapsedMilliseconds,
        status: WarmupTaskStatus.success,
      );
    } catch (e) {
      stopwatch.stop();
      AppLogger.w('Warmup task "${task.name}" failed: $e', 'AppWarmup');
      return WarmupTaskMetrics.create(
        taskName: task.name,
        durationMs: stopwatch.elapsedMilliseconds,
        status: WarmupTaskStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 并行执行任务组
  Future<List<WarmupTaskMetrics>> _runTaskGroupParallel(WarmupTaskGroup group) async {
    AppLogger.i('Running warmup group "${group.name}" in parallel (${group.tasks.length} tasks)', 'AppWarmup');

    final futures = group.tasks.map((task) async {
      final stopwatch = Stopwatch()..start();

      try {
        final taskTimeout = task.timeout ?? _taskTimeout;
        await task.task().timeout(taskTimeout);

        stopwatch.stop();
        return WarmupTaskMetrics.create(
          taskName: task.name,
          durationMs: stopwatch.elapsedMilliseconds,
          status: WarmupTaskStatus.success,
        );
      } catch (e) {
        stopwatch.stop();
        AppLogger.w('Warmup task "${task.name}" in group "${group.name}" failed: $e', 'AppWarmup');
        return WarmupTaskMetrics.create(
          taskName: task.name,
          durationMs: stopwatch.elapsedMilliseconds,
          status: WarmupTaskStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }).toList();

    // 使用 Future.wait 并行执行，设置组级超时
    try {
      return await Future.wait(futures).timeout(_parallelGroupTimeout);
    } on TimeoutException {
      AppLogger.w('Warmup group "${group.name}" timed out', 'AppWarmup');
      // 返回已完成的任务指标，未完成的标记为超时
      return group.tasks.map((task) => WarmupTaskMetrics.create(
        taskName: task.name,
        durationMs: _parallelGroupTimeout.inMilliseconds,
        status: WarmupTaskStatus.failed,
        errorMessage: 'Group timeout',
      ),).toList();
    }
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
