import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/network/proxy_service.dart';
import '../../core/enums/warmup_phase.dart';
import '../../core/services/app_warmup_service.dart';
import '../../core/services/cooccurrence_service.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/data_migration_service.dart';
import '../../core/services/translation/translation_providers.dart';
import '../../core/services/unified_tag_database.dart';
import '../../core/services/warmup_task_scheduler.dart';
import 'background_task_provider.dart';
import 'data_source_cache_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/local_gallery_repository.dart';
import 'auth_provider.dart';
import 'font_provider.dart';
import 'prompt_config_provider.dart';
import 'subscription_provider.dart';
import '../../data/services/vibe_library_migration_service.dart';

part 'warmup_provider.g.dart';

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

  factory WarmupState.initial() => WarmupState(
        progress: WarmupProgress.initial(),
      );

  factory WarmupState.complete() => WarmupState(
        progress: WarmupProgress.complete(),
        isComplete: true,
      );

  WarmupState copyWith({
    WarmupProgress? progress,
    bool? isComplete,
    String? error,
    String? subTaskMessage,
  }) {
    return WarmupState(
      progress: progress ?? this.progress,
      isComplete: isComplete ?? this.isComplete,
      error: error ?? this.error,
      subTaskMessage: subTaskMessage ?? this.subTaskMessage,
    );
  }
}

/// 预加载状态 Notifier
@riverpod
class WarmupNotifier extends _$WarmupNotifier {
  late WarmupTaskScheduler _scheduler;
  StreamSubscription<PhaseProgress>? _phaseSubscription;
  final _completer = Completer<void>();

  @override
  WarmupState build() {
    ref.onDispose(() {
      _phaseSubscription?.cancel();
    });

    _scheduler = WarmupTaskScheduler();
    _registerTasks();

    // 延迟后台任务注册到 build 完成后，避免修改其他 provider
    Future.microtask(_registerBackgroundPhaseTasks);

    _startWarmup();

    return WarmupState.initial();
  }

  /// 等待预热完成
  Future<void> get whenComplete => _completer.future;

  // ===== 任务实现方法 =====

  Future<void> _runDataMigration() async {
    AppLogger.i('开始数据迁移阶段...', 'Warmup');
    final migrationService = DataMigrationService.instance;

    migrationService.onProgress = (stage, progress) {
      state = state.copyWith(subTaskMessage: '$stage (${(progress * 100).toInt()}%)');
    };

    final result = await migrationService.migrateAll();
    migrationService.onProgress = null;

    await _runVibeLibraryMigration();
    state = state.copyWith(subTaskMessage: null);

    if (result.isSuccess) {
      AppLogger.i('数据迁移完成: $result', 'Warmup');
    } else {
      AppLogger.w('数据迁移部分失败: ${result.error}', 'Warmup');
    }
  }

  Future<void> _runVibeLibraryMigration() async {
    try {
      final vibeResult = await VibeLibraryMigrationService().migrateIfNeeded();
      if (vibeResult.success) {
        AppLogger.i('Vibe 库迁移完成，导出 ${vibeResult.exportedCount} 条', 'Warmup');
      } else {
        AppLogger.w('Vibe 库迁移失败: ${vibeResult.error}', 'Warmup');
      }
    } catch (e) {
      AppLogger.w('Vibe 库迁移异常: $e', 'Warmup');
    }
  }

  Future<void> _configureImageCache() async {
    PaintingBinding.instance.imageCache.maximumSize = 500;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
    // ignore: unused_local_variable
    final cacheManager = DanbooruImageCacheManager.instance;
    AppLogger.i('Image cache configured: max=500, maxBytes=100MB', 'Warmup');
  }

