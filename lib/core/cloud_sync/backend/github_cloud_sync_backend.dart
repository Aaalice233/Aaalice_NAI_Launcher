import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../telemetry.dart';
import 'backend_http.dart';
import 'cloud_namespace.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';
import 'github_api_client.dart';
import 'github_backend_support.dart';

class GitHubCloudSyncBackend
    implements
        CloudSyncBackend,
        CloudObjectInventoryBackend,
        ConcurrentCloudObjectUploadBackend {
  GitHubCloudSyncBackend({
    required this.owner,
    required this.repository,
    required this.branch,
    required String token,
    this.namespace = defaultCloudSyncV3Namespace,
    Dio? dio,
    Uri? apiBaseUri,
    BackendHttpSleeper? sleeper,
  }) : _api = GitHubApiClient(
         owner: owner,
         repository: repository,
         branch: branch,
         token: token,
         dio: _withTelemetry(dio),
         apiBaseUri: apiBaseUri,
         sleeper: sleeper,
       ) {
    for (final value in [owner, repository, branch]) {
      if (value.trim().isEmpty) throw ArgumentError('GitHub 配置不能为空');
    }
    GitHubBackendSupport.validatePath(namespace);
  }

  static const int _blobLimit = 100 * 1024 * 1024;

  static Dio _withTelemetry(Dio? dio) {
    final client = dio ?? Dio();
    if (!client.interceptors.any(
      (interceptor) => interceptor is _GitHubTelemetryInterceptor,
    )) {
      client.interceptors.add(const _GitHubTelemetryInterceptor());
    }
    return client;
  }

  final String owner;
  final String repository;
  final String branch;
  final String namespace;
  final GitHubApiClient _api;
  _StagingSession? _view;
  _StagingSession? _staging;
  Future<_StagingSession>? _stagingLoad;
  final Map<String, String> _verifiedObjectRevisions = {};

  @override
  int get maxConcurrentObjectUploads => 4;

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
    final isPrivate = repository['private'] == true;
    return CloudBackendCapability(
      mode: CloudBackendMode.bidirectional,
      message: 'GitHub 连接正常，可以推送和拉取备份。',
      supportsHistory: true,
      supportsDelete: true,
      warnings: [if (!isPrivate) CloudBackendWarning.githubPublicRepository],
    );
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    _staging = null;
    final view = await _refreshView();
    final result = await _readFromView(
      view,
      '$_root/HEAD.json',
      maxBytes: maxCloudHeadResponseBytes,
    );
    if (result == null) return null;
    return CloudHeadRead(
      bytes: result.bytes,
      revision: '${result.revision}:${view.base.commit}',
    );
  }

  @override
  Future<CloudObjectRead?> readObject(String objectId) async {
    GitHubBackendSupport.validateId(objectId);
    final view = await _currentView();
    final read = await _readFromView(
      view,
      '$_root/objects/$objectId',
      maxBytes: maxCloudObjectResponseBytes,
    );
    if (read != null &&
        CloudObjectNaming.isContentAddressedId(objectId) &&
        _hashBytes(read.bytes) != objectId) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'GitHub 不可变对象内容与对象标识不一致。',
      );
    }
    if (read != null && CloudObjectNaming.isContentAddressedId(objectId)) {
      _verifiedObjectRevisions[objectId] = read.revision;
    }
    return read;
  }

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) async {
    GitHubBackendSupport.validateId(snapshotId);
    final view = await _currentView();
    return _readFromView(
      view,
      '$_root/snapshots/$snapshotId.json',
      maxBytes: maxCloudManifestResponseBytes,
    );
  }

  @override
  Future<Set<String>> findExistingObjects(
    Map<String, int> expectedObjects,
  ) async {
    for (final entry in expectedObjects.entries) {
      GitHubBackendSupport.validateId(entry.key);
      if (entry.value < 0 || !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key)) {
        throw ArgumentError('GitHub 对象清单包含无效的 SHA256 或大小');
      }
    }
    final session = await _stagingSession();
    final existing = <String>{};
    for (final entry in expectedObjects.entries) {
      final remote = session.inventory['$_root/objects/${entry.key}'];
      if (remote == null) continue;
      if (remote.size != entry.value) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'GitHub 已存在大小不一致的不可变对象。',
        );
      }
      if (_verifiedObjectRevisions[entry.key] != remote.sha) {
        final read = await _api.readBlob(
          remote.sha,
          maxBytes: maxCloudObjectResponseBytes,
        );
        if (_hashBytes(read.bytes) != entry.key) {
          throw const CloudBackendException(
            CloudBackendErrorKind.conflict,
            'GitHub 已存在内容不一致的不可变对象。',
          );
        }
        _verifiedObjectRevisions[entry.key] = remote.sha;
      }
      existing.add(entry.key);
    }
    return existing;
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) {
    GitHubBackendSupport.validateId(objectId);
    return _stageImmutable(
      '$_root/objects/$objectId',
      bytes,
      sha256,
      maxBytes: maxCloudObjectResponseBytes,
      payloadVerified: payloadVerified,
    );
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) {
    GitHubBackendSupport.validateId(snapshotId);
    return _stageImmutable(
      '$_root/snapshots/$snapshotId.json',
      bytes,
      sha256,
      maxBytes: maxCloudManifestResponseBytes,
      payloadVerified: payloadVerified,
    );
  }

  Future<CloudCommitResult> _stageImmutable(
    String path,
    Uint8List bytes,
    String expectedHash, {
    required int maxBytes,
    required bool payloadVerified,
  }) async {
    _checkProtocolSize(bytes, maxBytes);
    if (!payloadVerified && _hashBytes(bytes) != expectedHash) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '上传内容与声明的 SHA-256 不一致。',
      );
    }
    final session = await _stagingSession();
    final existingEntry = session.inventory[path];
    if (existingEntry != null) {
      final existing = await _api.readBlob(
        existingEntry.sha,
        maxBytes: maxBytes,
      );
      if (_hashBytes(existing.bytes) == expectedHash) {
        if (path.startsWith('$_root/objects/')) {
          _verifiedObjectRevisions[expectedHash] = existing.revision;
        }
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
    if (path.startsWith('$_root/objects/')) {
      _verifiedObjectRevisions[expectedHash] = blobSha;
    }
    return CloudCommitResult(revision: blobSha);
  }

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    _checkProtocolSize(bytes, maxCloudHeadResponseBytes);
    final session = await _stagingSession();
    final current = await _readFromView(
      session,
      '$_root/HEAD.json',
      maxBytes: maxCloudHeadResponseBytes,
    );
    final expected = _HeadRevision.parse(expectedRevision);
    if ((expected == null && current != null) ||
        (expected != null &&
            (current?.revision != expected.file ||
                session.base.commit != expected.commit))) {
      _staging = null;
      _view = null;
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
      _view = null;
    }
  }

  Future<_StagingSession> _stagingSession() async {
    final existing = _staging;
    if (existing != null) return existing;
    final pending = _stagingLoad;
    if (pending != null) return pending;
    late final Future<_StagingSession> loading;
    loading = () async {
      final view = await _currentView();
      return _staging ??= _StagingSession(view.base, view.inventory);
    }();
    _stagingLoad = loading;
    try {
      return await loading;
    } finally {
      if (identical(_stagingLoad, loading)) _stagingLoad = null;
    }
  }

  Future<_StagingSession> _currentView() async {
    final existing = _view;
    if (existing != null) return existing;
    return _refreshView();
  }

  Future<_StagingSession> _refreshView() async {
    final base = await _api.readTreeBase();
    final inventory = await _api.readRecursiveTree(base.tree);
    return _view = _StagingSession(base, inventory);
  }

  Future<CloudObjectRead?> _readFromView(
    _StagingSession view,
    String path, {
    required int maxBytes,
  }) {
    final entry = view.inventory[path];
    if (entry == null) return Future.value();
    if (entry.size > maxBytes) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub blob 超过允许的下载大小。',
      );
    }
    return _api.readBlob(entry.sha, maxBytes: maxBytes);
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    if (limit <= 0) return const [];
    final view = await _refreshView();
    final prefix = '$_root/snapshots/';
    final ids =
        view.inventory.keys
            .where((path) => path.startsWith(prefix) && path.endsWith('.json'))
            .map((path) => path.substring(prefix.length, path.length - 5))
            .where((id) => id.isNotEmpty && !id.contains('/'))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return ids.take(limit).toList(growable: false);
  }

  @override
  Future<void> deleteNamespace() async {
    final view = await _refreshView();
    if (!view.inventory.keys.any(
      (path) => path == _root || path.startsWith('$_root/'),
    )) {
      _verifiedObjectRevisions.clear();
      return;
    }
    await _api.commitTree(
      base: view.base,
      entries: [
        {'path': _root, 'mode': '040000', 'type': 'tree', 'sha': null},
      ],
      message: 'cloud-sync: delete namespace',
    );
    _verifiedObjectRevisions.clear();
  }

  static List<Map<String, Object?>> _blobEntries(
    Map<String, String> values,
  ) => [
    for (final entry in values.entries)
      {'path': entry.key, 'mode': '100644', 'type': 'blob', 'sha': entry.value},
  ];

  static String _hashBytes(List<int> bytes) {
    CloudSyncTelemetry.recordHashPass();
    return sha256.convert(bytes).toString();
  }

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

