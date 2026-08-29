import 'dart:async';
import 'dart:ui' as ui;

import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/proxy_service.dart';
import '../../core/enums/warmup_phase.dart';
import '../../core/database/database.dart';
import '../../core/services/warmup_task_scheduler.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import 'auth_provider.dart';
import 'font_provider.dart';
import 'prompt_config_provider.dart';
import 'subscription_provider.dart';
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
  bool _postWarmupStarted = false;

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

  // 【修复】移除了 _configureImageCache 方法
  // Image Cache 配置已在 main.dart 中统一处理（200MB）

  Future<void> _preloadFonts() async {
    final fontConfig = ref.read(fontNotifierProvider);
    if (fontConfig.source != FontSource.google ||
        fontConfig.fontFamily.isEmpty) {
      AppLogger.i('Using system font, skip preload', 'Warmup');
      return;
    }

    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.getFont(fontConfig.fontFamily),
      ]);
      AppLogger.i('Preloaded Google Font: ${fontConfig.fontFamily}', 'Warmup');
    } catch (e) {
      AppLogger.w('Font preload failed: $e', 'Warmup');
    }
  }

  Future<void> _warmupImageEditor() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = const ui.Color(0xFF000000);
      canvas.drawCircle(ui.Offset.zero, 10, paint);
      final picture = recorder.endRecording();
      final image = await picture.toImage(50, 50);
      image.dispose();
      picture.dispose();
      AppLogger.i('Image editor canvas warmed up', 'Warmup');
    } catch (e) {
      AppLogger.w('Image editor warmup failed: $e', 'Warmup');
    }
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

  /// 检查网络环境（最多尝试2次，失败不阻塞启动）
  ///
  /// 总超时控制在 8 秒内（调度器 timeout），避免被强制终止
  Future<void> _checkNetworkEnvironment() async {
    const maxAttempts = 2;
    const timeout = Duration(seconds: 3);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      state = state.copyWith(
        subTaskMessage: 'warmup_networkCheck_attempt|$attempt|$maxAttempts',
      );

      try {
        final result = await ProxyService.testNovelAIConnection(
          timeout: timeout,
        );

        if (result.success) {
          AppLogger.i(
            'Network check successful: ${result.latencyMs}ms',
            'Warmup',
          );
          state = state.copyWith(
            subTaskMessage: 'warmup_networkCheck_success|${result.latencyMs}',
          );
          await Future.delayed(const Duration(milliseconds: 300));
          return;
        }

        AppLogger.w(
          'Network check attempt $attempt/$maxAttempts failed: ${result.errorMessage}',
          'Warmup',
        );
      } catch (e) {
        AppLogger.w(
          'Network check attempt $attempt/$maxAttempts error: $e',
          'Warmup',
        );
      }

      if (attempt >= maxAttempts) {
        AppLogger.w(
          'Network check reached max attempts, continuing offline',
          'Warmup',
        );
        state = state.copyWith(subTaskMessage: 'warmup_networkCheck_timeout');
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ===========================================================================
  // 三阶段预热架构
  // ===========================================================================

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

  /// 主应用首帧完成后再启动非关键任务，避免争用页面切换帧。
  void startPostWarmupTasks() {
    if (_postWarmupStarted || !state.isComplete) return;
    _postWarmupStarted = true;
    if (!ref.read(startupInitializationTasksProvider).enablePostWarmupTasks) {
      return;
    }
    _startNonCriticalWarmup();
  }

  void _startNonCriticalWarmup() {
    final tasks = <(String, Future<void> Function())>[
      ('Font preload', _preloadFonts),
      ('Image editor warmup', _warmupImageEditor),
      ('Network check', _checkNetworkEnvironment),
      ('Prompt config load', _loadPromptConfig),
      ('Gallery file count', _countGalleryFiles),
      ('Subscription cache load', _loadSubscriptionCached),
    ];
    for (final task in tasks) {
      unawaited(_runNonCriticalTask(task.$1, task.$2));
    }
  }

  Future<void> _runNonCriticalTask(
    String name,
    Future<void> Function() task,
  ) async {
    try {
      await task();
      AppLogger.d('$name completed', 'Warmup');
    } catch (e, stack) {
      AppLogger.e('$name failed', e, stack, 'Warmup');
    }
  }

  /// 加载提示词配置
  Future<void> _loadPromptConfig() async {
    final notifier = ref.read(promptConfigNotifierProvider.notifier);
    await notifier.whenLoaded.timeout(const Duration(seconds: 8));
  }

  /// 统计画廊文件数
  Future<void> _countGalleryFiles() async {
    try {
      final count = await GalleryFolderRepository.instance.getTotalImageCount();
      AppLogger.i('Gallery file count: $count', 'Warmup');
    } catch (e) {
      AppLogger.w('Gallery file count failed: $e', 'Warmup');
    }
  }

  /// 加载缓存的订阅信息（快速）
  Future<void> _loadSubscriptionCached() async {
    try {
      final authState = ref.read(authNotifierProvider);
      if (!authState.isAuthenticated) {
        AppLogger.i('User not authenticated, skip subscription', 'Warmup');
        return;
      }
      // 仅读取缓存，不强制网络请求
      final subState = ref.read(subscriptionNotifierProvider);
      if (!subState.isLoaded) {
        // 尝试快速加载，超时则跳过
        await ref
            .read(subscriptionNotifierProvider.notifier)
            .fetchSubscription()
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
      }
    } catch (e) {
      AppLogger.w('Subscription load failed (non-critical): $e', 'Warmup');
    }
  }
}
