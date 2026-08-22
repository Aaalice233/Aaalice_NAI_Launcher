import 'dart:async';
import 'dart:ui' as ui;

import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/proxy_service.dart';
import '../../core/enums/warmup_phase.dart';
import '../../core/database/database.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/warmup_task_scheduler.dart';

import 'data_source_cache_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import '../../data/services/gallery/unified_gallery_service.dart';
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

  /// 启动全局画廊扫描（预热结束后自动调用，不绑定页面）
  ///
  /// 这会触发 galleryServiceProvider 的初始化，从而启动后台索引扫描
  void _startGlobalGalleryScan() {
    AppLogger.i('[Warmup] 预热完成，启动全局画廊扫描...', 'Warmup');

    // 使用 Future.microtask 延迟到当前帧完成后执行，避免阻塞 UI
    Future.microtask(() async {
      try {
        // 【修复】读取 provider 会触发 GalleryService 的创建和初始化
        // 但需要等待真正的初始化完成，扫描才会开始
        var attempts = 0;
        const maxAttempts = 100; // 最多等待10秒

        while (attempts < maxAttempts) {
          final service = ref.read(galleryServiceProvider);

          if (service.isInitialized) {
            AppLogger.i('[Warmup] 画廊服务已就绪，后台扫描进行中', 'Warmup');
            return;
          }

          // 服务还在初始化中，等待
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        AppLogger.w('[Warmup] 等待画廊服务初始化超时', 'Warmup');
      } catch (e) {
        // 画廊扫描失败不应影响主流程
        AppLogger.w('[Warmup] 画廊扫描启动失败（非关键）: $e', 'Warmup');
      }
    });
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
    _startGlobalGalleryScan();
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

  // ==== 后台任务方法 ====

  // TODO: Remove with the retired dynamic tag-cache implementation.
  // ignore: unused_element
  Future<void> _fetchGeneralAndCharacterTags() async {
    AppLogger.i('[_fetchGeneralAndCharacterTags] 开始检查并拉取标签...', 'Warmup');

    final service = await ref.read(danbooruTagsLazyServiceProvider.future);

    // 直接检查各分类数量，不依赖 shouldRefresh() 的时间判断
    var needsGeneralFetch = false;
    var needsCharacterFetch = false;
    var needsCopyrightFetch = false;
    var needsMetaFetch = false;

    try {
      // 获取各分类数量
      final stats = await service.getCategoryStats();
      final generalCount = stats['general'] ?? 0;
      final characterCount = stats['character'] ?? 0;
      final copyrightCount = stats['copyright'] ?? 0;
      final metaCount = stats['meta'] ?? 0;
      final totalCount = stats['total'] ?? 0;

      AppLogger.i(
        '[_fetchGeneralAndCharacterTags] 当前分类统计: '
            'total=$totalCount, general=$generalCount, character=$characterCount, '
            'copyright=$copyrightCount, meta=$metaCount',
        'Warmup',
      );

      // 如果总数为0或任何主要分类为0，需要拉取
      needsGeneralFetch = totalCount == 0 || generalCount == 0;
      needsCharacterFetch = totalCount == 0 || characterCount == 0;
      needsCopyrightFetch = totalCount == 0 || copyrightCount == 0;
      needsMetaFetch = totalCount == 0 || metaCount == 0;

      // 额外检查：也调用 shouldRefresh() 来考虑时间因素
      // 但如果分类为空，强制拉取
      try {
        final needsTimeRefresh = await service.shouldRefresh();
        if (needsTimeRefresh) {
          AppLogger.i(
            '[_fetchGeneralAndCharacterTags] shouldRefresh() 返回 true，需要刷新',
            'Warmup',
          );
          needsGeneralFetch = true;
          needsCharacterFetch = true;
          needsCopyrightFetch = true;
          needsMetaFetch = true;
        }
      } catch (e) {
        AppLogger.w(
          '[_fetchGeneralAndCharacterTags] shouldRefresh() 失败，基于数量判断: $e',
          'Warmup',
        );
      }

      if (!needsGeneralFetch &&
          !needsCharacterFetch &&
          !needsCopyrightFetch &&
          !needsMetaFetch) {
        AppLogger.i('[_fetchGeneralAndCharacterTags] 所有分类都有数据，跳过拉取', 'Warmup');
        return;
      }

      AppLogger.i(
        '[_fetchGeneralAndCharacterTags] 需要拉取: '
            'general=$needsGeneralFetch, character=$needsCharacterFetch, '
            'copyright=$needsCopyrightFetch, meta=$needsMetaFetch',
        'Warmup',
      );
    } catch (e) {
      AppLogger.w(
        '[_fetchGeneralAndCharacterTags] 获取分类统计失败，将尝试拉取所有: $e',
        'Warmup',
      );
      needsGeneralFetch = true;
      needsCharacterFetch = true;
      needsCopyrightFetch = true;
      needsMetaFetch = true;
    }

    // 设置进度回调（不显示百分比，只显示数量和状态）
    service.onProgress = (progress, message) {
      state = state.copyWith(subTaskMessage: 'warmup_fetchingTags|$message');
    };

    try {
      // 定义标签拉取任务
      final fetchTasks = [
        (
          name: 'general',
          needed: needsGeneralFetch,
          message: 'warmup_fetchingGeneralTags',
          fetch: () => service.fetchGeneralTags(threshold: 1000, maxPages: 50),
        ),
        (
          name: 'character',
          needed: needsCharacterFetch,
          message: 'warmup_fetchingCharacterTags',
          fetch: () => service.fetchCharacterTags(threshold: 100, maxPages: 50),
        ),
        (
          name: 'copyright',
          needed: needsCopyrightFetch,
          message: 'warmup_fetchingCopyrightTags',
          fetch: () => service.fetchCopyrightTags(threshold: 500, maxPages: 50),
        ),
        (
          name: 'meta',
          needed: needsMetaFetch,
          message: 'warmup_fetchingMetaTags',
          fetch: () => service.fetchMetaTags(threshold: 10000, maxPages: 50),
        ),
      ];

      for (final task in fetchTasks) {
        if (!task.needed) {
          AppLogger.i(
            'Skipping ${task.name} tags fetch (already has data)',
            'Warmup',
          );
          continue;
        }
        state = state.copyWith(subTaskMessage: task.message);
        await task.fetch().timeout(
          const Duration(seconds: 60),
          onTimeout: () =>
              AppLogger.w('${task.name} tags fetch timeout', 'Warmup'),
        );
        AppLogger.i('${task.name} tags fetched successfully', 'Warmup');
      }

      // 验证拉取后的数据
      try {
        final newCount = await service.getTagCount();
        AppLogger.i('After fetch: danbooru tag count = $newCount', 'Warmup');
        if (newCount == 0) {
          AppLogger.w(
            'Tag count is still 0 after fetch, may need retry',
            'Warmup',
          );
        }
      } catch (e) {
        AppLogger.w('Failed to verify tag count after fetch: $e', 'Warmup');
      }

      // 🔴 关键：所有分类拉取完成后，保存元数据（统一设置 _lastUpdate）
      try {
        await service.saveMetaAfterFetch();
        AppLogger.i('Tags meta saved after all categories fetched', 'Warmup');
      } catch (e) {
        AppLogger.w('Failed to save tags meta: $e', 'Warmup');
      }

      // 🔴 关键：数据拉取完成后刷新 Provider，让 UI 更新
      // 关键修复：同时失效服务和数据源 Provider，确保下次获取时使用新连接
      AppLogger.i(
        'Invalidating providers after tags fetch: '
            'danbooruTagsLazyServiceProvider, danbooruTagsCacheNotifierProvider',
        'Warmup',
      );
      ref.invalidate(danbooruTagsLazyServiceProvider);
      ref.invalidate(danbooruTagsCacheNotifierProvider);

      // 验证最终数据
      try {
        final finalStats = await service.getCategoryStats();
        AppLogger.i(
          '[_fetchGeneralAndCharacterTags] 最终分类统计: '
              'total=${finalStats['total']}, general=${finalStats['general']}, '
              'character=${finalStats['character']}, copyright=${finalStats['copyright']}, '
              'meta=${finalStats['meta']}',
          'Warmup',
        );
      } catch (e) {
        AppLogger.w('Failed to get final category stats: $e', 'Warmup');
      }
    } on StateError catch (e) {
      // 数据库正在恢复中，不阻塞启动
      AppLogger.w('Cannot fetch tags, database recovering: $e', 'Warmup');
    } catch (e) {
      AppLogger.w('Failed to fetch tags: $e', 'Warmup');
      // 失败不阻塞，进入主页后后台会重试
    } finally {
      service.onProgress = null;
    }
  }

  /// 拉取画师标签（预热阶段同步执行）
  ///
  /// 使用 Provider 的 syncArtists 方法，在预热阶段同步完成
  /// 由于有热度限制，数据量不大，不会阻塞太久
  // ignore: unused_element
  Future<void> _fetchArtistTagsInWarmup() async {
    AppLogger.i('Starting artist tags fetch in warmup phase...', 'Warmup');

    try {
      // 使用 Provider 的 syncArtists 方法，确保完成后状态更新
      // 这会正确处理重复拉取的检查，并在完成后更新 Provider 状态
      await ref
          .read(danbooruTagsCacheNotifierProvider.notifier)
          .syncArtists(
            force: false, // 如果有数据则跳过
          );

      AppLogger.i('Artist tags fetch completed in warmup phase', 'Warmup');
    } catch (e, stack) {
      AppLogger.e(
        'Artist tags fetch error in warmup phase: $e',
        e,
        stack,
        'Warmup',
      );
      // 预热阶段失败不阻塞，进入主页后可能重试
    }
  }

  // ignore: unused_element
  Future<void> _checkAndRecoverData() async {
    AppLogger.i('检查数据完整性...', 'Warmup');

    try {
      // 使用新的 DatabaseManager 获取统计信息
      final manager = await ref.watch(databaseManagerProvider.future);

      // 等待初始化完成
      await manager.initialized;

      final runtimeStats = await manager.getStatistics();
      final tableStats = runtimeStats['tables'] as Map<String, int>? ?? {};
      final coreAssetStats = await manager.getCoreAssetStatistics();

      // 获取各表记录数
      final translationCount = coreAssetStats['translations'] ?? 0;
      final cooccurrenceCount = coreAssetStats['cooccurrences'] ?? 0;
      final danbooruCount = tableStats['danbooru_tags'] ?? 0;

      AppLogger.i(
        '核心资产数据库状态: translations=$translationCount, cooccurrences=$cooccurrenceCount, danbooru_tags=$danbooruCount',
        'Warmup',
      );

      // 1. 检查 translations 和 cooccurrences 资产库
      if (translationCount == 0 || cooccurrenceCount == 0) {
        AppLogger.w('核心资产数据为空，请检查本地打包数据库', 'Warmup');
      }

      // 2. 恢复 danbooru_tags（从API）
      // 不仅检查总数，还检查各分类数量
      final service = await ref.read(danbooruTagsLazyServiceProvider.future);
      final categoryStats = await service.getCategoryStats();

      final generalCount = categoryStats['general'] ?? 0;
      final characterCount = categoryStats['character'] ?? 0;
      final copyrightCount = categoryStats['copyright'] ?? 0;
      final metaCount = categoryStats['meta'] ?? 0;

      AppLogger.i(
        'Danbooru标签分类统计: general=$generalCount, character=$characterCount, '
            'copyright=$copyrightCount, meta=$metaCount',
        'Warmup',
      );

      // 判断哪些分类需要拉取
      final needsGeneralFetch = generalCount == 0;
      final needsCharacterFetch = characterCount == 0;
      final needsCopyrightFetch = copyrightCount == 0;
      final needsMetaFetch = metaCount == 0;

      final needsAnyFetch =
          needsGeneralFetch ||
          needsCharacterFetch ||
          needsCopyrightFetch ||
          needsMetaFetch;

      if (!needsAnyFetch) {
        AppLogger.i('所有标签分类数据已存在，跳过拉取', 'Warmup');
        return;
      }

      AppLogger.w(
        '部分标签分类为空，触发补充拉取: '
            'general=$needsGeneralFetch, character=$needsCharacterFetch, '
            'copyright=$needsCopyrightFetch, meta=$needsMetaFetch',
        'Warmup',
      );
      state = state.copyWith(
        subTaskMessage: 'warmup_fetchingTagDataFromServer',
      );

      // 定义标签拉取任务
      final fetchTasks = [
        if (needsGeneralFetch)
          (
            message: 'warmup_fetchingGeneralTags',
            fetch: () =>
                service.fetchGeneralTags(threshold: 1000, maxPages: 50),
          ),
        if (needsCharacterFetch)
          (
            message: 'warmup_fetchingCharacterTags',
            fetch: () =>
                service.fetchCharacterTags(threshold: 100, maxPages: 50),
          ),
        if (needsCopyrightFetch)
          (
            message: 'warmup_fetchingCopyrightTags',
            fetch: () =>
                service.fetchCopyrightTags(threshold: 500, maxPages: 50),
          ),
        if (needsMetaFetch)
          (
            message: 'warmup_fetchingMetaTags',
            fetch: () => service.fetchMetaTags(threshold: 10000, maxPages: 50),
          ),
      ];

      for (final task in fetchTasks) {
        state = state.copyWith(subTaskMessage: task.message);
        await task.fetch().timeout(
          const Duration(seconds: 60),
          onTimeout: () => AppLogger.w('${task.message}超时，将在后台继续', 'Warmup'),
        );
      }

      AppLogger.i('标签数据拉取完成', 'Warmup');
    } on StateError catch (e) {
      // 数据库正在恢复中，不阻塞启动
      AppLogger.w('检查数据完整性时数据库正在恢复，将在后台重试: $e', 'Warmup');
    } catch (e) {
      AppLogger.w('检查数据完整性失败: $e', 'Warmup');
      // 非致命错误，继续启动
    }
  }
}
