import 'dart:async';

import '../enums/warmup_phase.dart';
import '../utils/app_logger.dart';

/// 带阶段的预热任务
class PhasedWarmupTask {
  final String name;
  final String? displayName;
  final Future<void> Function() task;
  final int weight;
  final Duration? timeout;
  final WarmupPhase phase;

  const PhasedWarmupTask({
    required this.name,
    this.displayName,
    required this.task,
    required this.phase,
    this.weight = 1,
    this.timeout,
  });

  String get displayText => displayName ?? name;
}

/// 阶段任务组
class PhasedTaskGroup {
  final String name;
  final String? displayName;
  final List<PhasedWarmupTask> tasks;
  final bool parallel;
  final WarmupPhase phase;

  const PhasedTaskGroup({
    required this.name,
    this.displayName,
    required this.tasks,
    required this.phase,
    this.parallel = true,
  });

  int get weight => tasks.fold(0, (sum, t) => sum + t.weight);

  String get displayText => displayName ?? name;
}

/// 阶段进度
class PhaseProgress {
  final WarmupPhase phase;
  final double progress; // 0.0 - 1.0
  final String currentTask;
  final bool isComplete;
  final String? error;

  const PhaseProgress({
    required this.phase,
    required this.progress,
    required this.currentTask,
    this.isComplete = false,
    this.error,
  });

  factory PhaseProgress.initial(WarmupPhase phase) => PhaseProgress(
        phase: phase,
        progress: 0.0,
        currentTask: '${phase.displayName}准备中...',
      );
}

/// 带阶段划分的预热任务调度器
class WarmupTaskScheduler {
  final List<PhasedWarmupTask> _tasks = [];
  final List<PhasedTaskGroup> _groups = [];

  final Map<WarmupPhase, bool> _phaseComplete = {};
  final Map<WarmupPhase, StreamController<PhaseProgress>> _phaseControllers = {};

  /// 注册单个任务
  void registerTask(PhasedWarmupTask task) {
    _tasks.add(task);
    AppLogger.d('Registered task "${task.name}" for phase ${task.phase}', 'WarmupScheduler');
  }

  /// 注册任务组
  void registerGroup(PhasedTaskGroup group) {
    _groups.add(group);
    AppLogger.d(
      'Registered group "${group.name}" for phase ${group.phase} (${group.tasks.length} tasks)',
      'WarmupScheduler',
    );
  }

  /// 获取某阶段的任务
  List<PhasedWarmupTask> _getTasksForPhase(WarmupPhase phase) {
    return _tasks.where((t) => t.phase == phase).toList();
  }

  /// 获取某阶段的任务组
  List<PhasedTaskGroup> _getGroupsForPhase(WarmupPhase phase) {
    return _groups.where((g) => g.phase == phase).toList();
  }

  /// 计算阶段总权重
  int _getPhaseWeight(WarmupPhase phase) {
    final taskWeight = _getTasksForPhase(phase).fold(0, (sum, t) => sum + t.weight);
    final groupWeight = _getGroupsForPhase(phase).fold(0, (sum, g) => sum + g.weight);
    return taskWeight + groupWeight;
  }

  /// 执行指定阶段
  Stream<PhaseProgress> runPhase(WarmupPhase phase) async* {
    final controller = StreamController<PhaseProgress>.broadcast();
    _phaseControllers[phase] = controller;

    final tasks = _getTasksForPhase(phase);
    final groups = _getGroupsForPhase(phase);
    final totalWeight = _getPhaseWeight(phase);

    if (tasks.isEmpty && groups.isEmpty) {
      _phaseComplete[phase] = true;
      yield PhaseProgress(phase: phase, progress: 1.0, currentTask: 'complete', isComplete: true);
      controller.close();
      return;
    }

    yield PhaseProgress.initial(phase);
    controller.add(PhaseProgress.initial(phase));

    int completedWeight = 0;

    // 执行串行任务
    for (final task in tasks) {
      yield PhaseProgress(
        phase: phase,
        progress: completedWeight / totalWeight,
        currentTask: task.displayText,
      );

      await _executeTask(task);

      completedWeight += task.weight;
      final progress = PhaseProgress(
        phase: phase,
        progress: completedWeight / totalWeight,
        currentTask: task.displayText,
      );
      yield progress;
      controller.add(progress);
    }

    // 执行任务组
    for (final group in groups) {
      yield PhaseProgress(
        phase: phase,
        progress: completedWeight / totalWeight,
        currentTask: '${group.displayText}...',
      );

      if (group.parallel) {
        await _runGroupParallel(group);
      } else {
        for (final task in group.tasks) {
          await _executeTask(task);
        }
      }

      completedWeight += group.weight;
      final progress = PhaseProgress(
        phase: phase,
        progress: completedWeight / totalWeight,
        currentTask: '${group.displayText}完成',
      );
      yield progress;
      controller.add(progress);
    }

    final finalProgress = PhaseProgress(
      phase: phase,
      progress: 1.0,
      currentTask: 'complete',
      isComplete: true,
    );
    _phaseComplete[phase] = true;
    yield finalProgress;
    controller.add(finalProgress);
    controller.close();
  }

  /// 检查阶段是否完成
  bool isPhaseComplete(WarmupPhase phase) {
    return _phaseComplete[phase] ?? false;
  }

  /// 获取阶段进度流
  Stream<PhaseProgress>? getPhaseStream(WarmupPhase phase) {
    return _phaseControllers[phase]?.stream;
  }

  Future<void> _executeTask(PhasedWarmupTask task) async {
    try {
      final timeout = task.timeout ?? const Duration(seconds: 5);
      if (timeout == Duration.zero) {
        await task.task();
      } else {
        await task.task().timeout(timeout);
      }
      AppLogger.i('Task "${task.name}" completed', 'WarmupScheduler');
    } catch (e) {
      AppLogger.w('Task "${task.name}" failed: $e', 'WarmupScheduler');
      // 非关键阶段任务失败不抛出
      if (task.phase == WarmupPhase.critical) {
        rethrow;
      }
    }
  }

  Future<void> _runGroupParallel(PhasedTaskGroup group) async {
    await Future.wait(
      group.tasks.map((task) => _executeTask(task)),
      eagerError: false,
    );
  }

  /// 清空所有任务
  void clear() {
    _tasks.clear();
    _groups.clear();
    _phaseComplete.clear();
    for (final controller in _phaseControllers.values) {
      controller.close();
    }
    _phaseControllers.clear();
  }
}
