import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'backend_http.dart';
import 'cloud_sync_backend.dart';
import 'github_backend_support.dart';

class GitHubTreeBase {
  const GitHubTreeBase({required this.commit, required this.tree});

  final String commit;
  final String tree;
}

class GitHubTreeEntry {
  const GitHubTreeEntry({
    required this.path,
    required this.sha,
    required this.size,
  });

  final String path;
  final String sha;
  final int size;
}

class GitHubApiClient {
  static const String _emptyTreeSha =
      '4b825dc642cb6eb9a060e54bf8d69288fbee4904';

  GitHubApiClient({
    required this.owner,
    required this.repository,
    required this.branch,
    required String token,
    Dio? dio,
    Uri? apiBaseUri,
    BackendHttpSleeper? sleeper,
  }) : _authorization = 'Bearer $token',
       _http = BackendHttp(dio: dio, sleeper: sleeper),
       _apiBase = apiBaseUri ?? Uri.parse('https://api.github.com/');

  final String owner;
  final String repository;
  final String branch;
  final String _authorization;
  final BackendHttp _http;
  final Uri _apiBase;

  String get repo => 'repos/${segment(owner)}/${segment(repository)}';

  Map<String, String> get _headers => {
    'Authorization': _authorization,
    'Accept': 'application/vnd.github+json',
    'Content-Type': 'application/json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Accept-Encoding': 'identity',
  };

  Future<Map<String, dynamic>> repositoryInfo() =>
      jsonRequest('GET', repo, action: '检查仓库');

