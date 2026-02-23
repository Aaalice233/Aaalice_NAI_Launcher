import 'package:package_info_plus/package_info_plus.dart';

/// 应用版本号配置
/// 
/// 从 pubspec.yaml 自动读取版本号
/// 只需修改 pubspec.yaml 中的 version 字段即可
class AppVersion {
  AppVersion._();

  static PackageInfo? _packageInfo;

  /// 初始化版本信息
  static Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// 确保已初始化
  static PackageInfo get _info {
    if (_packageInfo == null) {
      throw StateError(
        'AppVersion not initialized. Call AppVersion.initialize() first.',
      );
    }
    return _packageInfo!;
  }

  /// 版本名称 (显示给用户)
  /// 从 pubspec.yaml 的 version 字段解析
  /// 例如: 1.0.0-Beta3.1
  static String get versionName {
    final version = _info.version;
    // 解析 x.y.z-prerelease+build -> 返回 x.y.z-Prerelease
    final match = RegExp(r'(\d+\.\d+\.\d+)-([^+]+)').firstMatch(version);
    if (match != null) {
      final core = match.group(1)!;  // 1.0.0
      final prerelease = match.group(2)!;  // beta3.1
      // 将 beta3.1 转为 Beta3.1
      final capitalized = prerelease.substring(0, 1).toUpperCase() + 
                          prerelease.substring(1);
      return '$core-$capitalized';
    }
    // 如果没有 prerelease 部分，直接返回版本号
    return version;
  }

  /// 完整版本号
  /// 例如: 1.0.0-beta3.1+3
  static String get fullVersion => _info.version;

  /// 主版本号
  static int get major => int.tryParse(_info.version.split('.')[0]) ?? 0;

  /// 次版本号
  static int get minor => int.tryParse(_info.version.split('.')[1]) ?? 0;

  /// 修订号
  static int get patch {
    final patchPart = _info.version.split('.')[2];
    return int.tryParse(patchPart.split('-')[0].split('+')[0]) ?? 0;
  }

  /// 构建号
  static String get buildNumber => _info.buildNumber;

  /// 获取带版本号的显示文本
  /// 例如: "NAI Launcher Beta3.1"
  static String getDisplayName(String appName) => '$appName $versionName';
}
