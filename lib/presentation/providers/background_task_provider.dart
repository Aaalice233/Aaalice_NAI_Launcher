import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';

part 'background_task_provider.g.dart';

/// 后台任务状态
enum BackgroundTaskStatus {
  pending,
  running,
  paused,
  completed,
  failed,
}

/// 后台任务信息
class BackgroundTask {
  final String id;
  final String name;
  final String displayName;
  final BackgroundTaskStatus status;
  final double progress; // 0.0 - 1.0
  final String? message;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? error;

  const BackgroundTask({
    required this.id,
    required this.name,
    required this.displayName,
    this.status = BackgroundTaskStatus.pending,
    this.progress = 0.0,
    this.message,
    this.startTime,
    this.endTime,
    this.error,
  });

  BackgroundTask copyWith({
    String? id,
    String? name,
    String? displayName,
    BackgroundTaskStatus? status,
    double? progress,
    String? message,
    DateTime? startTime,
    DateTime? endTime,
    String? error,
  }) {
    return BackgroundTask(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      error: error ?? this.error,
    );
  }

  bool get isActive => status == BackgroundTaskStatus.running;
  bool get isDone =>
      status == BackgroundTaskStatus.completed ||
      status == BackgroundTaskStatus.failed;
  Duration? get elapsedTime {
    if (startTime == null) return null;
    return (endTime ?? DateTime.now()).difference(startTime!);
  }
}

/// 后台任务状态
class BackgroundTaskState {
  final List<BackgroundTask> tasks;
  final bool isPaused;

  const BackgroundTaskState({
    this.tasks = const [],
    this.isPaused = false,
  });