  Future<String> ensureBranch(
    Map<String, dynamic> repository,
    String root,
  ) async {
    final existing = await branchShaOrNull();
    if (existing != null) return existing;
    if (!await _repositoryHasNoBranches()) {
      throw CloudBackendException(
        CloudBackendErrorKind.notFound,
        '找不到分支 "$branch"，请检查分支名称或 Token 对私有仓库的访问权限。',
        statusCode: 404,
      );
    }
    final initialized = await jsonRequest(
      'PUT',
      contents('$root/.init', forWrite: true),
      action: '初始化空仓库',
      accepted: const {200, 201},
      data: {
        'message': 'cloud-sync: initialize repository',
        'content': base64Encode(utf8.encode('Aaalice cloud sync\n')),
      },
    );
    final commit = initialized['commit'];
    final sha = commit is Map ? commit['sha'] : null;
    if (sha is! String) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub 初始化响应缺少 commit SHA。',
      );
    }
    if (branch != repository['default_branch']) {
      await jsonRequest(
        'POST',
        '$repo/git/refs',
        action: '创建同步分支',
        accepted: const {201},
        data: {'ref': 'refs/heads/$branch', 'sha': sha},
      );
    }
    return sha;
  }

  Future<String?> branchShaOrNull() async {
    final response = await request(
      'GET',
      '$repo/branches/${segment(branch)}',
      action: '读取分支 revision',
      allowNotFound: true,
    );
    if (response == null) return null;
    final value = decodeJson(response);
    final commit = value is Map ? value['commit'] : null;
    final sha = commit is Map ? commit['sha'] : null;
    if (sha is! String) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub 分支响应缺少 commit SHA。',
      );
    }
    return sha;
  }

  Future<GitHubTreeBase?> readTreeBase() async {
    final commitSha = await branchShaOrNull();
    if (commitSha == null) {
      // A missing requested branch is only an empty backup when the accessible
      // repository has no branches. Repository size can lag behind commits.
      await repositoryInfo();
      if (await _repositoryHasNoBranches()) return null;
      throw CloudBackendException(
        CloudBackendErrorKind.notFound,
        '找不到分支 "$branch"，请检查分支名称。',
        statusCode: 404,
      );
    }
    final commit = await jsonRequest(
      'GET',
      '$repo/git/commits/${segment(commitSha)}',
      action: '读取分支 tree',
    );
    final tree = commit['tree'];
    final treeSha = tree is Map ? tree['sha'] : null;
    if (treeSha is! String || treeSha.isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub commit 响应缺少 tree SHA。',
      );
    }
    return GitHubTreeBase(commit: commitSha, tree: treeSha);
  }

  Future<bool> _repositoryHasNoBranches() async {
    final response = await request(
      'GET',
      '$repo/branches?per_page=1',
      action: '检查仓库是否为空',
    );
    final branches = decodeJson(response!);
    if (branches is! List) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub 分支清单响应格式无效。',
      );
    }
    return branches.isEmpty;
  }

  Future<Map<String, GitHubTreeEntry>> readRecursiveTree(String treeSha) async {
    final response = await jsonRequest(
      'GET',
      '$repo/git/trees/${segment(treeSha)}?recursive=1',
      action: '读取仓库对象清单',
    );
    if (response['truncated'] != false) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub tree 清单被截断，无法安全判断远端对象。',
      );
    }
    final tree = response['tree'];
    if (tree is! List) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub tree 响应格式无效。',
      );
    }
    final entries = <String, GitHubTreeEntry>{};
    for (final item in tree.whereType<Map>()) {
      if (item['type'] != 'blob') continue;
      final path = item['path'];
      final sha = item['sha'];
      final size = item['size'];
      if (path is! String ||
          path.isEmpty ||
          sha is! String ||
          sha.isEmpty ||
          size is! int ||
          size < 0 ||
          entries.containsKey(path)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'GitHub tree 清单包含无效或重复的 blob 条目。',
        );
      }
      entries[path] = GitHubTreeEntry(path: path, sha: sha, size: size);
    }
    return entries;
  }

  Future<CloudObjectRead> readBlob(
    String blobSha, {
    required int maxBytes,
  }) async {
    final response = await request(
      'GET',
      '$repo/git/blobs/${segment(blobSha)}',
      action: '读取不可变 blob',
      maxResponseBytes: maxBytes,
      headers: const {'Accept': 'application/vnd.github.raw+json'},
    );
    final bytes = BackendHttp.bytesOf(response!);
    if (!GitHubBackendSupport.matchesGitBlobSha(bytes, blobSha)) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub blob 内容与 SHA 不匹配。',
      );
    }
    return CloudObjectRead(bytes: bytes, revision: blobSha);
  }

  Future<String> createBlob(Uint8List bytes, {required String action}) async {
    final blob = await jsonRequest(
      'POST',
      '$repo/git/blobs',
      action: action,
      accepted: const {201},
      data: {'content': base64Encode(bytes), 'encoding': 'base64'},
    );
    return requiredSha(blob, 'GitHub 未返回 blob SHA。');
  }

  Future<String> commitTree({
    required GitHubTreeBase base,
    required List<Map<String, Object?>> entries,
    required String message,
    bool includeBaseTree = true,
  }) async {
    final treeSha = entries.isEmpty && !includeBaseTree
        ? _emptyTreeSha
        : requiredSha(
            await jsonRequest(
              'POST',
              '$repo/git/trees',
              action: '创建原子同步 tree',
              accepted: const {201},
              data: {
                if (includeBaseTree) 'base_tree': base.tree,
                'tree': entries,
              },
            ),
            'GitHub 未返回 tree SHA。',
          );
    final commit = await jsonRequest(
      'POST',
      '$repo/git/commits',
      action: '创建原子同步 commit',
      accepted: const {201},
      data: {
        'message': message,
        'tree': treeSha,
        'parents': [base.commit],
      },
    );
    final commitSha = requiredSha(commit, 'GitHub 未返回 commit SHA。');
    await jsonRequest(
      'PATCH',
      '$repo/git/refs/heads/${segment(branch)}',
      action: '条件更新同步分支',
      data: {'sha': commitSha, 'force': false},
    );
    return commitSha;
  }

  Future<Map<String, dynamic>> jsonRequest(
    String method,
    String path, {
    required String action,
    Set<int> accepted = const {200},
    Object? data,
    int maxResponseBytes = maxCloudJsonApiResponseBytes,
  }) async {
    final response = await request(
      method,
      path,
      action: action,
      accepted: accepted,
      data: data,
      maxResponseBytes: maxResponseBytes,
    );
    final value = decodeJson(response!);
    if (value is! Map) {
      throw CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '$action失败：GitHub 返回格式无效。',
      );
    }
    return value.cast<String, dynamic>();
  }

  Future<Response<Uint8List>?> request(
    String method,
    String path, {
    required String action,
    Set<int> accepted = const {200},
    Object? data,
    bool allowNotFound = false,
    int maxResponseBytes = maxCloudJsonApiResponseBytes,
    Map<String, String>? headers,
  }) async {
    final response = await _http.request(
      method,
      _apiBase.resolve(path),
      headers: {..._headers, ...?headers},
      data: data == null ? null : jsonEncode(data),
      maxResponseBytes: maxResponseBytes,
      retryResponse: GitHubBackendSupport.isRateLimited,
    );
    final status = response.statusCode ?? 0;
    if (accepted.contains(status)) return response;
    if (allowNotFound && status == 404) return null;
    GitHubBackendSupport.throwResponse(response, action);
  }

  dynamic decodeJson(Response<Uint8List> response) =>
      GitHubBackendSupport.decodeJson(response);

  String contents(String path, {bool forWrite = false, String? ref}) {
    final endpoint = '$repo/contents/${path.split('/').map(segment).join('/')}';
    if (forWrite) return endpoint;
    return '$endpoint?ref=${Uri.encodeQueryComponent(ref ?? branch)}';
  }

  static String requiredSha(Map value, String message) {
    final sha = value['sha'];
    if (sha is! String || sha.isEmpty) {
      throw CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        message,
      );
    }
    return sha;
  }

  static String segment(String value) => Uri.encodeComponent(value);
}
