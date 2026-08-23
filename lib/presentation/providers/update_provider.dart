import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/update_check_service.dart';
import '../../core/services/update_installer_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/version/version_info.dart';

part 'update_provider.g.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  downloaded,
  installing,
  upToDate,
  error,
}

class UpdateState {
  final UpdateStatus status;
  final VersionInfo? versionInfo;
  final String? errorMessage;
  final UpdateCheckFailureType? checkFailureType;
  final double downloadProgress;
  final int receivedBytes;
  final int totalBytes;
  final int downloadBytesPerSecond;
  final DownloadedUpdate? downloadedUpdate;

  /// 是否显示全局更新提示；状态本身保留，以便设置页仍能重新打开。
  final bool notificationVisible;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.versionInfo,
    this.errorMessage,
    this.checkFailureType,
    this.downloadProgress = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.downloadBytesPerSecond = 0,
    this.downloadedUpdate,
    this.notificationVisible = false,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    VersionInfo? versionInfo,
    String? errorMessage,
    UpdateCheckFailureType? checkFailureType,
    double? downloadProgress,
    int? receivedBytes,
    int? totalBytes,
    int? downloadBytesPerSecond,
    DownloadedUpdate? downloadedUpdate,
    bool? notificationVisible,
  }) {
    return UpdateState(
      status: status ?? this.status,
      versionInfo: versionInfo ?? this.versionInfo,
      errorMessage: errorMessage,
      checkFailureType: checkFailureType,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadBytesPerSecond:
          downloadBytesPerSecond ?? this.downloadBytesPerSecond,
      downloadedUpdate: downloadedUpdate ?? this.downloadedUpdate,
      notificationVisible: notificationVisible ?? this.notificationVisible,
    );
  }

  bool get hasNewVersion =>
      status == UpdateStatus.available ||
      status == UpdateStatus.downloading ||
      status == UpdateStatus.downloaded ||
      status == UpdateStatus.installing ||
      (status == UpdateStatus.error && versionInfo != null);

  bool get hasDownloadedUpdate => downloadedUpdate != null;

  // 兼容现有 UI 字段名。
  int get downloadedBytes => receivedBytes;
  int get downloadSpeedBytesPerSecond => downloadBytesPerSecond;
  bool get hasUpdate => hasNewVersion;
  bool get isChecking => status == UpdateStatus.checking;
}

@Riverpod(keepAlive: true)
class UpdateStateNotifier extends _$UpdateStateNotifier {
  CancelToken? _downloadCancelToken;
  Timer? _reminderTimer;
  bool _initialized = false;

  @override
  UpdateState build() {
    ref.onDispose(() {
      _downloadCancelToken?.cancel();
      _reminderTimer?.cancel();
    });
    return const UpdateState();
  }

  /// 恢复待安装包和上一次独立更新脚本的结果。
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final installer = ref.read(updateInstallerServiceProvider);
    final result = await installer.consumeExecutionResult();
    final restored = await installer.restorePendingUpdate();
    final checkService = ref.read(updateCheckServiceProvider);

    if (restored != null &&
        VersionInfoComparator.isNewer(
          restored.versionInfo.version,
          checkService.currentVersion,
        )) {
      if (result != null && !result.success) {
        final logSuffix = result.logPath == null
            ? ''
            : '\n日志：${result.logPath}';
        state = UpdateState(
          status: UpdateStatus.error,
          versionInfo: restored.versionInfo,
          downloadedUpdate: restored.update,
          errorMessage: '${result.message ?? '安装更新失败'}$logSuffix',
          notificationVisible: true,
        );
      } else {
        final reminderDue = checkService.isReminderDue();
        state = UpdateState(
          status: UpdateStatus.downloaded,
          versionInfo: restored.versionInfo,
          downloadedUpdate: restored.update,
          downloadProgress: 1,
          receivedBytes: await restored.update.file.length(),
          totalBytes:
              restored.update.asset.size ?? await restored.update.file.length(),
          notificationVisible: reminderDue,
        );
        if (!reminderDue) {
          _scheduleReminder(
            checkService.reminderDelayRemaining ??
                UpdateCheckService.defaultReminderDelay,
          );
        }
      }
      return;
    }

