import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_uploader.dart';

import 'packed_snapshot_contract.dart';

/// Objects uploaded in one app session must be trusted by a fresh backend in
/// the next one through the persisted verification cache alone.
Future<void> verifyUploadedObjectProofsSurviveRestart({
  required CloudSyncBackend Function() createBackend,
  required int Function() objectDownloads,
}) async {
  final source = _VerificationCacheArtifacts();
  final writer = createBackend();
  await writer.testCapability();
  final resources = [
    for (var index = 0; index < 2; index++)
      CloudSyncRecord(
        id: 'resource-$index',
        kind: 'resource',
        binary: true,
        deleted: false,
        bytes: Uint8List(80 * 1024)..[0] = index + 1,
      ),
  ];
  await ResumableSnapshotUploader(
    backend: writer,
    dataSource: source,
    now: () => DateTime.utc(2026),
  ).resume(
    journal: uploadJournal(
      expectedRevision: (await writer.readHead())?.revision,
    ),
    snapshot: CloudSyncSnapshotData(resources),
    token: OperationToken(),
    checkpoint: (_) async {},
  );

  final reader = createBackend() as CloudObjectInventoryBackend;
  final downloadsBefore = objectDownloads();
  final existing = await reader.findExistingObjects({
    for (final record in resources)
      record.payload!.sha256: record.payload!.length,
  }, trustedRevisions: source.verifiedObjects);

  expect(existing, {for (final record in resources) record.payload!.sha256});
  expect(
    objectDownloads(),
    downloadsBefore,
    reason: 'objects uploaded last session must not be downloaded again',
  );

  final resumed = createBackend();
  for (final record in resources) {
    await resumed.readObject(record.payload!.sha256);
  }
  expect(
    (resumed as CloudObjectInventoryBackend).verifiedObjectProofs(
      existing.existingObjectIds,
    ),
    existing.verifiedRevisions,
    reason: 'byte-verified reads must issue the inventory proof format',
  );
}

class _VerificationCacheArtifacts extends PackedSnapshotArtifacts
    implements CloudObjectVerificationDataSource {
  Map<String, String> verifiedObjects = const {};

  @override
  Future<Map<String, String>> readVerifiedCloudObjects() async =>
      verifiedObjects;

  @override
  Future<void> writeVerifiedCloudObjects(Map<String, String> revisions) async {
    verifiedObjects = Map.unmodifiable(revisions);
  }
}
