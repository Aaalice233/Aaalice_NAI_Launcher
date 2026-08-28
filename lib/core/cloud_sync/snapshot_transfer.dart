import 'package:cryptography/cryptography.dart';

import 'backend/cloud_sync_backend.dart';
import 'crypto.dart';
import 'data_source.dart';
import 'models.dart';
import 'operation.dart';
import 'sync_types.dart';

class CloudSnapshotTransfer {
  const CloudSnapshotTransfer({
    required this.backend,
    required this.dataSource,
    required this.crypto,
    required this.masterKey,
    required this.now,
  });

  final CloudSyncBackend backend;
  final CloudSyncDataSource dataSource;
  final CloudCrypto crypto;
  final SecretKey masterKey;
  final DateTime Function() now;

  Future<CloudSyncSnapshotData> downloadHead(
    SnapshotHead head,
    OperationToken token,
    SyncProgressCallback? onProgress,
  ) async {
    final read = await backend.readSnapshotManifest(head.snapshotId);
    if (read == null) {
      throw const CloudFormatException('snapshot manifest is missing');
    }
    head.verifyManifest(read.bytes);
    return _decodeAndDownload(head.snapshotId, read.bytes, token, onProgress);
  }

  Future<CloudSyncSnapshotData> downloadId(
    String snapshotId,
    OperationToken token,
    SyncProgressCallback? onProgress,
  ) async {
    final read = await backend.readSnapshotManifest(snapshotId);
    if (read == null) {
      throw const CloudFormatException('snapshot manifest is missing');
    }
    return _decodeAndDownload(snapshotId, read.bytes, token, onProgress);
  }

  Future<CloudSyncSnapshotData> downloadManifest(
    SnapshotManifest manifest,
    OperationToken token,
    SyncProgressCallback? onProgress,
  ) async {
    final materializer = dataSource is CloudSyncPayloadMaterializer
        ? dataSource as CloudSyncPayloadMaterializer
        : null;
    await materializer?.beginRemoteMaterialization(manifest.snapshotId);
    final total = manifest.objects.fold<int>(
      0,
      (sum, object) => sum + object.size,
    );
    var bytes = 0;
    final records = <CloudSyncRecord>[];
    for (var index = 0; index < manifest.objects.length; index++) {
      await token.checkpoint();
      final object = manifest.objects[index];
      onProgress?.call(
        SyncProgress(
          phase: SyncPhase.downloading,
          objectId: object.id,
          objectsCompleted: index,
          objectsTotal: manifest.objects.length,
          bytesCompleted: bytes,
          bytesTotal: total,
        ),
      );
      final read = await backend.readObject(object.id);
      if (read == null) {
        throw CloudFormatException('object ${object.id} is missing');
      }
      object.verify(read.bytes);
      final clear = await crypto.decryptObject(
        read.bytes,
        masterKey,
        objectId: object.id,
        kind: object.kind,
      );
      final record = CloudSyncRecord.decode(clear);
      if (record.kind != object.kind) {
        throw const CloudFormatException('record kind does not match manifest');
      }
      records.add(
        materializer == null
            ? record
            : await materializer.materializeRemoteRecord(record),
      );
      bytes += object.size;
    }
    onProgress?.call(
      SyncProgress(
        phase: SyncPhase.downloading,
        objectsCompleted: manifest.objects.length,
        objectsTotal: manifest.objects.length,
        bytesCompleted: bytes,
        bytesTotal: total,
      ),
    );
    return CloudSyncSnapshotData(records);
  }

  Future<bool> matches(
    String snapshotId,
    CloudSyncSnapshotData snapshot,
    OperationToken token,
  ) async {
    await token.checkpoint();
    final remote = await downloadId(snapshotId, token, null);
    if (remote.records.length != snapshot.records.length) return false;
    for (final entry in remote.records.entries) {
      if (snapshot.records[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<CloudSyncSnapshotData> _decodeAndDownload(
    String snapshotId,
    List<int> encryptedManifest,
    OperationToken token,
    SyncProgressCallback? onProgress,
  ) async {
    final manifest = SnapshotManifest.decode(
      await crypto.decryptObject(
        encryptedManifest,
        masterKey,
        objectId: snapshotId,
        kind: 'manifest',
      ),
    );
    if (manifest.snapshotId != snapshotId) {
      throw const CloudFormatException('snapshot manifest identity mismatch');
    }
    return downloadManifest(manifest, token, onProgress);
  }
}
