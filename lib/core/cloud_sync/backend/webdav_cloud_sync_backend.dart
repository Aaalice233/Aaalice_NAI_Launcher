import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../telemetry.dart';
import 'backend_http.dart';
import 'cloud_namespace.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';
import 'webdav_backend_config.dart';
import 'webdav_capability_probe.dart';
import 'webdav_collection_ensurer.dart';
import 'webdav_etag_reader.dart';
import 'webdav_namespace_cleaner.dart';
import 'webdav_operation_inventory.dart';

class WebDavCloudSyncBackend
    implements
        CloudSyncBackend,
        ReadOnlyCloudSyncBackendValidation,
        ConcurrentCloudObjectUploadBackend,
        CloudObjectInventoryBackend {
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
    this.namespace = defaultCloudSyncV3Namespace,
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
       _http = BackendHttp(dio: _withTelemetry(dio)) {
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
  final Map<String, String> _verifiedObjectRevisions = {};

  @override
  int get maxConcurrentObjectUploads =>
      _verifiedMode == CloudBackendMode.manualBackupOnly ? 1 : 4;
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
  Future<void> validateConnectionReadOnly() async {
    final response = await _http.request(
      'PROPFIND',
      _baseUri,
      headers: {
        ..._headers,
        'Depth': '0',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      data: utf8.encode(
        '<?xml version="1.0"?><d:propfind xmlns:d="DAV:">'
        '<d:prop><d:resourcetype/></d:prop></d:propfind>',
      ),
      maxResponseBytes: maxCloudListingResponseBytes,
    );
    _expect(response, const {207}, action: '验证 WebDAV 连接');
    // Read-only validation cannot prove CAS semantics. Keep all later writes
    // on the conservative manual-backup path until an explicit probe runs.
    _verifiedMode = CloudBackendMode.manualBackupOnly;
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    final value = await _get(_head, maxBytes: maxCloudHeadResponseBytes);
    return value == null
        ? null
        : CloudHeadRead(bytes: value.bytes, revision: value.revision);
  }

  @override
  Future<CloudObjectRead?> readObject(String objectId) async {
    final read = await _get(
      _objectUri(objectId),
      maxBytes: maxCloudObjectResponseBytes,
    );
    if (read != null &&
        CloudObjectNaming.isContentAddressedId(objectId) &&
        _sha256(read.bytes) != objectId) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'WebDAV 不可变对象内容与对象标识不一致。',
      );
    }
    if (read != null && CloudObjectNaming.isContentAddressedId(objectId)) {
      _verifiedObjectRevisions[objectId] = read.revision;
    }
    return read;
  }

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) =>
      _get(_snapshotUri(snapshotId), maxBytes: maxCloudManifestResponseBytes);

  @override
  Future<Set<String>> findExistingObjects(
    Map<String, int> expectedObjects,
  ) async {
    for (final entry in expectedObjects.entries) {
      CloudObjectNaming.validateId(entry.key);
      if (entry.value < 0 || entry.value > maxCloudObjectResponseBytes) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          '对象清单包含非法大小。',
        );
      }
    }
    // Manual-backup providers cannot prove immutable-create CAS. Keep every
    // object on the conservative GET -> PUT -> GET path instead of treating a
    // listing entry as proof that an upload can be skipped.
    if (_verifiedMode == CloudBackendMode.manualBackupOnly ||
        expectedObjects.isEmpty) {
      return const <String>{};
    }
    await _ensureCollection(_objects);
    return WebDavOperationInventory(
      http: _http,
      headers: _headers,
      objects: _objects,
      verifiedObjectRevisions: _verifiedObjectRevisions,
    ).findExisting(expectedObjects);
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) async {
    _checkUploadSize(bytes, maxCloudObjectResponseBytes);
    if (!payloadVerified) _checkDeclaredHash(bytes, sha256);
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
    bool payloadVerified = false,
  }) async {
    _checkUploadSize(bytes, maxCloudManifestResponseBytes);
    if (!payloadVerified) _checkDeclaredHash(bytes, sha256);
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
        // A lost response is ambiguous on weak WebDAV providers. Replaying the
        // PUT could overwrite a concurrent writer after the first attempt was
        // already committed, so recovery must start with a fresh GET instead.
        retryable: false,
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
    final revision =
        _strongEtag(response.headers.value('etag')) ??
        _strongEtag(await _readEtag(uri));
    if (revision == null) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '对象已上传，但服务器未提供强 ETag，无法验证提交。',
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
    final revision =
        _strongEtag(response.headers.value('etag')) ??
        _strongEtag(await _readEtag(uri));
    if (revision == null) {
      throw CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '$label 已写入，但服务器未提供强 ETag。',
      );
    }
    return CloudCommitResult(revision: revision);
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    if (limit <= 0) return const [];
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
        '<d:prop><d:resourcetype/></d:prop></d:propfind>',
      ),
      maxResponseBytes: maxCloudListingResponseBytes,
    );
    if (response.statusCode == 404) return const [];
    _expect(response, const {207}, action: '读取快照历史');
    try {
      final document = XmlDocument.parse(BackendHttp.rawTextOf(response));
      final ids = <String>[];
      for (final item in document.findAllElements(
        'response',
        namespace: 'DAV:',
      )) {
        final href = item
            .getElement('href', namespace: 'DAV:')
            ?.innerText
            .trim();
        if (href == null || href.isEmpty) continue;
        XmlElement? properties;
        for (final propstat in item.findElements(
          'propstat',
          namespace: 'DAV:',
        )) {
          final status = propstat
              .getElement('status', namespace: 'DAV:')
              ?.innerText;
          if (status != null && status.contains(' 200 ')) {
            properties = propstat.getElement('prop', namespace: 'DAV:');
            break;
          }
        }
        if (properties == null ||
            properties
                    .getElement('resourcetype', namespace: 'DAV:')
                    ?.findElements('collection', namespace: 'DAV:')
                    .isNotEmpty ==
                true) {
          continue;
        }
        final path = Uri.parse(href).path;
        final name = Uri.decodeComponent(
          path.endsWith('/')
              ? path.substring(0, path.length - 1).split('/').last
              : path.split('/').last,
        );
        final snapshotId = CloudObjectNaming.snapshotIdFromManifestName(name);
        if (snapshotId != null) ids.add(snapshotId);
      }
      ids.sort((a, b) => b.compareTo(a));
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
    _verifiedObjectRevisions.clear();
  }

  Future<CloudObjectRead?> _get(Uri uri, {required int maxBytes}) async {
    final response = await _http.request(
      'GET',
      uri,
      headers: _headers,
      maxResponseBytes: maxBytes,
    );
    // Some WebDAV services return 409 instead of 404 when the requested
    // resource's parent collection has not been created yet. A conditional
    // conflict is impossible here because this is an unconditional GET.
    if (response.statusCode == 404 || response.statusCode == 409) return null;
    _expect(response, const {200}, action: '下载对象');
    final rawRevision = response.headers.value('etag');
    final revision = _verifiedMode == CloudBackendMode.manualBackupOnly
        ? rawRevision?.trim()
        : _strongEtag(rawRevision);
    if ((revision == null || revision.isEmpty) &&
        _verifiedMode != CloudBackendMode.manualBackupOnly) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '下载响应缺少强 ETag。',
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
      429 => CloudBackendErrorKind.rateLimited,
      _ => CloudBackendErrorKind.invalidResponse,
    };
    throw CloudBackendException(
      kind,
      '$action失败（HTTP $status）。',
      statusCode: status,
    );
  }

  static final Expando<bool> _telemetryInstalled = Expando<bool>();

  static Dio _withTelemetry(Dio? dio) {
    final client = dio ?? Dio();
    if (_telemetryInstalled[client] != true) {
      client.interceptors.add(_WebDavTelemetryInterceptor());
      _telemetryInstalled[client] = true;
    }
    return client;
  }

  static Uri _directoryUri(Uri uri) => uri.replace(
    path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    query: null,
    fragment: null,
  );

  static void _checkDeclaredHash(Uint8List bytes, String expectedHash) {
    if (_sha256(bytes) != expectedHash) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '上传内容与声明的 SHA-256 不一致。',
      );
    }
  }

  static String _sha256(Uint8List bytes) {
    CloudSyncTelemetry.recordHashPass();
    return sha256.convert(bytes).toString();
  }

  static String? _strongEtag(String? value) {
    final normalized = value?.trim();
    return normalized != null &&
            !normalized.startsWith('W/') &&
            RegExp(r'^"[^"\r\n]*"$').hasMatch(normalized)
        ? normalized
        : null;
  }

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

