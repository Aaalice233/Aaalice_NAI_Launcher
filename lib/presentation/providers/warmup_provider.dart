import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/proxy_service.dart';
import '../../core/network/system_proxy_http_overrides.dart';
import '../../core/enums/warmup_phase.dart';
import '../../core/services/app_warmup_service.dart';
import '../../core/services/cooccurrence_service.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/data_migration_service.dart';
import '../../core/services/translation/translation_providers.dart';
import '../../core/services/translation_lazy_service.dart';
import '../../core/services/unified_tag_database.dart';
import '../../core/services/warmup_metrics_service.dart';
import '../../core/services/warmup_task_scheduler.dart';
import 'background_task_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/nai_auth_api_service.dart';
import '../../data/datasources/remote/nai_user_info_api_service.dart';
import '../../data/models/settings/proxy_settings.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../screens/statistics/statistics_state.dart';
import 'auth_provider.dart';
import 'data_source_cache_provider.dart';
import 'font_provider.dart';
import 'prompt_config_provider.dart';
import 'proxy_settings_provider.dart';
import 'subscription_provider.dart';
import '../../data/services/vibe_library_migration_service.dart';

part 'warmup_provider.g.dart';

/// 进度回调类型定义
typedef WarmupTaskRef = void Function(double progress, String? message);

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
  late WarmupMetricsService _metricsService;
  StreamSubscription<PhaseProgress>? _phaseSubscription;
  final _completer = Completer<void>();

  @override
  WarmupState build() {
    ref.onDispose(() {
      _phaseSubscription?.cancel();
    });

    _scheduler = WarmupTaskScheduler();
    _metricsService = ref.read(warmupMetricsServiceProvider);
    _registerTasksV2();
    _startWarmupV2();

    return WarmupState.initial();
  }

  /// 等待预热完成
  Future<void> get whenComplete => _completer.future;

  /// 创建带进度回调的数据源初始化任务
  WarmupTask _createDataSourceTask({
    required String name,
    required String label,
    required int weight,
    required Duration timeout,
    required Future<void> Function(WarmupTaskRef) task,
  }) {
    return WarmupTask(
      name: name,
      weight: weight,
      timeout: timeout,
      task: () async {
        try {
          AppLogger.i('Initializing $label...', 'Warmup');
          await task((progress, message) {
            final msg = message ?? '${(progress * 100).toInt()}%';
            state = state.copyWith(subTaskMessage: '$label: $msg');
          });
          state = state.copyWith(subTaskMessage: null);
          AppLogger.i('$label initialized', 'Warmup');
        } catch (e) {
          state = state.copyWith(subTaskMessage: null);
          AppLogger.w('$label initialization failed: $e', 'Warmup');
        }
      },
    );
  }

  /// 创建简单的 Provider 读取任务
  WarmupTask _createProviderTask<T>(
    String name, {
    required int weight,
    required ProviderListenable<T> provider,
    String? logMessage,
  }) {
    return WarmupTask(
      name: name,
      weight: weight,
      task: () async {
        ref.read(provider);
        if (logMessage != null) {
          AppLogger.i(logMessage, 'Warmup');
        }
      },
    );
  }

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

  WarmupTask _createNetworkWarmupTask() {
    return WarmupTask(
      name: 'warmup_network',
      weight: 1,
      timeout: AppWarmupService.networkTimeout,
      task: () async {
        AppLogger.i('Network service warmup started', 'Warmup');
        try {
          await Future.delayed(const Duration(milliseconds: 100))
              .timeout(AppWarmupService.networkTimeout);
          AppLogger.i('Network service warmup completed', 'Warmup');
        } on TimeoutException {
          AppLogger.w('Network service warmup timed out', 'Warmup');
        } catch (e) {
          AppLogger.w('Network service warmup failed: $e', 'Warmup');
        }
      },
    );
  }

  WarmupTask _createSubscriptionTask() {
    return WarmupTask(
      name: 'warmup_subscription',
      weight: 2,
      timeout: const Duration(seconds: 10),
      task: () async {
        try {
          final authState = ref.read(authNotifierProvider);
          if (!authState.isAuthenticated) {
            AppLogger.i('User not authenticated, skip subscription preload', 'Warmup');
            return;
          }

          AppLogger.i('Preloading subscription info...', 'Warmup');
          await _fetchSubscriptionWithRetry();
          AppLogger.i('Subscription preloaded successfully', 'Warmup');
        } catch (e) {
          AppLogger.w('Subscription preload failed: $e', 'Warmup');
        }
      },
    );
  }

  Future<void> _fetchSubscriptionWithRetry() async {
    final notifier = ref.read(subscriptionNotifierProvider.notifier);

    await notifier.fetchSubscription().timeout(const Duration(seconds: 4));

    final subState = ref.read(subscriptionNotifierProvider);
    if (!subState.isError) return;

    AppLogger.w('Subscription preload failed, refreshing network and retrying...', 'Warmup');
    ref.invalidate(dioClientProvider);
    ref.invalidate(naiUserInfoApiServiceProvider);
    await Future.delayed(const Duration(milliseconds: 200));

    await ref.read(subscriptionNotifierProvider.notifier)
        .fetchSubscription()
        .timeout(const Duration(seconds: 4));
  }

  WarmupTask _createCacheServiceTask() {
    return WarmupTask(
      name: 'warmup_dataSourceCache',
      weight: 1,
      timeout: const Duration(seconds: 3),
      task: () async {
        try {
          AppLogger.i('Preloading data source cache services...', 'Warmup');
          ref.read(hFTranslationCacheNotifierProvider);
          ref.read(danbooruTagsCacheNotifierProvider);
          AppLogger.i('Data source cache services preloaded', 'Warmup');
        } catch (e) {
          AppLogger.w('Data source cache preload failed: $e', 'Warmup');
        }
      },
    );
  }

  WarmupTask _createGalleryCountTask() {
    return WarmupTask(
      name: 'warmup_galleryFileCount',
      weight: 1,
      timeout: const Duration(seconds: 3),
      task: () async {
        try {
          AppLogger.i('Counting gallery files...', 'Warmup');
          final files = await LocalGalleryRepository.instance.getAllImageFiles();
          AppLogger.i('Gallery file count: ${files.length}', 'Warmup');
        } catch (e) {
          AppLogger.w('Gallery file count failed: $e', 'Warmup');
        }
      },
    );
  }

  /// 重试预加载
  void retry() {
    _phaseSubscription?.cancel();
    _scheduler.clear();
    state = WarmupState.initial();
    _registerTasksV2();
    _startWarmupV2();
  }

  /// 确保网络服务 Provider 已完全重建
  /// 
  /// 在代理配置变化后调用，通过监听 Provider 状态确保新的 DioClient 实例已创建
  /// 避免自动登录使用旧的网络配置导致连接失败
  Future<void> _ensureNetworkProvidersReady() async {
    AppLogger.i('Waiting for network providers to rebuild...', 'Warmup');

    // 方法1：通过读取 Provider 触发重建并等待完成
    // 使用 listen 获取最新的 Provider 实例，确保已重建
    // 读取 dioClientProvider 确保 DioClient 已重建
    ref.read(dioClientProvider);
    final authApiService = ref.read(naiAuthApiServiceProvider);

    // 验证 DioClient 是否使用了新的代理配置
    // 通过发送一个简单的请求来验证连接是否正常工作
    try {
      // 发送一个轻量级的请求来预热连接
      await authApiService.validateToken('').timeout(
        const Duration(seconds: 2),
        onTimeout: () => {}, // 超时也没关系，只是验证连接可用
      );
    } catch (e) {
      // 预期会失败（token为空），但连接层应该正常工作
      // 如果是连接错误，说明 Provider 还未准备好
      if (e.toString().contains('connection') ||
          e.toString().contains('SocketException')) {
        AppLogger.w('Network providers not ready yet, waiting...', 'Warmup');
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    AppLogger.i('Network providers ready', 'Warmup');
  }

  /// 检查网络环境
  Future<void> _checkNetworkEnvironment() async {
    String? lastProxyAddress;

    while (true) {
      final proxySettings = ref.read(proxySettingsNotifierProvider);
      final currentProxyAddress = proxySettings.effectiveProxyAddress;

      if (currentProxyAddress != lastProxyAddress) {
        await _updateProxyConfiguration(currentProxyAddress);
        lastProxyAddress = currentProxyAddress;
      }

      // 尝试直接连接
      state = state.copyWith(subTaskMessage: '正在检测网络连接...');
      final directResult = await ProxyService.testNovelAIConnection();

      if (directResult.success) {
        await _onNetworkReady(directResult.latencyMs ?? 0, useProxy: false);
        break;
      }

      AppLogger.w('Direct connection failed: ${directResult.errorMessage}', 'Warmup');

      // 检查代理设置
      if (!proxySettings.enabled) {
        await _waitForUserAction('无法连接到 NovelAI，请开启VPN或启用代理设置');
        continue;
      }

      final proxyAddress = proxySettings.effectiveProxyAddress;
      if (proxyAddress == null || proxyAddress.isEmpty) {
        final message = proxySettings.mode == ProxyMode.auto
            ? '已启用代理但未检测到系统代理，请开启VPN'
            : '手动代理配置不完整，请检查设置';
        await _waitForUserAction(message);
        continue;
      }

      // 尝试代理连接
      state = state.copyWith(subTaskMessage: '正在通过代理检测网络...');
      final proxyResult = await ProxyService.testNovelAIConnection(proxyAddress: proxyAddress);

      if (proxyResult.success) {
        await _onNetworkReady(proxyResult.latencyMs ?? 0, useProxy: true);
        break;
      }

      AppLogger.w('NovelAI connection via proxy failed: ${proxyResult.errorMessage}', 'Warmup');
      await _waitForUserAction('网络连接失败: ${proxyResult.errorMessage}，请检查VPN');
    }
  }

  Future<void> _updateProxyConfiguration(String? proxyAddress) async {
    AppLogger.i('Proxy configuration changed to: $proxyAddress, refreshing network services', 'Warmup');

    HttpOverrides.global = (proxyAddress != null && proxyAddress.isNotEmpty)
        ? SystemProxyHttpOverrides('PROXY $proxyAddress')
        : null;

    ref.invalidate(dioClientProvider);
    ref.invalidate(naiAuthApiServiceProvider);
    ref.invalidate(naiUserInfoApiServiceProvider);

    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _onNetworkReady(int latencyMs, {required bool useProxy}) async {
    AppLogger.i('NovelAI connection ${useProxy ? 'via proxy ' : ''}successful: ${latencyMs}ms', 'Warmup');
    state = state.copyWith(subTaskMessage: '网络连接正常 (${latencyMs}ms)');
    await Future.delayed(const Duration(milliseconds: 500));
    state = state.copyWith(subTaskMessage: null);

    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.unauthenticated ||
        authState.status == AuthStatus.loading) {
      AppLogger.i('Network ready but user not authenticated (status: ${authState.status}), triggering auto-login retry', 'Warmup');
      await _ensureNetworkProvidersReady();
      await ref.read(authNotifierProvider.notifier).retryAutoLogin();
    }
  }

  Future<void> _waitForUserAction(String message) async {
    state = state.copyWith(subTaskMessage: message);
    await Future.delayed(const Duration(seconds: 2));
  }

  /// 检查网络环境（带超时）- V2优化版
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
  // V2: 三阶段预热架构
  // ===========================================================================

  /// 注册所有预热任务（新架构）
  void _registerTasksV2() {
    // ==== 阶段 1: Critical ====
    _registerCriticalPhaseTasks();

    // ==== 阶段 2: Quick ====
    _registerQuickPhaseTasks();

    // ==== 阶段 3: Background ====
    _registerBackgroundPhaseTasks();
  }

  void _registerCriticalPhaseTasks() {
    // 1. 数据迁移
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_dataMigration',
        phase: WarmupPhase.critical,
        weight: 2,
        timeout: const Duration(seconds: 60),
        task: _runDataMigration,
      ),
    );

    // 2. 数据库轻量级初始化
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_unifiedDbInit',
        phase: WarmupPhase.critical,
        weight: 1,
        timeout: const Duration(seconds: 10),
        task: _initUnifiedDatabaseLightweight,
      ),
    );

    // 3. 基础UI服务（并行）
    _scheduler.registerGroup(
      PhasedTaskGroup(
        name: 'basicUI',
        phase: WarmupPhase.critical,
        parallel: true,
        tasks: [
          PhasedWarmupTask(
            name: 'warmup_imageCache',
            phase: WarmupPhase.critical,
            weight: 1,
            task: _configureImageCache,
          ),
          PhasedWarmupTask(
            name: 'warmup_fonts',
            phase: WarmupPhase.critical,
            weight: 1,
            task: _preloadFonts,
          ),
          PhasedWarmupTask(
            name: 'warmup_imageEditor',
            phase: WarmupPhase.critical,
            weight: 1,
            task: _warmupImageEditor,
          ),
        ],
      ),
    );
  }

  void _registerQuickPhaseTasks() {
    // 1. 轻量级网络检测（带超时）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_networkCheck',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 30),
        task: _checkNetworkEnvironmentWithTimeout,
      ),
    );

    // 2. 提示词配置
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_loadingPromptConfig',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 10),
        task: _loadPromptConfig,
      ),
    );

    // 3. 画廊计数
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_galleryFileCount',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 3),
        task: _countGalleryFiles,
      ),
    );

    // 4. 订阅信息（仅缓存，不强制网络）
    _scheduler.registerTask(
      PhasedWarmupTask(
        name: 'warmup_subscription',
        phase: WarmupPhase.quick,
        weight: 1,
        timeout: const Duration(seconds: 3),
        task: _loadSubscriptionCached,
      ),
    );
  }

  void _registerBackgroundPhaseTasks() {
    // 后台任务注册到 BackgroundTaskProvider
    // 实际执行在进入主界面后
    final backgroundNotifier = ref.read(backgroundTaskNotifierProvider.notifier);

    // 共现数据后台加载
    backgroundNotifier.registerTask(
      'cooccurrence_preload',
      '共现数据',
      () => _preloadCooccurrenceInBackground(),
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

  /// 开始新的预热流程
  Future<void> _startWarmupV2() async {
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

      // 启动后台任务
      await Future.delayed(const Duration(seconds: 1)); // 稍等片刻让UI稳定
      ref.read(backgroundTaskNotifierProvider.notifier).startAll();
    } catch (e, stack) {
      AppLogger.e('Warmup failed', e, stack, 'Warmup');
      state = state.copyWith(
        error: e.toString(),
        progress: WarmupProgress.error(e.toString()),
      );
      _completer.completeError(e);
    }
  }

  /// 轻量级初始化统一数据库
  Future<void> _initUnifiedDatabaseLightweight() async {
    AppLogger.i('Initializing unified tag database (lightweight)...', 'Warmup');
    final db = ref.read(unifiedTagDatabaseProvider);
    await db.initialize();
    AppLogger.i('Unified tag database initialized', 'Warmup');
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

  Future<void> _preloadCooccurrenceInBackground() async {
    final service = ref.read(cooccurrenceServiceProvider);
    service.onProgress = (progress, message) {
      ref
          .read(backgroundTaskNotifierProvider.notifier)
          .updateProgress('cooccurrence_preload', progress, message: message);
    };
    await service.initializeLightweight();
    await service.preloadHotDataInBackground();
    service.onProgress = null;
  }

  Future<void> _preloadTranslationInBackground() async {
    final service = ref.read(translationLazyServiceProvider);
    service.onProgress = (progress, message) {
      ref
          .read(backgroundTaskNotifierProvider.notifier)
          .updateProgress('translation_preload', progress, message: message);
    };
    await service.initializeLightweight();
    await service.preloadHotDataInBackground();
    service.onProgress = null;
  }

  Future<void> _preloadDanbooruTagsInBackground() async {
    final service = ref.read(danbooruTagsLazyServiceProvider);
    service.onProgress = (progress, message) {
      ref
          .read(backgroundTaskNotifierProvider.notifier)
          .updateProgress('danbooru_tags_preload', progress, message: message);
    };
    await service.initializeLightweight();
    await service.preloadHotDataInBackground();
    service.onProgress = null;
  }
}
