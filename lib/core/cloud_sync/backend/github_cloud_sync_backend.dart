import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'cloud_sync_backend.dart';
import 'github_api_client.dart';
import 'github_backend_support.dart';

class GitHubCloudSyncBackend
    implements CloudSyncBackend, CloudKeyEnvelopeBackend {
  GitHubCloudSyncBackend({
    required this.owner,
    required this.repository,
    required this.branch,
    required String token,
    this.namespace = 'aaalice-sync',
    Dio? dio,
    Uri? apiBaseUri,
  }) : _api = GitHubApiClient(
         owner: owner,
         repository: repository,
         branch: branch,
         token: token,
         dio: dio,
         apiBaseUri: apiBaseUri,
       ) {
    for (final value in [owner, repository, branch]) {
      if (value.trim().isEmpty) throw ArgumentError('GitHub 配置不能为空');
    }
    GitHubBackendSupport.validatePath(namespace);
  }

  static const int _blobLimit = 100 * 1024 * 1024;

  final String owner;
  final String repository;
  final String branch;
  final String namespace;
  final GitHubApiClient _api;
  _StagingSession? _staging;

  String get _root => namespace.replaceAll(RegExp(r'^/+|/+$'), '');

  @override
  Future<CloudBackendCapability> testCapability() async {
    final repository = await _api.repositoryInfo();
    final permissions = repository['permissions'];
    if (permissions is Map && permissions['push'] == false) {
      throw const CloudBackendException(
        CloudBackendErrorKind.authorization,
        'Token 对该仓库没有写权限；私有仓库通常需要 Contents 读写权限。',
        statusCode: 403,
      );
    }
    await _api.ensureBranch(repository, _root);
    await _probeRepositoryCapabilities();
    return const CloudBackendCapability(
      mode: CloudBackendMode.bidirectional,
      message: 'GitHub 已验证认证、读写、非强制条件更新、历史、删除与 4 MiB 对象限制。',
      supportsHistory: true,
      supportsDelete: true,
      warnings: [
        'Git 会保留历史；删除仅移除当前 namespace，不会回收仓库历史空间。',
        '不使用 Git LFS 或 Releases；大二进制频繁变化会快速膨胀仓库历史。',
      ],
    );
  }

  Future<void> _probeRepositoryCapabilities() async {
    final id =
        '.capability-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final path = '$_root/$id';
    try {
      final maximum = Uint8List(maxCloudObjectResponseBytes);
      maximum[0] = 1;
      maximum[maximum.length - 1] = 2;
      final firstBlob = await _api.createBlob(maximum, action: '写入大小探针');
      final initial = await _api.readTreeBase();
      final firstCommit = await _api.commitTree(
        base: initial,
        entries: [_blobEntry(path, firstBlob)],
        message: 'cloud-sync: capability create',
      );
      final read = await _api.readPath(
        path,
        ref: firstCommit,
        maxBytes: maxCloudObjectResponseBytes,
      );
      if (read == null ||
          read.bytes.length != maximum.length ||
          read.bytes.first != 1 ||
          read.bytes.last != 2) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'GitHub 无法完整读回大小探针。',
        );
      }

      final updateBase = await _api.readTreeBase();
      final secondBlob = await _api.createBlob(
        Uint8List.fromList(const [3]),
        action: '写入条件更新探针',
      );
      await _api.commitTree(
        base: updateBase,
        entries: [_blobEntry(path, secondBlob)],
        message: 'cloud-sync: capability update',
      );
      final historical = await _api.readPath(
        path,
        ref: firstCommit,
        maxBytes: maxCloudObjectResponseBytes,
      );
      if (historical == null || historical.bytes.length != maximum.length) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'GitHub 无法读取探针历史版本。',
        );
      }
      var staleRejected = false;
      try {
        await _api.commitTree(
          base: updateBase,
          entries: [_blobEntry(path, secondBlob)],
          message: 'cloud-sync: capability stale update',
        );
      } on CloudBackendException catch (error) {
        if (error.kind != CloudBackendErrorKind.conflict) rethrow;
        staleRejected = true;
      }
      if (!staleRejected) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'GitHub 未拒绝基于旧 revision 的条件更新。',
        );
      }
      final deleteBase = await _api.readTreeBase();
      await _api.commitTree(
        base: deleteBase,
        entries: [
          {'path': path, 'mode': '100644', 'type': 'blob', 'sha': null},
        ],
        message: 'cloud-sync: capability delete',
      );
      if (await _api.readPath(path, maxBytes: maxCloudObjectResponseBytes) !=
          null) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'GitHub 删除探针后仍可读取该文件。',
        );
      }
    } finally {
      final base = await _api.readTreeBase();
      final leftover = await _api.readPath(
        path,
        ref: base.commit,
        maxBytes: maxCloudObjectResponseBytes,
      );
      if (leftover != null) {
        await _api.commitTree(
          base: base,
          entries: [
            {'path': path, 'mode': '100644', 'type': 'blob', 'sha': null},
          ],
          message: 'cloud-sync: cleanup capability probe',
        );
      }
    }
  }

  static Map<String, Object?> _blobEntry(String path, String sha) => {
    'path': path,
    'mode': '100644',
    'type': 'blob',
    'sha': sha,
  };

  @override
  Future<CloudHeadRead?> readHead() async {
    final branchSha = await _api.branchSha();
    final result = await _api.readPath(
      '$_root/HEAD.json',
      ref: branchSha,
      maxBytes: maxCloudHeadResponseBytes,
    );
    if (result == null) return null;
    return CloudHeadRead(
      bytes: result.bytes,
      revision: '${result.revision}:$branchSha',
    );
  }

  @override
  Future<CloudObjectRead?> readKeyEnvelope() =>
      _api.readPath('$_root/KEY.json', maxBytes: maxCloudKeyResponseBytes);

  @override
  Future<CloudCommitResult> commitKeyEnvelope(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    _checkProtocolSize(bytes, maxCloudKeyResponseBytes);
    final current = await _api.readPath(
      '$_root/KEY.json',
      maxBytes: maxCloudKeyResponseBytes,
    );
    if ((expectedRevision == null && current != null) ||
        (expectedRevision != null && current?.revision != expectedRevision)) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '远端 KEY 已被其他设备更新，请重新读取后重试。',
      );
    }
    final response = await _api.jsonRequest(
      'PUT',
      _api.contents('$_root/KEY.json', forWrite: true),
      action: '提交 KEY',
      accepted: const {200, 201},
      data: {
        'message': 'cloud-sync: update KEY',
        'content': base64Encode(bytes),
        'branch': branch,
        if (current != null) 'sha': current.revision,
      },
    );
    return CloudCommitResult(
      revision: GitHubBackendSupport.contentSha(response),
    );
  }

  @override
  Future<CloudObjectRead?> readObject(String objectId) {
    GitHubBackendSupport.validateId(objectId);
    return _api.readPath(
      '$_root/objects/$objectId',
      maxBytes: maxCloudObjectResponseBytes,
    );
  }

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) {
    GitHubBackendSupport.validateId(snapshotId);
    return _api.readPath(
      '$_root/snapshots/$snapshotId.json',
      maxBytes: maxCloudManifestResponseBytes,
    );
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
  }) {
    GitHubBackendSupport.validateId(objectId);
    return _stageImmutable(
      '$_root/objects/$objectId',
      bytes,
      sha256,
      maxBytes: maxCloudObjectResponseBytes,
    );
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
  }) {
    GitHubBackendSupport.validateId(snapshotId);
    return _stageImmutable(
      '$_root/snapshots/$snapshotId.json',
      bytes,
      sha256,
      maxBytes: maxCloudManifestResponseBytes,
    );
  }

  Future<CloudCommitResult> _stageImmutable(
    String path,
    Uint8List bytes,
    String expectedHash, {
    required int maxBytes,
  }) async {
    _checkProtocolSize(bytes, maxBytes);
    final session = await _stagingSession();
    final existing = await _api.readPath(
      path,
      ref: session.base.commit,
      maxBytes: maxCloudObjectResponseBytes,
    );
    if (existing != null) {
      if (sha256.convert(existing.bytes).toString() == expectedHash) {
        return CloudCommitResult(revision: existing.revision);
      }
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '远端已存在同名但内容不同的不可变数据。',
      );
    }
    final blobSha = await _api.createBlob(bytes, action: '暂存不可变数据');
    if (!GitHubBackendSupport.matchesGitBlobSha(bytes, blobSha)) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub 返回的 blob SHA 与上传内容不匹配。',
      );
    }
    session.entries[path] = blobSha;
    return CloudCommitResult(revision: blobSha);
  }

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    _checkProtocolSize(bytes, maxCloudHeadResponseBytes);
    final session = await _stagingSession();
    final current = await _api.readPath(
      '$_root/HEAD.json',
      ref: session.base.commit,
      maxBytes: maxCloudHeadResponseBytes,
    );
    final expected = _HeadRevision.parse(expectedRevision);
    if ((expected == null && current != null) ||
        (expected != null && current?.revision != expected.file)) {
      _staging = null;
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '远端 HEAD 或分支已被其他提交更新，请重新读取后重试。',
      );
    }
    try {
      final headBlob = await _api.createBlob(bytes, action: '暂存 HEAD');
      session.entries['$_root/HEAD.json'] = headBlob;
      final commitSha = await _api.commitTree(
        base: session.base,
        entries: _blobEntries(session.entries),
        message: 'cloud-sync: commit snapshot',
      );
      return CloudCommitResult(revision: '$headBlob:$commitSha');
    } finally {
      _staging = null;
    }
  }

  Future<_StagingSession> _stagingSession() async {
    final existing = _staging;
    if (existing != null) return existing;
    return _staging = _StagingSession(await _api.readTreeBase());
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    if (limit <= 0) return const [];
    final response = await _api.request(
      'GET',
      _api.contents('$_root/snapshots'),
      action: '读取快照历史',
      allowNotFound: true,
    );
    if (response == null) return const [];
    final decoded = _api.decodeJson(response);
    if (decoded is! List) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub 快照目录响应格式无效。',
      );
    }
    final ids =
        decoded
            .whereType<Map>()
            .map((item) => item['name'])
            .whereType<String>()
            .where((name) => name.endsWith('.json'))
            .map((name) => name.substring(0, name.length - 5))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return ids.take(limit).toList(growable: false);
  }

  @override
  Future<void> deleteNamespace() async {
    final base = await _api.readTreeBase();
    final existing = await _api.request(
      'GET',
      _api.contents(_root, ref: base.commit),
      action: '读取同步 namespace',
      allowNotFound: true,
    );
    if (existing == null) return;
    final retained = await _api.topLevelEntriesExcluding(base.tree, _root);
    await _api.commitTree(
      base: base,
      entries: retained,
      message: 'cloud-sync: delete namespace',
      includeBaseTree: false,
    );
  }

  static List<Map<String, Object?>> _blobEntries(
    Map<String, String> values,
  ) => [
    for (final entry in values.entries)
      {'path': entry.key, 'mode': '100644', 'type': 'blob', 'sha': entry.value},
  ];

  static void _checkProtocolSize(Uint8List bytes, int maxBytes) {
    GitHubBackendSupport.checkContentsSize(bytes, _blobLimit);
    if (bytes.length > maxBytes) {
      throw const CloudBackendException(
        CloudBackendErrorKind.quota,
        '上传内容超过云同步协议允许的大小上限。',
      );
    }
  }
}

class _StagingSession {
  _StagingSession(this.base);

  final GitHubTreeBase base;
  final Map<String, String> entries = {};
}

class _HeadRevision {
  const _HeadRevision(this.file);

  final String file;

  static _HeadRevision? parse(String? value) {
    if (value == null) return null;
    final separator = value.indexOf(':');
    if (separator <= 0 || separator == value.length - 1) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'HEAD revision 格式无效，请重新读取远端状态。',
      );
    }
    return _HeadRevision(value.substring(0, separator));
  }
}
