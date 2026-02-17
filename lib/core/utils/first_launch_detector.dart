import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import '../services/danbooru_tags_lazy_service.dart';
import 'app_logger.dart';

part 'first_launch_detector.g.dart';

/// 首次启动检测器
/// 负责检测应用是否首次启动，并触发必要的后台数据同步
class FirstLaunchDetector {
  final DanbooruTagsLazyService _tagsService;

  /// 是否正在执行初始同步
  bool _isInitialSyncing = false;

  FirstLaunchDetector({
    required DanbooruTagsLazyService tagsService,
  }) : _tagsService = tagsService;

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

  /// 检查并标记需要后台刷新
  ///
  /// 新的非阻塞实现：不再执行同步，而是标记需要刷新
  /// 实际的数据下载将在进入主界面后通过后台刷新处理
  Future<bool> checkAndMarkPendingRefresh() async {
    if (_isInitialSyncing) return false;
    _isInitialSyncing = true;

    try {
      // 检查标签数据源是否需要刷新（翻译服务使用内置CSV，自动处理）
      final needsTagsRefresh = await _tagsService.shouldRefresh();

      // 设置标记，让主界面知道需要显示后台刷新提示
      final prefs = await SharedPreferences.getInstance();

      if (needsTagsRefresh) {
        await prefs.setBool(StorageKeys.pendingDataSourceRefresh, true);
        AppLogger.i(
          'Marked pending refresh: tags=$needsTagsRefresh',
          'FirstLaunch',
        );
      }

      // 标记已完成首次启动
      await markLaunched();

      return true;
    } catch (e, stack) {
      AppLogger.e('Failed to check and mark pending refresh', e, stack, 'FirstLaunch');
      return false;
    } finally {
      _isInitialSyncing = false;
    }
  }
}

/// FirstLaunchDetector Provider
@Riverpod(keepAlive: true)
Future<FirstLaunchDetector> firstLaunchDetector(Ref ref) async {
  final tagsService = await ref.watch(danbooruTagsLazyServiceProvider.future);

  return FirstLaunchDetector(
    tagsService: tagsService,
  );
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
  ///
  /// 新的非阻塞实现：只标记需要刷新，不执行实际同步
  Future<void> checkAndSync(BuildContext context) async {
    final detector = await ref.read(firstLaunchDetectorProvider.future);

    final isFirst = await detector.isFirstLaunch();
    state = state.copyWith(isFirstLaunch: isFirst);

    if (isFirst) {
      state = state.copyWith(isSyncing: true);

      try {
        // 新的非阻塞检测，只标记需要刷新
        await detector.checkAndMarkPendingRefresh();
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
      // 非首次启动，不需要额外处理
      // 后台刷新由 BackgroundRefreshNotifier 处理
      AppLogger.d('Not first launch, skipping', 'FirstLaunch');
    }
  }
}
