import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/update_check_service.dart';
import '../../core/services/update_installer_service.dart';
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

  /// 正在下载更新
  downloading,

  /// 更新包已下载并通过校验，等待用户确认安装
  downloaded,

  /// 正在启动安装程序，应用即将退出
  installing,

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

  /// 版本信息（available / downloading / downloaded 状态时有效）
  final VersionInfo? versionInfo;

  /// 错误消息（仅在 error 状态时有效）
  final String? errorMessage;

  /// 下载进度，范围 0.0 - 1.0
  final double downloadProgress;

  /// 已下载字节数
  final int downloadedBytes;

  /// 更新包总字节数，未知时为 0
  final int totalBytes;

  /// 当前下载速度（字节/秒）
  final int downloadSpeedBytesPerSecond;

  /// 已下载完成、待安装的更新包（downloaded/installing 状态时有效）
  final DownloadedUpdate? downloadedUpdate;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.versionInfo,
    this.errorMessage,
    this.downloadProgress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.downloadSpeedBytesPerSecond = 0,
    this.downloadedUpdate,
  });

  /// 是否正在检查更新
  bool get isChecking => status == UpdateStatus.checking;

  /// 是否有可用更新
  bool get hasUpdate => status == UpdateStatus.available;

  /// 是否处于更新流程中（下载中/待安装/安装中）
  bool get isInstalling =>
      status == UpdateStatus.downloading ||
      status == UpdateStatus.downloaded ||
      status == UpdateStatus.installing;

  /// 是否发生错误
  bool get isError => status == UpdateStatus.error;

  /// 复制并修改状态
  UpdateState copyWith({
    UpdateStatus? status,
    VersionInfo? versionInfo,
    String? errorMessage,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    int? downloadSpeedBytesPerSecond,
    DownloadedUpdate? downloadedUpdate,
    bool clearVersionInfo = false,
    bool clearErrorMessage = false,
    bool clearDownloadedUpdate = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      versionInfo: clearVersionInfo ? null : (versionInfo ?? this.versionInfo),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadSpeedBytesPerSecond:
          downloadSpeedBytesPerSecond ?? this.downloadSpeedBytesPerSecond,
      downloadedUpdate: clearDownloadedUpdate
          ? null
          : (downloadedUpdate ?? this.downloadedUpdate),
    );
  }
}

/// 更新状态 Notifier
///
/// 管理应用更新检查、下载与安装的状态和逻辑
@Riverpod(keepAlive: true)
class UpdateStateNotifier extends _$UpdateStateNotifier {
  /// 当前下载的取消令牌，仅在 downloading 状态有效
  CancelToken? _downloadCancelToken;

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
      final service = await ref.read(updateCheckServiceReadyProvider.future);
      final versionInfo = await service.checkForUpdates();

      if (versionInfo != null) {
        // 有新版本
        state = state.copyWith(
          status: UpdateStatus.available,
          versionInfo: versionInfo,
          downloadProgress: 0,
          downloadedBytes: 0,
          totalBytes: 0,
          downloadSpeedBytesPerSecond: 0,
          clearErrorMessage: true,
          clearDownloadedUpdate: true,
        );
      } else {
        // 已是最新版本
        state = state.copyWith(
          status: UpdateStatus.upToDate,
          clearVersionInfo: true,
          downloadProgress: 0,
          downloadedBytes: 0,
          totalBytes: 0,
          downloadSpeedBytesPerSecond: 0,
          clearErrorMessage: true,
          clearDownloadedUpdate: true,
        );
      }
    } on UpdateCheckException catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.message,
        downloadProgress: 0,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
        downloadProgress: 0,
      );
    }
  }

  /// 下载当前检测到的更新包。
  ///
  /// 下载成功并校验通过后进入 [UpdateStatus.downloaded] 状态，
  /// 由用户确认后调用 [installDownloadedUpdate] 完成安装。
  Future<void> downloadUpdate() async {
    final currentVersionInfo = state.versionInfo;
    if (currentVersionInfo == null) return;
    if (state.status == UpdateStatus.downloading) return;

    final cancelToken = CancelToken();
    _downloadCancelToken = cancelToken;

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0,
      downloadedBytes: 0,
      totalBytes: 0,
      downloadSpeedBytesPerSecond: 0,
      clearErrorMessage: true,
      clearDownloadedUpdate: true,
    );

    try {
      final installer = ref.read(updateInstallerServiceProvider);
      final downloaded = await installer.downloadUpdate(
        currentVersionInfo,
        cancelToken: cancelToken,
        onProgress: (progress) {
          // 下载完成或取消后忽略迟到的进度回调
          if (state.status != UpdateStatus.downloading) return;
          state = state.copyWith(
            downloadProgress: progress.progress,
            downloadedBytes: progress.receivedBytes,
            totalBytes: progress.totalBytes,
            downloadSpeedBytesPerSecond: progress.bytesPerSecond,
          );
        },
      );
      state = state.copyWith(
        status: UpdateStatus.downloaded,
        downloadedUpdate: downloaded,
        downloadProgress: 1,
        downloadSpeedBytesPerSecond: 0,
      );
    } on UpdateDownloadCancelledException {
      // 取消后回到可重试的 available 状态
      state = state.copyWith(
        status: UpdateStatus.available,
        downloadProgress: 0,
        downloadedBytes: 0,
        totalBytes: 0,
        downloadSpeedBytesPerSecond: 0,
        clearDownloadedUpdate: true,
      );
    } on UpdateInstallException catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.message,
        downloadProgress: 0,
        downloadSpeedBytesPerSecond: 0,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
        downloadProgress: 0,
        downloadSpeedBytesPerSecond: 0,
      );
    } finally {
      if (_downloadCancelToken == cancelToken) {
        _downloadCancelToken = null;
      }
    }
  }

  /// 取消正在进行的下载，回到 available 状态。
  void cancelDownload() {
    _downloadCancelToken?.cancel();
  }

  /// 安装已下载的更新包并重启应用。
  ///
  /// 成功后应用会立即退出，由辅助脚本完成安装并启动新版本。
  Future<void> installDownloadedUpdate() async {
    final downloaded = state.downloadedUpdate;
    if (downloaded == null) return;
    if (state.status == UpdateStatus.installing) return;

    state = state.copyWith(
      status: UpdateStatus.installing,
      clearErrorMessage: true,
    );

    try {
      final installer = ref.read(updateInstallerServiceProvider);
      await installer.installAndRestart(downloaded);
      // 正常情况下进程随即退出，下面的状态仅用于测试环境。
    } on UpdateInstallException catch (e) {
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
      final service = await ref.read(updateCheckServiceReadyProvider.future);
      await service.skipVersion(currentVersionInfo.version);

      // 跳过之后重置为 upToDate 状态
      state = state.copyWith(
        status: UpdateStatus.upToDate,
        clearVersionInfo: true,
        clearDownloadedUpdate: true,
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
    _downloadCancelToken = null;
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
    state = UpdateState(status: UpdateStatus.error, errorMessage: message);
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
      final service = await ref.read(updateCheckServiceReadyProvider.future);
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
  final service = await ref.watch(updateCheckServiceReadyProvider.future);
  return service.shouldCheckForUpdates();
}
