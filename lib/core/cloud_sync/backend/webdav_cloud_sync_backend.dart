import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import 'backend_http.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';
import 'webdav_backend_config.dart';
import 'webdav_capability_probe.dart';
import 'webdav_collection_ensurer.dart';
import 'webdav_etag_reader.dart';
import 'webdav_namespace_cleaner.dart';
import 'webdav_object_maintenance.dart';

class WebDavCloudSyncBackend
    implements
        CloudSyncBackend,
        CloudSyncBackendMaintenance,
        ConcurrentCloudObjectUploadBackend {
  factory WebDavCloudSyncBackend.fromConfig({
    required WebDavBackendConfig config,
    required String username,
    required String password,
    Dio? dio,
  }) => WebDavCloudSyncBackend(
    baseUri: config.baseUri,
    username: username,
    password: password,
    dio: dio,
    namespace: config.namespace,
    allowInsecureHttp: config.allowInsecureHttp,
  );

  WebDavCloudSyncBackend({
    required Uri baseUri,
    required String username,
    required String password,
    Dio? dio,
    this.namespace = 'aaalice-sync',
    bool allowInsecureHttp = false,
  }) : _baseUri = _directoryUri(
         WebDavBackendConfig(
           baseUri: baseUri,
           namespace: namespace,
           allowInsecureHttp: allowInsecureHttp,
         ).baseUri,
       ),
       _authorization =
           'Basic ${base64Encode(utf8.encode('$username:$password'))}',
       _http = BackendHttp(dio: dio) {
    _collections = WebDavCollectionEnsurer(
      http: _http,
      headers: _headers,
      baseUri: _baseUri,
    );
  }

  final Uri _baseUri;
  final String _authorization;
  final BackendHttp _http;
  late final WebDavCollectionEnsurer _collections;
  final String namespace;
  CloudBackendMode? _verifiedMode;

  @override
  int get maxConcurrentObjectUploads => 4;
  Map<String, String> get _headers => {
    'Authorization': _authorization,
    'Accept-Encoding': 'identity',
  };

  Uri get _root => _baseUri.resolve('$namespace/');
  Uri get _objects => _root.resolve('objects/');
  Uri get _snapshots => _root.resolve('snapshots/');
  Uri get _head => _root.resolve('HEAD.json');

  @override
  Future<CloudBackendCapability> testCapability() async {
    final capability = await WebDavCapabilityProbe(
      http: _http,
      headers: _headers,
      baseUri: _baseUri,
      root: _root,
      objects: _objects,
      snapshots: _snapshots,
    ).run();
    _verifiedMode = capability.mode;
    return capability;
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    final value = await _get(_head, maxBytes: maxCloudHeadResponseBytes);
    return value == null
        ? null
        : CloudHeadRead(bytes: value.bytes, revision: value.revision);
  }

  @override
  Future<CloudObjectRead?> readObject(String objectId) =>
      _get(_objectUri(objectId), maxBytes: maxCloudObjectResponseBytes);

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) =>
      _get(_snapshotUri(snapshotId), maxBytes: maxCloudManifestResponseBytes);

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
  }) async {
    _checkUploadSize(bytes, maxCloudObjectResponseBytes);
    await _ensureCollection(_objects);
    return _putImmutable(
      _objectUri(objectId),
      bytes,
      sha256: sha256,
      maxBytes: maxCloudObjectResponseBytes,
    );
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
  }) async {
    _checkUploadSize(bytes, maxCloudManifestResponseBytes);
    await _ensureCollection(_snapshots);
    return _putImmutable(
      _snapshotUri(snapshotId),
      bytes,
      sha256: sha256,
      maxBytes: maxCloudManifestResponseBytes,
    );
  }

  Future<CloudCommitResult> _putImmutable(
    Uri uri,
    Uint8List bytes, {
    required String sha256,
    required int maxBytes,
  }) async {
    if (_verifiedMode == CloudBackendMode.manualBackupOnly) {
      final existing = await _get(uri, maxBytes: maxBytes);
      if (existing != null) {
        if (_sha256(existing.bytes) == sha256) {
          return CloudCommitResult(revision: existing.revision);
        }
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          '手动备份目标已存在同名但内容不同的数据。',
        );
      }
      final response = await _http.request(
        'PUT',
        uri,
        headers: _headers,
        data: bytes,
        retryable: true,
      );
      _expect(response, const {200, 201, 204}, action: '上传手动备份对象');
      final stored = await _get(uri, maxBytes: maxBytes);
      if (stored == null || _sha256(stored.bytes) != sha256) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          '手动备份对象写入后无法验证。',
        );
      }
      return CloudCommitResult(revision: stored.revision);
    }
    final response = await _http.request(
      'PUT',
      uri,
      headers: {..._headers, 'If-None-Match': '*'},
      data: bytes,
      retryable: true,
    );
    if (response.statusCode == 412) {
      final existing = await _get(uri, maxBytes: maxBytes);
      if (existing != null && _sha256(existing.bytes) == sha256) {
        return CloudCommitResult(revision: existing.revision);
      }
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '远端已存在同名但内容不同的不可变数据。',
        statusCode: 412,
      );
    }
    _expect(response, const {200, 201, 204}, action: '上传对象');
    final revision = response.headers.value('etag') ?? await _readEtag(uri);
    if (revision == null) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '对象已上传，但服务器未提供 ETag，无法验证提交。',
      );
    }
    return CloudCommitResult(revision: revision);
  }

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    return _commitMutable(
      _head,
      bytes,
      expectedRevision: expectedRevision,
      label: 'HEAD',
      maxBytes: maxCloudHeadResponseBytes,
    );
  }

  Future<CloudCommitResult> _commitMutable(
    Uri uri,
    Uint8List bytes, {
    required String? expectedRevision,
    required String label,
    required int maxBytes,
  }) async {
    _checkUploadSize(bytes, maxBytes);
    await _ensureCollection(_root);
    if (_verifiedMode == CloudBackendMode.manualBackupOnly) {
      final response = await _http.request(
        'PUT',
        uri,
        headers: _headers,
        data: bytes,
      );
      _expect(response, const {200, 201, 204}, action: '提交手动备份 $label');
      final stored = await _get(uri, maxBytes: maxBytes);
      if (stored == null || !_sameBytes(stored.bytes, bytes)) {
        throw CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          '手动备份 $label 写入后无法验证。',
        );
      }
      return CloudCommitResult(revision: stored.revision);
    }
    final response = await _http.request(
      'PUT',
      uri,
      headers: {
        ..._headers,
        expectedRevision == null ? 'If-None-Match' : 'If-Match':
            expectedRevision ?? '*',
      },
      data: bytes,
    );
    if (response.statusCode == 412) {
      throw CloudBackendException(
        CloudBackendErrorKind.conflict,
        '远端 $label 已被其他设备更新，请重新读取后重试。',
        statusCode: 412,
      );
    }
    _expect(response, const {200, 201, 204}, action: '提交 $label');
    final revision = response.headers.value('etag') ?? await _readEtag(uri);
    if (revision == null) {
      throw CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '$label 已写入，但服务器未提供 ETag。',
      );
    }
    return CloudCommitResult(revision: revision);
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    final response = await _http.request(
      'PROPFIND',
      _snapshots,
      headers: {
        ..._headers,
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
        '<d:allprop/></d:propfind>',
      ),
      maxResponseBytes: maxCloudListingResponseBytes,
    );
    if (response.statusCode == 404) return const [];
    _expect(response, const {207}, action: '读取快照历史');
    try {
      final document = XmlDocument.parse(BackendHttp.rawTextOf(response));
      final ids =
          document
              .findAllElements('href', namespace: 'DAV:')
              .map(
                (node) => Uri.decodeComponent(node.innerText).split('/').last,
              )
              .map(CloudObjectNaming.snapshotIdFromManifestName)
              .whereType<String>()
              .toList()
            ..sort((a, b) => b.compareTo(a));
      return ids.take(limit).toList(growable: false);
    } catch (_) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'WebDAV 返回了无法解析的 PROPFIND XML。',
      );
    }
  }

  @override
  Future<void> deleteNamespace() async {
    await WebDavNamespaceCleaner(
      http: _http,
      headers: _headers,
      root: _root,
      objects: _objects,
      snapshots: _snapshots,
    ).clean();
  }

  @override
  Future<CloudMaintenanceResult> cleanUnreferencedObjects() =>
      WebDavObjectMaintenance(
        http: _http,
        headers: _headers,
        root: _root,
        objects: _objects,
        snapshots: _snapshots,
        head: _head,
      ).clean();

  Future<CloudObjectRead?> _get(Uri uri, {required int maxBytes}) async {
    final response = await _http.request(
      'GET',
      uri,
      headers: _headers,
      maxResponseBytes: maxBytes,
    );
    if (response.statusCode == 404) return null;
    _expect(response, const {200}, action: '下载对象');
    final revision = response.headers.value('etag');
    if ((revision == null || revision.isEmpty) &&
        _verifiedMode != CloudBackendMode.manualBackupOnly) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '下载响应缺少 ETag。',
      );
    }
    return CloudObjectRead(
      bytes: BackendHttp.bytesOf(response),
      revision: revision == null || revision.isEmpty
          ? _sha256(BackendHttp.bytesOf(response))
          : revision,
    );
  }

  Future<void> _ensureCollection(Uri uri) async {
    await _collections.ensure(uri);
  }

  Future<String?> _readEtag(Uri uri) =>
      WebDavEtagReader(http: _http, headers: _headers).read(uri);

  Uri _objectUri(String id) {
    CloudObjectNaming.validateId(id);
    return _objects.resolve(Uri.encodeComponent(id));
  }

  Uri _snapshotUri(String id) {
    final name = CloudObjectNaming.manifestFileName(id);
    return _snapshots.resolve(Uri.encodeComponent(name));
  }

  void _expect(
    Response<Uint8List> response,
    Set<int> accepted, {
    required String action,
  }) {
    final status = response.statusCode ?? 0;
    if (accepted.contains(status)) return;
    final kind = switch (status) {
      401 => CloudBackendErrorKind.authentication,
      403 => CloudBackendErrorKind.authorization,
      404 => CloudBackendErrorKind.notFound,
      409 || 412 => CloudBackendErrorKind.conflict,
      413 || 507 => CloudBackendErrorKind.quota,
      _ => CloudBackendErrorKind.invalidResponse,
    };
    throw CloudBackendException(
      kind,
      '$action失败（HTTP $status）。',
      statusCode: status,
    );
  }

  static Uri _directoryUri(Uri uri) => uri.replace(
    path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    query: null,
    fragment: null,
  );

  static String _sha256(Uint8List bytes) => sha256.convert(bytes).toString();

  static bool _sameBytes(List<int> first, List<int> second) =>
      first.length == second.length &&
      _sha256(Uint8List.fromList(first)) == _sha256(Uint8List.fromList(second));

  static void _checkUploadSize(Uint8List bytes, int maxBytes) {
    if (bytes.length > maxBytes) {
      throw const CloudBackendException(
        CloudBackendErrorKind.quota,
        '上传内容超过云同步允许的大小上限。',
      );
    }
  }
}
