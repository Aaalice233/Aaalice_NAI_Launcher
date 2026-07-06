import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/version/release_asset_info.dart';
import '../../models/version/version_info.dart';

part 'github_api_service.g.dart';

/// GitHub API 异常
class GitHubApiException implements Exception {
  final String message;
  final Object? originalError;

  GitHubApiException(this.message, {this.originalError});

  @override
  String toString() => 'GitHubApiException: $message';
}

/// GitHub API 服务
///
/// 用于获取 GitHub Releases 最新版本信息
class GitHubApiService {
  /// 默认 GitHub API 基础 URL
  static const String defaultBaseUrl = 'https://api.github.com';

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
      final data = includePrerelease
          ? await _fetchLatestFromReleaseList(owner, repo)
          : await _fetchLatestStableRelease(owner, repo);

      if (data == null) {
        throw GitHubApiException('Release not found for $owner/$repo');
      }

      return await _parseReleaseData(data, currentVersion, platform);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw GitHubApiException(
          'Release not found for $owner/$repo',
          originalError: e,
        );
      }
      throw GitHubApiException(
        'Failed to fetch release: ${e.message}',
        originalError: e,
      );
    } catch (e) {
      if (e is GitHubApiException) rethrow;
      throw GitHubApiException('Unexpected error: $e', originalError: e);
    }
  }

  Future<Map<String, dynamic>?> _fetchLatestStableRelease(
    String owner,
    String repo,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/repos/$owner/$repo/releases/latest',
      options: _githubOptions(),
    );
    return response.data;
  }

  Future<Map<String, dynamic>?> _fetchLatestFromReleaseList(
    String owner,
    String repo,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '/repos/$owner/$repo/releases',
      queryParameters: {'per_page': 20},
      options: _githubOptions(),
    );

    final releases = response.data ?? const [];
    for (final release in releases) {
      if (release is! Map<String, dynamic>) continue;
      if (release['draft'] == true) continue;
      return release;
    }
    return null;
  }

  Options _githubOptions() {
    return Options(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
  }

  Future<Map<String, dynamic>?> _fetchReleaseManifest(
    List<ReleaseAssetInfo> githubAssets,
  ) async {
    final manifestAsset = githubAssets.where((asset) {
      return asset.fileName.toLowerCase() == 'release_manifest.json';
    }).firstOrNull;

    if (manifestAsset == null || manifestAsset.downloadUrl.isEmpty) {
      return null;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      manifestAsset.downloadUrl,
      options: Options(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {'Accept': 'application/json'},
      ),
    );
    return response.data;
  }

  /// 解析 Release 数据
  Future<VersionInfo> _parseReleaseData(
    Map<String, dynamic> data,
    String currentVersion,
    String platform,
  ) async {
    final tagName = data['tag_name'] as String? ?? '';
    final version = _extractVersion(tagName);
    final name = data['name'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final publishedAt = data['published_at'] as String? ?? '';
    final htmlUrl = data['html_url'] as String? ?? '';
    final assets = data['assets'] as List<dynamic>? ?? [];
    final githubAssets = _parseGitHubAssets(assets);
    final releaseAssets = await _mergeManifestAssets(githubAssets);
    final primaryAsset = _findPlatformAsset(releaseAssets, platform);

    return VersionInfo(
      version: version,
      currentVersion: currentVersion,
      name: name,
      releaseNotes: body,
      publishedAt: publishedAt,
      downloadUrl: primaryAsset?.downloadUrl ?? htmlUrl,
      htmlUrl: htmlUrl,
      assets: releaseAssets,
      primaryAsset: primaryAsset,
      isNewer: VersionInfoComparator.isNewer(version, currentVersion),
    );
  }

  List<ReleaseAssetInfo> _parseGitHubAssets(List<dynamic> assets) {
    return assets
        .whereType<Map<String, dynamic>>()
        .map(ReleaseAssetInfo.fromGitHubAsset)
        .where((asset) => asset.downloadUrl.isNotEmpty)
        .toList();
  }

  Future<List<ReleaseAssetInfo>> _mergeManifestAssets(
    List<ReleaseAssetInfo> githubAssets,
  ) async {
    Map<String, dynamic>? manifest;
    try {
      manifest = await _fetchReleaseManifest(githubAssets);
    } catch (_) {
      manifest = null;
    }

    final manifestAssets = manifest?['assets'];
    if (manifestAssets is! List) {
      return githubAssets;
    }

    final githubByName = {
      for (final asset in githubAssets) asset.fileName: asset,
    };
    final result = <ReleaseAssetInfo>[];

    for (final entry in manifestAssets) {
      if (entry is! Map<String, dynamic>) continue;
      final fileName = entry['fileName'] as String? ?? entry['name'] as String?;
      final githubAsset = fileName == null ? null : githubByName[fileName];
      final asset = ReleaseAssetInfo.fromManifestAsset(
        entry,
        githubAsset: githubAsset,
      );
      if (asset.downloadUrl.isNotEmpty) {
        result.add(asset);
      }
    }

    final manifestNames = result.map((asset) => asset.fileName).toSet();
    for (final asset in githubAssets) {
      if (asset.fileName == 'release_manifest.json') continue;
      if (!manifestNames.contains(asset.fileName)) {
        result.add(asset);
      }
    }

    return result;
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

  /// 从 tag_name 提取版本号（移除 v 前缀）
  String _extractVersion(String tagName) {
    if (tagName.startsWith('v')) {
      return tagName.substring(1);
    }
    return tagName;
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
