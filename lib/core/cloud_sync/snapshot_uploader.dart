import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'backend/cloud_sync_backend.dart';
import 'data_source.dart';
import 'journal.dart';
import 'models.dart';
import 'operation.dart';
import 'object_codec.dart';
import 'sync_types.dart';

typedef JournalCheckpoint = Future<void> Function(SyncJournal journal);

class ResumableSnapshotUploader {
  const ResumableSnapshotUploader({
    required this.backend,
    required this.dataSource,
    required this.codec,
    required this.now,
  });

  final CloudSyncBackend backend;
  final CloudSyncDataSource dataSource;
  final CloudObjectCodec codec;
  final DateTime Function() now;

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
    _validateCompletedPrefix(current, records);
    await _verifyCompletedObjects(current, token);

    final metadata = List<SnapshotObject?>.filled(records.length, null);
    for (var index = 0; index < current.completedObjects.length; index++) {
      metadata[index] = current.completedObjects[index];
    }
    for (
      var index = current.completedObjects.length;
      index < records.length;
      index++
    ) {
      await token.checkpoint();
      metadata[index] = await _prepareObject(current, records[index], index);
      onProgress?.call(
        SyncProgress(
          phase: SyncPhase.preparing,
          objectId: metadata[index]!.id,
          objectsCompleted: index + 1,
          objectsTotal: records.length,
        ),
      );
    }
    final allMetadata = metadata.whereType<SnapshotObject>().toList(
      growable: false,
    );
    if (allMetadata.length != records.length) {
      throw const CloudFormatException(
        'prepared object metadata is incomplete',
      );
    }

    var manifestBytes = await dataSource.readUploadArtifact(
      current.operationId,
      'manifest.bin',
    );
    if (manifestBytes == null) {
      final manifest = SnapshotManifest(
        snapshotId: current.snapshotId,
        createdAt: now().toUtc(),
        objects: allMetadata,
        encoding: codec.encoding,
      );
      manifestBytes = await codec.encode(
        Uint8List.fromList(manifest.encode()),
        objectId: current.snapshotId,
        kind: 'manifest',
      );
      await dataSource.writeUploadArtifact(
        current.operationId,
        'manifest.bin',
        manifestBytes,
      );
    }
    final manifestSha = hashes.sha256.convert(manifestBytes).toString();
    if (current.manifestSha256 != null &&
        current.manifestSha256 != manifestSha) {
      throw const CloudFormatException('pending manifest fingerprint mismatch');
    }

    final totalBytes =
        allMetadata.fold<int>(0, (sum, object) => sum + object.size) +
        manifestBytes.length;
    var completedObjects = current.completedObjects.length;
    var completedBytes = current.completedObjects.fold<int>(
      0,
      (sum, object) => sum + object.size,
    );
    final totalObjects = records.length + 1;
    onProgress?.call(
      SyncProgress(
        phase: SyncPhase.uploading,
        objectsCompleted: completedObjects,
        objectsTotal: totalObjects,
        bytesCompleted: completedBytes,
        bytesTotal: totalBytes,
      ),
    );

