/// GitHub Release 中可下载资产的类型。
enum ReleaseAssetType {
  windowsInstaller,
  windowsPortable,
  macosPortable,
  androidApk,
  unknown,
}

/// GitHub Release 中的单个下载资产。
class ReleaseAssetInfo {
  static final RegExp _apkAbiPattern = RegExp(
    r'(?:^|[_.-])(arm64-v8a|armeabi-v7a|x86_64)(?:$|[_.-])',
    caseSensitive: false,
  );

  final ReleaseAssetType type;
  final String platform;
  final String fileName;
  final String downloadUrl;
  final String? abi;
  final String? sha256;
  final int? size;
  final String? label;
  final String? description;

  const ReleaseAssetInfo({
    required this.type,
    required this.platform,
    required this.fileName,
    required this.downloadUrl,
    this.abi,
    this.sha256,
    this.size,
    this.label,
    this.description,
  });

  /// Windows 安装版与便携版由独立更新器替换应用；Android APK 在应用内
  /// 完成下载与校验后交给系统安装界面确认。macOS 仍需手动替换。
  bool get supportsInAppInstall =>
      type == ReleaseAssetType.windowsInstaller ||
      type == ReleaseAssetType.windowsPortable ||
      type == ReleaseAssetType.androidApk;

  String get typeId => switch (type) {
    ReleaseAssetType.windowsInstaller => 'windows-installer',
    ReleaseAssetType.windowsPortable => 'windows-portable',
    ReleaseAssetType.macosPortable => 'macos-portable',
    ReleaseAssetType.androidApk => 'android-apk',
    ReleaseAssetType.unknown => 'unknown',
  };

  ReleaseAssetInfo copyWith({
    ReleaseAssetType? type,
    String? platform,
    String? fileName,
    String? downloadUrl,
    String? abi,
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
      abi: abi ?? this.abi,
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
    final abi = type == ReleaseAssetType.androidApk
        ? inferAbi(fileName: fileName)
        : null;

    return ReleaseAssetInfo(
      type: type,
      platform: inferPlatform(type),
      fileName: fileName,
      downloadUrl: downloadUrl,
      abi: abi,
      size: size,
      label: defaultLabel(type, abi: abi),
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
    final abi =
        normalizeAbi(asset['abi']) ??
        githubAsset?.abi ??
        (type == ReleaseAssetType.androidApk
            ? inferAbi(fileName: fileName)
            : null);

    return ReleaseAssetInfo(
      type: type,
      platform: asset['platform'] as String? ?? inferPlatform(type),
      fileName: fileName,
      downloadUrl:
          asset['downloadUrl'] as String? ??
          asset['url'] as String? ??
          githubAsset?.downloadUrl ??
          '',
      abi: abi,
      sha256: asset['sha256'] as String? ?? githubAsset?.sha256,
      size: (asset['size'] as num?)?.toInt() ?? githubAsset?.size,
      label:
          asset['label'] as String? ??
          githubAsset?.label ??
          defaultLabel(type, abi: abi),
      description:
          asset['description'] as String? ??
          githubAsset?.description ??
          defaultDescription(type),
    );
  }

  static String? normalizeAbi(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? inferAbi({required String fileName}) {
    final lowerName = fileName.trim().toLowerCase();
    if (!lowerName.endsWith('.apk')) return null;
    final stem = lowerName.substring(0, lowerName.length - 4);
    final match = _apkAbiPattern.firstMatch(stem);
    return match?.group(1)?.toLowerCase();
  }

  /// 按设备支持的 ABI 顺序选择 Android APK 资产。
  ///
  /// 资产均无 [abi]（旧版通用 APK）时返回第一个 Android 资产；
  /// 否则按 [supportedAbis] 顺序匹配，都不匹配时退回 `arm64-v8a`，
  /// 再退回第一个 Android 资产。
  static ReleaseAssetInfo? selectAndroidAsset(
    Iterable<ReleaseAssetInfo> assets, {
    List<String> supportedAbis = const [],
  }) {
    final androidAssets = assets
        .where((asset) => asset.type == ReleaseAssetType.androidApk)
        .toList(growable: false);
    if (androidAssets.isEmpty) return null;

    final hasAnyAbi = androidAssets.any(
      (asset) => normalizeAbi(asset.abi) != null,
    );
    if (!hasAnyAbi) {
      return androidAssets.first;
    }

    for (final candidateAbi in supportedAbis) {
      final normalizedCandidate = normalizeAbi(candidateAbi);
      if (normalizedCandidate == null) continue;
      for (final asset in androidAssets) {
        if (normalizeAbi(asset.abi) == normalizedCandidate) {
          return asset;
        }
      }
    }

    for (final asset in androidAssets) {
      if (normalizeAbi(asset.abi) == 'arm64-v8a') {
        return asset;
      }
    }

    return androidAssets.first;
  }

  static ReleaseAssetType? parseType(String? value) {
    return switch (value) {
      'windows-installer' => ReleaseAssetType.windowsInstaller,
      'windows-portable' => ReleaseAssetType.windowsPortable,
      'macos-portable' => ReleaseAssetType.macosPortable,
      'android-apk' => ReleaseAssetType.androidApk,
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
    if (lowerName.contains('android') && lowerName.endsWith('.apk')) {
      return ReleaseAssetType.androidApk;
    }
    return ReleaseAssetType.unknown;
  }

  static String inferPlatform(ReleaseAssetType type) {
    return switch (type) {
      ReleaseAssetType.windowsInstaller ||
      ReleaseAssetType.windowsPortable => 'windows',
      ReleaseAssetType.macosPortable => 'macos',
      ReleaseAssetType.androidApk => 'android',
      ReleaseAssetType.unknown => 'unknown',
    };
  }

  static String defaultLabel(ReleaseAssetType type, {String? abi}) {
    return switch (type) {
      ReleaseAssetType.windowsInstaller => 'Windows 安装版',
      ReleaseAssetType.windowsPortable => 'Windows 便携版',
      ReleaseAssetType.macosPortable => 'macOS 便携版',
      ReleaseAssetType.androidApk =>
        abi != null && abi.isNotEmpty ? 'Android APK ($abi)' : 'Android APK',
      ReleaseAssetType.unknown => '下载文件',
    };
  }

  static String defaultDescription(ReleaseAssetType type) {
    return switch (type) {
      ReleaseAssetType.windowsInstaller => '推荐普通用户使用，支持应用内一键更新。',
      ReleaseAssetType.windowsPortable => '解压即用，支持应用内自动更新。',
      ReleaseAssetType.macosPortable => '解压后打开应用，更新时需要手动替换。',
      ReleaseAssetType.androidApk => '下载后由 Android 系统确认并安装更新。',
      ReleaseAssetType.unknown => '请查看 Release 页面说明。',
    };
  }
}
