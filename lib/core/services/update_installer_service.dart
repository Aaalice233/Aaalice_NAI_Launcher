import 'dart:async';
import 'dart:convert';
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
import 'desktop_app_shutdown_service.dart';
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

typedef AppShutdownHandler = Future<void> Function(int code);

/// 一次下载的实时进度快照。
class UpdateDownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress;
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
  final File file;
  final ReleaseAssetInfo asset;
  final String version;

  const DownloadedUpdate({
    required this.file,
    required this.asset,
    required this.version,
  });

  bool get isPortableZip => asset.type == ReleaseAssetType.windowsPortable;
}

/// 从磁盘恢复的待安装更新。
class RestoredDownloadedUpdate {
  final DownloadedUpdate update;
  final VersionInfo versionInfo;

  const RestoredDownloadedUpdate({
    required this.update,
    required this.versionInfo,
  });
}

/// 上一次独立更新脚本留下的执行结果。
class UpdateExecutionResult {
  final bool success;
  final String version;
  final String? message;
  final String? logPath;

  const UpdateExecutionResult({
    required this.success,
    required this.version,
    this.message,
    this.logPath,
  });
}

/// Windows 应用内更新服务。
///
/// 下载使用 `.part` 文件和 HTTP Range 真正续传；完整包必须同时通过
/// 长度与 SHA256 校验。安装由独立脚本在应用优雅退出后执行，并留下
/// 可在下次启动读取的结果与日志。
class UpdateInstallerService {
  final Dio _dio;
  final AppInstallationService _installationService;
  final AppShutdownHandler _shutdownHandler;
  final Directory? _updateDirectoryOverride;

