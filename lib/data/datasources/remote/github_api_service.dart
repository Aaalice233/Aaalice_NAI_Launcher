import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart';

import '../../models/version/release_asset_info.dart';
import '../../models/version/version_info.dart';

part 'github_api_service.g.dart';

enum GitHubReleaseErrorType {
  notFound,
  rateLimited,
  network,
  unavailable,
  invalidResponse,
  unknown,
}

/// GitHub Release 查询异常。面向用户的文案由 presentation 层按 [type] 本地化。
class GitHubApiException implements Exception {
  final String message;
  final GitHubReleaseErrorType type;
  final Object? originalError;

  GitHubApiException(
    this.message, {
    this.type = GitHubReleaseErrorType.unknown,
    this.originalError,
  });

  @override
  String toString() => 'GitHubApiException: $message';
}

/// GitHub API 服务
///
/// 用于获取 GitHub Releases 最新版本信息
class GitHubApiService {
  /// 保留既有构造方式；所有 Release 查询均使用不计匿名 API 配额的网页端点。
  static const String defaultBaseUrl = 'https://github.com';

  static const String _githubWebBaseUrl = 'https://github.com';

  /// 连接超时时间
  static const Duration connectTimeout = Duration(seconds: 10);

  /// 接收超时时间
  static const Duration receiveTimeout = Duration(seconds: 30);

  final Dio _dio;

  GitHubApiService({required Dio dio}) : _dio = dio;

  /// 获取最新 Release 版本信息
  ///
  /// [owner] 仓库所有者
  /// [repo] 仓库名称
  /// [currentVersion] 当前版本号（用于计算是否需要更新）
  /// [platform] 目标发布资产（windows-installer, windows-portable, macos 等）
  /// [includePrerelease] 是否允许预发布版本
  Future<VersionInfo> fetchLatestRelease({
    required String owner,
    required String repo,
    required String currentVersion,
    String platform = 'windows',
    bool includePrerelease = false,
  }) async {
    try {
      final tag = includePrerelease
          ? await _fetchLatestApplicationTagFromFeed(owner, repo)
          : null;
      return await _fetchReleaseManifest(
        owner: owner,
        repo: repo,
        currentVersion: currentVersion,
        platform: platform,
        tag: tag,
      );
    } on DioException catch (e) {
      throw _mapDioException(e, owner: owner, repo: repo);
    } on FormatException catch (e) {
      throw GitHubApiException(
        'Release metadata is invalid for $owner/$repo',
        type: GitHubReleaseErrorType.invalidResponse,
        originalError: e,
      );
    } catch (e) {
      if (e is GitHubApiException) rethrow;
      throw GitHubApiException('Unexpected error: $e', originalError: e);
    }
  }

