import 'data_source.dart';
import 'models.dart';
import 'operation.dart';
import 'snapshot_object_packer.dart';

/// Prepares and validates immutable upload artifacts before any remote writes.
class SnapshotUploadPlan {
  const SnapshotUploadPlan(this.manifest, this.manifestBytes, this.payloads);

  final SnapshotManifest manifest;
  final List<int> manifestBytes;
  final Map<String, CloudSyncPayload> payloads;

  static Future<SnapshotUploadPlan> prepare({
    required CloudSyncDataSource dataSource,
    required CloudSyncSnapshotData snapshot,
    required String operationId,
    required String snapshotId,
    required DateTime Function() now,
    required OperationToken token,
  }) async {
    final records = snapshot.records.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final refs = [for (final record in records) _reference(record)];
    final payloads = <String, CloudSyncPayload>{};
    for (final record in records) {
      final payload = record.payload;
      if (payload != null) payloads.putIfAbsent(payload.sha256, () => payload);
    }
    final persisted = await dataSource.readUploadArtifact(
      operationId,
      'manifest.json',
    );
    if (persisted != null) {
      final manifest = SnapshotManifest.decode(persisted);
      if (manifest.snapshotId != snapshotId ||
          !_sameRefs(manifest.records, refs)) {
        throw const CloudFormatException(
          'pending manifest does not match staged snapshot',
        );
      }
      await SnapshotObjectPacker.restore(manifest.packs, payloads, token);
      return SnapshotUploadPlan(manifest, persisted, payloads);
    }
    final packs = await SnapshotObjectPacker.pack(refs, payloads, token);
    final manifest = SnapshotManifest(
      snapshotId: snapshotId,
      createdAt: now().toUtc(),
      records: refs,
      packs: packs,
    );
    final bytes = manifest.encode();
    await dataSource.writeUploadArtifact(operationId, 'manifest.json', bytes);
    return SnapshotUploadPlan(manifest, bytes, payloads);
  }

  static SnapshotRecordRef _reference(CloudSyncRecord record) =>
      SnapshotRecordRef(
        recordId: record.id,
        kind: record.kind,
        binary: record.binary,
        deleted: record.deleted,
        objectId: record.payload?.sha256,
        size: record.payload?.length,
        tombstoneIdentity: record.tombstoneIdentity,
      );

  static bool _sameRefs(
    List<SnapshotRecordRef> left,
    List<SnapshotRecordRef> right,
  ) {
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
