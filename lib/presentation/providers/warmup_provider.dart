import 'dart:async';
import 'dart:ui' as ui;

import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/proxy_service.dart';
import '../../core/enums/warmup_phase.dart';
import '../../core/database/database.dart';
import '../../core/database/datasources/gallery_data_source.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/data_migration_service.dart';
import '../../core/services/translation/translation_providers.dart';
import '../../core/services/warmup_task_scheduler.dart';

import 'data_source_cache_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import '../../data/services/gallery/unified_gallery_service.dart';
import 'auth_provider.dart';
import 'font_provider.dart';
import 'prompt_config_provider.dart';
import 'subscription_provider.dart';
import '../../data/services/vibe_library_migration_service.dart';

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

  factory WarmupProgress.initial() => const WarmupProgress(
        progress: 0.0,
        currentTask: 'warmup_preparing',
      );

  factory WarmupProgress.complete() => const WarmupProgress(
        progress: 1.0,
        currentTask: 'warmup_complete',
        isComplete: true,
      );

  factory WarmupProgress.error(String message) => WarmupProgress(
        progress: 0.0,
        currentTask: message,
        error: message,
      );
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

  // 【修复】移除了 _configureImageCache 方法
  // Image Cache 配置已在 main.dart 中统一处理（200MB）

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

  /// 检查网络环境（最多尝试2次，失败不阻塞启动）
  ///
  /// 总超时控制在 8 秒内（调度器 timeout），避免被强制终止
  Future<void> _checkNetworkEnvironment() async {
    const maxAttempts = 2;
    const timeout = Duration(seconds: 3);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      state = state.copyWith(
        subTaskMessage: '正在检测网络连接... (尝试 $attempt/$maxAttempts)',
      );

      try {
        final result = await ProxyService.testNovelAIConnection(timeout: timeout);

        if (result.success) {
          AppLogger.i('Network check successful: ${result.latencyMs}ms', 'Warmup');
          state = state.copyWith(subTaskMessage: '网络连接正常 (${result.latencyMs}ms)');
          await Future.delayed(const Duration(milliseconds: 300));
          return;
        }

        AppLogger.w('Network check attempt $attempt/$maxAttempts failed: ${result.errorMessage}', 'Warmup');
      } catch (e) {
        AppLogger.w('Network check attempt $attempt/$maxAttempts error: $e', 'Warmup');
      }

      if (attempt >= maxAttempts) {
        AppLogger.w('Network check reached max attempts, continuing offline', 'Warmup');
        state = state.copyWith(subTaskMessage: '网络未连接，已离线启动');
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
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
          // 【修复】移除 warmup_imageCache 任务，因为 main.dart 已配置（200MB）
          // 避免重复配置和参数不一致问题
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
        task: () async {
          // 只执行轻量级检查，实际导入在 background 阶段
          await _initCooccurrenceData();
        },
      ),
    );

    // 4. 网络检测（8秒超时，防止无限等待）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_networkCheck',
        displayName: '检测网络',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 8),
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

    // 6. 画廊数据源初始化
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_galleryDataSource',
        displayName: '初始化画廊索引',
        phase: WarmupPhase.quick,
        weight: 3,
        timeout: const Duration(seconds: 30),
        task: _initGalleryDataSource,
      ),
    );

    // 7. 画廊计数
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

    // 8. 一般标签和角色标签数据拉取（在预热阶段完成，进入主页后不再显示后台进度）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_generalTagsFetch',
        displayName: '加载标签数据',
        phase: WarmupPhase.quick,
        weight: 2,
        timeout: const Duration(seconds: 90),
        task: _fetchGeneralAndCharacterTags,
      ),
    );

    // 9. 画师标签拉取（改为预热阶段执行，不再在后台执行）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_artistTagsFetch',
        displayName: '加载画师标签',
        phase: WarmupPhase.quick,
        weight: 2,
        timeout: const Duration(seconds: 60),
        task: _fetchArtistTagsInWarmup,
      ),
    );

    // 注意：共现数据导入在 Background 阶段，避免阻塞主界面

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
    // 注意：共现数据是预打包的数据库，在 _initCooccurrenceData() 中已完成初始化
    // 不需要额外的后台导入任务
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

      // 【关键】预热完成后，自动启动全局画廊扫描（不绑定页面）
      _startGlobalGalleryScan();
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
    AppLogger.i('等待数据库准备就绪...', 'Warmup');

    try {
      // 数据库已在 main() 中初始化和恢复，这里只需等待就绪
      final manager = await ref.watch(databaseManagerProvider.future);
      await manager.initialized.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          AppLogger.w('Database initialization timeout', 'Warmup');
          throw TimeoutException('数据库初始化超时，请检查磁盘空间');
        },
      );

      AppLogger.i('数据库已就绪', 'Warmup');
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

  /// 初始化画廊数据源
  Future<void> _initGalleryDataSource() async {
    try {
      // 获取 DatabaseManager 并等待初始化
      final dbManager = await ref.read(databaseManagerProvider.future);

      // 获取 GalleryDataSource
      final galleryDs = dbManager.getDataSource<GalleryDataSource>('gallery');
      if (galleryDs != null) {
        // 数据源已初始化（DatabaseManager 中已完成）
        AppLogger.i('GalleryDataSource initialized in warmup phase', 'Warmup');
      }
    } catch (e) {
      AppLogger.w('GalleryDataSource warmup failed: $e', 'Warmup');
      // 不抛出异常，避免阻塞启动
    }
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
      final cooccurrenceService = await ref.watch(cooccurrenceServiceProvider.future);
      
      // 初始化共现服务
      final isReady = await cooccurrenceService.initialize();

      if (isReady) {
        final count = await cooccurrenceService.getCount();
        AppLogger.i('共现数据已就绪（$count 条记录）', 'Warmup');
      } else {
        final count = await cooccurrenceService.getCount();
        if (count > 0) {
          AppLogger.w('共现数据不完整（$count 条记录），将在后台继续导入', 'Warmup');
        } else {
          AppLogger.i('共现数据为空，将在后台导入', 'Warmup');
        }
      }
    } on StateError catch (e) {
      // 数据库正在恢复中，不阻塞启动
      AppLogger.w('共现数据初始化时数据库正在恢复，将在后台重试: $e', 'Warmup');
    } catch (e, stack) {
      AppLogger.e('共现数据初始化失败', e, stack, 'Warmup');
    }
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

  /// 拉取一般标签和角色标签
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
        AppLogger.i(
          '[_fetchGeneralAndCharacterTags] 所有分类都有数据，跳过拉取',
          'Warmup',
        );
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
      state = state.copyWith(
        subTaskMessage: '拉取标签: $message',
      );
    };

    try {
      // 定义标签拉取任务
      final fetchTasks = [
        (
          name: '一般',
          needed: needsGeneralFetch,
          message: '拉取一般标签...',
          fetch: () => service.fetchGeneralTags(threshold: 1000, maxPages: 50),
        ),
        (
          name: '角色',
          needed: needsCharacterFetch,
          message: '拉取角色标签...',
          fetch: () => service.fetchCharacterTags(threshold: 100, maxPages: 50),
        ),
        (
          name: '版权',
          needed: needsCopyrightFetch,
          message: '拉取版权标签...',
          fetch: () => service.fetchCopyrightTags(threshold: 500, maxPages: 50),
        ),
        (
          name: '元',
          needed: needsMetaFetch,
          message: '拉取元标签...',
          fetch: () => service.fetchMetaTags(threshold: 10000, maxPages: 50),
        ),
      ];

      for (final task in fetchTasks) {
        if (!task.needed) {
          AppLogger.i('Skipping ${task.name} tags fetch (already has data)', 'Warmup');
          continue;
        }
        state = state.copyWith(subTaskMessage: task.message);
        await task.fetch().timeout(
          const Duration(seconds: 60),
          onTimeout: () => AppLogger.w('${task.name} tags fetch timeout', 'Warmup'),
        );
        AppLogger.i('${task.name} tags fetched successfully', 'Warmup');
      }

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
  Future<void> _fetchArtistTagsInWarmup() async {
    AppLogger.i('Starting artist tags fetch in warmup phase...', 'Warmup');

    try {
      // 使用 Provider 的 syncArtists 方法，确保完成后状态更新
      // 这会正确处理重复拉取的检查，并在完成后更新 Provider 状态
      await ref.read(danbooruTagsCacheNotifierProvider.notifier).syncArtists(
        force: false, // 如果有数据则跳过
      );

      AppLogger.i('Artist tags fetch completed in warmup phase', 'Warmup');
    } catch (e, stack) {
      AppLogger.e('Artist tags fetch error in warmup phase: $e', e, stack, 'Warmup');
      // 预热阶段失败不阻塞，进入主页后可能重试
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

      // 1. 检查 translations 和 cooccurrences
      // 注意：核心数据恢复已在 main() 中完成，这里只检查状态
      if (translationCount == 0 || cooccurrenceCount == 0) {
        AppLogger.w(
          '核心数据为空，将在后台通过API拉取补充',
          'Warmup',
        );
        // 不再调用 recover()，避免重复恢复导致 ConnectionPool 被替换
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

      final needsAnyFetch = needsGeneralFetch || needsCharacterFetch ||
          needsCopyrightFetch || needsMetaFetch;

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
      state = state.copyWith(subTaskMessage: '正在从服务器拉取标签数据...');

      // 定义标签拉取任务
      final fetchTasks = [
        if (needsGeneralFetch)
          (message: '正在拉取一般标签...', fetch: () => service.fetchGeneralTags(threshold: 1000, maxPages: 50)),
        if (needsCharacterFetch)
          (message: '正在拉取角色标签...', fetch: () => service.fetchCharacterTags(threshold: 100, maxPages: 50)),
        if (needsCopyrightFetch)
          (message: '正在拉取版权标签...', fetch: () => service.fetchCopyrightTags(threshold: 500, maxPages: 50)),
        if (needsMetaFetch)
          (message: '正在拉取元标签...', fetch: () => service.fetchMetaTags(threshold: 10000, maxPages: 50)),
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