  Future<void> _preloadFonts() async {
    final fontConfig = ref.read(fontNotifierProvider);
    if (fontConfig.source != FontSource.google || fontConfig.fontFamily.isEmpty) {
      AppLogger.i('Using system font, skip preload', 'Warmup');
      return;
    }

    try {
      await GoogleFonts.pendingFonts([GoogleFonts.getFont(fontConfig.fontFamily)]);
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

  /// 重试预加载
  void retry() {
    _phaseSubscription?.cancel();
    _scheduler.clear();
    state = WarmupState.initial();
    _registerTasks();
    _startWarmup();
  }

  /// 检查网络环境（带超时）
  Future<void> _checkNetworkEnvironmentWithTimeout() async {
    const timeout = Duration(seconds: 30);
    const checkInterval = Duration(seconds: 2);
    const maxAttempts = 15; // 30秒 / 2秒 = 15次

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      state = state.copyWith(
        subTaskMessage: '正在检测网络连接... (尝试 ${attempt + 1}/$maxAttempts)',
      );

      final result = await ProxyService.testNovelAIConnection();
      if (result.success) {
        AppLogger.i('Network check successful: ${result.latencyMs}ms', 'Warmup');
        state = state.copyWith(
          subTaskMessage: '网络连接正常 (${result.latencyMs}ms)',
        );
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }

      AppLogger.w(
        'Network check attempt ${attempt + 1} failed: ${result.errorMessage}',
        'Warmup',
      );

      if (attempt < maxAttempts - 1) {
        await Future.delayed(checkInterval);
      }
    }

    // 超时后记录日志但不阻塞
    AppLogger.w(
      'Network check timeout after ${timeout.inSeconds}s, continuing offline',
      'Warmup',
    );
    state = state.copyWith(subTaskMessage: '网络检测超时，继续离线启动');
    await Future.delayed(const Duration(seconds: 1));
  }

  // ===========================================================================
  // 三阶段预热架构
  // ===========================================================================

  /// 注册所有预热任务
  void _registerTasks() {
    // ==== 阶段 1: Critical ====
    _registerCriticalPhaseTasks();

    // ==== 阶段 2: Quick ====
    _registerQuickPhaseTasks();

    // 注意: 阶段 3 (Background) 在 build() 完成后通过 Future.microtask 注册
    // 避免在 build() 中修改其他 provider
  }

  void _registerCriticalPhaseTasks() {
    // 1. 数据迁移
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_dataMigration',
        displayName: '数据迁移',
        phase: WarmupPhase.critical,
        weight: 2,
        timeout: const Duration(seconds: 60),
        task: _runDataMigration,
      ),
    );

