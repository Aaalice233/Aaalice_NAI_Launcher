import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:win32_registry/win32_registry.dart';

part 'app_installation_service.g.dart';

typedef AndroidSupportedAbisLoader = Future<List<String>> Function();

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

  final AndroidSupportedAbisLoader? _androidSupportedAbisLoader;
  List<String>? _cachedAndroidAbis;

  AppInstallationService({
    AndroidSupportedAbisLoader? androidSupportedAbisLoader,
  }) : _androidSupportedAbisLoader = androidSupportedAbisLoader;

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

  /// 获取当前 Android 设备支持的 ABI 列表（按系统偏好顺序）。
  /// 非 Android 平台或读取失败时返回空列表。
  Future<List<String>> getAndroidSupportedAbis() async {
    final cached = _cachedAndroidAbis;
    if (cached != null) return cached;

    final loader = _androidSupportedAbisLoader;
    if (loader != null) {
      final loaded = _normalizeAbis(await loader());
      _cachedAndroidAbis = loaded;
      return loaded;
    }

    if (getInstallationType() != AppInstallationType.androidApk ||
        !Platform.isAndroid) {
      return const [];
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final abis = _normalizeAbis(androidInfo.supportedAbis);
      _cachedAndroidAbis = abis;
      return abis;
    } catch (_) {
      return const [];
    }
  }

  static List<String> _normalizeAbis(Iterable<String?> rawAbis) {
    return List<String>.unmodifiable(
      rawAbis
          .whereType<String>()
          .map((abi) => abi.trim().toLowerCase())
          .where((abi) => abi.isNotEmpty),
    );
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