    final concurrency = _uploadConcurrency;
    for (
      var start = current.completedObjects.length;
      start < records.length;
      start += concurrency
    ) {
      await token.checkpoint();
      final end = (start + concurrency).clamp(0, records.length);
      final batch = <Future<void>>[];
      for (var index = start; index < end; index++) {
        final object = allMetadata[index];
        batch.add(() async {
          final artifactName = 'object-$index.bin';
          final encrypted = await dataSource.readUploadArtifact(
            current.operationId,
            artifactName,
          );
          if (encrypted == null) {
            throw CloudFormatException(
              'prepared upload artifact $artifactName is missing',
            );
          }
          await backend.putObject(
            object.id,
            encrypted is Uint8List ? encrypted : Uint8List.fromList(encrypted),
            sha256: object.sha256,
          );
          completedObjects++;
          completedBytes += object.size;
          onProgress?.call(
            SyncProgress(
              phase: SyncPhase.uploading,
              objectId: object.id,
              objectsCompleted: completedObjects,
              objectsTotal: totalObjects,
              bytesCompleted: completedBytes,
              bytesTotal: totalBytes,
            ),
          );
        }());
      }
      await Future.wait(batch);
      current = current.copyWith(
        phase: JournalPhase.uploadingObjects,
        completedObjects: allMetadata.sublist(0, end),
        now: now(),
      );
      await checkpoint(current);
      for (var index = start; index < end; index++) {
        await dataSource.deleteUploadArtifact(
          current.operationId,
          'object-$index.bin',
        );
        await dataSource.deleteUploadArtifact(
          current.operationId,
          'object-$index.json',
        );
      }
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
      encoding: codec.encoding,
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

  Future<SnapshotObject> _prepareObject(
    SyncJournal journal,
    CloudSyncRecord record,
    int index,
  ) async {
    final objectId = '${journal.snapshotId}.$index';
    final artifactName = 'object-$index.bin';
    var encrypted = await dataSource.readUploadArtifact(
      journal.operationId,
      artifactName,
    );
    if (encrypted == null) {
      final clear = await record.encodeForTransport();
      if (clear.length > codec.maxClearObjectBytes) {
        throw const CloudFormatException('record object is too large');
      }
      encrypted = await codec.encode(
        clear,
        objectId: objectId,
        kind: record.kind,
      );
      await dataSource.writeUploadArtifact(
        journal.operationId,
        artifactName,
        encrypted,
      );
    }
    final metadata = SnapshotObject(
      id: objectId,
      kind: record.kind,
      size: encrypted.length,
      sha256: hashes.sha256.convert(encrypted).toString(),
    );
    final metadataName = 'object-$index.json';
    final pendingMetadata = await dataSource.readUploadArtifact(
      journal.operationId,
      metadataName,
    );
    if (pendingMetadata == null) {
      await dataSource.writeUploadArtifact(
        journal.operationId,
        metadataName,
        utf8.encode(jsonEncode(metadata.toJson())),
      );
    } else {
      final persisted = SnapshotObject.fromJson(
        jsonDecode(utf8.decode(pendingMetadata)),
      );
      if (!_sameMetadata(persisted, metadata)) {
        throw const CloudFormatException(
          'pending object metadata does not match ciphertext',
        );
      }
    }
    return metadata;
  }

  Future<void> _verifyCompletedObjects(
    SyncJournal journal,
    OperationToken token,
  ) async {
    final concurrency = _uploadConcurrency;
    for (
      var start = 0;
      start < journal.completedObjects.length;
      start += concurrency
    ) {
      await token.checkpoint();
      final end = (start + concurrency).clamp(
        0,
        journal.completedObjects.length,
      );
      await Future.wait([
        for (var index = start; index < end; index++)
          () async {
            final metadata = journal.completedObjects[index];
            final remote = await backend.readObject(metadata.id);
            if (remote == null) {
              throw CloudFormatException(
                'checkpointed object ${metadata.id} is missing',
              );
            }
            metadata.verify(remote.bytes);
          }(),
      ]);
    }
  }

  int get _uploadConcurrency {
    final requested = backend is ConcurrentCloudObjectUploadBackend
        ? (backend as ConcurrentCloudObjectUploadBackend)
              .maxConcurrentObjectUploads
        : 1;
    return requested.clamp(1, 8);
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
    // Persist the irreversible remote commit before cancellation is observed.
    await checkpoint(committed);
    await token.checkpoint();
    return committed;
  }

  void _validateCompletedPrefix(
    SyncJournal journal,
    List<CloudSyncRecord> records,
  ) {
    if (journal.completedObjects.length > records.length) {
      throw const CloudFormatException('journal has excess objects');
    }
    for (var index = 0; index < journal.completedObjects.length; index++) {
      final metadata = journal.completedObjects[index];
      if (metadata.id != '${journal.snapshotId}.$index' ||
          metadata.kind != records[index].kind) {
        throw const CloudFormatException('journal object order mismatch');
      }
    }
  }

  static bool _sameMetadata(SnapshotObject left, SnapshotObject right) =>
      left.id == right.id &&
      left.kind == right.kind &&
      left.size == right.size &&
      left.sha256 == right.sha256;
}
