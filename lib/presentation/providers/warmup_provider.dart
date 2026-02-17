import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/network/proxy_service.dart';
import '../../core/enums/warmup_phase.dart';
import '../../core/services/app_warmup_service.dart';
import '../../core/database/database.dart';
// import '../../core/services/artist_tags_isolate_service.dart'; // 暂时未使用，改用 fetchArtistTags
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/data_migration_service.dart';
import '../../core/services/translation/translation_providers.dart';
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

  /// 检查网络环境（循环等待直到连接成功）
  Future<void> _checkNetworkEnvironment() async {
    const checkInterval = Duration(seconds: 2);

    var attempt = 0;
    while (true) {
      attempt++;
      state = state.copyWith(
        subTaskMessage: '正在检测网络连接... (尝试 $attempt)',
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
        'Network check attempt $attempt failed: ${result.errorMessage}',
        'Warmup',
      );

      // 等待后重试
      await Future.delayed(checkInterval);
    }
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
    // 1. 数据库初始化
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_unifiedDbInit',
        displayName: '初始化数据库',
        phase: WarmupPhase.quick,
        weight: 2,
        task: _initUnifiedDatabaseLightweight,
      ),
    );

    // 2. 翻译数据初始化（在预热阶段完成，不显示后台进度）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_translationInit',
        displayName: '初始化翻译数据',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 35),
        task: _preloadTranslationInBackground,
      ),
    );

    // 3. 共现数据初始化（轻量级检查，依赖数据库）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_cooccurrenceInit',
        displayName: '初始化共现数据',
        phase: WarmupPhase.quick,
        weight: 1,
        task: _initCooccurrenceData,
      ),
    );

    // 4. 网络检测
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_networkCheck',
        displayName: '检测网络',
        phase: WarmupPhase.quick,
        weight: 1,
        task: _checkNetworkEnvironment,
      ),
    );

    // 5. 提示词配置
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_loadingPromptConfig',
        displayName: '加载提示词配置',
        phase: WarmupPhase.quick,
        weight: 1,
        task: _loadPromptConfig,
      ),
    );

    // 6. 画廊计数
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_galleryFileCount',
        displayName: '扫描画廊',
        phase: WarmupPhase.quick,
        weight: 1,
        task: _countGalleryFiles,
      ),
    );

    // 7. 订阅信息（仅缓存，不强制网络）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_subscription',
        displayName: '加载订阅信息',
        phase: WarmupPhase.quick,
        weight: 1,
        task: _loadSubscriptionCached,
      ),
    );

    // 8. 一般标签数据拉取（在预热阶段完成，进入主页后不再显示后台进度）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_generalTagsFetch',
        displayName: '加载标签数据',
        phase: WarmupPhase.quick,
        weight: 2,
        timeout: const Duration(seconds: 65),
        task: _fetchGeneralTags,
      ),
    );

    // 注意：画师标签拉取在 Background 阶段，避免阻塞主界面

    // 9. 检查并恢复数据（处理清除缓存后的数据缺失）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_checkAndRecoverData',
        displayName: '检查数据完整性',
        phase: WarmupPhase.quick,
        weight: 1,
        task: _checkAndRecoverData,
      ),
    );
  }

  void _registerBackgroundPhaseTasks() {
    // 后台任务注册到 BackgroundTaskProvider
    // 实际执行在进入主界面后
    final backgroundNotifier = ref.read(backgroundTaskNotifierProvider.notifier);

    // 只有画师标签在后台拉取（数据量大，不阻塞主界面）
    backgroundNotifier.registerTask(
      'artist_tags_fetch',
      '画师标签同步',
      () => _fetchArtistTagsInBackground(),
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

  /// 轻量级初始化统一数据库（带进度反馈、错误处理和损坏检测）
  Future<void> _initUnifiedDatabaseLightweight() async {
    AppLogger.i('Initializing unified tag database (lightweight)...', 'Warmup');

    try {
      // 更新进度状态
      state = state.copyWith(subTaskMessage: '正在准备数据库文件...');

      // 使用新的 DatabaseManager 初始化
      final manager = await ref.watch(databaseManagerProvider.future);

      // 等待初始化完成
      await manager.initialized.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          AppLogger.w('Database initialization timeout', 'Warmup');
          throw TimeoutException('数据库初始化超时，请检查磁盘空间');
        },
      );

      // 预热阶段：检测数据库是否损坏
      state = state.copyWith(subTaskMessage: '正在检查数据库完整性...');
      final healthCheck = await manager.quickHealthCheck();

      if (healthCheck.isCorrupted) {
        AppLogger.w('Database corruption detected during warmup, rebuilding...', 'Warmup');
        state = state.copyWith(subTaskMessage: '检测到数据库损坏，正在修复...');
        await manager.recover();
        AppLogger.i('Database rebuilt successfully during warmup', 'Warmup');
      }

      AppLogger.i('Unified tag database initialized', 'Warmup');
    } on TimeoutException {
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Database initialization failed', e, stack, 'Warmup');
      // 检查是否是数据库损坏错误
      if (e.toString().contains('database disk image is malformed') ||
          e.toString().contains('database is corrupted')) {
        AppLogger.w('Database corruption detected, attempting rebuild...', 'Warmup');
        state = state.copyWith(subTaskMessage: '检测到数据库损坏，正在修复...');
        try {
          final manager = await ref.watch(databaseManagerProvider.future);
          await manager.recover();
          AppLogger.i('Database rebuilt successfully after corruption', 'Warmup');
          return;
        } catch (rebuildError) {
          AppLogger.e('Failed to rebuild database', rebuildError, null, 'Warmup');
        }
      }
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

    try {
      final manager = await ref.watch(databaseManagerProvider.future);

      // 等待新数据库管理器初始化
      await manager.initialized;

      // 使用数据库统计获取共现记录数
      final stats = await manager.getStatistics();
      final tableStats = stats['tables'] as Map<String, int>? ?? {};
      final count = tableStats['cooccurrences'] ?? 0;

      AppLogger.i('共现数据记录数: $count', 'Warmup');

      if (count == 0) {
        AppLogger.w('共现数据为空，需要后台导入', 'Warmup');
      } else {
        AppLogger.i('共现数据已就绪（$count 条记录）', 'Warmup');
      }
    } on StateError catch (e) {
      // ConnectionPool disposed 或其他状态错误，不阻塞启动
      AppLogger.w('共现数据初始化时数据库正在恢复，将在后台重试: $e', 'Warmup');
    } catch (e, stack) {
      AppLogger.e('共现数据初始化失败', e, stack, 'Warmup');
    }
  }

  Future<void> _checkAndImportCooccurrence() async {
    // 使用新的 CooccurrenceService 进行 CSV 导入
    final service = await ref.watch(cooccurrenceServiceProvider.future);

    // 直接导入 CSV，等待完成（不是后台任务）
    await service.importCsvToSQLite(
      onProgress: (progress, message) {
        ref
            .read(backgroundTaskNotifierProvider.notifier)
            .updateProgress('cooccurrence_import', progress, message: message);
      },
    ).timeout(
      const Duration(minutes: 3), // 给足够时间导入（共现数据量大）
      onTimeout: () {
        AppLogger.w('共现数据导入超时', 'Warmup');
        return -1;
      },
    );
  }

  Future<void> _preloadTranslationInBackground() async {
    // 统一翻译服务在读取 provider 时自动初始化
    // 增加超时时间，CSV加载可能需要较长时间
    try {
      await ref.read(unifiedTranslationServiceProvider.future).timeout(
        const Duration(seconds: 30),
      );
    } on TimeoutException {
      AppLogger.w('Translation initialization timeout, will retry later', 'Warmup');
    }
  }

  Future<void> _preloadDanbooruTagsInBackground() async {
    final service = await ref.read(danbooruTagsLazyServiceProvider.future);
    final cacheStateAsync = ref.read(danbooruTagsCacheNotifierProvider);

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
      if (cacheStateAsync is AsyncData &&
          cacheStateAsync.value != null &&
          cacheStateAsync.value!.syncArtists) {
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

  /// 拉取一般标签（非画师标签，category != 1）
  Future<void> _fetchGeneralTags() async {
    AppLogger.i('开始拉取一般标签...', 'Warmup');

    final service = await ref.read(danbooruTagsLazyServiceProvider.future);

    // 先检测数据库中是否已有数据
    try {
      final tagCount = await service.getTagCount();
      AppLogger.i('Current danbooru tag count: $tagCount', 'Warmup');
      
      if (tagCount == 0) {
        state = state.copyWith(subTaskMessage: '检测到标签数据为空，开始从服务器拉取...');
        AppLogger.i('Tag database is empty, will fetch from API', 'Warmup');
      } else {
        AppLogger.i('Tag database has $tagCount records, checking if refresh needed...', 'Warmup');
      }
    } on StateError catch (e) {
      // 数据库正在恢复中
      AppLogger.w('Cannot check tag count, database recovering: $e', 'Warmup');
    } catch (e) {
      AppLogger.w('Failed to check tag count: $e', 'Warmup');
    }

    // 设置进度回调（不显示百分比，只显示数量和状态）
    service.onProgress = (progress, message) {
      state = state.copyWith(
        subTaskMessage: '拉取标签: $message',
      );
    };

    try {
      // 只拉取一般标签（category != 1）
      await service.fetchGeneralTags(
        threshold: 1000, // 热度阈值
        maxPages: 50,    // 最多50页
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          AppLogger.w('General tags fetch timeout', 'Warmup');
          // 超时不阻塞，后台会继续
        },
      );

      // 验证拉取后的数据
      try {
        final newCount = await service.getTagCount();
        AppLogger.i('After fetch: danbooru tag count = $newCount', 'Warmup');
        if (newCount == 0) {
          AppLogger.w('Tag count is still 0 after fetch, may need retry', 'Warmup');
        }
      } catch (e) {
        AppLogger.w('Failed to verify tag count after fetch: $e', 'Warmup');
      }

      AppLogger.i('General tags fetched successfully', 'Warmup');
    } on StateError catch (e) {
      // 数据库正在恢复中，不阻塞启动
      AppLogger.w('Cannot fetch tags, database recovering: $e', 'Warmup');
    } catch (e) {
      AppLogger.w('Failed to fetch general tags: $e', 'Warmup');
      // 失败不阻塞，进入主页后后台会重试
    } finally {
      service.onProgress = null;
    }
  }

  /// 拉取画师标签
  ///
  /// 使用新的 fetchArtistTags 方法，显示页数和数量（不是百分比）
  /// 进度显示在右下角的独立进度条组件上
  Future<void> _fetchArtistTagsInBackground() async {
    AppLogger.i('Starting artist tags fetch...', 'Background');

    final service = await ref.read(danbooruTagsLazyServiceProvider.future);
    final notifier = ref.read(backgroundTaskNotifierProvider.notifier);

    try {
      // 初始状态
      notifier.updateProgress(
        'artist_tags_fetch',
        0.0,
        message: '准备拉取画师标签...',
      );

      // 使用新的 fetchArtistTags 方法
      await service.fetchArtistTags(
        onProgress: (currentPage, importedCount, message) {
          // 更新后台任务进度（不显示进度条，因为不知道总数）
          notifier.updateProgress(
            'artist_tags_fetch',
            0, // 不确定进度，使用循环动画
            message: message,
          );
        },
        maxPages: 100, // 画师标签量大，限制页数
      );

      AppLogger.i('Artist tags fetch completed', 'Background');
    } catch (e, stack) {
      AppLogger.e('Artist tags fetch error: $e', e, stack, 'Background');
    }
  }

  /// 检查并恢复数据（处理清除缓存后的数据缺失）
  Future<void> _checkAndRecoverData() async {
    AppLogger.i('检查数据完整性...', 'Warmup');

    try {
      // 使用新的 DatabaseManager 获取统计信息
      final manager = await ref.watch(databaseManagerProvider.future);
      
      // 等待初始化完成
      await manager.initialized;
      
      final stats = await manager.getStatistics();
      final tableStats = stats['tables'] as Map<String, int>? ?? {};

      // 获取各表记录数
      final translationCount = tableStats['translations'] ?? 0;
      final cooccurrenceCount = tableStats['cooccurrences'] ?? 0;
      final danbooruCount = tableStats['danbooru_tags'] ?? 0;

      AppLogger.i(
        '数据表状态: translations=$translationCount, cooccurrences=$cooccurrenceCount, danbooru_tags=$danbooruCount',
        'Warmup',
      );

      // 1. 恢复 translations 和 cooccurrences（从预打包数据库）
      if (translationCount == 0 || cooccurrenceCount == 0) {
        AppLogger.w(
          '检测到核心数据缺失，从预打包数据库恢复...',
          'Warmup',
        );
        state = state.copyWith(
          subTaskMessage: '正在恢复核心数据（翻译+共现）...',
        );

        // 使用 RecoveryManager 重新导入预打包数据
        await manager.recover();

        AppLogger.i('核心数据恢复完成', 'Warmup');
      }

      // 2. 恢复 danbooru_tags（从API）
      if (danbooruCount == 0) {
        AppLogger.w(
          '标签数据为空，触发从服务器拉取',
          'Warmup',
        );
        state = state.copyWith(
          subTaskMessage: '正在从服务器拉取标签数据...',
        );

        final service = await ref.read(danbooruTagsLazyServiceProvider.future);
        await service.fetchGeneralTags(
          threshold: 1000,
          maxPages: 50,
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            AppLogger.w('标签拉取超时，将在后台继续', 'Warmup');
          },
        );

        AppLogger.i('标签数据拉取完成', 'Warmup');
      }
    } on StateError catch (e) {
      // 数据库正在恢复中，不阻塞启动
      AppLogger.w('检查数据完整性时数据库正在恢复，将在后台重试: $e', 'Warmup');
    } catch (e) {
      AppLogger.w('检查数据完整性失败: $e', 'Warmup');
      // 非致命错误，继续启动
    }
  }
}
