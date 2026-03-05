import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/update_check_service.dart';
import '../../data/models/version/version_info.dart';

part 'update_provider.g.dart';

/// 更新状态枚举
enum UpdateStatus {
  /// 空闲状态
  idle,

  /// 检查中状态
  checking,

  /// 有可用更新
  available,

  /// 已是最新版本
  upToDate,

  /// 错误状态
  error,
}

/// 更新状态数据类
///
/// 用于存储和管理更新状态
class UpdateState {
  /// 当前状态
  final UpdateStatus status;

  /// 版本信息（仅在 available 状态时有效）
  final VersionInfo? versionInfo;

  /// 错误消息（仅在 error 状态时有效）
  final String? errorMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.versionInfo,
    this.errorMessage,
  });

  /// 是否正在检查更新
  bool get isChecking => status == UpdateStatus.checking;

  /// 是否有可用更新
  bool get hasUpdate => status == UpdateStatus.available;

  /// 是否发生错误
  bool get isError => status == UpdateStatus.error;

  /// 复制并修改状态
  UpdateState copyWith({
    UpdateStatus? status,
    VersionInfo? versionInfo,
    String? errorMessage,
    bool clearVersionInfo = false,
    bool clearErrorMessage = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      versionInfo: clearVersionInfo ? null : (versionInfo ?? this.versionInfo),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 更新状态 Notifier
///
/// 管理应用更新检查的状态和逻辑
@Riverpod(keepAlive: true)
class UpdateStateNotifier extends _$UpdateStateNotifier {
  @override
  UpdateState build() {
    return const UpdateState();
  }

  /// 检查更新
  ///
  /// 调用服务检查是否有新版本可用
  Future<void> checkForUpdates() async {
    // 设置为检查中状态
    state = state.copyWith(status: UpdateStatus.checking);

    try {
      final service = ref.read(updateCheckServiceProvider);
      final versionInfo = await service.checkForUpdates();

      if (versionInfo != null) {
        // 有新版本
        state = state.copyWith(
          status: UpdateStatus.available,
          versionInfo: versionInfo,
        );
      } else {
        // 已是最新版本
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          clearVersionInfo: true,
        );
      }
    } on UpdateCheckException catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 跳过当前更新
  ///
  /// 调用服务跳过当前检测到的版本
  Future<void> skipUpdate() async {
    final currentVersionInfo = state.versionInfo;
    if (currentVersionInfo == null) return;

    try {
      final service = ref.read(updateCheckServiceProvider);
      await service.skipVersion(currentVersionInfo.version);

      // 跳过之后重置为 upToDate 状态
      state = state.copyWith(
        status: UpdateStatus.upToDate,
        clearVersionInfo: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 重置状态
  ///
  /// 将状态重置为 idle
  void resetState() {
    state = const UpdateState();
  }

  /// 设置可用状态（用于测试或外部设置）
  ///
  /// [versionInfo] 新版本信息
  void setAvailable(VersionInfo versionInfo) {
    state = UpdateState(
      status: UpdateStatus.available,
      versionInfo: versionInfo,
    );
  }

  /// 设置错误状态（用于测试或外部设置）
  ///
  /// [message] 错误消息
  void setError(String message) {
    state = UpdateState(
      status: UpdateStatus.error,
      errorMessage: message,
    );
  }

  /// 关闭更新提示
  ///
  /// 将状态重置为 idle
  void dismissUpdate() {
    resetState();
  }

  /// 设置是否包含预发布版本
  ///
  /// [include] 是否包含
  Future<void> setIncludePrerelease(bool include) async {
    try {
      final service = ref.read(updateCheckServiceProvider);
      await service.setIncludePrerelease(include);
    } catch (e) {
      // 静默处理错误，不影响状态
    }
  }
}

/// 更新状态 Provider
///
/// 这是 updateStateNotifierProvider 的别名，用于兼容测试
final updateStateProvider = updateStateNotifierProvider;

/// 是否有新版本 Provider
///
/// 派生状态：根据当前状态判断是否有新版本
@riverpod
bool hasNewVersion(Ref ref) {
  final state = ref.watch(updateStateNotifierProvider);
  return state.hasUpdate;
}

/// 最新版本信息 Provider
///
/// 派生状态：获取当前检测到的版本信息
@riverpod
VersionInfo? latestVersionInfo(Ref ref) {
  final state = ref.watch(updateStateNotifierProvider);
  return state.versionInfo;
}

/// 启动时是否检查更新 Provider
///
/// 异步 Provider：决定是否在应用启动时检查更新
@riverpod
Future<bool> checkUpdateOnStartup(Ref ref) async {
  final service = ref.watch(updateCheckServiceProvider);
  return service.shouldCheckForUpdates();
}
