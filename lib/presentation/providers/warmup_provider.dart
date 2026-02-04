import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/services/app_warmup_service.dart';
import '../../core/services/cooccurrence_service.dart';
import '../../core/services/danbooru_tags_lazy_service.dart';
import '../../core/services/tag_data_service.dart';
import '../../core/services/translation_lazy_service.dart';
import '../../core/services/warmup_metrics_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/tag_translation_service.dart';
import '../screens/statistics/statistics_state.dart';
import 'auth_provider.dart';
import 'data_source_cache_provider.dart';
import 'font_provider.dart';
import 'prompt_config_provider.dart';
import 'subscription_provider.dart';

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
  late AppWarmupService _warmupService;
  late WarmupMetricsService _metricsService;
  StreamSubscription<WarmupProgress>? _subscription;

  @override
  WarmupState build() {
    // 注册生命周期回调
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // 初始化服务并开始预加载
    _warmupService = AppWarmupService();
    _metricsService = ref.read(warmupMetricsServiceProvider);
    _registerTasks();
    _startWarmup();

    return WarmupState.initial();
  }

  /// 注册所有预加载任务
  void _registerTasks() {
    // ==== 第1组：基础UI服务（并行执行）====
    // 这些任务相互独立，可以并行执行
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'basicUI',
        parallel: true,
        tasks: [
          // 配置图片缓存
          WarmupTask(
            name: 'warmup_imageCache',
            weight: 1,
            task: () async {
              PaintingBinding.instance.imageCache.maximumSize = 500;
              PaintingBinding.instance.imageCache.maximumSizeBytes =
                  100 * 1024 * 1024; // 100MB
              // 触发缓存管理器初始化
              // ignore: unused_local_variable
              final cacheManager = DanbooruImageCacheManager.instance;
              AppLogger.i(
                'Image cache configured: max=500, maxBytes=100MB',
                'Warmup',
              );
            },
          ),
          // 预加载字体
          WarmupTask(
            name: 'warmup_fonts',
            weight: 1,
            task: () async {
              final fontConfig = ref.read(fontNotifierProvider);
              if (fontConfig.source == FontSource.google &&
                  fontConfig.fontFamily.isNotEmpty) {
                try {
                  await GoogleFonts.pendingFonts([
                    GoogleFonts.getFont(fontConfig.fontFamily),
                  ]);
                  AppLogger.i(
                    'Preloaded Google Font: ${fontConfig.fontFamily}',
                    'Warmup',
                  );
                } catch (e) {
                  AppLogger.w('Font preload failed: $e', 'Warmup');
                }
              } else {
                AppLogger.i('Using system font, skip preload', 'Warmup');
              }
            },
          ),
          // 预热图片编辑器
          WarmupTask(
            name: 'warmup_imageEditor',
            weight: 1,
            task: () async {
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
            },
          ),
        ],
      ),
    );

    // ==== 第2组：数据服务（并行执行）====
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'dataServices',
        parallel: true,
        tasks: [
          // 加载标签翻译服务
          WarmupTask(
            name: 'warmup_loadingTranslation',
            weight: 2,
            timeout: const Duration(seconds: 5),
            task: () async {
              final translationService = ref.read(tagTranslationServiceProvider);
              await translationService.load();
            },
          ),
          // 初始化标签数据服务
          WarmupTask(
            name: 'warmup_initTagSystem',
            weight: 1,
            timeout: const Duration(seconds: 15),
            task: () async {
              final translationService = ref.read(tagTranslationServiceProvider);
              final tagDataService = ref.read(tagDataServiceProvider);
              translationService.setTagDataService(tagDataService);
              await tagDataService.initialize();
            },
          ),
          // 加载随机提示词配置
          WarmupTask(
            name: 'warmup_loadingPromptConfig',
            weight: 1,
            timeout: const Duration(seconds: 10),
            task: () async {
              final notifier = ref.read(promptConfigNotifierProvider.notifier);
              await notifier.whenLoaded.timeout(const Duration(seconds: 8));
            },
          ),
        ],
      ),
    );

    // ==== 第3组：网络服务（并行执行）====
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'networkServices',
        parallel: true,
        tasks: [
          // 初始化网络连接状态
          WarmupTask(
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
          ),
          // 初始化 Danbooru 认证状态
          WarmupTask(
            name: 'warmup_danbooruAuth',
            weight: 1,
            task: () async {
              ref.read(danbooruAuthProvider);
              AppLogger.i('Danbooru auth provider initialized', 'Warmup');
            },
          ),
          // 预加载订阅信息
          WarmupTask(
            name: 'warmup_subscription',
            weight: 2,
            timeout: const Duration(seconds: 5),
            task: () async {
              try {
                final authState = ref.read(authNotifierProvider);
                if (authState.isAuthenticated) {
                  AppLogger.i('Preloading subscription info...', 'Warmup');
                  await ref
                      .read(subscriptionNotifierProvider.notifier)
                      .fetchSubscription()
                      .timeout(const Duration(seconds: 4));
                  AppLogger.i('Subscription preloaded successfully', 'Warmup');
                } else {
                  AppLogger.i('User not authenticated, skip subscription preload', 'Warmup');
                }
              } catch (e) {
                AppLogger.w('Subscription preload failed: $e', 'Warmup');
              }
            },
          ),
        ],
      ),
    );

    // ==== 第4组：缓存服务（并行执行）====
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'cacheServices',
        parallel: true,
        tasks: [
          // 预初始化数据源缓存服务
          WarmupTask(
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
          ),
          // 本地图库文件计数
          WarmupTask(
            name: 'warmup_galleryFileCount',
            weight: 1,
            timeout: const Duration(seconds: 3),
            task: () async {
              try {
                AppLogger.i('Counting gallery files...', 'Warmup');
                final repo = LocalGalleryRepository.instance;
                final files = await repo.getAllImageFiles();
                AppLogger.i('Gallery file count: ${files.length}', 'Warmup');
              } catch (e) {
                AppLogger.w('Gallery file count failed: $e', 'Warmup');
              }
            },
          ),
        ],
      ),
    );

    // ==== 串行任务：统计数据（最耗时，需要独立执行）====
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_statistics',
        weight: 3,
        timeout: const Duration(seconds: 10),
        task: () async {
          try {
            final notifier = ref.read(statisticsNotifierProvider.notifier);
            await notifier.preloadForWarmup();
          } catch (e) {
            AppLogger.w('Statistics preload failed: $e', 'Warmup');
          }
        },
      ),
    );

    // ==== 第5组：数据源懒加载初始化（并行执行）====
    // 三个数据源并行初始化，每个只加载热数据到内存
    _warmupService.registerGroup(
      WarmupTaskGroup(
        name: 'dataSourceInitialization',
        parallel: true,
        tasks: [
          // 共现数据懒加载初始化
          WarmupTask(
            name: 'warmup_cooccurrenceInit',
            weight: 3,
            timeout: const Duration(seconds: 180),
            task: () async {
              try {
                AppLogger.i('Initializing cooccurrence data...', 'Warmup');
                final service = ref.read(cooccurrenceServiceProvider);
                service.onProgress = (progress, message) {
                  final msg = message ?? '${(progress * 100).toInt()}%';
                  // 更新子任务消息到状态
                  state = state.copyWith(subTaskMessage: '共现: $msg');
                  AppLogger.d(
                    'Cooccurrence init: ${(progress * 100).toStringAsFixed(1)}% - $message',
                    'Warmup',
                  );
                };
                await service.initializeLazy();
                state = state.copyWith(subTaskMessage: null);
                AppLogger.i('Cooccurrence data initialized', 'Warmup');
              } catch (e) {
                state = state.copyWith(subTaskMessage: null);
                AppLogger.w('Cooccurrence initialization failed: $e', 'Warmup');
              }
            },
          ),
          // 翻译数据懒加载初始化（首次使用时会下载数据）
          WarmupTask(
            name: 'warmup_translationInit',
            weight: 3,
            timeout: const Duration(seconds: 60),
            task: () async {
              try {
                AppLogger.i('Initializing translation data...', 'Warmup');
                final service = ref.read(translationLazyServiceProvider);
                service.onProgress = (progress, message) {
                  final msg = message ?? '${(progress * 100).toInt()}%';
                  // 更新子任务消息到状态
                  state = state.copyWith(subTaskMessage: '翻译: $msg');
                  AppLogger.d(
                    'Translation init: ${(progress * 100).toStringAsFixed(1)}% - $message',
                    'Warmup',
                  );
                };
                await service.initialize();
                state = state.copyWith(subTaskMessage: null);
                AppLogger.i('Translation data initialized', 'Warmup');
              } catch (e) {
                state = state.copyWith(subTaskMessage: null);
                AppLogger.w('Translation initialization failed: $e', 'Warmup');
              }
            },
          ),
          // Danbooru 标签懒加载初始化（首次使用时会下载数据）
          WarmupTask(
            name: 'warmup_danbooruTagsInit',
            weight: 3,
            timeout: const Duration(seconds: 120),
            task: () async {
              try {
                AppLogger.i('Initializing Danbooru tags...', 'Warmup');
                final service = ref.read(danbooruTagsLazyServiceProvider);
                service.onProgress = (progress, message) {
                  final msg = message ?? '${(progress * 100).toInt()}%';
                  // 更新子任务消息到状态
                  state = state.copyWith(subTaskMessage: '标签: $msg');
                  AppLogger.d(
                    'Danbooru tags init: ${(progress * 100).toStringAsFixed(1)}% - $message',
                    'Warmup',
                  );
                };
                await service.initialize();
                state = state.copyWith(subTaskMessage: null);
                AppLogger.i('Danbooru tags initialized', 'Warmup');
              } catch (e) {
                state = state.copyWith(subTaskMessage: null);
                AppLogger.w('Danbooru tags initialization failed: $e', 'Warmup');
              }
            },
          ),
        ],
      ),
    );

    // 注意：画师数据同步已从启动时移除，改为登录成功后触发
    // 这样可以确保用户有网络连接且已登录后再进行同步
    // 同步逻辑现在位于 auth_provider.dart 的登录成功回调中
  }

  /// 开始预加载
  void _startWarmup() {
    _subscription = _warmupService.run().listen(
      (progress) {
        // 保存指标数据
        if (progress.isComplete && progress.metrics != null) {
          _metricsService.saveSession(progress.metrics!).catchError((e) {
            AppLogger.e('Failed to save warmup metrics: $e', 'Warmup');
          });
        }

        state = state.copyWith(
          progress: progress,
          isComplete: progress.isComplete,
        );
      },
      onError: (error) {
        state = state.copyWith(
          error: error.toString(),
        );
      },
      onDone: () {
        if (!state.isComplete) {
          state = WarmupState.complete();
        }
      },
    );
  }

  /// 重试预加载
  void retry() {
    _subscription?.cancel();
    state = WarmupState.initial();
    _startWarmup();
  }
}
