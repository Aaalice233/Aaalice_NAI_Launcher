import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_transfer.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_upload_plan.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_uploader.dart';

import 'coordinator_test_backend.dart';
import 'packed_snapshot_contract.dart';

void main() {
  test(
    '800 configuration records pack without changing legacy restore or identity',
    () async {
      final backend = CoordinatorTestBackend();
      await verifyPackedSnapshotRoundTrip(backend, backend);
    },
  );

  test(
    'pending legacy upload resumes its original manifest and completed objects',
    () async {
      final backend = CoordinatorTestBackend();
      final source = PackedSnapshotArtifacts();
      final records = [configRecord('a', 1), configRecord('b', 2)];
      final snapshot = CloudSyncSnapshotData(records);
      final manifest = SnapshotManifest(
        version: 2,
        snapshotId: 'packed-snapshot',
        createdAt: DateTime.utc(2025),
        records: records.map(recordRef).toList(),
      );
      source.artifacts['packed-upload/manifest.json'] = manifest.encode();
      final first = records.first.payload!;
      await backend.putObject(
        first.sha256,
        await first.readBytes(),
        sha256: first.sha256,
      );
      final journal = uploadJournal().copyWith(
        completedObjectIds: [first.sha256],
      );
      await ResumableSnapshotUploader(
        backend: backend,
        dataSource: source,
        now: () => DateTime.utc(2026),
      ).resume(
        journal: journal,
        snapshot: snapshot,
        token: OperationToken(),
        checkpoint: (_) async {},
      );
      expect(
        (await backend.readSnapshotManifest(manifest.snapshotId))!.bytes,
        manifest.encode(),
      );
      final head = SnapshotHead.decode(backend.head!.bytes);
      expect(head.version, 2);
      expect(backend.putAttempts[first.sha256], hasLength(1));
      expect(
        await CloudSnapshotTransfer(backend: backend, dataSource: source)
            .downloadHead(head, OperationToken(), null)
            .then((value) => value.records),
        snapshot.records,
      );
    },
  );

  test(
    'pending packed upload restores saved grouping rather than repacking',
    () async {
      final source = PackedSnapshotArtifacts();
      final records = [
        for (var index = 0; index < 4; index++) configRecord('r$index', index),
      ];
      final packs = <String, List<String>>{};
      for (var index = 0; index < 4; index += 2) {
        final members = records.sublist(index, index + 2);
        final bytes = <int>[
          for (final record in members) ...(await record.readBytes())!,
        ];
        packs[hashes.sha256.convert(bytes).toString()] = [
          for (final record in members) record.payload!.sha256,
        ];
      }
      final manifest = SnapshotManifest(
        snapshotId: 'packed-snapshot',
        createdAt: DateTime.utc(2025),
        records: records.map(recordRef).toList(),
        packs: packs,
      );
      source.artifacts['packed-upload/manifest.json'] = manifest.encode();
      final plan = await _plan(source, CloudSyncSnapshotData(records));
      expect(plan.manifestBytes, manifest.encode());
      expect(plan.payloads.keys, unorderedEquals(packs.keys));
      for (final payload in plan.payloads.values) {
        expect(
          hashes.sha256.convert(await payload.readBytes()).toString(),
          payload.sha256,
        );
      }
    },
  );

  test('lost pack response resumes without duplicating objects', () async {
    final backend = CoordinatorTestBackend()..loseFirstObjectResponse = true;
    final source = PackedSnapshotArtifacts();
    final snapshot = CloudSyncSnapshotData([
      configRecord('a', 1),
      configRecord('b', 2),
    ]);
    var journal = uploadJournal();
    final uploader = ResumableSnapshotUploader(
      backend: backend,
      dataSource: source,
      now: () => DateTime.utc(2026),
    );
    Future<void> resume() async {
      await uploader.resume(
        journal: journal,
        snapshot: snapshot,
        token: OperationToken(),
        checkpoint: (value) async => journal = value,
      );
    }

    await expectLater(resume(), throwsA(isA<CloudBackendException>()));
    final before = List.of(source.artifacts['packed-upload/manifest.json']!);
    await resume();
    expect(source.artifacts['packed-upload/manifest.json'], before);
    expect(
      backend.putAttempts.values.every((attempts) => attempts.length == 1),
      isTrue,
    );
    final restored =
        await CloudSnapshotTransfer(
          backend: backend,
          dataSource: source,
        ).downloadHead(
          SnapshotHead.decode(backend.head!.bytes),
          OperationToken(),
          null,
        );
    expect(restored.records, snapshot.records);
  });

  test(
    'many small records use bounded packs and binary resources stay independent',
    () async {
      final records = [
        for (var index = 0; index < 40; index++)
          CloudSyncRecord(
            id: 'r$index',
            kind: 'metadata',
            binary: false,
            deleted: false,
            bytes: Uint8List(64 * 1024)..[0] = index,
          ),
        CloudSyncRecord(
          id: 'image',
          kind: 'resource',
          binary: true,
          deleted: false,
          bytes: Uint8List(10),
        ),
      ];
      final plan = await _plan(
        PackedSnapshotArtifacts(),
        CloudSyncSnapshotData(records),
      );
      expect(plan.manifest.packs, hasLength(3));
      expect(plan.payloads, hasLength(4));
      expect(
        plan.payloads.values.every((payload) => payload.length <= 1024 * 1024),
        isTrue,
      );
      expect(plan.payloads, contains(records.last.payload!.sha256));
    },
  );

  test(
    'corrupt pack and corrupt member identities fail before returning a snapshot',
    () async {
      final source = PackedSnapshotArtifacts();
      final snapshot = CloudSyncSnapshotData([
        configRecord('a', 1),
        configRecord('b', 2),
      ]);
      final plan = await _plan(source, snapshot);
      final pack = plan.payloads.entries.single;
      final bytes = await pack.value.readBytes();
      final backend = CoordinatorTestBackend();
      final transfer = CloudSnapshotTransfer(
        backend: backend,
        dataSource: source,
      );
      backend.objects[pack.key] = CloudObjectRead(
        bytes: Uint8List.fromList(bytes)..[0] ^= 1,
        revision: 'bad',
      );
      await expectLater(
        transfer.downloadManifest(plan.manifest, OperationToken(), null),
        throwsA(isA<CloudFormatException>()),
      );
      backend.objects[pack.key] = CloudObjectRead(
        bytes: bytes,
        revision: 'valid-pack',
      );
      final wrongMembers = SnapshotManifest(
        snapshotId: plan.manifest.snapshotId,
        createdAt: plan.manifest.createdAt,
        records: plan.manifest.records,
        packs: {pack.key: plan.manifest.packs[pack.key]!.reversed.toList()},
      );
      await expectLater(
        transfer.downloadManifest(wrongMembers, OperationToken(), null),
        throwsA(isA<CloudFormatException>()),
      );
    },
  );

  test('cancelled preparation never writes an upload artifact', () async {
    final source = PackedSnapshotArtifacts();
    final token = OperationToken()..cancel();
    await expectLater(
      _plan(
        source,
        CloudSyncSnapshotData([configRecord('a', 1), configRecord('b', 2)]),
        token: token,
      ),
      throwsA(isA<OperationCancelledException>()),
    );
    expect(source.artifacts, isEmpty);
  });
}

Future<SnapshotUploadPlan> _plan(
  PackedSnapshotArtifacts source,
  CloudSyncSnapshotData snapshot, {
  OperationToken? token,
}) => SnapshotUploadPlan.prepare(
  dataSource: source,
  snapshot: snapshot,
  operationId: 'packed-upload',
  snapshotId: 'packed-snapshot',
  now: () => DateTime.utc(2026),
  token: token ?? OperationToken(),
);
