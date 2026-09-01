import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/database.dart';
import '../../core/enums/warmup_phase.dart';
import '../../core/services/warmup_task_scheduler.dart';
import '../../core/utils/app_logger.dart';
import 'startup_initialization_provider.dart';

part 'warmup_provider.g.dart';

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

  factory WarmupProgress.initial() =>
      const WarmupProgress(progress: 0.0, currentTask: 'warmup_preparing');

  factory WarmupProgress.complete() => const WarmupProgress(
    progress: 1.0,
    currentTask: 'warmup_complete',
    isComplete: true,
  );

  factory WarmupProgress.error(String message) =>
      WarmupProgress(progress: 0.0, currentTask: message, error: message);
}

class WarmupLocalizedException implements Exception {
  const WarmupLocalizedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 预加载状态
class WarmupState {
  final WarmupProgress progress;
  final bool isComplete;
  final String? error;

  /// 子任务详细消息（如"下载中... 50%"）
  final String? subTaskMessage;

  const WarmupState({
    required this.progress,
    this.isComplete = false,
    this.error,
    this.subTaskMessage,
  });

  factory WarmupState.initial() =>
      WarmupState(progress: WarmupProgress.initial());

  factory WarmupState.complete() =>
      WarmupState(progress: WarmupProgress.complete(), isComplete: true);

  WarmupState copyWith({
    WarmupProgress? progress,
    bool? isComplete,
    String? error,
    String? subTaskMessage,
    bool clearError = false,
    bool clearSubTaskMessage = false,
  }) {
    return WarmupState(
      progress: progress ?? this.progress,
      isComplete: isComplete ?? this.isComplete,
      error: clearError ? null : error ?? this.error,
      subTaskMessage: clearSubTaskMessage
          ? null
          : subTaskMessage ?? this.subTaskMessage,
    );
  }
}

/// 预加载状态 Notifier
@riverpod
class WarmupNotifier extends _$WarmupNotifier {
  late WarmupTaskScheduler _scheduler;
  Completer<void> _completer = Completer<void>();
  bool _isRunning = false;

  @override
  WarmupState build() {
    _scheduler = WarmupTaskScheduler();
    _registerTasks();
    return WarmupState.initial();
  }

  /// 等待当前预热尝试结束，结果通过 [state] 判断。
  Future<void> get whenComplete => _completer.future;

  /// Splash 首帧完成后才开始关键初始化。
  void start() {
    if (_isRunning || state.isComplete) return;
    unawaited(_startWarmup());
  }

  // ===== 任务实现方法 =====

  Future<void> _initializeRuntimeConfiguration() async {
    AppLogger.i('开始运行时配置...', 'Warmup');
    await ref
        .read(startupInitializationTasksProvider)
        .initializeRuntimeConfiguration();
    AppLogger.i('运行时配置完成', 'Warmup');
  }

  Future<void> _runDataMigration() async {
    AppLogger.i('开始数据迁移阶段...', 'Warmup');
    final tasks = ref.read(startupInitializationTasksProvider);
    final result = await tasks.runDataMigration((stage, progress) {
      state = state.copyWith(
        subTaskMessage: '$stage (${(progress * 100).toInt()}%)',
      );
    });

    state = state.copyWith(clearSubTaskMessage: true);

    if (!result.isSuccess) {
      throw WarmupLocalizedException(
        'warmup_dataMigrationFailed|${result.error ?? result}',
      );
    }
    AppLogger.i('数据迁移完成: $result', 'Warmup');
  }

  Future<void> _initializeDatabase() async {
    AppLogger.i('开始数据库初始化...', 'Warmup');
    await ref.read(startupInitializationTasksProvider).initializeDatabase();
    AppLogger.i('数据库初始化完成', 'Warmup');
  }

  Future<void> _initializeCriticalServices() async {
    AppLogger.i('开始关键服务初始化...', 'Warmup');
    await ref
        .read(startupInitializationTasksProvider)
        .initializeCriticalServices();
    AppLogger.i('关键服务初始化完成', 'Warmup');
  }

  Future<void> _initializeMainShellData() async {
    AppLogger.i('开始主页交互数据初始化...', 'Warmup');
    await ref
        .read(startupInitializationTasksProvider)
        .initializeMainShellData();
    AppLogger.i('主页交互数据初始化完成', 'Warmup');
  }

  /// 重试预加载。失败的数据库 FutureProvider 必须失效后重新创建实例。
  void retry() {
    if (_isRunning) return;
    ref.invalidate(databaseManagerProvider);
    _scheduler = WarmupTaskScheduler();
    _completer = Completer<void>();
    state = WarmupState.initial();
    _registerTasks();
    start();
  }

  /// 注册进入主界面前必须成功的任务。它们严格串行，确保迁移早于数据库打开。
  void _registerTasks() {
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_runtimeConfiguration',
        displayName: 'warmup_group_basicUI',
        phase: WarmupPhase.critical,
        weight: 1,
        timeout: Duration.zero,
        task: _initializeRuntimeConfiguration,
      ),
    );
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_dataMigration',
        displayName: 'warmup_dataMigration',
        phase: WarmupPhase.critical,
        weight: 2,
        timeout: Duration.zero,
        task: _runDataMigration,
      ),
    );
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_unifiedDbInit',
        displayName: 'warmup_initUnifiedDatabase',
        phase: WarmupPhase.critical,
        weight: 4,
        timeout: Duration.zero,
        task: _initializeDatabase,
      ),
    );
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_criticalServices',
        displayName: 'warmup_group_basicUI',
        phase: WarmupPhase.critical,
        weight: 2,
        timeout: Duration.zero,
        task: _initializeCriticalServices,
      ),
    );
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_mainShellData',
        displayName: 'warmup_group_dataServices',
        phase: WarmupPhase.critical,
        weight: 2,
        timeout: Duration.zero,
        task: _initializeMainShellData,
      ),
    );
  }

  /// 开始预热流程。
  Future<void> _startWarmup() async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      await for (final progress in _scheduler.runPhase(WarmupPhase.critical)) {
        state = state.copyWith(
          progress: WarmupProgress(
            progress: progress.progress,
            currentTask: progress.currentTask,
          ),
          clearError: true,
          clearSubTaskMessage: true,
        );
      }

      state = WarmupState.complete();
      AppLogger.i('Warmup completed; entering main application', 'Warmup');
    } catch (e, stack) {
      AppLogger.e('Warmup failed', e, stack, 'Warmup');
      state = state.copyWith(
        error: e.toString(),
        progress: WarmupProgress.error(e.toString()),
      );
    } finally {
      _isRunning = false;
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    }
  }
}
