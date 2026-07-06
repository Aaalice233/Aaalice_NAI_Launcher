import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/version/version_info.dart';
import '../utils/app_logger.dart';
import 'app_installation_service.dart';

part 'update_installer_service.g.dart';

class UpdateInstallException implements Exception {
  final String message;
  final Object? originalError;

  const UpdateInstallException(this.message, {this.originalError});

  @override
  String toString() =>
      'UpdateInstallException: $message${originalError != null ? ' ($originalError)' : ''}';
}

typedef AppExitHandler = void Function(int code);

/// 下载并启动 Windows 安装版更新包。
class UpdateInstallerService {
  final Dio _dio;
  final AppInstallationService _installationService;
  final AppExitHandler _exitHandler;

  const UpdateInstallerService({
    required Dio dio,
    required AppInstallationService installationService,
    AppExitHandler exitHandler = exit,
  }) : _dio = dio,
       _installationService = installationService,
       _exitHandler = exitHandler;

  Future<void> downloadAndInstall(
    VersionInfo versionInfo, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_installationService.supportsInAppInstall) {
      throw const UpdateInstallException('当前版本不支持应用内自动安装更新');
    }

    final asset = versionInfo.primaryAsset;
    if (asset == null || !asset.supportsInAppInstall) {
      throw const UpdateInstallException('未找到 Windows 安装版更新包');
    }
    final expectedSha256 = asset.sha256;
    if (expectedSha256 == null || expectedSha256.isEmpty) {
      throw const UpdateInstallException('更新包缺少 SHA256 校验信息');
    }

    final updateDir = Directory(
      p.join(Directory.systemTemp.path, 'nai_launcher_updates'),
    );
    await updateDir.create(recursive: true);
    final installerFile = File(p.join(updateDir.path, asset.fileName));
    if (await installerFile.exists()) {
      await installerFile.delete();
    }

    try {
      await _dio.download(
        asset.downloadUrl,
        installerFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call((received / total).clamp(0, 0.99));
          }
        },
      );

      final actualSha256 = await calculateSha256(installerFile);
      if (!equalsSha256(actualSha256, expectedSha256)) {
        try {
          await installerFile.delete();
        } catch (_) {
          // 校验失败后尽量清掉坏包；删除失败不应掩盖真正的校验错误。
        }
        throw UpdateInstallException(
          '更新包校验失败',
          originalError: 'expected=$expectedSha256 actual=$actualSha256',
        );
      }

      onProgress?.call(1);
      await _launchInstallerAndExit(installerFile);
    } on UpdateInstallException {
      rethrow;
    } catch (e) {
      throw UpdateInstallException('下载或安装更新失败', originalError: e);
    }
  }

  Future<void> _launchInstallerAndExit(File installerFile) async {
    if (!Platform.isWindows) {
      throw const UpdateInstallException('当前平台不支持安装版自动更新');
    }
    AppLogger.i(
      'Launching installer update: ${installerFile.path}',
      'UpdateInstaller',
    );
    await Process.start(installerFile.path, [
      '/S',
    ], mode: ProcessStartMode.detached);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300)).then((_) {
        _exitHandler(0);
      }),
    );
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