class _GitHubTelemetryInterceptor extends Interceptor {
  const _GitHubTelemetryInterceptor();

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    if (body is ResponseBody) {
      body.stream = _recordingStream(
        body.stream,
        bytesWritten: _requestBodyBytes(response.requestOptions.data),
      );
    } else {
      CloudSyncTelemetry.recordRequest(
        bytesRead: _responseBodyBytes(body),
        bytesWritten: _requestBodyBytes(response.requestOptions.data),
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    CloudSyncTelemetry.recordRequest(
      bytesRead: _responseBodyBytes(error.response?.data),
      bytesWritten: _requestBodyBytes(error.requestOptions.data),
    );
    handler.next(error);
  }

  static Stream<Uint8List> _recordingStream(
    Stream<Uint8List> source, {
    required int bytesWritten,
  }) {
    late StreamController<Uint8List> controller;
    StreamSubscription<Uint8List>? subscription;
    var bytesRead = 0;
    var recorded = false;

    void record() {
      if (recorded) return;
      recorded = true;
      CloudSyncTelemetry.recordRequest(
        bytesRead: bytesRead,
        bytesWritten: bytesWritten,
      );
    }

    controller = StreamController<Uint8List>(
      sync: true,
      onListen: () {
        subscription = source.listen(
          (chunk) {
            bytesRead += chunk.length;
            controller.add(chunk);
          },
          onError: (Object error, StackTrace stackTrace) {
            record();
            controller.addError(error, stackTrace);
          },
          onDone: () {
            record();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        await subscription?.cancel();
        record();
      },
    );
    return controller.stream;
  }

  static int _requestBodyBytes(Object? data) => switch (data) {
    null => 0,
    final Uint8List bytes => bytes.length,
    final List<int> bytes => bytes.length,
    final String text => utf8.encode(text).length,
    _ => 0,
  };

  static int _responseBodyBytes(Object? data) => switch (data) {
    null => 0,
    ResponseBody _ => 0,
    final Uint8List bytes => bytes.length,
    final List<int> bytes => bytes.length,
    final String text => utf8.encode(text).length,
    _ => 0,
  };
}

class _StagingSession {
  _StagingSession(this.base, this.inventory);

  final GitHubTreeBase base;
  final Map<String, GitHubTreeEntry> inventory;
  final Map<String, String> entries = {};
}

class _HeadRevision {
  const _HeadRevision(this.file, this.commit);

  final String file;
  final String commit;

  static _HeadRevision? parse(String? value) {
    if (value == null) return null;
    final separator = value.indexOf(':');
    if (separator <= 0 || separator == value.length - 1) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'HEAD revision 格式无效，请重新读取远端状态。',
      );
    }
    return _HeadRevision(
      value.substring(0, separator),
      value.substring(separator + 1),
    );
  }
}