  static const Duration _speedSampleWindow = Duration(milliseconds: 500);
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 60);
  static const Duration _staleFileAge = Duration(days: 14);
  static const String _updateDirectoryName = 'nai_launcher_updates';
  static const String _pendingMetadataName = 'pending_update.json';
  static const String _resultMetadataName = 'update_result.json';

  UpdateInstallerService({
    required Dio dio,
    required AppInstallationService installationService,
    AppShutdownHandler shutdownHandler =
        DesktopAppShutdownService.shutdownAndExit,
    Directory? updateDirectory,
  }) : _dio = dio,
       _installationService = installationService,
       _shutdownHandler = shutdownHandler,
       _updateDirectoryOverride = updateDirectory;

  bool get supportsInAppInstall => _installationService.supportsInAppInstall;

  /// 下载更新包并完成长度与 SHA256 校验。
  ///
  /// 完整缓存会直接复用；未完成的 `.part` 文件通过 Range 请求续传。
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
    await _cleanupStaleFiles(updateDir);
    final targetFile = File(p.join(updateDir.path, asset.fileName));

    if (await targetFile.exists()) {
      if (await _isPackageValid(targetFile, asset)) {
        final length = await targetFile.length();
        onProgress?.call(
          UpdateDownloadProgress(
            receivedBytes: length,
            totalBytes: asset.size ?? length,
            progress: 1,
            bytesPerSecond: 0,
          ),
        );
        final downloaded = DownloadedUpdate(
          file: targetFile,
          asset: asset,
          version: versionInfo.version,
        );
        await _writePendingMetadata(downloaded, versionInfo);
        AppLogger.i(
          'Reusing verified update package: ${targetFile.path}',
          'UpdateInstaller',
        );
        return downloaded;
      }
      await targetFile.delete();
    }

    final partFile = File('${targetFile.path}.part');
    try {
      await _downloadToPartFile(
        asset,
        partFile,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on UpdateDownloadCancelledException {
      rethrow;
    } on FileSystemException catch (error) {
      if (_isDiskFull(error)) {
        throw UpdateInstallException('磁盘空间不足，无法保存更新包', originalError: error);
      }
      throw UpdateInstallException('写入更新包失败', originalError: error);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const UpdateDownloadCancelledException();
      }
      throw UpdateInstallException('下载更新包失败', originalError: error);
    } on UpdateInstallException {
      rethrow;
    } catch (error) {
      throw UpdateInstallException('下载更新包失败', originalError: error);
    }

    if (cancelToken?.isCancelled ?? false) {
      throw const UpdateDownloadCancelledException();
    }

    final fileLength = await partFile.length();
    if (asset.size != null && fileLength != asset.size) {
      await _deleteQuietly(partFile);
      throw UpdateInstallException(
        '更新包大小校验失败',
        originalError: 'expected=${asset.size} actual=$fileLength',
      );
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
    onProgress?.call(
      UpdateDownloadProgress(
        receivedBytes: fileLength,
        totalBytes: asset.size ?? fileLength,
        progress: 1,
        bytesPerSecond: 0,
      ),
    );

    final downloaded = DownloadedUpdate(
      file: targetFile,
      asset: asset,
      version: versionInfo.version,
    );
    await _writePendingMetadata(downloaded, versionInfo);
    return downloaded;
  }

  Future<void> _downloadToPartFile(
    ReleaseAssetInfo asset,
    File partFile, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    var existingBytes = await partFile.exists() ? await partFile.length() : 0;
    var retriedWithoutRange = false;

    while (true) {
      if (cancelToken?.isCancelled ?? false) {
        throw const UpdateDownloadCancelledException();
      }

      final response = await _dio.get<ResponseBody>(
        asset.downloadUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          connectTimeout: _connectTimeout,
          receiveTimeout: _receiveTimeout,
          headers: {
            'Accept-Encoding': 'identity',
            if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
          },
          validateStatus: (status) =>
              status == HttpStatus.ok ||
              status == HttpStatus.partialContent ||
              status == HttpStatus.requestedRangeNotSatisfiable,
        ),
      );

      final statusCode = response.statusCode;
      if (statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        if (asset.size != null && existingBytes == asset.size) {
          return;
        }
        if (retriedWithoutRange) {
          throw const UpdateInstallException('服务器拒绝了更新包续传请求');
        }
        await _deleteQuietly(partFile);
        existingBytes = 0;
        retriedWithoutRange = true;
        continue;
      }

      final isResumed =
          statusCode == HttpStatus.partialContent && existingBytes > 0;
      if (!isResumed && existingBytes > 0) {
        await _deleteQuietly(partFile);
        existingBytes = 0;
      }

      final responseBody = response.data;
      if (responseBody == null) {
        throw const UpdateInstallException('更新服务器返回了空响应');
      }

      final contentLength = _parseHeaderInt(
        response.headers.value(Headers.contentLengthHeader),
      );
      final contentRangeTotal = _parseContentRangeTotal(
        response.headers.value('content-range'),
      );
      final totalBytes =
          contentRangeTotal ??
          (contentLength == null
              ? (asset.size ?? 0)
              : existingBytes + contentLength);

      var receivedBytes = existingBytes;
      var lastSampleBytes = receivedBytes;
      var lastSampleTime = DateTime.now();
      var smoothedSpeed = 0;
      final sink = partFile.openWrite(
        mode: isResumed ? FileMode.append : FileMode.write,
      );

      try {
        await for (final chunk in responseBody.stream) {
          if (cancelToken?.isCancelled ?? false) {
            throw const UpdateDownloadCancelledException();
          }
          sink.add(chunk);
          receivedBytes += chunk.length;

          final now = DateTime.now();
          final elapsed = now.difference(lastSampleTime);
          if (elapsed >= _speedSampleWindow) {
            final instantSpeed =
                ((receivedBytes - lastSampleBytes) *
                        1000 /
                        elapsed.inMilliseconds)
                    .round();
            smoothedSpeed = smoothedSpeed == 0
                ? instantSpeed
                : (smoothedSpeed * 0.7 + instantSpeed * 0.3).round();
            lastSampleTime = now;
            lastSampleBytes = receivedBytes;
          }

          onProgress?.call(
            UpdateDownloadProgress(
              receivedBytes: receivedBytes,
              totalBytes: totalBytes,
              progress: totalBytes > 0
                  ? (receivedBytes / totalBytes).clamp(0.0, 0.99)
                  : 0,
              bytesPerSecond: smoothedSpeed,
            ),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      return;
    }
  }

  /// 恢复上次已经校验完成、但尚未安装的更新包。
  Future<RestoredDownloadedUpdate?> restorePendingUpdate() async {
    final metadataFile = await _pendingMetadataFile();
    if (!await metadataFile.exists()) return null;

    try {
      final data = jsonDecode(await metadataFile.readAsString());
      if (data is! Map<String, dynamic> || data['schemaVersion'] != 1) {
        throw const FormatException('Unsupported pending update metadata');
      }

      final assetData = data['asset'];
      if (assetData is! Map<String, dynamic>) {
        throw const FormatException('Missing pending update asset');
      }
      final type = ReleaseAssetInfo.parseType(assetData['type'] as String?);
      final asset = ReleaseAssetInfo(
        type: type ?? ReleaseAssetType.unknown,
        platform: assetData['platform'] as String? ?? 'unknown',
        fileName: assetData['fileName'] as String? ?? '',
        downloadUrl: assetData['downloadUrl'] as String? ?? '',
        sha256: assetData['sha256'] as String?,
        size: (assetData['size'] as num?)?.toInt(),
        label: assetData['label'] as String?,
        description: assetData['description'] as String?,
      );
      final file = File(data['filePath'] as String? ?? '');
      if (asset.sha256 == null ||
          asset.fileName.isEmpty ||
          !await file.exists() ||
          !await _isPackageValid(file, asset)) {
        await _deleteQuietly(metadataFile);
        return null;
      }

      final version = data['version'] as String? ?? '';
      if (version.isEmpty) {
        await _deleteQuietly(metadataFile);
        return null;
      }
      final info = VersionInfo(
        version: version,
        currentVersion: data['currentVersion'] as String?,
        name: data['name'] as String?,
        releaseNotes: data['releaseNotes'] as String?,
        publishedAt: data['publishedAt'] as String?,
        downloadUrl: asset.downloadUrl,
        htmlUrl: data['htmlUrl'] as String?,
        assets: [asset],
        primaryAsset: asset,
        isNewer: true,
      );
      return RestoredDownloadedUpdate(
        update: DownloadedUpdate(file: file, asset: asset, version: version),
        versionInfo: info,
      );
    } catch (error) {
      AppLogger.w(
        'Ignoring invalid pending update metadata: $error',
        'UpdateInstaller',
      );
      await _deleteQuietly(metadataFile);
      return null;
    }
  }

  /// 读取并消费独立更新脚本的结果。
  Future<UpdateExecutionResult?> consumeExecutionResult() async {
    final resultFile = await _resultMetadataFile();
    if (!await resultFile.exists()) return null;

    try {
      final data = jsonDecode(await resultFile.readAsString());
      if (data is! Map<String, dynamic>) return null;
      return UpdateExecutionResult(
        success: data['success'] == true,
        version: data['version'] as String? ?? '',
        message: data['message'] as String?,
        logPath: data['logPath'] as String?,
      );
    } catch (error) {
      AppLogger.w('Unable to read update result: $error', 'UpdateInstaller');
      return null;
    } finally {
      await _deleteQuietly(resultFile);
    }
  }

  /// 启动独立更新脚本，并通过统一退出流程释放应用资源。
  Future<void> installAndRestart(DownloadedUpdate update) async {
    if (!Platform.isWindows) {
      throw const UpdateInstallException('当前平台不支持应用内自动更新');
    }
    if (!await update.file.exists()) {
      throw const UpdateInstallException('更新包已被清理，请重新下载');
    }
    if (!await _isPackageValid(update.file, update.asset)) {
      throw const UpdateInstallException('更新包已损坏，请重新下载');
    }

    final scriptFile = await _writeUpdateScript(update);
    AppLogger.i(
      'Launching update script: ${scriptFile.path} '
          '(pid=$pid, package=${update.file.path})',
      'UpdateInstaller',
    );

    try {
      await Process.start('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        scriptFile.path,
      ], mode: ProcessStartMode.detached);
    } catch (error) {
      throw UpdateInstallException('启动更新程序失败', originalError: error);
    }

    await _shutdownHandler(0);
  }

  Future<File> _writeUpdateScript(DownloadedUpdate update) async {
    final updateDir = await _ensureUpdateDir();
    final scriptFile = File(
      p.join(updateDir.path, 'nai_launcher_update_${update.version}.ps1'),
    );
    final resultFile = await _resultMetadataFile();
    final pendingFile = await _pendingMetadataFile();
    final logFile = File(
      p.join(updateDir.path, 'update_${update.version}.log'),
    );
    final executablePath = Platform.resolvedExecutable;
    final appDirectory = p.dirname(executablePath);
    final parentDirectory = p.dirname(appDirectory);
    final safeVersion = update.version.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]'),
      '_',
    );

    final script = update.isPortableZip
        ? WindowsUpdateScript.buildPortableScript(
            appPid: pid,
            version: update.version,
            zipPath: update.file.path,
            appDirectory: appDirectory,
            executableName: p.basename(executablePath),
            extractDirectory: p.join(
              parentDirectory,
              '.nai_update_$safeVersion',
            ),
            backupDirectory: p.join(
              parentDirectory,
              '.nai_backup_$safeVersion',
            ),
            resultPath: resultFile.path,
            pendingMetadataPath: pendingFile.path,
            logPath: logFile.path,
          )
        : WindowsUpdateScript.buildInstallerScript(
            appPid: pid,
            version: update.version,
            installerPath: update.file.path,
            executablePath: executablePath,
            resultPath: resultFile.path,
            pendingMetadataPath: pendingFile.path,
            logPath: logFile.path,
          );

    await scriptFile.writeAsString(script, flush: true);
    return scriptFile;
  }

  Future<void> _writePendingMetadata(
    DownloadedUpdate update,
    VersionInfo info,
  ) async {
    final file = await _pendingMetadataFile();
    final data = <String, Object?>{
      'schemaVersion': 1,
      'version': info.version,
      'currentVersion': info.currentVersion,
      'name': info.name,
      'releaseNotes': info.releaseNotes,
      'publishedAt': info.publishedAt,
      'htmlUrl': info.htmlUrl,
      'filePath': update.file.path,
      'asset': <String, Object?>{
        'type': update.asset.typeId,
        'platform': update.asset.platform,
        'fileName': update.asset.fileName,
        'downloadUrl': update.asset.downloadUrl,
        'sha256': update.asset.sha256,
        'size': update.asset.size,
        'label': update.asset.label,
        'description': update.asset.description,
      },
    };
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<bool> _isPackageValid(File file, ReleaseAssetInfo asset) async {
    if (!await file.exists()) return false;
    if (asset.size != null && await file.length() != asset.size) return false;
    final expected = asset.sha256;
    if (expected == null || expected.isEmpty) return false;
    return equalsSha256(await calculateSha256(file), expected);
  }

  Future<Directory> _ensureUpdateDir() async {
    final updateDir =
        _updateDirectoryOverride ??
        Directory(p.join(Directory.systemTemp.path, _updateDirectoryName));
    await updateDir.create(recursive: true);
    return updateDir;
  }

  Future<File> _pendingMetadataFile() async {
    final directory = await _ensureUpdateDir();
    return File(p.join(directory.path, _pendingMetadataName));
  }

  Future<File> _resultMetadataFile() async {
    final directory = await _ensureUpdateDir();
    return File(p.join(directory.path, _resultMetadataName));
  }

  Future<void> _cleanupStaleFiles(Directory directory) async {
    final cutoff = DateTime.now().subtract(_staleFileAge);
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name == _pendingMetadataName || name == _resultMetadataName) continue;
      try {
        if ((await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (error) {
        AppLogger.d(
          'Unable to clean stale update file ${entity.path}: $error',
          'UpdateInstaller',
        );
      }
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清理失败不能覆盖原始下载或解析错误。
    }
  }

  static int? _parseHeaderInt(String? value) {
    return value == null ? null : int.tryParse(value);
  }

  static int? _parseContentRangeTotal(String? value) {
    if (value == null) return null;
    final match = RegExp(r'/([0-9]+)$').firstMatch(value.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static bool _isDiskFull(FileSystemException error) {
    final code = error.osError?.errorCode;
    return code == 112 || code == 28 || code == 39;
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