    // 2. 基础UI服务（并行）- 移除了数据库初始化，让它在 Quick 阶段异步执行
    _scheduler.registerGroup(
      PhasedTaskGroup(
        name: 'basicUI',
        displayName: '准备界面',
        phase: WarmupPhase.critical,
        parallel: true,
        tasks: [
          PhasedWarmupTask(
            name: 'warmup_imageCache',
            displayName: '图片缓存',
            phase: WarmupPhase.critical,
            weight: 1,
            task: _configureImageCache,
          ),
          PhasedWarmupTask(
            name: 'warmup_fonts',
            displayName: '字体加载',
            phase: WarmupPhase.critical,
            weight: 1,
            task: _preloadFonts,
          ),
          PhasedWarmupTask(
            name: 'warmup_imageEditor',
            displayName: '编辑器',
            phase: WarmupPhase.critical,
            weight: 1,
            task: _warmupImageEditor,
          ),
        ],
      ),
    );
  }

  void _registerQuickPhaseTasks() {
    // 1. 数据库初始化（移到 Quick 阶段，允许更长超时）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_unifiedDbInit',
        displayName: '初始化数据库',
        phase: WarmupPhase.quick,
        weight: 2,
        timeout: const Duration(seconds: 60),
        task: _initUnifiedDatabaseLightweight,
      ),
    );

    // 2. 共现数据初始化（轻量级检查，依赖数据库）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_cooccurrenceInit',
        displayName: '初始化共现数据',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 10),
        task: _initCooccurrenceData,
      ),
    );

    // 3. 轻量级网络检测（带超时）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_networkCheck',
        displayName: '检测网络',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 30),
        task: _checkNetworkEnvironmentWithTimeout,
      ),
    );

    // 4. 提示词配置
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_loadingPromptConfig',
        displayName: '加载提示词配置',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 10),
        task: _loadPromptConfig,
      ),
    );

    // 5. 画廊计数
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_galleryFileCount',
        displayName: '扫描画廊',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 3),
        task: _countGalleryFiles,
      ),
    );

    // 6. 订阅信息（仅缓存，不强制网络）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_subscription',
        displayName: '加载订阅信息',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 3),
        task: _loadSubscriptionCached,
      ),
    );
  }

  void _registerBackgroundPhaseTasks() {
    AppLogger.i('Registering background phase tasks...', 'Warmup');
    // 后台任务注册到 BackgroundTaskProvider
    // 实际执行在进入主界面后
    final backgroundNotifier = ref.read(backgroundTaskNotifierProvider.notifier);

    // 共现数据导入/更新（如果需要）
    backgroundNotifier.registerTask(
      'cooccurrence_import',
      '共现数据导入',
      () => _checkAndImportCooccurrence(),
    );

    // 翻译数据后台加载
    backgroundNotifier.registerTask(
      'translation_preload',
      '翻译数据',
      () => _preloadTranslationInBackground(),
    );

    // Danbooru标签后台加载
    backgroundNotifier.registerTask(
      'danbooru_tags_preload',
      '标签数据',
      () => _preloadDanbooruTagsInBackground(),
    );
  }

  /// 开始预热流程
  Future<void> _startWarmup() async {
    try {
      // 阶段 1: Critical
      await for (final progress in _scheduler.runPhase(WarmupPhase.critical)) {
        state = state.copyWith(
          progress: WarmupProgress(
            progress: progress.progress * 0.3, // critical 占 30%
            currentTask: progress.currentTask,
          ),
          subTaskMessage: progress.currentTask,
        );
      }

      // 阶段 2: Quick
      await for (final progress in _scheduler.runPhase(WarmupPhase.quick)) {
        state = state.copyWith(
          progress: WarmupProgress(
            progress: 0.3 + progress.progress * 0.7, // quick 占 70%
            currentTask: progress.currentTask,
          ),
          subTaskMessage: progress.currentTask,
        );
      }

      // 完成，进入主界面
      state = WarmupState.complete();
      _completer.complete();

      // 延迟1秒后启动后台任务，确保UI稳定和任务注册完成
      AppLogger.i('Warmup complete, scheduling background tasks in 1 second...', 'Warmup');
      await Future.delayed(const Duration(seconds: 1));
      AppLogger.i('Starting background tasks now', 'Warmup');
      Future.microtask(() {
        AppLogger.i('Microtask executing startAll', 'Warmup');
        ref.read(backgroundTaskNotifierProvider.notifier).startAll();
      });
    } catch (e, stack) {
      AppLogger.e('Warmup failed', e, stack, 'Warmup');
      state = state.copyWith(
        error: e.toString(),
        progress: WarmupProgress.error(e.toString()),
      );
      _completer.completeError(e);
    }
  }

  /// 轻量级初始化统一数据库（带进度反馈和错误处理）
  Future<void> _initUnifiedDatabaseLightweight() async {
    AppLogger.i('Initializing unified tag database (lightweight)...', 'Warmup');

    try {
      // 更新进度状态
      state = state.copyWith(subTaskMessage: '正在准备数据库文件...');

      final db = ref.read(unifiedTagDatabaseProvider);

      // 使用较长的超时，但允许用户看到进度
      await db.initialize().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          AppLogger.w('Database initialization timeout', 'Warmup');
          throw TimeoutException('数据库初始化超时，请检查磁盘空间');
        },
      );

      AppLogger.i('Unified tag database initialized', 'Warmup');
    } on TimeoutException {
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Database initialization failed', e, stack, 'Warmup');
      // 数据库初始化失败不应阻塞启动，记录错误但继续
      AppLogger.w('Continuing without database - will retry on first use', 'Warmup');
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
      final files = await LocalGalleryRepository.instance.getAllImageFiles();
      AppLogger.i('Gallery file count: ${files.length}', 'Warmup');
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
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
      }
    } catch (e) {
      AppLogger.w('Subscription load failed (non-critical): $e', 'Warmup');
    }
  }

  // ==== 后台任务方法 ====

  Future<void> _initCooccurrenceData() async {
    AppLogger.i('开始初始化共现数据...', 'Warmup');

    final service = ref.read(cooccurrenceServiceProvider);
    final unifiedDb = ref.read(unifiedTagDatabaseProvider);

    try {
      // 设置数据库连接
      service.setUnifiedDatabase(unifiedDb);

      // 统一初始化流程
      final isReady = await service.initializeUnified().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.w('共现数据初始化超时', 'Warmup');
          return false;
        },
      );

      if (isReady) {
        AppLogger.i('共现数据已就绪（SQLite）', 'Warmup');
      } else {
        AppLogger.i('共现数据需要后台导入', 'Warmup');
      }
    } catch (e, stack) {
      AppLogger.e('共现数据初始化失败', e, stack, 'Warmup');
    }
  }

  Future<void> _checkAndImportCooccurrence() async {
    final service = ref.read(cooccurrenceServiceProvider);

    await service.performBackgroundImport();
  }

  Future<void> _preloadTranslationInBackground() async {
    // 统一翻译服务在读取 provider 时自动初始化
    await ref.read(unifiedTranslationServiceProvider.future);
  }

  Future<void> _preloadDanbooruTagsInBackground() async {
    final service = ref.read(danbooruTagsLazyServiceProvider);
    final cacheState = ref.read(danbooruTagsCacheNotifierProvider);

    service.onProgress = (progress, message) {
      ref
          .read(backgroundTaskNotifierProvider.notifier)
          .updateProgress('danbooru_tags_preload', progress, message: message);
    };

    // 轻量级初始化
    await service.initializeLightweight();

    // 检查是否需要自动刷新（根据设置中的自动刷新间隔）
    final shouldRefresh = await service.shouldRefreshInBackground();
    final tagCount = await service.getTagCount();

    if (tagCount == 0 || shouldRefresh) {
      AppLogger.i('Danbooru tags need refresh (count: $tagCount, shouldRefresh: $shouldRefresh)', 'Warmup');
      // 自动触发数据拉取
      await service.refresh();

      // 如果开启了同步画师，也同步画师数据
      if (cacheState.syncArtists) {
        AppLogger.i('Artist sync is enabled, syncing artists...', 'Warmup');
        // TODO: 实现画师同步
        // await ref.read(danbooruTagsCacheNotifierProvider.notifier).syncArtists();
      }
    } else {
      // 不需要刷新，只加载热数据
      await service.preloadHotDataInBackground();
    }

    service.onProgress = null;
  }
}