  /// 直接读取 Release 资产，不消耗匿名 GitHub API 配额。
  Future<VersionInfo> _fetchReleaseManifest({
    required String owner,
    required String repo,
    required String currentVersion,
    required String platform,
    String? tag,
  }) async {
    final manifestUrl = tag == null
        ? '$_githubWebBaseUrl/$owner/$repo/releases/latest/download/'
              'release_manifest.json'
        : '$_githubWebBaseUrl/$owner/$repo/releases/download/$tag/'
              'release_manifest.json';
    final response = await _dio.get<String>(
      manifestUrl,
      options: _releaseAssetOptions(),
    );
    final body = response.data;
    if (body == null || body.trim().isEmpty) {
      throw GitHubApiException(
        'Release manifest is empty for $owner/$repo',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw GitHubApiException(
        'Release manifest is not a JSON object for $owner/$repo',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }
    return _parseManifestData(
      decoded,
      owner: owner,
      repo: repo,
      currentVersion: currentVersion,
      platform: platform,
      expectedTag: tag,
    );
  }

  Future<String?> _fetchLatestApplicationTagFromFeed(
    String owner,
    String repo,
  ) async {
    final response = await _dio.get<String>(
      '$_githubWebBaseUrl/$owner/$repo/releases.atom',
      options: Options(
        responseType: ResponseType.plain,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {'Accept': 'application/atom+xml'},
      ),
    );
    final body = response.data;
    if (body == null || body.trim().isEmpty) {
      throw GitHubApiException(
        'Release feed is empty for $owner/$repo',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }

    final document = XmlDocument.parse(body);
    Version? latestVersion;
    String? latestTag;
    final entries = document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'entry',
    );
    for (final entry in entries) {
      final links = entry.descendants.whereType<XmlElement>().where(
        (element) => element.name.local == 'link',
      );
      for (final link in links) {
        final href = link.getAttribute('href');
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri == null) continue;
        final tagIndex = uri.pathSegments.indexOf('tag');
        if (tagIndex < 0 || tagIndex + 1 >= uri.pathSegments.length) continue;
        final tag = uri.pathSegments[tagIndex + 1];
        if (!_isApplicationTag(tag)) continue;
        Version version;
        try {
          version = Version.parse(tag.substring(1));
        } on FormatException {
          continue;
        }
        if (latestVersion == null || version > latestVersion) {
          latestVersion = version;
          latestTag = tag;
        }
      }
    }

    // GitHub feed 仅保留最近若干条，独立数据包可能挤掉应用版本。
    // 此时退回 stable 的 latest manifest，至少不会漏掉正式更新。
    return latestTag;
  }

  Options _releaseAssetOptions() {
    return Options(
      responseType: ResponseType.plain,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {'Accept': 'application/octet-stream'},
    );
  }

  Future<VersionInfo> _parseManifestData(
    Map<String, dynamic> manifest, {
    required String owner,
    required String repo,
    required String currentVersion,
    required String platform,
    required String? expectedTag,
  }) async {
    final version = manifest['version'] as String? ?? '';
    final tag = manifest['tag'] as String? ?? '';
    try {
      Version.parse(version);
    } on FormatException {
      throw GitHubApiException(
        'Release manifest contains an invalid version',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }

    final versionWithoutBuild = version.split('+').first;
    if (tag != 'v$versionWithoutBuild' ||
        (expectedTag != null && tag != expectedTag)) {
      throw GitHubApiException(
        'Release manifest tag does not match its version',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }

    final rawAssets = manifest['assets'];
    if (rawAssets is! List || rawAssets.isEmpty) {
      throw GitHubApiException(
        'Release manifest contains no downloadable assets',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }

    final assets = <ReleaseAssetInfo>[];
    for (final rawAsset in rawAssets) {
      if (rawAsset is! Map<String, dynamic>) {
        throw GitHubApiException(
          'Release manifest contains an invalid asset entry',
          type: GitHubReleaseErrorType.invalidResponse,
        );
      }
      final asset = ReleaseAssetInfo.fromManifestAsset(rawAsset);
      _validateManifestAsset(asset, owner: owner, repo: repo, tag: tag);
      assets.add(asset);
    }

    final primaryAsset = _findPlatformAsset(assets, platform);
    if (primaryAsset == null) {
      throw GitHubApiException(
        'Release manifest has no asset for platform $platform',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }

    final htmlUrl = '$_githubWebBaseUrl/$owner/$repo/releases/tag/$tag';
    final embeddedNotes = manifest['releaseNotes'] as String?;
    final releaseNotes = embeddedNotes?.trim().isNotEmpty == true
        ? embeddedNotes!
        : await _fetchReleaseNotes(owner: owner, repo: repo, tag: tag);

    return VersionInfo(
      version: version,
      currentVersion: currentVersion,
      name: manifest['name'] as String? ?? 'NAI Launcher $tag',
      releaseNotes: releaseNotes,
      publishedAt: manifest['publishedAt'] as String? ?? '',
      downloadUrl: primaryAsset.downloadUrl,
      htmlUrl: htmlUrl,
      assets: assets,
      primaryAsset: primaryAsset,
      isNewer: VersionInfoComparator.isNewer(version, currentVersion),
    );
  }

  void _validateManifestAsset(
    ReleaseAssetInfo asset, {
    required String owner,
    required String repo,
    required String tag,
  }) {
    final uri = Uri.tryParse(asset.downloadUrl);
    final expectedPathPrefix = '/$owner/$repo/releases/download/$tag/';
    final validHash = RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(asset.sha256 ?? '');
    if (asset.fileName.isEmpty ||
        asset.type == ReleaseAssetType.unknown ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'github.com' ||
        !uri.path.startsWith(expectedPathPrefix) ||
        uri.pathSegments.isEmpty ||
        uri.pathSegments.last != asset.fileName ||
        !validHash ||
        (asset.size ?? 0) <= 0) {
      throw GitHubApiException(
        'Release manifest contains invalid asset metadata',
        type: GitHubReleaseErrorType.invalidResponse,
      );
    }
  }

  Future<String> _fetchReleaseNotes({
    required String owner,
    required String repo,
    required String tag,
  }) async {
    final fileName = 'release_notes_$tag.md';
    final url =
        '$_githubWebBaseUrl/$owner/$repo/releases/download/$tag/$fileName';
    try {
      final response = await _dio.get<String>(
        url,
        options: _releaseAssetOptions(),
      );
      return response.data ?? '';
    } on DioException {
      // 更新清单和安装包仍可独立工作；发布说明缺失不应阻断更新。
      return '';
    }
  }

  GitHubApiException _mapDioException(
    DioException error, {
    required String owner,
    required String repo,
  }) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 404) {
      return GitHubApiException(
        'Release not found for $owner/$repo',
        type: GitHubReleaseErrorType.notFound,
        originalError: error,
      );
    }
    if (statusCode == 403 || statusCode == 429) {
      return GitHubApiException(
        'Release service rate limited the request',
        type: GitHubReleaseErrorType.rateLimited,
        originalError: error,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return GitHubApiException(
        'Release service is temporarily unavailable',
        type: GitHubReleaseErrorType.unavailable,
        originalError: error,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return GitHubApiException(
        'Unable to connect to the release service',
        type: GitHubReleaseErrorType.network,
        originalError: error,
      );
    }
    return GitHubApiException(
      'Failed to fetch release: ${error.message}',
      type: GitHubReleaseErrorType.unknown,
      originalError: error,
    );
  }

  ReleaseAssetInfo? _findPlatformAsset(
    List<ReleaseAssetInfo> assets,
    String platform,
  ) {
    final normalizedPlatform = platform.toLowerCase();
    if (normalizedPlatform == 'windows-installer') {
      return _firstAssetOfType(assets, ReleaseAssetType.windowsInstaller);
    }
    if (normalizedPlatform == 'windows-portable' ||
        normalizedPlatform == 'windows') {
      return _firstAssetOfType(assets, ReleaseAssetType.windowsPortable) ??
          _firstAssetOfType(assets, ReleaseAssetType.windowsInstaller);
    }
    if (normalizedPlatform == 'macos') {
      return _firstAssetOfType(assets, ReleaseAssetType.macosPortable);
    }
    return assets
        .where((asset) => asset.type != ReleaseAssetType.unknown)
        .firstOrNull;
  }

  ReleaseAssetInfo? _firstAssetOfType(
    List<ReleaseAssetInfo> assets,
    ReleaseAssetType type,
  ) {
    return assets.where((asset) => asset.type == type).firstOrNull;
  }

  static bool _isApplicationTag(String tag) {
    return RegExp(
      r'^v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
    ).hasMatch(tag);
  }
}

/// GitHubApiService Provider
@riverpod
GitHubApiService gitHubApiService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: GitHubApiService.defaultBaseUrl,
      connectTimeout: GitHubApiService.connectTimeout,
      receiveTimeout: GitHubApiService.receiveTimeout,
    ),
  );
  return GitHubApiService(dio: dio);
}