  BackgroundTaskState copyWith({
    List<BackgroundTask>? tasks,
    bool? isPaused,
  }) {
    return BackgroundTaskState(
      tasks: tasks ?? this.tasks,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  /// 正在运行的任务
  List<BackgroundTask> get runningTasks =>
      tasks.where((t) => t.status == BackgroundTaskStatus.running).toList();

  /// 等待中的任务
  List<BackgroundTask> get pendingTasks =>
      tasks.where((t) => t.status == BackgroundTaskStatus.pending).toList();

  /// 已完成的任务
  List<BackgroundTask> get completedTasks =>
      tasks.where((t) => t.status == BackgroundTaskStatus.completed).toList();

  /// 失败的任务
  List<BackgroundTask> get failedTasks =>
      tasks.where((t) => t.status == BackgroundTaskStatus.failed).toList();

  /// 总体进度
  double get overallProgress {
    if (tasks.isEmpty) return 1.0;
    return tasks.fold(0.0, (sum, t) => sum + t.progress) / tasks.length;
  }

  /// 是否所有任务完成
  bool get allComplete => tasks.every((t) => t.isDone);

  /// 是否有活跃任务
  bool get hasActiveTasks => tasks.any((t) => t.isActive);
}

@riverpod
class BackgroundTaskNotifier extends _$BackgroundTaskNotifier {
  final Map<String, Future<void> Function()> _taskExecutors = {};
  final Map<String, StreamSubscription<void>> _runningTasks = {};

  @override
  BackgroundTaskState build() {
    ref.onDispose(() {
      // 清理正在运行的任务
      for (final subscription in _runningTasks.values) {
        subscription.cancel();
      }
      _runningTasks.clear();
    });
    return const BackgroundTaskState();
  }

  /// 注册后台任务
  void registerTask(
    String id,
    String displayName,
    Future<void> Function() executor,
  ) {
    _taskExecutors[id] = executor;

    final existingIndex = state.tasks.indexWhere((t) => t.id == id);
    if (existingIndex >= 0) return; // 已存在

    final newTask = BackgroundTask(
      id: id,
      name: id,
      displayName: displayName,
    );

    state = state.copyWith(tasks: [...state.tasks, newTask]);
    AppLogger.i('Registered background task: $id', 'BackgroundTask');
  }

  /// 开始执行所有待执行的任务
  Future<void> startAll() async {
    AppLogger.i('startAll called, executors: ${_taskExecutors.length}, tasks: ${state.tasks.length}', 'BackgroundTask');

    if (state.isPaused) {
      AppLogger.d('Background tasks are paused, resuming...', 'BackgroundTask');
      state = state.copyWith(isPaused: false);
    }

    for (final entry in _taskExecutors.entries) {
      final id = entry.key;
      final executor = entry.value;

      final taskIndex = state.tasks.indexWhere((t) => t.id == id);
      if (taskIndex < 0) continue;

      final task = state.tasks[taskIndex];
      if (task.status != BackgroundTaskStatus.pending) continue;

      _startTask(id, executor);
    }
  }

  /// 开始执行单个任务
  void _startTask(String id, Future<void> Function() executor) {
    final taskIndex = state.tasks.indexWhere((t) => t.id == id);
    if (taskIndex < 0) return;

    // 更新状态为运行中
    final updatedTask = state.tasks[taskIndex].copyWith(
      status: BackgroundTaskStatus.running,
      startTime: DateTime.now(),
    );
    final newTasks = [...state.tasks];
    newTasks[taskIndex] = updatedTask;
    state = state.copyWith(tasks: newTasks);

    AppLogger.i('Starting background task: $id', 'BackgroundTask');

    // 执行任务
    executor().then(
      (_) => _onTaskComplete(id),
      onError: (error) => _onTaskComplete(id, error: error.toString()),
    );
  }

  void _onTaskComplete(String id, {String? error}) {
    final taskIndex = state.tasks.indexWhere((t) => t.id == id);
    if (taskIndex < 0) return;

    _runningTasks.remove(id)?.cancel();

    final updatedTask = state.tasks[taskIndex].copyWith(
      status: error != null
          ? BackgroundTaskStatus.failed
          : BackgroundTaskStatus.completed,
      progress: 1.0,
      endTime: DateTime.now(),
      error: error,
    );

    final newTasks = [...state.tasks];
    newTasks[taskIndex] = updatedTask;
    state = state.copyWith(tasks: newTasks);

    if (error != null) {
      AppLogger.w('Background task $id failed: $error', 'BackgroundTask');
    } else {
      AppLogger.i('Background task $id completed', 'BackgroundTask');
    }
  }

  /// 更新任务进度
  void updateProgress(String id, double progress, {String? message}) {
    if (state.isPaused) return;

    final taskIndex = state.tasks.indexWhere((t) => t.id == id);
    if (taskIndex < 0) return;

    final updatedTask = state.tasks[taskIndex].copyWith(
      progress: progress.clamp(0.0, 1.0),
      message: message,
    );

    final newTasks = [...state.tasks];
    newTasks[taskIndex] = updatedTask;
    state = state.copyWith(tasks: newTasks);
  }

  /// 暂停后台任务
  void pause() {
    state = state.copyWith(isPaused: true);
    AppLogger.i('Background tasks paused', 'BackgroundTask');
  }

  /// 恢复后台任务
  void resume() {
    state = state.copyWith(isPaused: false);
    AppLogger.i('Background tasks resumed', 'BackgroundTask');
    startAll();
  }

  /// 重试失败的任务
  Future<void> retryFailed() async {
    for (final task in state.failedTasks) {
      final executor = _taskExecutors[task.id];
      if (executor == null) continue;

      // 重置任务状态
      final taskIndex = state.tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex < 0) continue;

      final resetTask = state.tasks[taskIndex].copyWith(
        status: BackgroundTaskStatus.pending,
        progress: 0.0,
        error: null,
        startTime: null,
        endTime: null,
      );

      final newTasks = [...state.tasks];
      newTasks[taskIndex] = resetTask;
      state = state.copyWith(tasks: newTasks);

      // 重新执行
      _startTask(task.id, executor);
    }
  }

  /// 立即执行某个任务（用户主动触发）
  Future<void> runImmediately(String id) async {
    final executor = _taskExecutors[id];
    if (executor == null) {
      AppLogger.w('Task $id not found', 'BackgroundTask');
      return;
    }

    // 取消现有任务（如果在运行）
    _runningTasks.remove(id)?.cancel();

    // 重置状态
    final taskIndex = state.tasks.indexWhere((t) => t.id == id);
    if (taskIndex >= 0) {
      final resetTask = state.tasks[taskIndex].copyWith(
        status: BackgroundTaskStatus.pending,
        progress: 0.0,
        error: null,
      );
      final newTasks = [...state.tasks];
      newTasks[taskIndex] = resetTask;
      state = state.copyWith(tasks: newTasks);
    }

    // 立即执行
    _startTask(id, executor);
  }

  /// 清空所有任务
  void clear() {
    for (final subscription in _runningTasks.values) {
      subscription.cancel();
    }
    _runningTasks.clear();
    _taskExecutors.clear();
    state = const BackgroundTaskState();
  }
}
