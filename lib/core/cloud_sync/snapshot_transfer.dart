import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;

import 'backend/cloud_sync_backend.dart';
import 'bounded_transfer_scheduler.dart';
import 'data_source.dart';
import 'models.dart';
import 'operation.dart';
import 'sync_types.dart';
import 'telemetry.dart';

class CloudSnapshotTransfer {
  const CloudSnapshotTransfer({
    required this.backend,
    required this.dataSource,
    this.transferLimits,
  });

  final CloudSyncBackend backend;
  final CloudSyncDataSource dataSource;
  final CloudTransferLimits? transferLimits;

  CloudTransferLimits get _transferLimits =>
      transferLimits ?? cloudTransferPlatformLimits;

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
    final localResolver = dataSource is CloudSyncLocalPayloadResolver
        ? dataSource as CloudSyncLocalPayloadResolver
        : null;
    final objectSizes = <String, int>{};
    for (final ref in manifest.records) {
      final objectId = ref.objectId;
      final size = ref.size;
      if (objectId == null || size == null) continue;
      final previous = objectSizes[objectId];
      if (previous != null && previous != size) {
        throw const CloudFormatException('shared object has conflicting sizes');
      }
      objectSizes[objectId] = size;
    }
    final entries = objectSizes.entries.toList(growable: false);
    final total = objectSizes.values.fold<int>(0, (sum, size) => sum + size);
    var bytesCompleted = 0;
    var objectsCompleted = 0;
    onProgress?.call(
      SyncProgress(
        phase: SyncPhase.downloading,
        objectsTotal: entries.length,
        bytesTotal: total,
      ),
    );

    final scheduler = BoundedTransferScheduler(
      maxConcurrentItems: _transferConcurrency,
      maxBytesInFlight: _transferLimits.maxBytesInFlight,
    );
    final downloaded = await scheduler
        .run<MapEntry<String, int>, _DownloadedObject>(
          items: [
            for (final entry in entries)
              BoundedTransferItem(value: entry, bytes: entry.value),
          ],
          token: token,
          transfer: (entry) async {
            CloudSyncPayload? payload;
            Uint8List? bytes;
            if (localResolver != null) {
              payload = await localResolver.resolveLocalPayload(
                expectedLength: entry.value,
                expectedSha256: entry.key,
              );
            }
            if (payload == null) {
              final read = await backend.readObject(entry.key);
              if (read == null) {
                throw CloudFormatException('object ${entry.key} is missing');
              }
              if (materializer != null) {
                payload = await materializer.materializeRemotePayload(
                  read.bytes,
                  expectedLength: entry.value,
                  expectedSha256: entry.key,
                );
                if (payload.length != entry.value ||
                    payload.sha256 != entry.key) {
                  throw const CloudFormatException(
                    'materialized payload identity mismatch',
                  );
                }
              } else {
                CloudSyncTelemetry.recordHashPass();
                if (read.bytes.length != entry.value ||
                    hashes.sha256.convert(read.bytes).toString() != entry.key) {
                  throw CloudFormatException(
                    'object ${entry.key} failed size or SHA-256 validation',
                  );
                }
                bytes = read.bytes;
              }
            }
            bytesCompleted += entry.value;
            objectsCompleted++;
            onProgress?.call(
              SyncProgress(
                phase: SyncPhase.downloading,
                objectId: entry.key,
                objectsCompleted: objectsCompleted,
                objectsTotal: entries.length,
                bytesCompleted: bytesCompleted,
                bytesTotal: total,
              ),
            );
            return _DownloadedObject(payload: payload, bytes: bytes);
          },
        );
    onProgress?.call(
      SyncProgress(
        phase: SyncPhase.verifying,
        objectsCompleted: entries.length,
        objectsTotal: entries.length,
        bytesCompleted: total,
        bytesTotal: total,
      ),
    );
    final objects = <String, _DownloadedObject>{
      for (var index = 0; index < entries.length; index++)
        entries[index].key: downloaded[index],
    };

    final records = <CloudSyncRecord>[];
    for (final ref in manifest.records) {
      if (ref.deleted) {
        records.add(
          CloudSyncRecord(
            id: ref.recordId,
            kind: ref.kind,
            binary: ref.binary,
            deleted: true,
            tombstoneIdentity: ref.tombstoneIdentity,
          ),
        );
      } else {
        records.add(
          CloudSyncRecord(
            id: ref.recordId,
            kind: ref.kind,
            binary: ref.binary,
            deleted: false,
            bytes: objects[ref.objectId!]!.bytes,
            payload: objects[ref.objectId!]!.payload,
          ),
        );
      }
    }
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
    List<int> encodedManifest,
    OperationToken token,
    SyncProgressCallback? onProgress,
  ) async {
    final manifest = SnapshotManifest.decode(encodedManifest);
    if (manifest.snapshotId != snapshotId) {
      throw const CloudFormatException('snapshot manifest identity mismatch');
    }
    return downloadManifest(manifest, token, onProgress);
  }

  int get _transferConcurrency {
    final requested = backend is ConcurrentCloudObjectUploadBackend
        ? (backend as ConcurrentCloudObjectUploadBackend)
              .maxConcurrentObjectUploads
        : 4;
    return requested.clamp(1, _transferLimits.maxConcurrentItems);
  }
}

final class _DownloadedObject {
  const _DownloadedObject({required this.payload, required this.bytes});

  final CloudSyncPayload? payload;
  final Uint8List? bytes;
}
