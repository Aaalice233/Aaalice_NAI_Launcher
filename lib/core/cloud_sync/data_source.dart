import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;

import 'models.dart';

typedef CloudPayloadReader = Stream<List<int>> Function();

/// Maximum payload before record JSON/base64 encoding and AES-GCM framing.
/// The fixed reserve covers the largest valid record identity and schema.
const maxCloudRecordPayloadBytes = ((maxCloudClearObjectBytes - 1024) * 3) ~/ 4;

/// Replayable payload reference. Data sources may point this at a file so a
/// snapshot can describe an arbitrarily large library without retaining it.
class CloudSyncPayload {
  const CloudSyncPayload({
    required this.length,
    required this.sha256,
    required this.openRead,
  });

  final int length;
  final String sha256;
  final CloudPayloadReader openRead;

  Future<Uint8List> readBytes() async {
    if (length > maxCloudRecordPayloadBytes) {
      throw const CloudFormatException('record is too large');
    }
    final builder = BytesBuilder(copy: false);
    var read = 0;
    await for (final chunk in openRead()) {
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
  CloudSyncRecord({
    required this.id,
    required this.kind,
    required this.binary,
    required this.deleted,
    Uint8List? bytes,
    CloudSyncPayload? payload,
  }) : bytes = bytes == null ? null : Uint8List.fromList(bytes),
       payload =
           payload ??
           (bytes == null
               ? null
               : CloudSyncPayload(
                   length: bytes.length,
                   sha256: hashes.sha256.convert(bytes).toString(),
                   openRead: () => Stream.value(bytes),
                 )) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(id) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(kind)) {
      throw const CloudFormatException('invalid record identity');
    }
    if (!deleted && this.payload == null) {
      throw const CloudFormatException('live records must contain data');
    }
    if ((this.payload?.length ?? 0) > maxCloudRecordPayloadBytes) {
      throw const CloudFormatException('record is too large');
    }
  }

  final String id;
  final String kind;
  final bool binary;
  final bool deleted;
  final Uint8List? bytes;
  final CloudSyncPayload? payload;

  Map<String, Object?> toJson() => {
    'version': cloudSyncSchemaVersion,
    'id': id,
    'kind': kind,
    'binary': binary,
    'deleted': deleted,
    'data': bytes == null ? null : base64Encode(bytes!),
  };

  factory CloudSyncRecord.decode(List<int> encoded) {
    if (encoded.length > maxCloudClearObjectBytes) {
      throw const CloudFormatException('record object is too large');
    }
    try {
      final json = strictJsonMap(jsonDecode(utf8.decode(encoded)), {
        'version',
        'id',
        'kind',
        'binary',
        'deleted',
        'data',
      });
      if (json['version'] != cloudSyncSchemaVersion ||
          json['id'] is! String ||
          json['kind'] is! String ||
          json['binary'] is! bool ||
          json['deleted'] is! bool ||
          (json['data'] != null && json['data'] is! String)) {
        throw const CloudFormatException('invalid record schema');
      }
      Uint8List? bytes;
      if (json['data'] case final String value) {
        bytes = base64Decode(value);
      }
      return CloudSyncRecord(
        id: json['id']! as String,
        kind: json['kind']! as String,
        binary: json['binary']! as bool,
        deleted: json['deleted']! as bool,
        bytes: bytes,
      );
    } on CloudFormatException {
      rethrow;
    } catch (error) {
      throw CloudFormatException('invalid record JSON: $error');
    }
  }

  Uint8List encode() {
    final encoded = Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
    if (encoded.length > maxCloudClearObjectBytes) {
      throw const CloudFormatException('record object is too large');
    }
    return encoded;
  }

  Future<Uint8List> encodeForTransport() async {
    if (bytes != null || payload == null) return encode();
    final data = await payload!.readBytes();
    return CloudSyncRecord(
      id: id,
      kind: kind,
      binary: binary,
      deleted: deleted,
      bytes: data,
    ).encode();
  }

  Future<Uint8List?> readBytes() async => bytes ?? await payload?.readBytes();

  @override
  bool operator ==(Object other) =>
      other is CloudSyncRecord &&
      id == other.id &&
      kind == other.kind &&
      binary == other.binary &&
      deleted == other.deleted &&
      payload?.sha256 == other.payload?.sha256;

  @override
  int get hashCode => Object.hash(id, kind, binary, deleted, payload?.sha256);
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

  Future<void> stage(String operationId, CloudSyncSnapshotData snapshot);

  /// Reads the validated, durable target written by [stage].
  Future<CloudSyncSnapshotData> readStaged(String operationId);

  /// Stable digest of the complete staged target index.
  Future<String> stagedFingerprint(String operationId);

  Future<void> apply(String operationId);

  Future<void> rollback(String operationId);

  /// Restores the recovery point without deleting the staged target. Used
  /// after a process dies while adapters may have been partially applied.
  Future<void> rollbackForRecovery(String operationId);

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

/// Optional streaming bridge used by coordinators after decoding one remote
/// object. The returned record must not retain [record.bytes] in memory.
abstract interface class CloudSyncPayloadMaterializer {
  Future<void> beginRemoteMaterialization(String snapshotId);

  Future<CloudSyncRecord> materializeRemoteRecord(CloudSyncRecord record);
}
