import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:win32_registry/win32_registry.dart';

part 'app_installation_service.g.dart';

enum AppInstallationType {
  windowsInstaller,
  windowsPortable,
  macosPortable,
  androidApk,
  unsupported,
}

/// 判断当前应用是安装版还是便携版。
class AppInstallationService {
  static const uninstallRegistryPath =
      r'Software\Microsoft\Windows\CurrentVersion\Uninstall\Aaalice NAI Launcher';

  AppInstallationType getInstallationType() {
    if (Platform.isWindows) {
      return _isInstalledWindowsApp()
          ? AppInstallationType.windowsInstaller
          : AppInstallationType.windowsPortable;
    }
    if (Platform.isMacOS) {
      return AppInstallationType.macosPortable;
    }
    if (Platform.isAndroid) {
      return AppInstallationType.androidApk;
    }
    return AppInstallationType.unsupported;
  }

  String getReleaseAssetPreference() {
    return switch (getInstallationType()) {
      AppInstallationType.windowsInstaller => 'windows-installer',
      AppInstallationType.windowsPortable => 'windows-portable',
      AppInstallationType.macosPortable => 'macos',
      AppInstallationType.androidApk => 'android-apk',
      AppInstallationType.unsupported => 'unknown',
    };
  }

  /// Windows 由独立更新器替换应用；Android 下载并校验 APK 后交给
  /// 系统安装界面确认。macOS 涉及签名与隔离属性，暂不支持自动替换。
  bool get supportsInAppInstall {
    final type = getInstallationType();
    return type == AppInstallationType.windowsInstaller ||
        type == AppInstallationType.windowsPortable ||
        type == AppInstallationType.androidApk;
  }

  bool _isInstalledWindowsApp() {
    final installLocation = readWindowsInstallLocation();
    if (installLocation == null || installLocation.isEmpty) {
      return false;
    }
    return isExecutableInsideInstallDir(
      executablePath: Platform.resolvedExecutable,
      installLocation: installLocation,
    );
  }

  String? readWindowsInstallLocation() {
    if (!Platform.isWindows) return null;
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.currentUser,
        path: uninstallRegistryPath,
      );
      return key.getValueAsString('InstallLocation');
    } catch (_) {
      return null;
    } finally {
      key?.close();
    }
  }

  static bool isExecutableInsideInstallDir({
    required String executablePath,
    required String installLocation,
  }) {
    final normalizedExe = _normalizePath(executablePath);
    final normalizedInstall = _normalizePath(installLocation);
    return normalizedExe == normalizedInstall ||
        normalizedExe.startsWith('$normalizedInstall\\');
  }

  static String _normalizePath(String value) {
    var normalized = value.replaceAll('/', r'\').trim();
    while (normalized.endsWith(r'\')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.toLowerCase();
  }
}

@riverpod
AppInstallationService appInstallationService(Ref ref) {
  return AppInstallationService();
}
