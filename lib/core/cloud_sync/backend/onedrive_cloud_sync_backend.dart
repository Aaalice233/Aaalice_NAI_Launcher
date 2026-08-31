import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'cloud_namespace.dart';
import 'cloud_object_naming.dart';
import 'cloud_sync_backend.dart';
import 'onedrive_api_client.dart';

class OneDriveCloudSyncBackend
    implements CloudSyncBackend, CloudKeyEnvelopeBackend {
  OneDriveCloudSyncBackend({
    required Future<String> Function() accessTokenProvider,
    this.namespace = 'aaalice-sync',
    Dio? dio,
    Uri? graphBaseUri,
  }) : _api = OneDriveApiClient(
         accessTokenProvider: accessTokenProvider,
         dio: dio,
         graphBaseUri: graphBaseUri,
       ) {
    CloudNamespace.validate(namespace);
  }

  final String namespace;
  final OneDriveApiClient _api;

  String get _headPath => '$namespace/HEAD.json';
  String get _keyPath => '$namespace/KEY.json';

  @override
  Future<CloudBackendCapability> testCapability() async {
    await _api.ensureFolder(namespace);
    final random = Random.secure();
    final suffix = List<int>.generate(
      12,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final path = '$namespace/.capability-$suffix';
    Object? probeFailure;
    try {
      final first = await _api.upload(
        path,
        Uint8List.fromList(const [1]),
        expectedETag: null,
      );
      final second = await _api.upload(
        path,
        Uint8List.fromList(const [2]),
        expectedETag: first.eTag,
      );
      final staleETagRejected = await _expectExactConflict(
        () => _api.upload(
          path,
          Uint8List.fromList(const [3]),
          expectedETag: first.eTag,
        ),
        412,
      );
      final createConflictRejected = await _expectExactConflict(
        () => _api.upload(
          path,
          Uint8List.fromList(const [4]),
          expectedETag: null,
        ),
        409,
      );
      final downloaded = await _read(path, maxCloudHeadResponseBytes);
      final readAfterWrite =
          downloaded != null &&
          downloaded.revision == second.eTag &&
          _sameBytes(downloaded.bytes, const [2]);
      if (!staleETagRejected || !createConflictRejected || !readAfterWrite) {
        return const CloudBackendCapability(
          mode: CloudBackendMode.manualBackupOnly,
          message: 'OneDrive 可以写入备份，但无法证明条件写入语义，已停用双向同步。',
          supportsHistory: true,
          supportsDelete: true,
          warnings: ['服务端未通过 stale eTag 与同名创建冲突探针。'],
        );
      }
      return const CloudBackendCapability(
        mode: CloudBackendMode.bidirectional,
        message: 'OneDrive 应用文件夹连接正常，可以推送和拉取备份。',
        supportsHistory: true,
        supportsDelete: true,
      );
    } catch (error) {
      probeFailure = error;
      rethrow;
    } finally {
      try {
        await _api.delete(path);
      } catch (_) {
        // Preserve the probe failure; a cleanup-only failure must still fail
        // capability detection so a stale probe is never reported as success.
        if (probeFailure == null) rethrow;
      }
    }
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    final read = await _read(_headPath, maxCloudHeadResponseBytes);
    if (read == null) return null;
    return CloudHeadRead(bytes: read.bytes, revision: read.revision);
  }

  @override
  Future<CloudObjectRead?> readKeyEnvelope() =>
      _read(_keyPath, maxCloudKeyResponseBytes);

  @override
  Future<CloudObjectRead?> readObject(String objectId) {
    CloudObjectNaming.validateId(objectId);
    return _read('$namespace/objects/$objectId', maxCloudObjectResponseBytes);
  }

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) {
    final name = CloudObjectNaming.manifestFileName(snapshotId);
    return _read('$namespace/snapshots/$name', maxCloudManifestResponseBytes);
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
  }) {
    CloudObjectNaming.validateId(objectId);
    return _putImmutable(
      '$namespace/objects/$objectId',
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
  }) => _putImmutable(
    '$namespace/snapshots/${CloudObjectNaming.manifestFileName(snapshotId)}',
    bytes,
    sha256,
    maxCloudManifestResponseBytes,
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
  Future<CloudCommitResult> commitKeyEnvelope(
    Uint8List bytes, {
    required String? expectedRevision,
  }) => _commitMutable(
    _keyPath,
    bytes,
    expectedRevision,
    maxCloudKeyResponseBytes,
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
  Future<void> deleteNamespace() => _api.delete(namespace);

  Future<CloudObjectRead?> _read(String path, int maxBytes) async {
    for (var attempt = 0; attempt < 2; attempt++) {
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
        return CloudObjectRead(bytes: bytes, revision: item.eTag);
      } on CloudBackendException catch (error) {
        if (error.statusCode != 412 || attempt != 0) rethrow;
      }
    }
    throw StateError('unreachable');
  }

  Future<CloudCommitResult> _commitMutable(
    String path,
    Uint8List bytes,
    String? expectedRevision,
    int maxBytes,
  ) async {
    _checkSize(bytes, maxBytes);
    await _ensureParent(path);
    try {
      final uploaded = await _api.upload(
        path,
        bytes,
        expectedETag: expectedRevision,
      );
      return CloudCommitResult(revision: uploaded.eTag);
    } on CloudBackendException catch (error) {
      if (expectedRevision != null && error.statusCode == 404) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'OneDrive 中的条件写入目标已被删除。',
          statusCode: 404,
        );
      }
      rethrow;
    }
  }

  Future<CloudCommitResult> _putImmutable(
    String path,
    Uint8List bytes,
    String expectedHash,
    int maxBytes,
  ) async {
    _checkSize(bytes, maxBytes);
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != expectedHash.toLowerCase()) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        '上传内容与声明的 SHA-256 不一致。',
      );
    }
    final existing = await _read(path, maxBytes);
    if (existing != null) {
      if (sha256.convert(existing.bytes).toString() == actualHash) {
        return CloudCommitResult(revision: existing.revision);
      }
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'OneDrive 已存在同名但内容不同的不可变数据。',
      );
    }
    await _ensureParent(path);
    try {
      final uploaded = await _api.upload(path, bytes, expectedETag: null);
      return CloudCommitResult(revision: uploaded.eTag);
    } on CloudBackendException catch (error) {
      if (error.statusCode != 409) rethrow;
      final raced = await _read(path, maxBytes);
      if (raced != null &&
          sha256.convert(raced.bytes).toString() == actualHash) {
        return CloudCommitResult(revision: raced.revision);
      }
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'OneDrive 已存在同名但内容不同的不可变数据。',
        statusCode: 409,
      );
    }
  }

  Future<void> _ensureParent(String path) async {
    final separator = path.lastIndexOf('/');
    if (separator <= 0) return;
    await _api.ensureFolder(path.substring(0, separator));
  }

  static Future<bool> _expectExactConflict(
    Future<OneDriveItem> Function() operation,
    int statusCode,
  ) async {
    try {
      await operation();
      return false;
    } on CloudBackendException catch (error) {
      if (error.kind == CloudBackendErrorKind.authentication ||
          error.kind == CloudBackendErrorKind.authorization ||
          error.kind == CloudBackendErrorKind.network ||
          error.kind == CloudBackendErrorKind.rateLimited ||
          error.kind == CloudBackendErrorKind.quota) {
        rethrow;
      }
      return error.kind == CloudBackendErrorKind.conflict &&
          error.statusCode == statusCode;
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

  static bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
