import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/version/release_asset_info.dart';
import '../../data/models/version/version_info.dart';
import '../utils/app_logger.dart';
import 'app_installation_service.dart';
import 'windows_update_script.dart';

part 'update_installer_service.g.dart';

class UpdateInstallException implements Exception {
  final String message;
  final Object? originalError;

  const UpdateInstallException(this.message, {this.originalError});

  @override
  String toString() =>
      'UpdateInstallException: $message${originalError != null ? ' ($originalError)' : ''}';
}

/// 更新下载被取消时抛出，调用方应将其与真正的失败区分开。
class UpdateDownloadCancelledException implements Exception {
  const UpdateDownloadCancelledException();

  @override
  String toString() => 'UpdateDownloadCancelledException';
}

typedef AppExitHandler = void Function(int code);

/// 一次下载的实时进度快照。
class UpdateDownloadProgress {
  /// 已接收字节数
  final int receivedBytes;

  /// 总字节数，未知时为 0
  final int totalBytes;

  /// 归一化进度 0.0 - 1.0，总量未知时为 0
  final double progress;

  /// 瞬时下载速度（字节/秒），基于最近采样平滑计算
  final int bytesPerSecond;

  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
    required this.bytesPerSecond,
  });
}

/// 已下载并通过完整性校验的更新包。
class DownloadedUpdate {
  /// 更新包文件（安装器 exe 或便携版 zip）
  final File file;

  /// 对应的发布资产
  final ReleaseAssetInfo asset;

  /// 目标版本号
  final String version;

  const DownloadedUpdate({
    required this.file,
    required this.asset,
    required this.version,
  });

  /// 该更新包对应的安装方式。
  bool get isPortableZip => asset.type == ReleaseAssetType.windowsPortable;
}

/// Windows 应用内更新服务。
///
/// 负责下载更新包（支持取消、断点复用、SHA256 校验），并通过
/// 独立辅助脚本完成安装：脚本等待应用进程退出后再执行安装或
/// 文件替换，避免安装器与运行中的应用争抢文件占用。
class UpdateInstallerService {
  final Dio _dio;
  final AppInstallationService _installationService;
  final AppExitHandler _exitHandler;

  /// 速度采样窗口，过短会剧烈抖动，过长则反应迟钝
  static const Duration _speedSampleWindow = Duration(milliseconds: 500);

  /// 下载连接超时
  static const Duration _connectTimeout = Duration(seconds: 15);

  /// 下载接收超时（连续无数据的最长容忍时间），防止网络停滞后无限挂起
  static const Duration _receiveTimeout = Duration(seconds: 60);

  const UpdateInstallerService({
    required Dio dio,
    required AppInstallationService installationService,
    AppExitHandler exitHandler = exit,
  }) : _dio = dio,
       _installationService = installationService,
       _exitHandler = exitHandler;

  /// 当前环境是否支持应用内自动安装更新。
  bool get supportsInAppInstall => _installationService.supportsInAppInstall;

  /// 下载更新包并完成 SHA256 校验。
  ///
  /// 同一版本校验通过的更新包会被复用，重复点击安装不会重新下载。
  /// [cancelToken] 取消时抛出 [UpdateDownloadCancelledException]。
  Future<DownloadedUpdate> downloadUpdate(
    VersionInfo versionInfo, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!_installationService.supportsInAppInstall) {
      throw const UpdateInstallException('当前版本不支持应用内自动安装更新');
    }

    final asset = versionInfo.primaryAsset;
    if (asset == null || !asset.supportsInAppInstall) {
      throw const UpdateInstallException('未找到可自动安装的更新包');
    }
    final expectedSha256 = asset.sha256;
    if (expectedSha256 == null || expectedSha256.isEmpty) {
      throw const UpdateInstallException('更新包缺少 SHA256 校验信息');
    }

    final updateDir = await _ensureUpdateDir();
    final targetFile = File(p.join(updateDir.path, asset.fileName));

    // 已下载且校验通过的更新包直接复用。
    if (await targetFile.exists()) {
      final cachedSha256 = await calculateSha256(targetFile);
      if (equalsSha256(cachedSha256, expectedSha256)) {
        AppLogger.i(
          'Reusing verified update package: ${targetFile.path}',
          'UpdateInstaller',
        );
        onProgress?.call(
          UpdateDownloadProgress(
            receivedBytes: await targetFile.length(),
            totalBytes: asset.size ?? await targetFile.length(),
            progress: 1,
            bytesPerSecond: 0,
          ),
        );
        return DownloadedUpdate(
          file: targetFile,
          asset: asset,
          version: versionInfo.version,
        );
      }
      await targetFile.delete();
    }

    // 先下载到 .part 临时文件，避免中断留下被误认为完整的坏包。
    final partFile = File('${targetFile.path}.part');
    if (await partFile.exists()) {
      await partFile.delete();
    }

    var lastSampleTime = DateTime.now();
    var lastSampleBytes = 0;
    var smoothedSpeed = 0;