    if (result != null && !result.success) {
      state = UpdateState(
        status: UpdateStatus.error,
        errorMessage: result.message ?? '安装更新失败，请查看更新日志',
        notificationVisible: true,
      );
    }
  }

  /// 检查更新。
  ///
  /// 自动检查保持安静，仅在发现新版本时显示全局提示；手动检查会展示
  /// “已是最新版”和错误状态，并允许重新查看曾经跳过的版本。
  Future<void> checkForUpdates({bool manual = false}) async {
    final service = ref.read(updateCheckServiceProvider);
    if (manual) {
      await service.clearReminder();
      state = const UpdateState(status: UpdateStatus.checking);
    }

    try {
      final versionInfo = await service.checkForUpdates(ignoreSkipped: manual);
      if (versionInfo != null) {
        state = UpdateState(
          status: UpdateStatus.available,
          versionInfo: versionInfo,
          notificationVisible: true,
        );
      } else if (manual) {
        state = const UpdateState(status: UpdateStatus.upToDate);
      } else if (!state.hasDownloadedUpdate) {
        state = const UpdateState();
      }
    } catch (error, stackTrace) {
      AppLogger.w('Update check failed: $error', 'UpdateNotifier');
      AppLogger.d('$stackTrace', 'UpdateNotifier');
      if (manual) {
        state = UpdateState(
          status: UpdateStatus.error,
          errorMessage: error is UpdateCheckException
              ? null
              : _formatError(error),
          checkFailureType: error is UpdateCheckException
              ? error.type
              : UpdateCheckFailureType.unknown,
        );
      } else if (!state.hasDownloadedUpdate) {
        state = const UpdateState();
      }
    }
  }

  Future<bool> shouldCheck() {
    return ref.read(updateCheckServiceProvider).shouldCheck();
  }

  Future<void> skipVersion(String version) async {
    await ref.read(updateCheckServiceProvider).skipVersion(version);
    _reminderTimer?.cancel();
    state = const UpdateState();
  }

  Future<void> skipUpdate() async {
    final version = state.versionInfo?.version;
    if (version != null) await skipVersion(version);
  }

  /// 延后全局提示，但保留更新详情和已下载文件。
  Future<void> remindLater({Duration? delay}) async {
    final service = ref.read(updateCheckServiceProvider);
    final reminderDelay = delay ?? UpdateCheckService.defaultReminderDelay;
    await service.remindLater(delay: reminderDelay);
    state = state.copyWith(notificationVisible: false);
    _scheduleReminder(reminderDelay);
  }

  void _scheduleReminder(Duration delay) {
    _reminderTimer?.cancel();
    _reminderTimer = Timer(delay, () {
      if (state.hasNewVersion || state.hasDownloadedUpdate) {
        state = state.copyWith(notificationVisible: true);
      }
    });
  }

  /// 从设置页重新展示当前更新。
  void showNotification() {
    if (state.hasNewVersion || state.hasDownloadedUpdate) {
      state = state.copyWith(notificationVisible: true);
    }
  }

  Future<void> setIncludePrerelease(bool value) async {
    final service = ref.read(updateCheckServiceProvider);
    await service.setIncludePrerelease(value);
  }

  bool getIncludePrerelease() {
    return ref.read(updateCheckServiceProvider).shouldIncludePrerelease();
  }

  Future<void> downloadUpdate() async {
    final versionInfo = state.versionInfo;
    if (versionInfo == null) return;

    final cancelToken = CancelToken();
    _downloadCancelToken?.cancel();
    _downloadCancelToken = cancelToken;
    await ref.read(updateCheckServiceProvider).clearReminder();

    state = state.copyWith(
      status: UpdateStatus.downloading,
      errorMessage: null,
      downloadProgress: 0,
      receivedBytes: 0,
      totalBytes: versionInfo.primaryAsset?.size ?? 0,
      downloadBytesPerSecond: 0,
      notificationVisible: true,
    );

    try {
      final downloaded = await ref
          .read(updateInstallerServiceProvider)
          .downloadUpdate(
            versionInfo,
            cancelToken: cancelToken,
            onProgress: (progress) {
              if (cancelToken.isCancelled) return;
              state = state.copyWith(
                status: UpdateStatus.downloading,
                downloadProgress: progress.progress,
                receivedBytes: progress.receivedBytes,
                totalBytes: progress.totalBytes,
                downloadBytesPerSecond: progress.bytesPerSecond,
                notificationVisible: true,
              );
            },
          );
      state = state.copyWith(
        status: UpdateStatus.downloaded,
        downloadedUpdate: downloaded,
        downloadProgress: 1,
        receivedBytes: downloaded.asset.size ?? await downloaded.file.length(),
        totalBytes: downloaded.asset.size ?? await downloaded.file.length(),
        downloadBytesPerSecond: 0,
        notificationVisible: true,
      );
    } on UpdateDownloadCancelledException {
      state = UpdateState(
        status: UpdateStatus.available,
        versionInfo: versionInfo,
        notificationVisible: true,
      );
    } catch (error) {
      state = UpdateState(
        status: UpdateStatus.error,
        versionInfo: versionInfo,
        errorMessage: _formatError(error),
        notificationVisible: true,
      );
    } finally {
      if (identical(_downloadCancelToken, cancelToken)) {
        _downloadCancelToken = null;
      }
    }
  }

  void cancelDownload() {
    _downloadCancelToken?.cancel('cancelled by user');
  }

  Future<void> installDownloadedUpdate() => installAndRestart();

  Future<void> installAndRestart() async {
    final downloaded = state.downloadedUpdate;
    if (downloaded == null) return;

    state = state.copyWith(
      status: UpdateStatus.installing,
      errorMessage: null,
      notificationVisible: true,
    );
    try {
      await ref
          .read(updateInstallerServiceProvider)
          .installAndRestart(downloaded);
    } catch (error) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: _formatError(error),
        notificationVisible: true,
      );
    }
  }

  Future<void> openDownloadPage() async {
    final info = state.versionInfo;
    if (info == null) return;
    final rawUrl = info.htmlUrl ?? info.downloadUrl;
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void reset() {
    _downloadCancelToken?.cancel();
    _downloadCancelToken = null;
    _reminderTimer?.cancel();
    state = const UpdateState();
  }

  String _formatError(Object error) {
    if (error is UpdateCheckException) return error.message;
    if (error is UpdateInstallException) return error.message;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => '网络连接超时，请稍后重试',
        DioExceptionType.connectionError => '无法连接更新服务器，请检查网络或代理设置',
        DioExceptionType.cancel => '操作已取消',
        _ => '更新请求失败，请稍后重试',
      };
    }
    return '更新操作失败，请稍后重试';
  }
}

/// 保持既有调用方使用的简洁 Provider 名称。
final updateStateProvider = updateStateNotifierProvider;

@riverpod
bool hasNewVersion(Ref ref) {
  return ref.watch(updateStateProvider).hasNewVersion;
}

@riverpod
VersionInfo? latestVersionInfo(Ref ref) {
  return ref.watch(updateStateProvider).versionInfo;
}

@riverpod
Future<void> automaticUpdateCheck(Ref ref, {bool onStartup = false}) async {
  final service = await ref.read(updateCheckServiceReadyProvider.future);
  final notifier = ref.read(updateStateProvider.notifier);
  await notifier.initialize();
  final updateState = ref.read(updateStateProvider);
  if (updateState.hasDownloadedUpdate || updateState.hasNewVersion) return;

  final shouldCheck = onStartup
      ? await service.shouldCheckOnStartup()
      : await notifier.shouldCheck();
  if (shouldCheck) await notifier.checkForUpdates();
}
