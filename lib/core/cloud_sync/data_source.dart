import 'dart:collection';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;

import 'models.dart';
import 'telemetry.dart';

typedef CloudPayloadReader = Stream<List<int>> Function();

/// Payload bytes are stored directly as immutable remote objects.
const maxCloudRecordPayloadBytes = maxCloudObjectBytes;

/// Replayable payload reference. Data sources may point this at a file so a
/// snapshot can describe an arbitrarily large library without retaining it.
class CloudSyncPayload {
  CloudSyncPayload({
    required this.length,
    required this.sha256,
    required this.openRead,
  }) {
    if (length < 0 || length > maxCloudRecordPayloadBytes) {
      throw const CloudFormatException('record payload size is invalid');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw const CloudFormatException('record payload SHA-256 is invalid');
    }
  }

  final int length;
  final String sha256;
  final CloudPayloadReader openRead;

  Stream<List<int>> readStream() async* {
    CloudSyncTelemetry.recordPayloadOpen();
    await for (final chunk in openRead()) {
      CloudSyncTelemetry.recordLocalRead(chunk.length);
      yield chunk;
    }
  }

  Future<Uint8List> readBytes() async {
    if (length > maxCloudRecordPayloadBytes) {
      throw const CloudFormatException('record is too large');
    }
    final builder = BytesBuilder(copy: false);
    var read = 0;
    await for (final chunk in readStream()) {
      read += chunk.length;
      if (read > length) {
        throw const CloudFormatException('record payload length mismatch');
      }
      builder.add(chunk);
    }
    if (read != length) {
      throw const CloudFormatException('record payload length mismatch');
    }
    final bytes = builder.takeBytes();
    if (hashes.sha256.convert(bytes).toString() != sha256) {
      throw const CloudFormatException('record payload checksum mismatch');
    }
    return bytes;
  }
}

class CloudSyncRecord {
  factory CloudSyncRecord({
    required String id,
    required String kind,
    required bool binary,
    required bool deleted,
    Uint8List? bytes,
    CloudSyncPayload? payload,
    String? tombstoneIdentity,
  }) {
    final copiedBytes = bytes == null ? null : Uint8List.fromList(bytes);
    return CloudSyncRecord._(
      id: id,
      kind: kind,
      binary: binary,
      deleted: deleted,
      bytes: copiedBytes,
      payload:
          payload ??
          (copiedBytes == null
              ? null
              : CloudSyncPayload(
                  length: copiedBytes.length,
                  sha256: hashes.sha256.convert(copiedBytes).toString(),
                  openRead: () => Stream.value(copiedBytes),
                )),
      tombstoneIdentity: tombstoneIdentity,
    );
  }

  CloudSyncRecord._({
    required this.id,
    required this.kind,
    required this.binary,
    required this.deleted,
    required this.bytes,
    required this.payload,
    required this.tombstoneIdentity,
  }) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,65534}$').hasMatch(id) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(kind)) {
      throw const CloudFormatException('invalid record identity');
    }
    if (deleted != (payload == null)) {
      throw const CloudFormatException(
        'live records require data and tombstones forbid it',
      );
    }
    if (!deleted && tombstoneIdentity != null) {
      throw const CloudFormatException(
        'live records must not contain tombstone identity',
      );
    }
    final identity = tombstoneIdentity;
    if (identity != null && (identity.isEmpty || identity.length > 64 * 1024)) {
      throw const CloudFormatException('tombstone identity is invalid');
    }
  }

  final String id;
  final String kind;
  final bool binary;
  final bool deleted;
  final Uint8List? bytes;
  final CloudSyncPayload? payload;
  final String? tombstoneIdentity;

  Future<Uint8List?> readBytes() async => bytes ?? await payload?.readBytes();

  @override
  bool operator ==(Object other) =>
      other is CloudSyncRecord &&
      id == other.id &&
      kind == other.kind &&
      binary == other.binary &&
      deleted == other.deleted &&
      payload?.length == other.payload?.length &&
      payload?.sha256 == other.payload?.sha256 &&
      tombstoneIdentity == other.tombstoneIdentity;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    binary,
    deleted,
    payload?.length,
    payload?.sha256,
    tombstoneIdentity,
  );
}

