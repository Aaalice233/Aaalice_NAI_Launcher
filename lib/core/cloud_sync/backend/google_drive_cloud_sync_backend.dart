import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'backend_http.dart';
import 'cloud_namespace.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';

/// Stores cloud-sync records in Google Drive's hidden `appDataFolder` space.
///
/// Drive does not expose conditional file updates, so HEAD and KEY revisions
/// are only checked immediately before a write. This backend must therefore
/// remain manual-backup-only even when those checks succeed.
class GoogleDriveCloudSyncBackend
    implements CloudSyncBackend, CloudKeyEnvelopeBackend {
  GoogleDriveCloudSyncBackend({
    required Future<String> Function() accessTokenProvider,
    required this.namespace,
    Dio? dio,
    Uri? apiBaseUri,
  }) : _accessTokenProvider = accessTokenProvider,
       _http = BackendHttp(dio: dio),
       _apiBase = _normalizeBase(
         apiBaseUri ?? Uri.parse('https://www.googleapis.com/'),
       ) {
    CloudNamespace.validate(namespace);
  }

  static const _protocolProperty = 'aaalice-cloud-sync-v1';
  static const _fileFields =
      'id,name,size,md5Checksum,modifiedTime,version,appProperties';
  static const _listFields = 'nextPageToken,files($_fileFields)';

  final Future<String> Function() _accessTokenProvider;
  final BackendHttp _http;
  final Uri _apiBase;
  final String namespace;

  String get _namespaceHash =>
      sha256.convert(utf8.encode(namespace)).toString();

  @override
  Future<CloudBackendCapability> testCapability() async {
    await _list(recordType: 'head', pageSize: 1);
    return const CloudBackendCapability(
      mode: CloudBackendMode.manualBackupOnly,
      message: 'Google Drive appDataFolder 连接正常，仅支持显式手动推送与拉取。',
      supportsHistory: true,
      supportsDelete: true,
      warnings: [
        'Google Drive API 不提供文件内容的强 compare-and-swap；HEAD/KEY 只能检测已读到的旧 revision，无法安全启用双向同步。',
      ],
    );
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    final read = await _readMutable('head', _fileName('head'));
    return read == null
        ? null
        : CloudHeadRead(bytes: read.bytes, revision: read.revision);
  }

  @override
  Future<CloudObjectRead?> readKeyEnvelope() =>
      _readMutable('key', _fileName('key'));

  @override
  Future<CloudObjectRead?> readObject(String objectId) {
    CloudObjectNaming.validateId(objectId);
    return _readImmutable('object', _fileName('object', objectId));
  }

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) {
    CloudObjectNaming.validateId(snapshotId);
    return _readImmutable('manifest', _fileName('manifest', snapshotId));
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
  }) {
    CloudObjectNaming.validateId(objectId);
    return _putImmutable(
      'object',
      _fileName('object', objectId),
      bytes,
      sha256,
      maxCloudObjectResponseBytes,
    );
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
  }) {
    CloudObjectNaming.validateId(snapshotId);
    return _putImmutable(
      'manifest',
      _fileName('manifest', snapshotId),
      bytes,
      sha256,
      maxCloudManifestResponseBytes,
    );
  }

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) => _commitMutable(
    'head',
    _fileName('head'),
    bytes,
    expectedRevision,
    maxCloudHeadResponseBytes,
  );

  @override
  Future<CloudCommitResult> commitKeyEnvelope(
    Uint8List bytes, {
    required String? expectedRevision,
  }) => _commitMutable(
    'key',
    _fileName('key'),
    bytes,
    expectedRevision,
    maxCloudKeyResponseBytes,
  );

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    if (limit <= 0) return const [];
    final files = await _list(recordType: 'manifest');
    final grouped = <String, List<_DriveFile>>{};
    for (final file in files) {
      final id = _snapshotIdFromName(file.name);
      if (id != null) (grouped[id] ??= []).add(file);
    }
    for (final entry in grouped.entries) {
      if (entry.value.length > 1) {
        await _readImmutableCandidates(
          entry.value,
          maxCloudManifestResponseBytes,
        );
      }
    }
    final ids = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return ids.take(limit).toList(growable: false);
  }

  @override
  Future<void> deleteNamespace() async {
    final files = await _list();
    for (final file in files) {
      final response = await _request(
        'DELETE',
        _uri('drive/v3/files/${Uri.encodeComponent(file.id)}'),
        action: '删除 namespace 文件',
        maxResponseBytes: maxCloudJsonApiResponseBytes,
        retryable: true,
      );
      if (response.statusCode != 204 && response.statusCode != 404) {
        _throwResponse(response, '删除 namespace 文件');
      }
    }
  }

  Future<CloudObjectRead?> _readMutable(String type, String name) async {
    final files = await _list(recordType: type, name: name);
    if (files.isEmpty) return null;
    if (files.length != 1) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 中存在多个同名同步文件，无法确定当前版本。',
      );
    }
    return _download(files.single, _limitFor(type));
  }

  Future<CloudObjectRead?> _readImmutable(String type, String name) async {
    final files = await _list(recordType: type, name: name);
    if (files.isEmpty) return null;
    return _readImmutableCandidates(files, _limitFor(type));
  }

  Future<CloudObjectRead> _readImmutableCandidates(
    List<_DriveFile> files,
    int maxBytes,
  ) async {
    final reads = <CloudObjectRead>[];
    String? contentHash;
    for (final file in files) {
      final read = await _download(file, maxBytes);
      final hash = sha256.convert(read.bytes).toString();
      if (contentHash != null && contentHash != hash) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Google Drive 中存在同名但内容不同的不可变数据。',
        );
      }
      contentHash = hash;
      reads.add(read);
    }
    return reads.first;
  }

  Future<CloudCommitResult> _putImmutable(
    String type,
    String name,
    Uint8List bytes,
    String expectedHash,
    int maxBytes,
  ) async {
    _checkUpload(bytes, maxBytes);
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != expectedHash) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '上传内容与声明的 SHA-256 不一致。',
      );
    }
    final existing = await _list(recordType: type, name: name);
    if (existing.isNotEmpty) {
      final read = await _readImmutableCandidates(existing, maxBytes);
      if (sha256.convert(read.bytes).toString() != expectedHash) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Google Drive 中已存在同名但内容不同的不可变数据。',
        );
      }
      return CloudCommitResult(revision: read.revision);
    }
    await _create(type, name, bytes);
    final created = await _list(recordType: type, name: name);
    if (created.isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'Google Drive 上传后未返回可读取的文件。',
      );
    }
    final verified = await _readImmutableCandidates(created, maxBytes);
    if (sha256.convert(verified.bytes).toString() != expectedHash) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 上传后的不可变数据校验失败。',
      );
    }
    return CloudCommitResult(revision: verified.revision);
  }

  Future<CloudCommitResult> _commitMutable(
    String type,
    String name,
    Uint8List bytes,
    String? expectedRevision,
    int maxBytes,
  ) async {
    _checkUpload(bytes, maxBytes);
    final files = await _list(recordType: type, name: name);
    if (files.length > 1) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 中存在多个同名同步文件，禁止覆盖。',
      );
    }
    final current = files.firstOrNull;
    if ((expectedRevision == null && current != null) ||
        (expectedRevision != null &&
            (current == null || current.revision != expectedRevision))) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 中的远端版本已变化，请重新读取后重试。',
      );
    }
    if (current == null) {
      await _create(type, name, bytes);
    } else {
      await _update(current.id, bytes);
    }
    final after = await _list(recordType: type, name: name);
    if (after.length != 1) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 写入后出现同名文件，无法确认更新结果。',
      );
    }
    final read = await _download(after.single, maxBytes);
    if (!_sameBytes(read.bytes, bytes)) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 写入后内容已被其他客户端改变。',
      );
    }
    return CloudCommitResult(revision: read.revision);
  }

  Future<CloudObjectRead> _download(_DriveFile file, int maxBytes) async {
    final response = await _request(
      'GET',
      _uri('drive/v3/files/${Uri.encodeComponent(file.id)}', {'alt': 'media'}),
      action: '下载同步文件',
      maxResponseBytes: maxBytes,
    );
    if (response.statusCode != 200) _throwResponse(response, '下载同步文件');
    return CloudObjectRead(
      bytes: BackendHttp.bytesOf(response),
      revision: file.revision,
    );
  }

  Future<void> _create(String type, String name, Uint8List bytes) async {
    final boundary =
        'aaalice-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final metadata = jsonEncode({
      'name': name,
      'parents': ['appDataFolder'],
      'appProperties': _properties(type),
    });
    final body = BytesBuilder(copy: false)
      ..add(utf8.encode('--$boundary\r\n'))
      ..add(
        utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'),
      )
      ..add(utf8.encode(metadata))
      ..add(utf8.encode('\r\n--$boundary\r\n'))
      ..add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    // A lost create response is ambiguous and Drive has no idempotency key.
    // Let the caller retry from a fresh list instead of creating duplicates.
    final response = await _request(
      'POST',
      _uri('upload/drive/v3/files', {
        'uploadType': 'multipart',
        'fields': _fileFields,
      }),
      action: '上传同步文件',
      data: body.takeBytes(),
      extraHeaders: {'content-type': 'multipart/related; boundary=$boundary'},
      maxResponseBytes: maxCloudJsonApiResponseBytes,
      retryable: false,
    );
    if (response.statusCode != 200) _throwResponse(response, '上传同步文件');
  }

  Future<void> _update(String id, Uint8List bytes) async {
    // Retrying an ambiguous weak-CAS update could overwrite a concurrent
    // writer after the first request actually succeeded.
    final response = await _request(
      'PATCH',
      _uri('upload/drive/v3/files/${Uri.encodeComponent(id)}', {
        'uploadType': 'media',
        'fields': _fileFields,
      }),
      action: '更新同步文件',
      data: bytes,
      extraHeaders: {'content-type': 'application/octet-stream'},
      maxResponseBytes: maxCloudJsonApiResponseBytes,
      retryable: false,
    );
    if (response.statusCode != 200) _throwResponse(response, '更新同步文件');
  }

  Future<List<_DriveFile>> _list({
    String? recordType,
    String? name,
    int? pageSize,
  }) async {
    final result = <_DriveFile>[];
    String? pageToken;
    do {
      final clauses = <String>[
        "'appDataFolder' in parents",
        'trashed = false',
        "appProperties has { key='protocol' and value='$_protocolProperty' }",
        "appProperties has { key='namespace' and value='$_namespaceHash' }",
        if (recordType != null)
          "appProperties has { key='recordType' and value='${_escapeQuery(recordType)}' }",
        if (name != null) "name = '${_escapeQuery(name)}'",
      ];
      final response = await _request(
        'GET',
        _uri('drive/v3/files', {
          'spaces': 'appDataFolder',
          'q': clauses.join(' and '),
          'fields': _listFields,
          'pageSize': '${pageSize ?? 100}',
          if (pageToken != null) 'pageToken': pageToken,
        }),
        action: '列出同步文件',
        maxResponseBytes: maxCloudListingResponseBytes,
      );
      if (response.statusCode != 200) _throwResponse(response, '列出同步文件');
      final decoded = _decodeJson(response, '列出同步文件');
      if (decoded is! Map || decoded['files'] is! List) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'Google Drive 文件列表格式无效。',
        );
      }
      for (final value in decoded['files'] as List) {
        if (value is! Map) {
          throw const CloudBackendException(
            CloudBackendErrorKind.invalidResponse,
            'Google Drive 文件元数据格式无效。',
          );
        }
        result.add(_DriveFile.fromJson(value));
      }
      final next = decoded['nextPageToken'];
      if (next != null && (next is! String || next.isEmpty)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'Google Drive 分页标记格式无效。',
        );
      }
      pageToken = next as String?;
    } while (pageToken != null);
    return result;
  }

  Future<Response<Uint8List>> _request(
    String method,
    Uri uri, {
    required String action,
    Object? data,
    Map<String, String>? extraHeaders,
    required int maxResponseBytes,
    bool retryable = true,
  }) async {
    final token = (await _accessTokenProvider()).trim();
    if (token.isEmpty) {
      throw CloudBackendException(
        CloudBackendErrorKind.authentication,
        '$action失败：Google access token 为空，请重新登录。',
      );
    }
    return _http.request(
      method,
      uri,
      headers: {'authorization': 'Bearer $token', ...?extraHeaders},
      data: data,
      maxResponseBytes: maxResponseBytes,
      retryable: retryable,
    );
  }

  Never _throwResponse(Response<Uint8List> response, String action) {
    final status = response.statusCode ?? 0;
    final details = _googleErrorReason(response);
    final rateLimited =
        status == 429 ||
        (status == 403 &&
            const {
              'rateLimitExceeded',
              'userRateLimitExceeded',
              'dailyLimitExceeded',
            }.contains(details));
    final quota =
        status == 413 ||
        (status == 403 &&
            const {'storageQuotaExceeded', 'quotaExceeded'}.contains(details));
    final kind = rateLimited
        ? CloudBackendErrorKind.rateLimited
        : quota
        ? CloudBackendErrorKind.quota
        : switch (status) {
            401 => CloudBackendErrorKind.authentication,
            403 => CloudBackendErrorKind.authorization,
            404 => CloudBackendErrorKind.notFound,
            409 || 412 => CloudBackendErrorKind.conflict,
            _ => CloudBackendErrorKind.invalidResponse,
          };
    throw CloudBackendException(
      kind,
      '$action失败（HTTP $status）。',
      statusCode: status,
      retryAfter: _retryAfter(response),
    );
  }

  static dynamic _decodeJson(Response<Uint8List> response, String action) {
    try {
      return jsonDecode(BackendHttp.rawTextOf(response));
    } on FormatException {
      throw CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '$action时 Google Drive 返回了无法解析的 JSON。',
      );
    }
  }

  static String? _googleErrorReason(Response<Uint8List> response) {
    try {
      final decoded = jsonDecode(BackendHttp.rawTextOf(response));
      final error = decoded is Map ? decoded['error'] : null;
      final errors = error is Map ? error['errors'] : null;
      final first = errors is List && errors.isNotEmpty ? errors.first : null;
      final reason = first is Map ? first['reason'] : null;
      return reason is String ? reason : null;
    } on FormatException {
      return null;
    }
  }

  static DateTime? _retryAfter(Response<Uint8List> response) {
    final value = response.headers.value('retry-after');
    final seconds = int.tryParse(value ?? '');
    if (seconds != null) {
      return DateTime.now().toUtc().add(Duration(seconds: seconds));
    }
    if (value == null) return null;
    try {
      return HttpDate.parse(value).toUtc();
    } on FormatException {
      return null;
    }
  }

  Map<String, String> _properties(String type) => {
    'protocol': _protocolProperty,
    'namespace': _namespaceHash,
    'recordType': type,
  };

  String _fileName(String type, [String? id]) => switch (type) {
    'head' => 'aaalice-cloud-sync-HEAD.json',
    'key' => 'aaalice-cloud-sync-KEY.json',
    'object' => 'aaalice-cloud-sync-object-$id',
    'manifest' => 'aaalice-cloud-sync-snapshot-$id.json',
    _ => throw StateError('Unknown Google Drive record type'),
  };

  static String? _snapshotIdFromName(String name) {
    const prefix = 'aaalice-cloud-sync-snapshot-';
    const suffix = '.json';
    if (!name.startsWith(prefix) || !name.endsWith(suffix)) return null;
    final id = name.substring(prefix.length, name.length - suffix.length);
    return CloudObjectNaming.isValidId(id) ? id : null;
  }

  static int _limitFor(String type) => switch (type) {
    'head' => maxCloudHeadResponseBytes,
    'key' => maxCloudKeyResponseBytes,
    'manifest' => maxCloudManifestResponseBytes,
    'object' => maxCloudObjectResponseBytes,
    _ => throw StateError('Unknown Google Drive record type'),
  };

  static void _checkUpload(Uint8List bytes, int maxBytes) {
    if (bytes.length > maxBytes) {
      throw const CloudBackendException(
        CloudBackendErrorKind.quota,
        '上传内容超过云同步协议允许的大小上限。',
      );
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      _apiBase.resolve(path).replace(queryParameters: query);

  static Uri _normalizeBase(Uri value) {
    if (!value.hasScheme || value.host.isEmpty) {
      throw ArgumentError.value(value, 'apiBaseUri', 'Must be an absolute URI');
    }
    return value.path.endsWith('/')
        ? value
        : value.replace(path: '${value.path}/');
  }

  static String _escapeQuery(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  static bool _sameBytes(Uint8List first, Uint8List second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

class _DriveFile {
  const _DriveFile({
    required this.id,
    required this.name,
    required this.revision,
  });

  final String id;
  final String name;
  final String revision;

  factory _DriveFile.fromJson(Map<dynamic, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final version = json['version'];
    final modifiedTime = json['modifiedTime'];
    final checksum = json['md5Checksum'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'Google Drive 文件元数据缺少 id 或 name。',
      );
    }
    final revisionParts = [
      id,
      if (version != null) '$version',
      if (modifiedTime != null) '$modifiedTime',
      if (checksum != null) '$checksum',
    ];
    if (revisionParts.length == 1) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'Google Drive 文件元数据缺少 revision 信息。',
      );
    }
    return _DriveFile(id: id, name: name, revision: revisionParts.join(':'));
  }
}
