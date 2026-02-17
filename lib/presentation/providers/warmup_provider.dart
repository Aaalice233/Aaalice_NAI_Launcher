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
    final quickTasks = [
      ('warmup_unifiedDbInit', '初始化数据库', 2, const Duration(seconds: 60), _initUnifiedDatabaseLightweight),
      ('warmup_danbooruTagsInit', '加载标签数据', 3, const Duration(seconds: 120), _initDanbooruTags),
      ('warmup_cooccurrenceInit', '初始化共现数据', 2, const Duration(seconds: 120), _initCooccurrenceData),
      ('warmup_networkCheck', '检测网络', 1, const Duration(seconds: 30), _checkNetworkEnvironmentWithTimeout),
      ('warmup_loadingPromptConfig', '加载提示词配置', 1, const Duration(seconds: 10), _loadPromptConfig),
      ('warmup_galleryFileCount', '扫描画廊', 1, const Duration(seconds: 3), _countGalleryFiles),
      ('warmup_subscription', '加载订阅信息', 1, const Duration(seconds: 3), _loadSubscriptionCached),
    ];

    for (final (name, displayName, weight, timeout, task) in quickTasks) {
      _scheduler.registerTask(
        PhasedWarmupTask(
          name: name,
          displayName: displayName,
          phase: WarmupPhase.quick,
          weight: weight,
          timeout: timeout,
          task: task,
        ),
      );
    }
  }

  void _registerBackgroundPhaseTasks() {
    final notifier = ref.read(backgroundTaskNotifierProvider.notifier);
    final tasks = [
      ('cooccurrence_check', '检查共现数据更新', _checkAndImportCooccurrence),
      ('translation_preload', '翻译数据', _preloadTranslationInBackground),
      ('danbooru_tags_refresh', '标签数据刷新', _refreshDanbooruTagsInBackground),
      ('artist_tags_sync', '画师标签同步', _syncArtistTagsInBackground),
    ];

    for (final (id, name, task) in tasks) {
      notifier.registerTask(id, name, task);
    }
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
      await Future.delayed(const Duration(seconds: 1));
      Future.microtask(() {
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

  /// 预热阶段：初始化 Danbooru 标签数据（仅普通标签，不包含画师）
  Future<void> _initDanbooruTags() async {
    AppLogger.i('开始初始化 Danbooru 标签数据（仅普通标签）...', 'Warmup');

    try {
      final service = ref.read(danbooruTagsLazyServiceProvider);

      // 先显示初始进度
      state = state.copyWith(subTaskMessage: '正在检查标签数据...');

      // 设置进度回调
      service.onProgress = (progress, message, {processedCount, totalCount}) {
        state = state.copyWith(subTaskMessage: message);
      };

      // 先初始化服务，确保数据库连接就绪
      await service.initialize();

      // 检查数据库中是否已有数据
      final tagCount = await service.getTagCount();
      final isPrebuiltDatabase = tagCount >= 30000;

      if (isPrebuiltDatabase) {
        // 预构建数据库：数据已加载，无需额外操作
        AppLogger.i('检测到预构建数据库（$tagCount 条标签），跳过下载', 'Warmup');
      } else {
        // 需要下载：只下载普通标签，画师标签留给后台任务
        AppLogger.i('数据库为空或数据不足（仅 $tagCount 条），开始下载普通标签...', 'Warmup');
        await service.refreshGeneralOnly().timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            AppLogger.w('Danbooru 普通标签下载超时', 'Warmup');
            throw TimeoutException('标签数据下载超时');
          },
        );
      }

      service.onProgress = null;
      state = state.copyWith(subTaskMessage: null);

      AppLogger.i('Danbooru 普通标签初始化完成', 'Warmup');
    } on TimeoutException {
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Danbooru 标签初始化失败', e, stack, 'Warmup');
      // 标签初始化失败不应阻塞启动
    }
  }

  /// 预热阶段：初始化共现数据（优先数据库，没有则导入CSV）
  Future<void> _initCooccurrenceData() async {
    AppLogger.i('开始初始化共现数据...', 'Warmup');

    state = state.copyWith(subTaskMessage: '检查共现数据...');

    final service = ref.read(cooccurrenceServiceProvider);
    final unifiedDb = ref.read(unifiedTagDatabaseProvider);

    try {
      // 设置数据库连接
      service.setUnifiedDatabase(unifiedDb);

      // 1. 先检查数据库状态
      final isReady = await service.initializeUnified().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.w('共现数据检查超时', 'Warmup');
          return false;
        },
      );

      if (isReady) {
        // 数据库有数据且最新，直接使用
        AppLogger.i('共现数据已就绪（SQLite）', 'Warmup');
        return;
      }

      // 2. 需要导入（首次或需要更新）
      // 检查是否已有部分数据（预构建数据库）
      final currentCount = (await unifiedDb.getRecordCounts()).cooccurrences;
      final isIncremental = currentCount > 0;

      if (isIncremental) {
        AppLogger.i('共现数据部分存在（$currentCount 条），开始增量导入...', 'Warmup');
      } else {
        AppLogger.i('共现数据需要导入，开始从CSV导入...', 'Warmup');
      }

      // 使用进度回调更新UI
      final imported = await service.importCsvToSQLite(
        onProgress: (progress, message) {
          state = state.copyWith(subTaskMessage: message);
        },
        skipExisting: isIncremental, // 增量导入模式
      ).timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          AppLogger.w('共现数据导入超时', 'Warmup');
          throw TimeoutException('共现数据导入超时');
        },
      );

      if (imported > 0) {
        // 更新版本信息
        await unifiedDb.updateDataSourceVersion('cooccurrences', 1);
        AppLogger.i('共现数据导入完成，共 $imported 条记录', 'Warmup');
      } else {
        AppLogger.w('共现数据导入失败，将在后台重试', 'Warmup');
      }

      state = state.copyWith(subTaskMessage: null);
    } on TimeoutException {
      rethrow;
    } catch (e, stack) {
      AppLogger.e('共现数据初始化失败', e, stack, 'Warmup');
      // 共现数据失败不应阻塞启动
    }
  }

  /// 后台任务：检查共现数据是否需要更新（预热阶段已完成导入）
  Future<void> _checkAndImportCooccurrence() async {
    final service = ref.read(cooccurrenceServiceProvider);
    final unifiedDb = ref.read(unifiedTagDatabaseProvider);

    try {
      // 设置数据库连接
      service.setUnifiedDatabase(unifiedDb);

      // 检查数据库状态
      final isReady = await service.initializeUnified();

      if (isReady) {
        // 数据已最新（包括预构建数据库），无需操作
        AppLogger.i('共现数据已就绪，后台任务跳过', 'Warmup');
        return;
      }

      // 需要更新（预构建不完整或CSV有变化）
      AppLogger.i('共现数据需要更新，开始后台增量导入...', 'Warmup');
      await service.performBackgroundImport(
        onProgress: (progress, message) {
          ref.read(backgroundTaskNotifierProvider.notifier).updateProgress(
            'cooccurrence_check',
            progress,
            message: message,
          );
        },
        incremental: true, // 使用增量导入
      );
    } catch (e, stack) {
      AppLogger.e('后台共现数据检查失败', e, stack, 'Warmup');
    }
  }

  Future<void> _preloadTranslationInBackground() async {
    // 统一翻译服务在读取 provider 时自动初始化
    await ref.read(unifiedTranslationServiceProvider.future);
  }

  /// 后台任务：检查并刷新 Danbooru 标签数据（预热阶段已完成初始化）
  Future<void> _refreshDanbooruTagsInBackground() async {
    await _runBackgroundTagTask(
      taskId: 'danbooru_tags_refresh',
      shouldRun: (service) async {
        final shouldRefresh = await service.shouldRefreshInBackground();
        final tagCount = await service.getTagCount();
        return tagCount == 0 || shouldRefresh;
      },
      task: (service) => service.refreshGeneralOnly(),
    );
  }

  /// 后台任务：同步画师标签（避免预热阶段超时）
  Future<void> _syncArtistTagsInBackground() async {
    await _runBackgroundTagTask(
      taskId: 'artist_tags_sync',
      logName: '画师标签',
      shouldRun: (_) async => true,
      task: (service) => service.refreshArtistsOnly(),
    );
  }

  /// 通用后台标签任务执行器
  Future<void> _runBackgroundTagTask({
    required String taskId,
    String? logName,
    required Future<bool> Function(DanbooruTagsLazyService) shouldRun,
    required Future<void> Function(DanbooruTagsLazyService) task,
  }) async {
    final service = ref.read(danbooruTagsLazyServiceProvider);

    service.onProgress = (progress, message, {processedCount, totalCount}) {
      ref.read(backgroundTaskNotifierProvider.notifier).updateProgress(
        taskId,
        progress,
        message: message,
        processedCount: processedCount,
        totalCount: totalCount,
      );
    };

    try {
      if (await shouldRun(service)) {
        if (logName != null) {
          AppLogger.i('开始后台同步$logName...', 'Warmup');
        }
        await task(service);
        if (logName != null) {
          AppLogger.i('$logName同步完成', 'Warmup');
        }
      }
    } catch (e, stack) {
      AppLogger.e('${logName ?? taskId}同步失败', e, stack, 'Warmup');
    } finally {
      service.onProgress = null;
    }
  }
}
