import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../operation.dart';
import 'cloud_object_inventory_verifier.dart';
import '../telemetry.dart';
import 'backend_http.dart';
import 'cloud_namespace.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';

/// Stores cloud-sync records in Google Drive's hidden `appDataFolder` space.
///
/// Drive does not expose conditional file updates, so HEAD revisions are only
/// checked immediately before a write. This backend must therefore
/// remain manual-backup-only even when those checks succeed.
class GoogleDriveCloudSyncBackend
    implements
        CloudSyncBackend,
        CloudObjectInventoryBackend,
        ConcurrentCloudObjectUploadBackend {
  GoogleDriveCloudSyncBackend({
    required Future<String> Function() accessTokenProvider,
    required this.namespace,
    Dio? dio,
    Uri? apiBaseUri,
  }) : _accessTokenProvider = accessTokenProvider,
       _http = BackendHttp(
         dio: dio,
         observer: (metric) => CloudSyncTelemetry.recordRequest(
           bytesRead: metric.responseBytes ?? 0,
           bytesWritten: metric.requestBytes ?? 0,
         ),
       ),
       _apiBase = _normalizeBase(
         apiBaseUri ?? Uri.parse('https://www.googleapis.com/'),
       ) {
    CloudNamespace.validate(namespace);
    // This hashes connection metadata, not a payload, and is intentionally
    // outside per-operation payload hash telemetry.
    _namespaceHash = sha256.convert(utf8.encode(namespace)).toString();
  }

  static const _protocolProperty = 'aaalice-cloud-sync-v2';
  static const _fileFields =
      'id,name,size,md5Checksum,modifiedTime,version,appProperties';
  static const _listFields = 'nextPageToken,files($_fileFields)';

  final Future<String> Function() _accessTokenProvider;
  final BackendHttp _http;
  final Uri _apiBase;
  final String namespace;
  late final String _namespaceHash;
  final Expando<_DriveInventoryScope> _operationInventories =
      Expando<_DriveInventoryScope>('google-drive-inventory');
  final _unscopedInventory = _DriveInventoryScope();
  final Map<String, String> _verifiedObjectRevisions = {};

  _DriveInventoryScope get _inventoryScope {
    final operation = OperationToken.current;
    if (operation == null) return _unscopedInventory;
    return _operationInventories[operation] ??= _DriveInventoryScope();
  }

  @override
  int get maxConcurrentObjectUploads => 4;

  @override
  Future<CloudBackendCapability> testCapability() async {
    await _loadInventory();
    return const CloudBackendCapability(
      mode: CloudBackendMode.manualBackupOnly,
      message: 'Google Drive appDataFolder 连接正常，仅支持显式手动推送与拉取。',
      supportsHistory: true,
      supportsDelete: true,
      warnings: [CloudBackendWarning.googleDriveWeakCas],
    );
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    await _loadInventory();
    final read = await _readMutable('head', _fileName('head'));
    return read == null
        ? null
        : CloudHeadRead(bytes: read.bytes, revision: read.revision);
  }

  @override
  Future<CloudObjectRead?> readObject(String objectId) async {
    CloudObjectNaming.validateId(objectId);
    final read = await _readImmutable('object', _fileName('object', objectId));
    if (read != null &&
        CloudObjectNaming.isContentAddressedId(objectId) &&
        _hashBytes(read.bytes) != objectId) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 不可变对象内容与对象标识不一致。',
      );
    }
    if (read != null && CloudObjectNaming.isContentAddressedId(objectId)) {
      _verifiedObjectRevisions[_fileName('object', objectId)] = read.revision;
    }
    return read;
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
    bool payloadVerified = false,
  }) {
    CloudObjectNaming.validateId(objectId);
    return _putImmutable(
      'object',
      _fileName('object', objectId),
      bytes,
      sha256,
      maxCloudObjectResponseBytes,
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
    CloudObjectNaming.validateId(snapshotId);
    return _putImmutable(
      'manifest',
      _fileName('manifest', snapshotId),
      bytes,
      sha256,
      maxCloudManifestResponseBytes,
      payloadVerified: payloadVerified,
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
  Future<CloudObjectInventoryResult> findExistingObjects(
    Map<String, int> expectedObjects, {
    Map<String, String> trustedRevisions = const {},
    OperationToken? token,
    CloudObjectInventoryProgressCallback? onProgress,
  }) async {
    final inventory = await _loadInventory();
    final inventoryCandidates = <CloudObjectInventoryCandidate>[];
    final filesByObjectId = <String, _DriveFile>{};
    for (final entry in expectedObjects.entries) {
      CloudObjectNaming.validateId(entry.key);
      if (entry.value < 0 || entry.value > maxCloudObjectResponseBytes) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          '待上传对象的预期大小无效。',
        );
      }
      final files = inventory[_fileName('object', entry.key)] ?? const [];
      if (files.length > 1) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Google Drive 中存在多个同名不可变对象，无法确认对象身份。',
        );
      }
      if (files.isEmpty) continue;
      final file = files.single;
      if (file.recordType != 'object' || file.size != entry.value) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Google Drive 中的不可变对象元数据与待上传对象不一致。',
        );
      }
      filesByObjectId[entry.key] = file;
      inventoryCandidates.add(
        CloudObjectInventoryCandidate(
          objectId: entry.key,
          size: entry.value,
          revision: file.revision,
          verificationRevision: 'google-drive:${file.id}:${file.revision}',
        ),
      );
    }
    final inMemoryRevisions = <String, String>{};
    for (final candidate in inventoryCandidates) {
      final inMemory =
          _verifiedObjectRevisions[_fileName('object', candidate.objectId)];
      if (inMemory == candidate.revision ||
          inMemory == candidate.verificationRevision) {
        inMemoryRevisions[candidate.objectId] = candidate.verificationRevision;
      }
    }
    final result = await verifyCloudObjectInventory(
      candidates: inventoryCandidates,
      trustedRevisions: {...trustedRevisions, ...inMemoryRevisions},
      maxConcurrentItems: maxConcurrentObjectUploads,
      token: token,
      onProgress: onProgress,
      verify: (candidate) async {
        final read = await _download(
          filesByObjectId[candidate.objectId]!,
          maxCloudObjectResponseBytes,
        );
        if (_hashBytes(read.bytes) != candidate.objectId) {
          throw const CloudBackendException(
            CloudBackendErrorKind.conflict,
            'Google Drive 中的不可变对象内容与对象标识不一致。',
          );
        }
      },
    );
    for (final entry in result.verifiedRevisions.entries) {
      _verifiedObjectRevisions[_fileName('object', entry.key)] = entry.value;
    }
    return result;
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    if (limit <= 0) return const [];
    final inventory = await _loadInventory();
    final grouped = <String, List<_DriveFile>>{};
    for (final candidates in inventory.values) {
      for (final file in candidates) {
        if (file.recordType != 'manifest') continue;
        final id = _snapshotIdFromName(file.name);
        if (id != null) (grouped[id] ??= []).add(file);
      }
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
    final inventory = await _loadInventory();
    final files = inventory.values.expand((files) => files).toList();
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
      inventory[file.name]?.removeWhere((candidate) => candidate.id == file.id);
    }
    _verifiedObjectRevisions.clear();
  }

  Future<CloudObjectRead?> _readMutable(String type, String name) async {
    final files = await _candidates(type, name);
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
    final files = await _candidates(type, name);
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
      final hash = _hashBytes(read.bytes);
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
    int maxBytes, {
    required bool payloadVerified,
  }) async {
    _checkUpload(bytes, maxBytes);
    if (!payloadVerified && _hashBytes(bytes) != expectedHash) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        '上传内容与声明的 SHA-256 不一致。',
      );
    }
    final existing = await _candidates(type, name);
    if (existing.isNotEmpty) {
      final read = await _readImmutableCandidates(existing, maxBytes);
      if (_hashBytes(read.bytes) != expectedHash) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Google Drive 中已存在同名但内容不同的不可变数据。',
        );
      }
      if (type == 'object') _verifiedObjectRevisions[name] = read.revision;
      return CloudCommitResult(revision: read.revision);
    }
    final created = await _create(type, name, bytes);
    final expectedMd5 = md5.convert(bytes).toString();
    final verified = created.md5Checksum != expectedMd5
        ? await _download(created, maxBytes)
        : null;
    if (verified != null && _hashBytes(verified.bytes) != expectedHash) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 上传后的不可变数据校验失败。',
      );
    }
    final revision = verified?.revision ?? created.revision;
    if (type == 'object') _verifiedObjectRevisions[name] = revision;
    return CloudCommitResult(revision: revision);
  }

  Future<CloudCommitResult> _commitMutable(
    String type,
    String name,
    Uint8List bytes,
    String? expectedRevision,
    int maxBytes,
  ) async {
    _checkUpload(bytes, maxBytes);
    final files = await _candidates(type, name);
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
    final written = current == null
        ? await _create(type, name, bytes)
        : await _update(current, bytes);
    final expectedMd5 = md5.convert(bytes).toString();
    if (written.md5Checksum != expectedMd5) {
      final read = await _download(written, maxBytes);
      if (!_bytesEqual(read.bytes, bytes)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Google Drive 写入后内容已被其他客户端改变。',
        );
      }
      return CloudCommitResult(revision: read.revision);
    }
    return CloudCommitResult(revision: written.revision);
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

  Future<_DriveFile> _create(String type, String name, Uint8List bytes) async {
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
    try {
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
      final file = _decodeFile(response, '上传同步文件');
      if (file.name != name ||
          file.size != bytes.length ||
          file.recordType != type ||
          file.protocol != _protocolProperty ||
          file.namespace != _namespaceHash) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'Google Drive 上传响应与请求的同步文件不一致。',
        );
      }
      _addToInventory(file);
      return file;
    } catch (_) {
      // Once the request was sent, a missing or invalid response cannot prove
      // that Drive did not create the file. The next operation must re-list.
      _invalidateAfterAmbiguousWrite();
      rethrow;
    }
  }

  Future<_DriveFile> _update(_DriveFile current, Uint8List bytes) async {
    // Retrying an ambiguous weak-CAS update could overwrite a concurrent
    // writer after the first request actually succeeded.
    final response = await _request(
      'PATCH',
      _uri('upload/drive/v3/files/${Uri.encodeComponent(current.id)}', {
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
    final file = _decodeFile(response, '更新同步文件');
    if (file.id != current.id ||
        file.name != current.name ||
        file.size != bytes.length ||
        file.recordType != current.recordType ||
        file.protocol != _protocolProperty ||
        file.namespace != _namespaceHash) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'Google Drive 更新响应与请求的同步文件不一致。',
      );
    }
    final candidates = _inventoryScope.inventory?[current.name];
    final index = candidates?.indexWhere((file) => file.id == current.id) ?? -1;
    if (index < 0) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'Google Drive 更新响应与当前 inventory 不一致。',
      );
    }
    candidates![index] = file;
    return file;
  }

  void _invalidateAfterAmbiguousWrite() {
    if (OperationToken.current == null) {
      _unscopedInventory.invalidate();
    } else {
      _inventoryScope.markUnusable();
    }
  }

  Future<Map<String, List<_DriveFile>>> _loadInventory() async {
    final scope = _inventoryScope;
    if (scope.unusable) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'Google Drive 当前操作的 inventory 已失效，请开始新操作后重试。',
      );
    }
    final cached = scope.inventory;
    if (cached != null) return cached;
    final loading = scope.inventoryLoad;
    if (loading != null) return loading;
    final future = _fetchInventory(scope);
    scope.inventoryLoad = future;
    try {
      return await future;
    } finally {
      if (identical(scope.inventoryLoad, future)) scope.inventoryLoad = null;
    }
  }

  Future<Map<String, List<_DriveFile>>> _fetchInventory(
    _DriveInventoryScope scope,
  ) async {
    final result = <String, List<_DriveFile>>{};
    final seenPageTokens = <String>{};
    var pageCount = 0;
    String? pageToken;
    do {
      pageCount++;
      if (pageCount > 1000) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'Google Drive 文件列表分页过多。',
        );
      }
      final clauses = <String>[
        "'appDataFolder' in parents",
        'trashed = false',
        "appProperties has { key='protocol' and value='$_protocolProperty' }",
        "appProperties has { key='namespace' and value='$_namespaceHash' }",
      ];
      final response = await _request(
        'GET',
        _uri('drive/v3/files', {
          'spaces': 'appDataFolder',
          'q': clauses.join(' and '),
          'fields': _listFields,
          'pageSize': '1000',
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
        final file = _DriveFile.fromJson(value);
        if (file.protocol != _protocolProperty ||
            file.namespace != _namespaceHash) {
          throw const CloudBackendException(
            CloudBackendErrorKind.invalidResponse,
            'Google Drive inventory 返回了协议或 namespace 不匹配的文件。',
          );
        }
        (result[file.name] ??= []).add(file);
      }
      final next = decoded['nextPageToken'];
      if (next != null && (next is! String || next.isEmpty)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'Google Drive 分页标记格式无效。',
        );
      }
      pageToken = next as String?;
      if (pageToken != null && !seenPageTokens.add(pageToken)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'Google Drive 文件列表分页标记重复。',
        );
      }
    } while (pageToken != null);
    scope.inventory = result;
    return result;
  }

  Future<List<_DriveFile>> _candidates(String type, String name) async {
    final candidates = (await _loadInventory())[name] ?? const [];
    if (candidates.any((file) => file.recordType != type)) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Google Drive 同名文件的同步类型不一致。',
      );
    }
    return candidates;
  }

  void _addToInventory(_DriveFile file) {
    final inventory = _inventoryScope.inventory;
    if (inventory == null) {
      throw StateError('Google Drive inventory was not loaded before write');
    }
    (inventory[file.name] ??= []).add(file);
  }

  static _DriveFile _decodeFile(Response<Uint8List> response, String action) {
    final decoded = _decodeJson(response, action);
    if (decoded is! Map) {
      throw CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '$action时 Google Drive 返回了无效的文件元数据。',
      );
    }
    return _DriveFile.fromJson(decoded);
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
    final tokenFuture = _accessTokenProvider();
    final operation = OperationToken.current;
    final token = (await (operation?.race(tokenFuture) ?? tokenFuture)).trim();
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
      retryResponse: (response) =>
          response.statusCode == 403 &&
          const {
            'rateLimitExceeded',
            'userRateLimitExceeded',
            'dailyLimitExceeded',
          }.contains(_googleErrorReason(response)),
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
    'manifest' => maxCloudManifestResponseBytes,
    'object' => maxCloudObjectResponseBytes,
    _ => throw StateError('Unknown Google Drive record type'),
  };

  static String _hashBytes(List<int> bytes) {
    CloudSyncTelemetry.recordHashPass();
    return sha256.convert(bytes).toString();
  }

  static bool _bytesEqual(Uint8List left, Uint8List right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

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
}

