import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_transfer.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_uploader.dart';

/// Exercises the production transport against each provider's HTTP fixture.
Future<void> verifyPackedSnapshotRoundTrip(
  CloudSyncBackend writer,
  CloudSyncBackend reader,
) async {
  await writer.testCapability();
  final source = PackedSnapshotArtifacts();
  final oldRecord = configRecord('old-setting', 1);
  final legacy = SnapshotManifest(
    version: 2,
    snapshotId: 'legacy-snapshot',
    createdAt: DateTime.utc(2025),
    records: [recordRef(oldRecord)],
  );
  final oldBytes = await oldRecord.readBytes();
  await writer.putObject(
    oldRecord.payload!.sha256,
    oldBytes!,
    sha256: oldRecord.payload!.sha256,
  );
  final legacyBytes = Uint8List.fromList(legacy.encode());
  final manifestHash = hashes.sha256.convert(legacyBytes).toString();
  await writer.putSnapshotManifest(
    legacy.snapshotId,
    legacyBytes,
    sha256: manifestHash,
  );
  await writer.commitHead(
    Uint8List.fromList(
      SnapshotHead(
        version: 2,
        snapshotId: legacy.snapshotId,
        manifestSha256: manifestHash,
        updatedAt: DateTime.utc(2025),
      ).encode(),
    ),
    expectedRevision: null,
  );

  final legacyHead = SnapshotHead.decode((await reader.readHead())!.bytes);
  final transfer = CloudSnapshotTransfer(backend: reader, dataSource: source);
  final restoredOld = await transfer.downloadHead(
    legacyHead,
    OperationToken(),
    null,
  );
  expect(restoredOld.records[oldRecord.id], oldRecord);

  final snapshot = CloudSyncSnapshotData([
    for (var index = 0; index < 800; index++)
      configRecord('config-$index', index),
    CloudSyncRecord(
      id: 'large-resource',
      kind: 'resource',
      binary: true,
      deleted: false,
      bytes: Uint8List(130 * 1024)..[0] = 37,
    ),
    CloudSyncRecord(
      id: 'removed',
      kind: 'metadata',
      binary: false,
      deleted: true,
      tombstoneIdentity: 'legacy-deletion-identity',
    ),
  ]);
  await ResumableSnapshotUploader(
    backend: writer,
    dataSource: source,
    now: () => DateTime.utc(2026),
  ).resume(
    journal: uploadJournal(
      expectedRevision: (await writer.readHead())!.revision,
    ),
    snapshot: snapshot,
    token: OperationToken(),
    checkpoint: (_) async {},
  );
  final head = SnapshotHead.decode((await reader.readHead())!.bytes);
  final manifest = SnapshotManifest.decode(
    (await reader.readSnapshotManifest(head.snapshotId))!.bytes,
  );
  expect(manifest.packs, hasLength(1));
  expect(manifest.packs.values.single, hasLength(800));
  final progress = <int>[];
  final downloaded = await transfer.downloadHead(
    head,
    OperationToken(),
    (value) => progress.add(value.objectsTotal),
  );
  expect(downloaded.records, snapshot.records);
  // Eight hundred configurations plus one binary resource use two object reads.
  expect(progress.toSet(), {2});
  for (final record in snapshot.records.values) {
    expect(
      await downloaded.records[record.id]!.readBytes(),
      await record.readBytes(),
    );
  }
  final historical = await transfer.downloadId(
    legacy.snapshotId,
    OperationToken(),
    null,
  );
  expect(historical.records, restoredOld.records);
}

CloudSyncRecord configRecord(String id, int index) => CloudSyncRecord(
  id: id,
  kind: 'metadata',
  binary: false,
  deleted: false,
  bytes: Uint8List.fromList(
    utf8.encode(jsonEncode({'value': index, 'text': '跨设备保留的固定词与设置 $index'})),
  ),
);

SnapshotRecordRef recordRef(CloudSyncRecord record) => SnapshotRecordRef(
  recordId: record.id,
  kind: record.kind,
  binary: record.binary,
  deleted: record.deleted,
  objectId: record.payload?.sha256,
  size: record.payload?.length,
  tombstoneIdentity: record.tombstoneIdentity,
);

SyncJournal uploadJournal({String? expectedRevision}) => SyncJournal(
  operationId: 'packed-upload',
  operation: JournalOperation.uploadLocal,
  phase: JournalPhase.prepared,
  updatedAt: DateTime.utc(2026),
  snapshotId: 'packed-snapshot',
  targetFingerprint: 'a' * 64,
  expectedRevision: expectedRevision,
  uploadRequired: true,
);

class PackedSnapshotArtifacts extends Fake implements CloudSyncDataSource {
  final Map<String, List<int>> artifacts = {};
  @override
  Future<List<int>?> readUploadArtifact(
    String operationId,
    String name,
  ) async => artifacts['$operationId/$name'];
  @override
  Future<void> writeUploadArtifact(
    String operationId,
    String name,
    List<int> bytes,
  ) async {
    artifacts['$operationId/$name'] = List.of(bytes);
  }
}