final class _WebDavTelemetryInterceptor extends Interceptor {
  static const _requestBytesKey = 'webdavTelemetryRequestBytes';
  static const _recordedKey = 'webdavTelemetryRecorded';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestBytesKey] = _byteLength(options.data);
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final body = response.data;
    if (body is ResponseBody) {
      body.stream = _recordResponse(body.stream, response.requestOptions);
    } else {
      _record(response.requestOptions, bytesRead: _byteLength(body));
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    _record(error.requestOptions);
    super.onError(error, handler);
  }

  Stream<Uint8List> _recordResponse(
    Stream<Uint8List> stream,
    RequestOptions options,
  ) async* {
    var bytesRead = 0;
    try {
      await for (final chunk in stream) {
        bytesRead += chunk.length;
        yield chunk;
      }
    } finally {
      _record(options, bytesRead: bytesRead);
    }
  }

  static void _record(RequestOptions options, {int bytesRead = 0}) {
    if (options.extra[_recordedKey] == true) return;
    options.extra[_recordedKey] = true;
    CloudSyncTelemetry.recordRequest(
      bytesRead: bytesRead,
      bytesWritten: options.extra[_requestBytesKey] as int? ?? 0,
    );
  }

  static int _byteLength(Object? value) {
    if (value is Uint8List) return value.length;
    if (value is List<int>) return value.length;
    if (value is String) return utf8.encode(value).length;
    return 0;
  }
}
