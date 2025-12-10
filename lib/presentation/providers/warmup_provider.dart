import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_warmup_service.dart';
import '../../core/services/tag_data_service.dart';
import '../../data/services/tag_translation_service.dart';
import 'prompt_config_provider.dart';

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
class WarmupNotifier extends StateNotifier<WarmupState> {
  final Ref _ref;
  late AppWarmupService _warmupService;
  StreamSubscription<WarmupProgress>? _subscription;

  WarmupNotifier(this._ref) : super(WarmupState.initial()) {
    _warmupService = AppWarmupService();
    _registerTasks();
    _startWarmup();
  }

  /// 注册所有预加载任务
  void _registerTasks() {
    // 1. 加载标签翻译服务
    _warmupService.registerTask(
      WarmupTask(
        name: 'warmup_loadingTranslation',
        weight: 2,
        task: () async {
          final translationService = _ref.read(tagTranslationServiceProvider);
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
          final translationService = _ref.read(tagTranslationServiceProvider);
          final tagDataService = _ref.read(tagDataServiceProvider);

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
          _ref.read(promptConfigNotifierProvider.notifier);
          // 等待最多 3 秒
          for (var i = 0; i < 60; i++) {
            await Future.delayed(const Duration(milliseconds: 50));
            final state = _ref.read(promptConfigNotifierProvider);
            if (!state.isLoading) break;
          }
        },
      ),
    );
  }

  /// 开始预加载
  void _startWarmup() {
    _subscription = _warmupService.run().listen(
      (progress) {
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// 预加载状态 Provider
final warmupNotifierProvider =
    StateNotifierProvider<WarmupNotifier, WarmupState>((ref) {
  return WarmupNotifier(ref);
});
