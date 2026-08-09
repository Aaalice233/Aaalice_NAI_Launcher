import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/storage_keys.dart';
import 'app_logger.dart';

part 'first_launch_detector.g.dart';

/// 首次启动检测器
/// 负责检测应用是否首次启动并记录当前应用版本。
class FirstLaunchDetector {
  /// 是否正在执行初始同步
  bool _isInitialSyncing = false;

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

  /// 完成首次启动记录。
  ///
  /// 基础标签 catalog 已随应用发布，不在这里执行网络同步。
  Future<bool> checkAndMarkPendingRefresh() async {
    if (_isInitialSyncing) return false;
    _isInitialSyncing = true;

    try {
      // 基础标签 catalog 随应用发布，首次启动不再触发全量网络同步。
      await markLaunched();

      return true;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to check and mark pending refresh',
        e,
        stack,
        'FirstLaunch',
      );
      return false;
    } finally {
      _isInitialSyncing = false;
    }
  }
}

/// FirstLaunchDetector Provider
@Riverpod(keepAlive: true)
Future<FirstLaunchDetector> firstLaunchDetector(Ref ref) async {
  return FirstLaunchDetector();
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

  /// 检查并完成首次启动记录。
  Future<void> checkAndSync(BuildContext context) async {
    final detector = await ref.read(firstLaunchDetectorProvider.future);

    final isFirst = await detector.isFirstLaunch();
    state = state.copyWith(isFirstLaunch: isFirst);

    if (isFirst) {
      state = state.copyWith(isSyncing: true);

      try {
        // 首次启动只记录版本，词库安装由用户在设置中主动管理。
        await detector.checkAndMarkPendingRefresh();
        state = state.copyWith(isSyncing: false, hasSyncCompleted: true);
      } catch (e) {
        state = state.copyWith(isSyncing: false, error: e.toString());
      }
    } else {
      // 非首次启动不需要额外处理。
      AppLogger.d('Not first launch, skipping', 'FirstLaunch');
    }
  }
}
