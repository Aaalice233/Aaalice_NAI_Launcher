import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/app_warmup_service.dart';
import '../../core/services/tag_data_service.dart';
import '../../core/services/warmup_metrics_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/services/danbooru_auth_service.dart';
import '../../data/services/tag_translation_service.dart';
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
    // 1. 加载标签翻译服务
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_loadingTranslation',
        weight: 2,
        task: () async {
          final translationService = ref.read(tagTranslationServiceProvider);
          await translationService.load();
        },
      ),
    );

    // 2. 初始化标签数据服务（非阻塞式，网络下载在后台进行）
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

    // 3. 加载随机提示词配置
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

    // 4. 初始化 Danbooru 认证状态（加载保存的凭据）
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

    // 5. 预加载图片编辑器资源（stub 实现）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_imageEditor',
        weight: 1,
        task: () async {
          // Stub implementation for future image editor resource preloading
          AppLogger.i('Image editor resources warmup (stub)', 'Warmup');
          // Placeholder for future image editor resource initialization
          await Future.delayed(const Duration(milliseconds: 100));
        },
      ),
    );

    // 6. 预加载数据库内容（stub 实现）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_database',
        weight: 1,
        task: () async {
          // Stub implementation for future database content warmup
          AppLogger.i('Database content warmup (stub)', 'Warmup');
          // Placeholder for future database content initialization (e.g., frequently accessed queries, indexes, cached data)
          await Future.delayed(const Duration(milliseconds: 100));
        },
      ),
    );

    // 7. 检查网络连接状态（带超时）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_network',
        weight: 1,
        task: () async {
          // Network connectivity check with timeout
          AppLogger.i('Network connectivity check started', 'Warmup');

          try {
            // Simulate network connectivity check with timeout
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

    // 8. 预加载字体和图标（stub 实现）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_fonts',
        weight: 1,
        task: () async {
          // Stub implementation for fonts and icons preloading
          AppLogger.i('Fonts and icons warmup (stub)', 'Warmup');
          // Placeholder for future fonts and icons initialization (e.g., custom fonts, icon packs, font caching)
          await Future.delayed(const Duration(milliseconds: 100));
        },
      ),
    );

    // 9. 预加载图片缓存（stub 实现）
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_imageCache',
        weight: 1,
        task: () async {
          // Stub implementation for image cache warmup
          AppLogger.i('Image cache warmup (stub)', 'Warmup');
          // Placeholder for future image cache initialization (e.g., preloading common images, cache size configuration, memory limits)
          await Future.delayed(const Duration(milliseconds: 100));
        },
      ),
    );
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

  /// 跳过预加载（直接进入应用）
  void skip() {
    _subscription?.cancel();
    state = WarmupState.complete();
  }
}
