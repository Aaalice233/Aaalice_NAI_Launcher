import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/danbooru_image_cache_manager.dart';
import '../../core/services/app_warmup_service.dart';
import '../../core/services/tag_data_service.dart';
import '../../core/services/warmup_metrics_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/tag_translation_service.dart';
import '../screens/statistics/statistics_state.dart';
import 'font_provider.dart';
import 'prompt_config_provider.dart';

part 'warmup_provider.g.dart';

/// 预加载状态
class WarmupState {
  final WarmupProgress progress;
  final bool isComplete;
  final String? error;

  const WarmupState({
    required this.progress,
    this.isComplete = false,
    this.error,
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
  }) {
    return WarmupState(
      progress: progress ?? this.progress,
      isComplete: isComplete ?? this.isComplete,
      error: error ?? this.error,
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
    // 1. 配置图片缓存（优先执行）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_imageCache',
        weight: 1,
        task: () async {
          // 配置 Flutter 图片缓存大小
          PaintingBinding.instance.imageCache.maximumSize = 500;
          PaintingBinding.instance.imageCache.maximumSizeBytes =
              100 * 1024 * 1024; // 100MB

          // 初始化 Danbooru 缓存管理器（触发单例）
          // ignore: unused_local_variable
          final cacheManager = DanbooruImageCacheManager.instance;

          AppLogger.i(
            'Image cache configured: max=500, maxBytes=100MB',
            'Warmup',
          );
        },
      ),
    );

    // 2. 预加载用户选择的字体
    _warmupService.registerTask(
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
    );

    // 3. 加载标签翻译服务（优化后：缓存优先 + Isolate 解析，< 1秒）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_loadingTranslation',
        weight: 2,
        timeout: const Duration(seconds: 5),
        task: () async {
          final translationService = ref.read(tagTranslationServiceProvider);
          await translationService.load();
        },
      ),
    );

    // 4. 初始化标签数据服务（非阻塞式，网络下载在后台进行）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_initTagSystem',
        weight: 1,
        task: () async {
          final translationService = ref.read(tagTranslationServiceProvider);
          final tagDataService = ref.read(tagDataServiceProvider);

          // 关联服务
          translationService.setTagDataService(tagDataService);

          // 初始化（非阻塞式：先用内置数据，网络下载在后台）
          await tagDataService.initialize();
        },
      ),
    );

    // 5. 加载随机提示词配置
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_loadingPromptConfig',
        weight: 1,
        task: () async {
          // 触发 provider 初始化并等待加载完成
          ref.read(promptConfigNotifierProvider.notifier);
          // 等待最多 3 秒
          for (var i = 0; i < 60; i++) {
            await Future.delayed(const Duration(milliseconds: 50));
            final configState = ref.read(promptConfigNotifierProvider);
            if (!configState.isLoading) break;
          }
        },
      ),
    );

    // 6. 初始化 Danbooru 认证状态（加载保存的凭据）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_danbooruAuth',
        weight: 1,
        task: () async {
          // 触发 provider 初始化，会自动调用 build() 中的 _loadSavedCredentials()
          ref.read(danbooruAuthProvider);
          AppLogger.i('Danbooru auth provider initialized', 'Warmup');
        },
      ),
    );

    // 7. 预加载统计数据（最耗时任务，使用10秒超时）
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

    // 8. 预热图片编辑器 Canvas
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_imageEditor',
        weight: 1,
        task: () async {
          try {
            // 轻量级预热：测试 Canvas 渲染能力
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
    );

    // 9. 检查网络连接状态（带超时）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_network',
        weight: 1,
        task: () async {
          AppLogger.i('Network connectivity check started', 'Warmup');

          try {
            // 模拟网络连接检查
            await Future.delayed(const Duration(milliseconds: 200))
                .timeout(const Duration(seconds: 2));
            AppLogger.i('Network connectivity check completed', 'Warmup');
          } on TimeoutException {
            AppLogger.w('Network connectivity check timed out', 'Warmup');
          } catch (e) {
            AppLogger.w('Network connectivity check failed: $e', 'Warmup');
          }
        },
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
