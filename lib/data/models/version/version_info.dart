import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'release_asset_info.dart';

part 'version_info.freezed.dart';
part 'version_info.g.dart';

/// 版本信息模型
///
/// 用于存储 GitHub Release 的版本信息
@freezed
class VersionInfo with _$VersionInfo {
  const factory VersionInfo({
    /// 版本号（不含 v 前缀）
    required String version,

    /// 当前本地版本号
    String? currentVersion,

    /// Release 名称
    String? name,

    /// 发布说明
    String? releaseNotes,

    /// 发布时间（ISO 8601 格式）
    String? publishedAt,

    /// 下载链接（如果找不到匹配平台的资源，则为 html_url）
    String? downloadUrl,

    /// Release 页面链接
    String? htmlUrl,

    /// Release 中识别到的下载资产
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default([])
    List<ReleaseAssetInfo> assets,

    /// 当前运行环境推荐使用的下载资产
    @JsonKey(includeFromJson: false, includeToJson: false)
    ReleaseAssetInfo? primaryAsset,

    /// 是否比当前版本新
    @Default(false) bool isNewer,
  }) = _VersionInfo;

  const VersionInfo._();

  factory VersionInfo.fromJson(Map<String, dynamic> json) =>
      _$VersionInfoFromJson(json);

  /// 检查此版本是否需要从指定版本更新
  ///
  /// [current] 当前安装的版本
  /// 返回 true 如果此版本比当前版本新
  bool shouldUpdateFrom(VersionInfo current) {
    return VersionInfoComparator.isNewer(version, current.version);
  }

  /// 当前版本是否可以在应用内下载安装。
  bool get supportsInAppInstall =>
      primaryAsset?.supportsInAppInstall == true &&
      primaryAsset?.sha256 != null &&
      primaryAsset!.sha256!.isNotEmpty;
}

/// 版本号比较器
class VersionInfoComparator {
  /// 清理版本号字符串，移除 v 前缀
  static String _cleanVersion(String version) {
    final withoutPrefix = version.startsWith('v') || version.startsWith('V')
        ? version.substring(1)
        : version;
    return withoutPrefix.trim();
  }

  /// 比较两个版本号，检查新版本是否比当前版本新
  static bool isNewer(String newVersion, String currentVersion) {
    try {
      final parsedNewVersion = Version.parse(_cleanVersion(newVersion));
      final parsedCurrentVersion = Version.parse(_cleanVersion(currentVersion));
      final semverCompare = parsedNewVersion.compareTo(parsedCurrentVersion);
      if (semverCompare != 0) {
        return semverCompare > 0;
      }

      return _compareBuildMetadata(parsedNewVersion, parsedCurrentVersion) > 0;
    } catch (_) {
      return false;
    }
  }

  /// 是否为预发布版本。
  static bool isPrerelease(String version) {
    try {
      return Version.parse(_cleanVersion(version)).isPreRelease;
    } catch (_) {
      return false;
    }
  }

  static int _compareBuildMetadata(Version newVersion, Version currentVersion) {
    final newBuild = _parseBuildNumber(newVersion.build);
    final currentBuild = _parseBuildNumber(currentVersion.build);
    if (newBuild != null && currentBuild != null) {
      return newBuild.compareTo(currentBuild);
    }
    if (newVersion.build.isEmpty || currentVersion.build.isEmpty) {
      return newVersion.build.length.compareTo(currentVersion.build.length);
    }
    return newVersion.build.join('.').compareTo(currentVersion.build.join('.'));
  }

  static int? _parseBuildNumber(List<Object> buildParts) {
    if (buildParts.length != 1) {
      return null;
    }
    return int.tryParse(buildParts.single.toString());
  }
}
