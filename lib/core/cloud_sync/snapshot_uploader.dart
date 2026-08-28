import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

import 'backend/cloud_sync_backend.dart';
import 'crypto.dart';
import 'data_source.dart';
import 'journal.dart';
import 'models.dart';
import 'operation.dart';
import 'sync_types.dart';

typedef JournalCheckpoint = Future<void> Function(SyncJournal journal);

class ResumableSnapshotUploader {
  const ResumableSnapshotUploader({
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
    for (final metadata in current.completedObjects) {
      await token.checkpoint();
      final remote = await backend.readObject(metadata.id);
      if (remote == null) {
        throw CloudFormatException(
          'checkpointed object ${metadata.id} is missing',
        );
      }
      metadata.verify(remote.bytes);
    }
    for (
      var index = current.completedObjects.length;
      index < records.length;
      index++
    ) {
      await token.checkpoint();
      final record = records[index];
      final objectId = '${current.snapshotId}.$index';
      final artifactName = 'object-$index.bin';
      var encrypted = await dataSource.readUploadArtifact(
        current.operationId,
        artifactName,
      );
      if (encrypted == null) {
        final clear = await record.encodeForTransport();
        if (clear.length > maxCloudClearObjectBytes) {
          throw const CloudFormatException('record object is too large');
        }
        encrypted = await crypto.encryptObject(
          clear,
          masterKey,
          objectId: objectId,
          kind: record.kind,
        );
        await dataSource.writeUploadArtifact(
          current.operationId,
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
        current.operationId,
        metadataName,
      );
      if (pendingMetadata == null) {
        await dataSource.writeUploadArtifact(
          current.operationId,
          metadataName,
          utf8.encode(jsonEncode(metadata.toJson())),
        );
      } else {
        final persisted = SnapshotObject.fromJson(
          jsonDecode(utf8.decode(pendingMetadata)),
        );
        if (persisted.id != metadata.id ||
            persisted.kind != metadata.kind ||
            persisted.size != metadata.size ||
            persisted.sha256 != metadata.sha256) {
          throw const CloudFormatException(
            'pending object metadata does not match ciphertext',
          );
        }
      }
      onProgress?.call(
        SyncProgress(
          phase: SyncPhase.uploading,
          objectId: objectId,
          objectsCompleted: index,
          objectsTotal: records.length + 1,
          bytesTotal: encrypted.length,
        ),
      );
      await backend.putObject(
        objectId,
        Uint8List.fromList(encrypted),
        sha256: metadata.sha256,
      );
      current = current.copyWith(
        phase: JournalPhase.uploadingObjects,
        completedObjects: [...current.completedObjects, metadata],
        now: now(),
      );
      await checkpoint(current);
      await dataSource.deleteUploadArtifact(current.operationId, artifactName);
      await dataSource.deleteUploadArtifact(current.operationId, metadataName);
    }

    var manifestBytes = await dataSource.readUploadArtifact(
      current.operationId,
      'manifest.bin',
    );
    if (manifestBytes == null) {
      final manifest = SnapshotManifest(
        snapshotId: current.snapshotId,
        createdAt: now().toUtc(),
        objects: current.completedObjects,
      );
      manifestBytes = await crypto.encryptObject(
        Uint8List.fromList(manifest.encode()),
        masterKey,
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
}