class CloudSyncSnapshotData {
  CloudSyncSnapshotData(Iterable<CloudSyncRecord> records)
    : records = UnmodifiableMapView({
        for (final record in records) record.id: record,
      }) {
    if (this.records.length != records.length) {
      throw const CloudFormatException('duplicate record id');
    }
  }

  const CloudSyncSnapshotData.empty() : records = const {};

  final Map<String, CloudSyncRecord> records;
}

abstract interface class CloudSyncDataSource {
  Future<CloudSyncSnapshotData> captureLocal();

  Future<CloudSyncSnapshotData?> readBase();

  Future<void> stage(
    String operationId,
    CloudSyncSnapshotData snapshot, {
    CloudSyncSnapshotData? recoveryPoint,
  });

  /// Reads the validated, durable target written by [stage].
  Future<CloudSyncSnapshotData> readStaged(String operationId);

  /// Stable digest of the complete staged target index.
  Future<String> stagedFingerprint(String operationId);

  Future<void> apply(String operationId);

  Future<void> rollback(String operationId);

  /// Restores the recovery point without deleting the staged target. Used
  /// after a process dies while adapters may have been partially applied.
  Future<void> rollbackForRecovery(String operationId);

  /// Restores the base that was current when [stage] began. This is separate
  /// from local rollback because [saveBase] may have published a new base
  /// before the operation's completed checkpoint became durable.
  Future<void> restoreBaseForRecovery(String operationId);

  Future<void> saveBase(CloudSyncSnapshotData snapshot, String snapshotId);

  Future<void> writeUploadArtifact(
    String operationId,
    String name,
    List<int> bytes,
  );

  Future<List<int>?> readUploadArtifact(String operationId, String name);

  Future<void> deleteUploadArtifact(String operationId, String name);

  /// Removes staging, recovery, and pending upload material.
  Future<void> completeOperation(String operationId);
}

/// Optional hook for data sources that must augment a captured local recovery
/// point with allowlisted tombstones for records introduced by [target].
abstract interface class CloudSyncRecoveryPointBuilder {
  Future<CloudSyncSnapshotData> buildRecoveryPoint({
    required CloudSyncSnapshotData local,
    required CloudSyncSnapshotData target,
  });
}

/// Marker contract for payloads whose declared length and SHA-256 were
/// verified while their immutable backing storage was created.
abstract interface class VerifiedCloudSyncPayload {}

/// Optional bridge that verifies and durably materializes one remote object.
abstract interface class CloudSyncPayloadMaterializer {
  Future<CloudSyncPayload> materializeRemotePayload(
    List<int> bytes, {
    required int expectedLength,
    required String expectedSha256,
  });
}

/// Optional bridge for reusing a locally verified content-addressed object
/// before issuing a remote download.
abstract interface class CloudSyncLocalPayloadResolver {
  Future<CloudSyncPayload?> resolveLocalPayload({
    required int expectedLength,
    required String expectedSha256,
  });
}

class CloudSyncPreparedPreview {
  const CloudSyncPreparedPreview({
    required this.local,
    required this.base,
    required this.remoteRevision,
    required this.remoteHead,
    required this.remote,
  });

  final CloudSyncSnapshotData local;
  final CloudSyncSnapshotData base;
  final String? remoteRevision;
  final SnapshotHead? remoteHead;
  final CloudSyncSnapshotData? remote;
}

class CloudSyncPreparedRestore {
  const CloudSyncPreparedRestore({
    required this.local,
    required this.target,
    required this.remoteRevision,
  });

  final CloudSyncSnapshotData local;
  final CloudSyncSnapshotData target;
  final String? remoteRevision;
}

/// Optional durable preview store. Snapshot descriptors reference verified CAS
/// blobs, so confirmation after coordinator reconstruction does not redownload.
abstract interface class CloudSyncPreviewStore {
  Future<void> saveSyncPreview(CloudSyncPreparedPreview preview);
  Future<CloudSyncPreparedPreview?> readSyncPreview();
  Future<void> deleteSyncPreview();
  Future<void> saveRestorePreview(
    String snapshotId,
    CloudSyncPreparedRestore preview,
  );
  Future<CloudSyncPreparedRestore?> readRestorePreview(String snapshotId);
  Future<void> deleteRestorePreviews();
}
