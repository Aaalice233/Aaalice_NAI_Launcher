import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;

import 'backend/cloud_sync_backend.dart';
import 'bounded_transfer_scheduler.dart';
import 'data_source.dart';
import 'journal.dart';
import 'models.dart';
import 'operation.dart';
import 'sync_types.dart';
import 'telemetry.dart';

typedef JournalCheckpoint = Future<void> Function(SyncJournal journal);

class ResumableSnapshotUploader {
  const ResumableSnapshotUploader({
    required this.backend,
    required this.dataSource,
    required this.now,
    this.transferLimits,
  });

  final CloudSyncBackend backend;
  final CloudSyncDataSource dataSource;
  final DateTime Function() now;
  final CloudTransferLimits? transferLimits;

  CloudTransferLimits get _transferLimits =>
      transferLimits ?? cloudTransferPlatformLimits;

  Future<SyncJournal> resume({
    required SyncJournal journal,
    required CloudSyncSnapshotData snapshot,
    required OperationToken token,
    required JournalCheckpoint checkpoint,
    SyncProgressCallback? onProgress,
  }) async {
    var current = journal;
    final records = snapshot.records.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final refs = <SnapshotRecordRef>[];
    final uniquePayloads = <String, CloudSyncPayload>{};
    for (final record in records) {
      final payload = record.deleted ? null : record.payload;
      refs.add(
        SnapshotRecordRef(
          recordId: record.id,
          kind: record.kind,
          binary: record.binary,
          deleted: record.deleted,
          objectId: payload?.sha256,
          size: payload?.length,
          tombstoneIdentity: record.tombstoneIdentity,
        ),
      );
      if (payload != null) {
        uniquePayloads.putIfAbsent(payload.sha256, () => payload);
      }
    }
    final objectIds = uniquePayloads.keys.toList(growable: false);
    _validateCompletedSet(current, objectIds);
    await _verifyCompletedObjects(current, uniquePayloads, token);
    final existingObjectIds = backend is CloudObjectInventoryBackend
        ? await (backend as CloudObjectInventoryBackend).findExistingObjects({
            for (final entry in uniquePayloads.entries)
              if (!current.completedObjectIds.contains(entry.key))
                entry.key: entry.value.length,
          })
        : const <String>{};
    if (existingObjectIds.any((id) => !uniquePayloads.containsKey(id))) {
      throw const CloudFormatException(
        'backend inventory returned an unknown object',
      );
    }

    var manifestBytes = await dataSource.readUploadArtifact(
      current.operationId,
      'manifest.json',
    );
    if (manifestBytes == null) {
      manifestBytes = SnapshotManifest(
        snapshotId: current.snapshotId,
        createdAt: now().toUtc(),
        records: refs,
      ).encode();
      await dataSource.writeUploadArtifact(
        current.operationId,
        'manifest.json',
        manifestBytes,
      );
    } else {
      final persisted = SnapshotManifest.decode(manifestBytes);
      if (persisted.snapshotId != current.snapshotId ||
          !_sameRefs(persisted.records, refs)) {
        throw const CloudFormatException(
          'pending manifest does not match staged snapshot',
        );
      }
    }
    final manifestSha = hashes.sha256.convert(manifestBytes).toString();
    if (current.manifestSha256 != null &&
        current.manifestSha256 != manifestSha) {
      throw const CloudFormatException('pending manifest fingerprint mismatch');
    }

    final totalBytes =
        uniquePayloads.values.fold<int>(
          0,
          (sum, payload) => sum + payload.length,
        ) +
        manifestBytes.length;
    final completedIds = current.completedObjectIds.toSet();
    var completedObjects = completedIds.length;
    var completedBytes = completedIds.fold<int>(
      0,
      (sum, id) => sum + uniquePayloads[id]!.length,
    );
    final totalObjects = objectIds.length + 1;
    final reusedObjects = objectIds.where(existingObjectIds.contains).length;
    if (reusedObjects > 0) {
      onProgress?.call(
        SyncProgress(
          phase: SyncPhase.reusing,
          objectsCompleted: reusedObjects,
          objectsTotal: objectIds.length,
          objectsReused: reusedObjects,
        ),
      );
    }
    onProgress?.call(
      SyncProgress(
        phase: SyncPhase.uploading,
        objectsCompleted: completedObjects,
        objectsTotal: totalObjects,
        bytesCompleted: completedBytes,
        bytesTotal: totalBytes,
        objectsReused: reusedObjects,
      ),
    );

    const checkpointBatchSize = 128;
    var checkpointTail = Future<void>.value();
    var checkpointedCount = completedIds.length;

    Future<void> flushCompleted() {
      if (completedIds.length == checkpointedCount) return checkpointTail;
      checkpointedCount = completedIds.length;
      final canonicalIds = completedIds.toList()..sort();
      current = current.copyWith(
        phase: JournalPhase.uploadingObjects,
        completedObjectIds: canonicalIds,
        now: now(),
      );
      final checkpointValue = current;
      checkpointTail = checkpointTail.then((_) => checkpoint(checkpointValue));
      return checkpointTail;
    }

    Future<void> recordCompleted(String objectId) {
      completedIds.add(objectId);
      if (completedIds.length - checkpointedCount < checkpointBatchSize) {
        return Future<void>.value();
      }
      return flushCompleted();
    }

    final pending = [
      for (final id in objectIds)
        if (!completedIds.contains(id)) id,
    ];
    final scheduler = BoundedTransferScheduler(
      maxConcurrentItems: _uploadConcurrency,
      maxBytesInFlight: _transferLimits.maxBytesInFlight,
    );
    try {
      await scheduler.run<String, void>(
        items: [
          for (final id in pending)
            BoundedTransferItem(value: id, bytes: uniquePayloads[id]!.length),
        ],
        token: token,
        transfer: (objectId) async {
          final payload = uniquePayloads[objectId]!;
          await _ensureObject(
            objectId,
            payload,
            knownExisting: existingObjectIds.contains(objectId),
          );
          completedObjects++;
          completedBytes += payload.length;
          onProgress?.call(
            SyncProgress(
              phase: SyncPhase.uploading,
              objectId: objectId,
              objectsCompleted: completedObjects,
              objectsTotal: totalObjects,
              bytesCompleted: completedBytes,
              bytesTotal: totalBytes,
              objectsReused: reusedObjects,
            ),
          );
          await recordCompleted(objectId);
        },
      );
    } finally {
      await flushCompleted();
    }

    if (current.phase != JournalPhase.uploadingManifest) {
      current = current.copyWith(
        phase: JournalPhase.uploadingManifest,
        manifestSha256: manifestSha,
        now: now(),
      );
      await checkpoint(current);
    }
    await token.checkpoint();
    await backend.putSnapshotManifest(
      current.snapshotId,
      Uint8List.fromList(manifestBytes),
      sha256: manifestSha,
      payloadVerified: true,
    );
    completedBytes += manifestBytes.length;
    onProgress?.call(
      SyncProgress(
        phase: SyncPhase.uploading,
        objectId: current.snapshotId,
        objectsCompleted: totalObjects,
        objectsTotal: totalObjects,
        bytesCompleted: completedBytes,
        bytesTotal: totalBytes,
        objectsReused: reusedObjects,
      ),
    );

    var headBytes = await dataSource.readUploadArtifact(
      current.operationId,
      'head.json',
    );
    headBytes ??= SnapshotHead(
      snapshotId: current.snapshotId,
      manifestSha256: manifestSha,
      updatedAt: now().toUtc(),
    ).encode();
    if (await dataSource.readUploadArtifact(current.operationId, 'head.json') ==
        null) {
      await dataSource.writeUploadArtifact(
        current.operationId,
        'head.json',
        headBytes,
      );
    }
    current = current.copyWith(
      phase: JournalPhase.committingHead,
      manifestSha256: manifestSha,
      now: now(),
    );
    await checkpoint(current);
    onProgress?.call(
      SyncProgress(
        phase: SyncPhase.committing,
        objectsCompleted: totalObjects,
        objectsTotal: totalObjects,
        bytesCompleted: totalBytes,
        bytesTotal: totalBytes,
        objectsReused: reusedObjects,
      ),
    );
    await token.checkpoint();
    final remote = await backend.readHead();
    if (remote != null) {
      final head = SnapshotHead.decode(remote.bytes);
      if (head.snapshotId == current.snapshotId) {
        if (head.manifestSha256 != manifestSha) {
          throw const CloudFormatException('committed HEAD manifest mismatch');
        }
        return _checkpointCommitted(current, token, checkpoint);
      }
    }
    if (remote?.revision != current.expectedRevision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Remote HEAD advanced while resuming the pending sync.',
      );
    }
    await backend.commitHead(
      Uint8List.fromList(headBytes),
      expectedRevision: current.expectedRevision,
    );
    return _checkpointCommitted(current, token, checkpoint);
  }

  Future<void> _ensureObject(
    String objectId,
    CloudSyncPayload payload, {
    required bool knownExisting,
  }) async {
    if (knownExisting) return;
    if (backend is! CloudObjectInventoryBackend) {
      final existing = await backend.readObject(objectId);
      if (existing != null) {
        _verifyObject(objectId, payload.length, existing.bytes);
        return;
      }
    }
    final bytes = await _readPayloadForUpload(payload);
    await backend.putObject(
      objectId,
      bytes,
      sha256: objectId,
      payloadVerified: true,
    );
  }

  Future<Uint8List> _readPayloadForUpload(CloudSyncPayload payload) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in payload.readStream()) {
      length += chunk.length;
      if (length > payload.length) {
        throw const CloudFormatException('record payload length mismatch');
      }
      builder.add(chunk);
    }
    if (length != payload.length) {
      throw const CloudFormatException('record payload length mismatch');
    }
    final bytes = builder.takeBytes();
    if (payload is! VerifiedCloudSyncPayload) {
      CloudSyncTelemetry.recordHashPass();
    }
    if (payload is! VerifiedCloudSyncPayload &&
        hashes.sha256.convert(bytes).toString() != payload.sha256) {
      throw const CloudFormatException('record payload checksum mismatch');
    }
    return bytes;
  }

  Future<void> _verifyCompletedObjects(
    SyncJournal journal,
    Map<String, CloudSyncPayload> payloads,
    OperationToken token,
  ) async {
    final scheduler = BoundedTransferScheduler(
      maxConcurrentItems: _uploadConcurrency,
      maxBytesInFlight: _transferLimits.maxBytesInFlight,
    );
    await scheduler.run<String, void>(
      items: [
        for (final id in journal.completedObjectIds)
          BoundedTransferItem(value: id, bytes: payloads[id]!.length),
      ],
      token: token,
      transfer: (id) async {
        final remote = await backend.readObject(id);
        if (remote == null) {
          throw CloudFormatException('checkpointed object $id is missing');
        }
        _verifyObject(id, payloads[id]!.length, remote.bytes);
      },
    );
  }

  void _verifyObject(String objectId, int size, List<int> bytes) {
    if (bytes.length != size ||
        hashes.sha256.convert(bytes).toString() != objectId) {
      throw CloudFormatException(
        'object $objectId failed size or SHA-256 validation',
      );
    }
  }

  int get _uploadConcurrency {
    final requested = backend is ConcurrentCloudObjectUploadBackend
        ? (backend as ConcurrentCloudObjectUploadBackend)
              .maxConcurrentObjectUploads
        : 1;
    return requested.clamp(1, _transferLimits.maxConcurrentItems);
  }

  Future<SyncJournal> _checkpointCommitted(
    SyncJournal current,
    OperationToken token,
    JournalCheckpoint checkpoint,
  ) async {
    final committed = current.copyWith(
      phase: current.appliesLocally
          ? JournalPhase.applyStarted
          : JournalPhase.savingBase,
      now: now(),
    );
    await checkpoint(committed);
    await token.checkpoint();
    return committed;
  }

  void _validateCompletedSet(SyncJournal journal, List<String> objectIds) {
    final expected = objectIds.toSet();
    if (journal.completedObjectIds.any((id) => !expected.contains(id))) {
      throw const CloudFormatException(
        'journal checkpoint contains an unknown object',
      );
    }
  }

  bool _sameRefs(List<SnapshotRecordRef> left, List<SnapshotRecordRef> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.recordId != b.recordId ||
          a.kind != b.kind ||
          a.binary != b.binary ||
          a.deleted != b.deleted ||
          a.objectId != b.objectId ||
          a.size != b.size ||
          a.tombstoneIdentity != b.tombstoneIdentity) {
        return false;
      }
    }
    return true;
  }
}