    try {
      await _dio.download(
        asset.downloadUrl,
        partFile.path,
        cancelToken: cancelToken,
        options: Options(
          connectTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
        ),
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(lastSampleTime);
          if (elapsed >= _speedSampleWindow) {
            final instantSpeed =
                ((received - lastSampleBytes) * 1000 / elapsed.inMilliseconds)
                    .round();
            // 简单指数平滑，避免速度显示剧烈跳动。
            smoothedSpeed = smoothedSpeed == 0
                ? instantSpeed
                : (smoothedSpeed * 0.7 + instantSpeed * 0.3).round();
            lastSampleTime = now;
            lastSampleBytes = received;
          }
          final effectiveTotal = total > 0 ? total : (asset.size ?? 0);
          onProgress?.call(
            UpdateDownloadProgress(
              receivedBytes: received,
              totalBytes: effectiveTotal,
              progress: effectiveTotal > 0
                  ? (received / effectiveTotal).clamp(0.0, 0.99)
                  : 0,
              bytesPerSecond: smoothedSpeed,
            ),
          );
        },
      );
    } on DioException catch (e) {
      await _deleteQuietly(partFile);
      if (CancelToken.isCancel(e)) {
        throw const UpdateDownloadCancelledException();
      }
      throw UpdateInstallException('下载更新包失败', originalError: e);
    } catch (e) {
      await _deleteQuietly(partFile);
      throw UpdateInstallException('下载更新包失败', originalError: e);
    }

    if (cancelToken?.isCancelled ?? false) {
      await _deleteQuietly(partFile);
      throw const UpdateDownloadCancelledException();
    }

    final actualSha256 = await calculateSha256(partFile);
    if (!equalsSha256(actualSha256, expectedSha256)) {
      await _deleteQuietly(partFile);
      throw UpdateInstallException(
        '更新包校验失败',
        originalError: 'expected=$expectedSha256 actual=$actualSha256',
      );
    }

    await partFile.rename(targetFile.path);
    final fileLength = await targetFile.length();
    onProgress?.call(
      UpdateDownloadProgress(
        receivedBytes: fileLength,
        totalBytes: fileLength,
        progress: 1,
        bytesPerSecond: smoothedSpeed,
      ),
    );

    return DownloadedUpdate(
      file: targetFile,
      asset: asset,
      version: versionInfo.version,
    );
  }

  /// 安装已下载的更新包并退出当前应用。
  ///
  /// 启动独立辅助脚本后立刻退出本进程，由脚本等待进程结束后
  /// 执行安装/替换并启动新版本。
  Future<void> installAndRestart(DownloadedUpdate update) async {
    if (!Platform.isWindows) {
      throw const UpdateInstallException('当前平台不支持应用内自动更新');
    }
    if (!await update.file.exists()) {
      // 临时目录可能被系统清理，明确报错让调用方回到可重试状态，
      // 而不是退出应用后脚本静默失败。
      throw const UpdateInstallException('更新包已被清理，请重新下载');
    }

    final scriptFile = await _writeUpdateScript(update);
    AppLogger.i(
      'Launching update script: ${scriptFile.path} '
      '(pid=$pid, package=${update.file.path})',
      'UpdateInstaller',
    );

    try {
      await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          scriptFile.path,
        ],
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      throw UpdateInstallException('启动更新程序失败', originalError: e);
    }

    // 脚本已独立运行，立即退出本进程让脚本接管。
    _exitHandler(0);
  }

  Future<Directory> _ensureUpdateDir() async {
    final updateDir = Directory(
      p.join(Directory.systemTemp.path, 'nai_launcher_updates'),
    );
    await updateDir.create(recursive: true);
    return updateDir;
  }

  Future<File> _writeUpdateScript(DownloadedUpdate update) async {
    final updateDir = await _ensureUpdateDir();
    final scriptFile = File(
      p.join(updateDir.path, 'nai_launcher_update_${update.version}.ps1'),
    );

    final executablePath = Platform.resolvedExecutable;
    final script = update.isPortableZip
        ? WindowsUpdateScript.buildPortableScript(
            appPid: pid,
            zipPath: update.file.path,
            appDirectory: p.dirname(executablePath),
            executablePath: executablePath,
            extractDirectory: p.join(updateDir.path, 'extract_${update.version}'),
          )
        : WindowsUpdateScript.buildInstallerScript(
            appPid: pid,
            installerPath: update.file.path,
          );

    await scriptFile.writeAsString(script, flush: true);
    return scriptFile;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 清理失败不应掩盖真正的错误，临时文件会被系统或下次下载清掉。
    }
  }

  static Future<String> calculateSha256(File file) async {
    return (await sha256.bind(file.openRead()).first).toString();
  }

  static bool equalsSha256(String actual, String expected) {
    return actual.toLowerCase() == expected.toLowerCase();
  }
}

@riverpod
UpdateInstallerService updateInstallerService(Ref ref) {
  return UpdateInstallerService(
    dio: Dio(),
    installationService: ref.watch(appInstallationServiceProvider),
  );
}
