import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'cloud_namespace.dart';
import '../operation.dart';
import '../telemetry.dart';
import 'cloud_object_inventory_verifier.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';
import 'onedrive_api_client.dart';

class OneDriveCloudSyncBackend
    implements
        CloudSyncBackend,
        CloudObjectInventoryBackend,
        ConcurrentCloudObjectUploadBackend {
  OneDriveCloudSyncBackend({
    required Future<String> Function() accessTokenProvider,
    this.namespace = defaultCloudSyncV3Namespace,
    Dio? dio,
    Uri? graphBaseUri,
  }) : _api = OneDriveApiClient(
         accessTokenProvider: accessTokenProvider,
         dio: dio,
         graphBaseUri: graphBaseUri,
       ) {
    CloudNamespace.validate(namespace);
  }

  static final RegExp _sha256FileName = RegExp(r'^[0-9a-f]{64}$');

  // Post-upload processing can rewrite eTag between our read and the
  // conditional request; each retry re-reads and re-checks the content tag.
  static const int _preconditionAttempts = 3;
  static const _conditionalTargetDeleted = CloudBackendException(
    CloudBackendErrorKind.conflict,
    'OneDrive 中的条件写入目标已被删除。',
    statusCode: 404,
  );

  final String namespace;
  final OneDriveApiClient _api;
  Future<void>? _objectsDirectoryFuture;
  final Map<String, String> _verifiedObjectProofs = {};

  @override
  int get maxConcurrentObjectUploads => 4;

  String get _headPath => '$namespace/HEAD.json';
  String get _objectsPath => '$namespace/objects';

  @override
  Future<CloudBackendCapability> testCapability() async {
    // Saving an account only validates that Graph can provision and read the
    // provider-managed App Folder. Backup folders and probe files are created
    // only after the user explicitly starts a push.
    await _api.validateAppRoot();
    return const CloudBackendCapability(
      mode: CloudBackendMode.bidirectional,
      message: 'OneDrive 应用文件夹连接正常，可以推送和拉取备份。',
      supportsHistory: true,
      supportsDelete: true,
    );
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    final read = await _read(_headPath, maxCloudHeadResponseBytes);
    if (read == null) return null;
    return CloudHeadRead(
      bytes: read.bytes,
      revision: read.item.contentRevision,
    );
  }

  @override
  Future<CloudObjectRead?> readObject(String objectId) async {
    CloudObjectNaming.validateId(objectId);
    final read = await _read(
      '$_objectsPath/$objectId',
      maxCloudObjectResponseBytes,
    );
    if (read == null) return null;
    if (CloudObjectNaming.isContentAddressedId(objectId)) {
      if (_hashBytes(read.bytes) != objectId) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'OneDrive 不可变对象内容与对象标识不一致。',
        );
      }
      _rememberProof(objectId, read.item);
    }
    return _objectRead(read);
  }

  @override
  Map<String, String> verifiedObjectProofs(Iterable<String> objectIds) => {
    for (final objectId in objectIds)
      if (_verifiedObjectProofs[objectId] case final proof?) objectId: proof,
  };

  @override
  Future<CloudObjectInventoryResult> findExistingObjects(
    Map<String, int> expectedObjects, {
    Map<String, String> trustedRevisions = const {},
    OperationToken? token,
    CloudObjectInventoryProgressCallback? onProgress,
  }) async {
    if (expectedObjects.isEmpty) return CloudObjectInventoryResult.empty();
    for (final entry in expectedObjects.entries) {
      if (!_sha256FileName.hasMatch(entry.key) || entry.value < 0) {
        throw const FormatException('Invalid cloud object inventory');
      }
    }

    await _ensureObjectsDirectory();
    final children = await _api.listChildren(_objectsPath);
    final byName = <String, OneDriveItem>{};
    for (final item in children) {
      if (!_sha256FileName.hasMatch(item.name)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'OneDrive objects 目录包含非法对象文件名。',
        );
      }
      if (item.isFolder || byName.containsKey(item.name)) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'OneDrive objects 目录包含重复对象或同名目录。',
        );
      }
      byName[item.name] = item;
    }

    final candidates = <CloudObjectInventoryCandidate>[];
    final listedItems = <String, OneDriveItem>{};
    for (final entry in expectedObjects.entries) {
      final item = byName[entry.key];
      if (item == null) continue;
      candidates.add(_inventoryCandidate(entry.key, entry.value, item));
      listedItems[entry.key] = item;
    }
    final result = await verifyCloudObjectInventory(
      candidates: candidates,
      trustedRevisions: _effectiveTrustedRevisions(
        candidates,
        listedItems,
        trustedRevisions,
      ),
      maxConcurrentItems: maxConcurrentObjectUploads,
      token: token,
      onProgress: onProgress,
      verify: (candidate) async {
        final bytes = await _downloadListedObject(
          candidate.objectId,
          listedItems[candidate.objectId]!,
        );
        if (_hashBytes(bytes) != candidate.objectId) {
          throw const CloudBackendException(
            CloudBackendErrorKind.conflict,
            'OneDrive 已存在内容不一致的不可变对象。',
          );
        }
      },
    );
    _verifiedObjectProofs.addAll(result.verifiedRevisions);
    return result;
  }

  CloudObjectInventoryCandidate _inventoryCandidate(
    String objectId,
    int size,
    OneDriveItem item,
  ) {
    if (item.size != size) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'OneDrive 已存在大小不一致的不可变对象。',
      );
    }
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'OneDrive 对象清单缺少文件标识。',
      );
    }
    return CloudObjectInventoryCandidate(
      objectId: objectId,
      size: size,
      revision: item.contentRevision,
      verificationRevision: _proof(itemId, item.contentRevision),
    );
  }

  Map<String, String> _effectiveTrustedRevisions(
    List<CloudObjectInventoryCandidate> candidates,
    Map<String, OneDriveItem> listedItems,
    Map<String, String> trustedRevisions,
  ) {
    final effective = {...trustedRevisions};
    for (final candidate in candidates) {
      final listed = listedItems[candidate.objectId]!;
      // Stored proofs may be keyed by eTag; they stay valid only while that
      // eTag is unchanged, since it pins the exact bytes that were verified.
      final legacyProof = _proof(listed.id!, listed.eTag);
      if (_verifiedObjectProofs[candidate.objectId] ==
              candidate.verificationRevision ||
          trustedRevisions[candidate.objectId] == legacyProof) {
        effective[candidate.objectId] = candidate.verificationRevision;
      }
    }
    return effective;
  }

  static String _proof(String itemId, String revision) =>
      'onedrive:$itemId:$revision';

  void _rememberProof(String objectId, OneDriveItem item) {
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) return;
    _verifiedObjectProofs[objectId] = _proof(itemId, item.contentRevision);
  }

  static CloudObjectRead _objectRead(_ItemRead read) =>
      CloudObjectRead(bytes: read.bytes, revision: read.item.contentRevision);

  Future<Uint8List> _downloadListedObject(
    String objectId,
    OneDriveItem listed,
  ) async {
    final path = '$_objectsPath/$objectId';
    try {
      return await _api.download(
        path,
        expectedETag: listed.eTag,
        maxBytes: maxCloudObjectResponseBytes,
      );
    } on CloudBackendException catch (error) {
      if (error.statusCode != 412) rethrow;
    }
    final current = await _read(path, maxCloudObjectResponseBytes);
    if (current == null ||
        current.item.contentRevision != listed.contentRevision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'OneDrive 不可变对象在校验期间被改写或删除。',
      );
    }
    return current.bytes;
  }

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) async {
    final name = CloudObjectNaming.manifestFileName(snapshotId);
    final read = await _read(
      '$namespace/snapshots/$name',
      maxCloudManifestResponseBytes,
    );
    return read == null ? null : _objectRead(read);
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) {
    CloudObjectNaming.validateId(objectId);
    return _putObjectImmutable(
      objectId,
      bytes,
      sha256,
      payloadVerified: payloadVerified,
    );
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) => _putImmutable(
    '$namespace/snapshots/${CloudObjectNaming.manifestFileName(snapshotId)}',
    bytes,
    sha256,
    maxCloudManifestResponseBytes,
    payloadVerified: payloadVerified,
  );

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) => _commitMutable(
    _headPath,
    bytes,
    expectedRevision,
    maxCloudHeadResponseBytes,
  );

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    if (limit <= 0) return const [];
    final children = await _api.listChildren('$namespace/snapshots');
    final ids =
        children
            .where((item) => !item.isFolder)
            .map(
              (item) => CloudObjectNaming.snapshotIdFromManifestName(item.name),
            )
            .whereType<String>()
            .toList()
          ..sort((first, second) => second.compareTo(first));
    return ids.take(limit).toList(growable: false);
  }

  @override
  Future<void> deleteNamespace() async {
    try {
      await _api.delete(namespace);
    } finally {
      _invalidateNamespaceDirectories();
      _verifiedObjectProofs.clear();
    }
  }

  Future<_ItemRead?> _read(String path, int maxBytes) async {
    for (var attempt = 1; ; attempt++) {
      final item = await _api.metadata(path);
      if (item == null) return null;
      if (item.isFolder || item.size > maxBytes) {
        throw const CloudBackendException(
          CloudBackendErrorKind.invalidResponse,
          'OneDrive 文件超过允许的大小或返回了目录。',
        );
      }
      try {
        final bytes = await _api.download(
          path,
          expectedETag: item.eTag,
          maxBytes: maxBytes,
        );
        return (item: item, bytes: bytes);
      } on CloudBackendException catch (error) {
        if (error.statusCode != 412 || attempt >= _preconditionAttempts) {
          rethrow;
        }
      }
    }
  }

  Future<CloudCommitResult> _commitMutable(
    String path,
    Uint8List bytes,
    String? expectedRevision,
    int maxBytes,
  ) async {
    _checkSize(bytes, maxBytes);
    await _ensureParent(path);
    if (expectedRevision == null) {
      final created = await _uploadWithDirectoryRecovery(
        path,
        bytes,
        expectedETag: null,
      );
      return CloudCommitResult(revision: created.contentRevision);
    }
    for (var attempt = 1; ; attempt++) {
      final current = await _api.metadata(path);
      if (current == null) throw _conditionalTargetDeleted;
      if (current.contentRevision != expectedRevision) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'OneDrive 中的条件写入目标已被其他设备更新。',
          statusCode: 412,
        );
      }
      try {
        final uploaded = await _uploadWithDirectoryRecovery(
          path,
          bytes,
          expectedETag: current.eTag,
        );
        return CloudCommitResult(revision: uploaded.contentRevision);
      } on CloudBackendException catch (error) {
        if (error.statusCode == 404) throw _conditionalTargetDeleted;
        final preconditionFailed =
            error.statusCode == 409 || error.statusCode == 412;
        if (!preconditionFailed || attempt >= _preconditionAttempts) rethrow;
      }
    }
  }

  Future<CloudCommitResult> _putObjectImmutable(
    String objectId,
    Uint8List bytes,
    String expectedHash, {
    required bool payloadVerified,
  }) async {
    _checkSize(bytes, maxCloudObjectResponseBytes);
    if (!payloadVerified) _checkHash(bytes, expectedHash);
    await _ensureObjectsDirectory();
    final path = '$_objectsPath/$objectId';
    try {
      final uploaded = await _uploadWithDirectoryRecovery(
        path,
        bytes,
        expectedETag: null,
      );
      _rememberProof(objectId, uploaded);
      return CloudCommitResult(revision: uploaded.contentRevision);
    } on CloudBackendException catch (error) {
      if (error.statusCode != 409) rethrow;
      final raced = await _read(path, maxCloudObjectResponseBytes);
      if (raced != null &&
          _hashBytes(raced.bytes) == expectedHash.toLowerCase()) {
        _rememberProof(objectId, raced.item);
        return CloudCommitResult(revision: raced.item.contentRevision);
      }
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'OneDrive 已存在同名但内容不同的不可变数据。',
        statusCode: 409,
      );
    }
  }

  Future<CloudCommitResult> _putImmutable(
    String path,
    Uint8List bytes,
    String expectedHash,
    int maxBytes, {
    required bool payloadVerified,
  }) async {
    _checkSize(bytes, maxBytes);
    if (!payloadVerified) _checkHash(bytes, expectedHash);
    final actualHash = expectedHash.toLowerCase();
    final existing = await _read(path, maxBytes);
    if (existing != null) {
      if (_hashBytes(existing.bytes) == actualHash) {
        return CloudCommitResult(revision: existing.item.contentRevision);
      }
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'OneDrive 已存在同名但内容不同的不可变数据。',
      );
    }
    await _ensureParent(path);
    try {
      final uploaded = await _uploadWithDirectoryRecovery(
        path,
        bytes,
        expectedETag: null,
      );
      return CloudCommitResult(revision: uploaded.contentRevision);
    } on CloudBackendException catch (error) {
      if (error.statusCode != 409) rethrow;
      final raced = await _read(path, maxBytes);
      if (raced != null && _hashBytes(raced.bytes) == actualHash) {
        return CloudCommitResult(revision: raced.item.contentRevision);
      }
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'OneDrive 已存在同名但内容不同的不可变数据。',
        statusCode: 409,
      );
    }
  }

  Future<OneDriveItem> _uploadWithDirectoryRecovery(
    String path,
    Uint8List bytes, {
    required String? expectedETag,
  }) async {
    try {
      return await _api.upload(path, bytes, expectedETag: expectedETag);
    } on CloudBackendException catch (error) {
      if (error.statusCode != 404) rethrow;
      // A createUploadSession 404 is a definite pre-upload failure. Drop the
      // stale singleflight chain, rebuild its parent once, then preserve the
      // original create-only or If-Match condition on the retry.
      _invalidateNamespaceDirectories();
      final separator = path.lastIndexOf('/');
      final parent = separator <= 0 ? '' : path.substring(0, separator);
      if (parent == _objectsPath) {
        await _ensureObjectsDirectory();
      } else {
        await _ensureParent(path);
      }
      return _api.upload(path, bytes, expectedETag: expectedETag);
    }
  }

  void _invalidateNamespaceDirectories() {
    _objectsDirectoryFuture = null;
    _api.invalidateFolderCache(namespace);
  }

  Future<void> _ensureObjectsDirectory() {
    final cached = _objectsDirectoryFuture;
    if (cached != null) return cached;
    final future = _resolveObjectsDirectory();
    _objectsDirectoryFuture = future;
    return future;
  }

  Future<void> _resolveObjectsDirectory() async {
    try {
      await _api.ensureFolder(_objectsPath);
    } catch (_) {
      _objectsDirectoryFuture = null;
      rethrow;
    }
  }

  Future<void> _ensureParent(String path) async {
    final separator = path.lastIndexOf('/');
    if (separator <= 0) return;
    await _api.ensureFolder(path.substring(0, separator));
  }

  static String _hashBytes(List<int> bytes) {
    CloudSyncTelemetry.recordHashPass();
    return sha256.convert(bytes).toString();
  }

  static void _checkHash(Uint8List bytes, String expectedHash) {
    if (_hashBytes(bytes) != expectedHash.toLowerCase()) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '上传内容与声明的 SHA-256 不一致。',
      );
    }
  }

  static void _checkSize(Uint8List bytes, int maxBytes) {
    if (bytes.length > maxBytes) {
      throw const CloudBackendException(
        CloudBackendErrorKind.quota,
        '上传内容超过云同步协议允许的大小上限。',
      );
    }
  }
}

typedef _ItemRead = ({OneDriveItem item, Uint8List bytes});
