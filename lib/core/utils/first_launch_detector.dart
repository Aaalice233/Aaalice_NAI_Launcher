import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/widgets/common/app_toast.dart';
import '../constants/storage_keys.dart';
import '../services/danbooru_tags_sync_service.dart';
import '../services/hf_translation_sync_service.dart';
import 'app_logger.dart';

part 'first_launch_detector.g.dart';

/// 首次启动检测器
/// 负责检测应用是否首次启动，并触发必要的后台数据同步
class FirstLaunchDetector {
  final HFTranslationSyncService _translationService;
  final DanbooruTagsSyncService _tagsService;

  /// 是否正在执行初始同步
  bool _isInitialSyncing = false;

  FirstLaunchDetector(
    this._translationService,
    this._tagsService,
  );

  /// 是否正在执行初始同步
  bool get isInitialSyncing => _isInitialSyncing;

  /// 检测是否为首次启动
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getString(StorageKeys.firstLaunchVersion);

      // 如果没有保存的版本号，说明是首次启动
      if (savedVersion == null || savedVersion.isEmpty) {
        return true;
      }

      // 如果版本号存在，说明不是首次启动
      return false;
    } catch (e) {
      AppLogger.w('Failed to check first launch: $e', 'FirstLaunch');
      return false;
    }
  }

  /// 标记已完成首次启动
  Future<void> markLaunched() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      await prefs.setString(
        StorageKeys.firstLaunchVersion,
        packageInfo.version,
      );
      AppLogger.i('Marked as launched: ${packageInfo.version}', 'FirstLaunch');
    } catch (e) {
      AppLogger.w('Failed to mark launched: $e', 'FirstLaunch');
    }
  }

  /// 执行首次启动后的初始化同步
  ///
  /// [context] 用于显示 Toast 通知
  /// 返回同步是否成功
  Future<bool> performInitialSync(BuildContext context) async {
    if (_isInitialSyncing) {
      AppLogger.w('Initial sync already in progress', 'FirstLaunch');
      return false;
    }

    _isInitialSyncing = true;
    ToastController? toastController;

    try {
      // 显示进度 Toast
      if (context.mounted) {
        toastController = AppToast.showProgress(
          context,
          '正在初始化数据...',
          progress: 0.0,
          subtitle: '首次启动，请稍候',
        );
      }

      // 1. 同步翻译数据
      toastController?.updateProgress(0.1, message: '正在同步翻译数据...');

      _translationService.onSyncProgress = (progress, message) {
        toastController?.updateProgress(
          0.1 + progress * 0.4, // 10% - 50%
          message: message ?? '正在同步翻译数据...',
        );
      };

      await _translationService.syncTranslations();

      // 2. 同步标签数据
      toastController?.updateProgress(0.5, message: '正在同步标签数据...');

      _tagsService.onSyncProgress = (progress, message) {
        toastController?.updateProgress(
          0.5 + progress * 0.3, // 50% - 80%
          message: message ?? '正在同步标签数据...',
        );
      };

      // 使用默认阈值同步
      await _tagsService.syncHotTags(minPostCount: 1000);

      // 3. 画师数据同步已移至登录成功后触发
      // 避免在首次启动时立即同步，确保用户有网络连接且已登录
      // 详见 auth_provider.dart 中的登录成功处理逻辑

      // 4. 标记已启动
      await markLaunched();

      // 完成
      toastController?.complete(message: '数据初始化完成');
      AppLogger.i('Initial sync completed successfully', 'FirstLaunch');

      return true;
    } catch (e, stack) {
      AppLogger.e('Initial sync failed', e, stack, 'FirstLaunch');
      toastController?.fail(message: '数据初始化失败');
      return false;
    } finally {
      _isInitialSyncing = false;
      _translationService.onSyncProgress = null;
      _tagsService.onSyncProgress = null;
    }
  }

  /// 检查并执行首次启动同步（自动检测）
  ///
  /// [context] 用于显示 Toast 通知
  /// 返回是否执行了同步
  Future<bool> checkAndPerformInitialSync(BuildContext context) async {
    final isFirst = await isFirstLaunch();

    if (isFirst) {
      AppLogger.i(
        'First launch detected, starting initial sync',
        'FirstLaunch',
      );
      // ignore: use_build_context_synchronously
      await performInitialSync(context);
      return true;
    }

    AppLogger.d('Not first launch, skipping initial sync', 'FirstLaunch');
    return false;
  }

  /// 检查数据是否需要刷新并执行后台刷新
  ///
  /// 这个方法用于非首次启动时检查是否需要自动刷新
  Future<void> checkAndRefreshIfNeeded() async {
    try {
      // 检查翻译数据是否需要刷新
      final needsTranslationRefresh = await _translationService.shouldRefresh();

      if (needsTranslationRefresh) {
        AppLogger.i('Translation data needs refresh', 'FirstLaunch');

        // 后台静默刷新，不显示 Toast
        _translationService.onSyncProgress = null;
        await _translationService.syncTranslations();
      }

      // 注意：Danbooru 标签数据不需要自动刷新
      // 用户可以手动触发刷新
    } catch (e) {
      AppLogger.w('Background refresh failed: $e', 'FirstLaunch');
    }
  }
}

/// FirstLaunchDetector Provider
@Riverpod(keepAlive: true)
FirstLaunchDetector firstLaunchDetector(Ref ref) {
  final translationService = ref.read(hfTranslationSyncServiceProvider);
  final tagsService = ref.read(danbooruTagsSyncServiceProvider);

  return FirstLaunchDetector(translationService, tagsService);
}

/// 首次启动状态
class FirstLaunchState {
  final bool isFirstLaunch;
  final bool isSyncing;
  final bool hasSyncCompleted;
  final String? error;

  const FirstLaunchState({
    this.isFirstLaunch = false,
    this.isSyncing = false,
    this.hasSyncCompleted = false,
    this.error,
  });

  FirstLaunchState copyWith({
    bool? isFirstLaunch,
    bool? isSyncing,
    bool? hasSyncCompleted,
    String? error,
  }) {
    return FirstLaunchState(
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isSyncing: isSyncing ?? this.isSyncing,
      hasSyncCompleted: hasSyncCompleted ?? this.hasSyncCompleted,
      error: error ?? this.error,
    );
  }
}

/// 首次启动状态 Notifier
@riverpod
class FirstLaunchNotifier extends _$FirstLaunchNotifier {
  @override
  FirstLaunchState build() {
    return const FirstLaunchState();
  }

  /// 检查并执行首次启动同步
  Future<void> checkAndSync(BuildContext context) async {
    final detector = ref.read(firstLaunchDetectorProvider);

    final isFirst = await detector.isFirstLaunch();
    state = state.copyWith(isFirstLaunch: isFirst);

    if (isFirst) {
      state = state.copyWith(isSyncing: true);

      try {
        // ignore: use_build_context_synchronously
        await detector.performInitialSync(context);
        state = state.copyWith(
          isSyncing: false,
          hasSyncCompleted: true,
        );
      } catch (e) {
        state = state.copyWith(
          isSyncing: false,
          error: e.toString(),
        );
      }
    } else {
      // 非首次启动，检查是否需要后台刷新
      await detector.checkAndRefreshIfNeeded();
    }
  }
}
