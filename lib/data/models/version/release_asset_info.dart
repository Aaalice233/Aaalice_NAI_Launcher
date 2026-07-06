/// GitHub Release 中可下载资产的类型。
enum ReleaseAssetType {
  windowsInstaller,
  windowsPortable,
  macosPortable,
  unknown,
}

/// GitHub Release 中的单个下载资产。
class ReleaseAssetInfo {
  final ReleaseAssetType type;
  final String platform;
  final String fileName;
  final String downloadUrl;
  final String? sha256;
  final int? size;
  final String? label;
  final String? description;

  const ReleaseAssetInfo({
    required this.type,
    required this.platform,
    required this.fileName,
    required this.downloadUrl,
    this.sha256,
    this.size,
    this.label,
    this.description,
  });

  bool get supportsInAppInstall => type == ReleaseAssetType.windowsInstaller;

  String get typeId => switch (type) {
    ReleaseAssetType.windowsInstaller => 'windows-installer',
    ReleaseAssetType.windowsPortable => 'windows-portable',
    ReleaseAssetType.macosPortable => 'macos-portable',
    ReleaseAssetType.unknown => 'unknown',
  };

  ReleaseAssetInfo copyWith({
    ReleaseAssetType? type,
    String? platform,
    String? fileName,
    String? downloadUrl,
    String? sha256,
    int? size,
    String? label,
    String? description,
  }) {
    return ReleaseAssetInfo(
      type: type ?? this.type,
      platform: platform ?? this.platform,
      fileName: fileName ?? this.fileName,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      sha256: sha256 ?? this.sha256,
      size: size ?? this.size,
      label: label ?? this.label,
      description: description ?? this.description,
    );
  }

  factory ReleaseAssetInfo.fromGitHubAsset(Map<String, dynamic> asset) {
    final fileName = asset['name'] as String? ?? '';
    final downloadUrl = asset['browser_download_url'] as String? ?? '';
    final size = (asset['size'] as num?)?.toInt();
    final type = inferType(fileName: fileName);

    return ReleaseAssetInfo(
      type: type,
      platform: inferPlatform(type),
      fileName: fileName,
      downloadUrl: downloadUrl,
      size: size,
      label: defaultLabel(type),
      description: defaultDescription(type),
    );
  }

  factory ReleaseAssetInfo.fromManifestAsset(
    Map<String, dynamic> asset, {
    ReleaseAssetInfo? githubAsset,
  }) {
    final fileName =
        asset['fileName'] as String? ??
        asset['name'] as String? ??
        githubAsset?.fileName ??
        '';
    final type =
        parseType(asset['type'] as String?) ?? inferType(fileName: fileName);

    return ReleaseAssetInfo(
      type: type,
      platform: asset['platform'] as String? ?? inferPlatform(type),
      fileName: fileName,
      downloadUrl:
          asset['downloadUrl'] as String? ??
          asset['url'] as String? ??
          githubAsset?.downloadUrl ??
          '',
      sha256: asset['sha256'] as String? ?? githubAsset?.sha256,
      size: (asset['size'] as num?)?.toInt() ?? githubAsset?.size,
      label:
          asset['label'] as String? ?? githubAsset?.label ?? defaultLabel(type),
      description:
          asset['description'] as String? ??
          githubAsset?.description ??
          defaultDescription(type),
    );
  }

  static ReleaseAssetType? parseType(String? value) {
    return switch (value) {
      'windows-installer' => ReleaseAssetType.windowsInstaller,
      'windows-portable' => ReleaseAssetType.windowsPortable,
      'macos-portable' => ReleaseAssetType.macosPortable,
      'unknown' => ReleaseAssetType.unknown,
      _ => null,
    };
  }

  static ReleaseAssetType inferType({required String fileName}) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.exe') &&
        lowerName.contains('windows') &&
        (lowerName.contains('setup') || lowerName.contains('installer'))) {
      return ReleaseAssetType.windowsInstaller;
    }
    if (lowerName.contains('windows') &&
        (lowerName.contains('portable') || lowerName.endsWith('.zip'))) {
      return ReleaseAssetType.windowsPortable;
    }
    if ((lowerName.contains('macos') || lowerName.contains('mac')) &&
        (lowerName.contains('portable') || lowerName.endsWith('.zip'))) {
      return ReleaseAssetType.macosPortable;
    }
    return ReleaseAssetType.unknown;
  }

  static String inferPlatform(ReleaseAssetType type) {
    return switch (type) {
      ReleaseAssetType.windowsInstaller ||
      ReleaseAssetType.windowsPortable => 'windows',
      ReleaseAssetType.macosPortable => 'macos',
      ReleaseAssetType.unknown => 'unknown',
    };
  }

  static String defaultLabel(ReleaseAssetType type) {
    return switch (type) {
      ReleaseAssetType.windowsInstaller => 'Windows 安装版',
      ReleaseAssetType.windowsPortable => 'Windows 便携版',
      ReleaseAssetType.macosPortable => 'macOS 便携版',
      ReleaseAssetType.unknown => '下载文件',
    };
  }

  static String defaultDescription(ReleaseAssetType type) {
    return switch (type) {
      ReleaseAssetType.windowsInstaller => '推荐普通用户使用，支持应用内一键更新。',
      ReleaseAssetType.windowsPortable => '解压即用，不会自动覆盖更新。',
      ReleaseAssetType.macosPortable => '解压后打开应用，更新时需要手动替换。',
      ReleaseAssetType.unknown => '请查看 Release 页面说明。',
    };
  }
}