class _DriveInventoryScope {
  Map<String, List<_DriveFile>>? inventory;
  Future<Map<String, List<_DriveFile>>>? inventoryLoad;
  bool unusable = false;

  void invalidate() {
    inventory = null;
    inventoryLoad = null;
    unusable = false;
  }

  void markUnusable() {
    inventory = null;
    inventoryLoad = null;
    unusable = true;
  }
}

class _DriveFile {
  const _DriveFile({
    required this.id,
    required this.name,
    required this.size,
    required this.protocol,
    required this.namespace,
    required this.recordType,
    required this.revision,
    required this.md5Checksum,
  });

  final String id;
  final String name;
  final int size;
  final String protocol;
  final String namespace;
  final String recordType;
  final String revision;
  final String? md5Checksum;

  factory _DriveFile.fromJson(Map<dynamic, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final size = int.tryParse('${json['size'] ?? ''}');
    final version = json['version'];
    final modifiedTime = json['modifiedTime'];
    final checksum = json['md5Checksum'];
    final appProperties = json['appProperties'];
    final protocol = appProperties is Map ? appProperties['protocol'] : null;
    final namespace = appProperties is Map ? appProperties['namespace'] : null;
    final recordType = appProperties is Map
        ? appProperties['recordType']
        : null;
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        size == null ||
        size < 0 ||
        protocol is! String ||
        protocol.isEmpty ||
        namespace is! String ||
        namespace.isEmpty ||
        recordType is! String ||
        recordType.isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'Google Drive 文件元数据缺少 id、name、size 或 appProperties。',
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
    return _DriveFile(
      id: id,
      name: name,
      size: size,
      protocol: protocol,
      namespace: namespace,
      recordType: recordType,
      revision: revisionParts.join(':'),
      md5Checksum: checksum is String && checksum.isNotEmpty ? checksum : null,
    );
  }
}
