import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/coordinator.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_uploader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_test_backend.dart';

void main() {
  test(
    'direct coordinator calls scope their OperationToken into backends',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final token = OperationToken();

      await fixture.coordinator.preview(token: token);

      expect(fixture.backend.readHeadOperation, same(token));
    },
  );

  test(
    'first sync uploads objects then CAS HEAD and reports real progress',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final progress = <SyncProgress>[];

      final outcome = await fixture.coordinator.synchronize(
        onProgress: progress.add,
      );

      expect(outcome.uploaded, isTrue);
      expect(fixture.backend.head, isNotNull);
      expect(fixture.backend.events.last, 'head');
      final manifest =
          fixture.backend.objects['snapshot.${outcome.snapshotId}']!;
      final decodedManifest = SnapshotManifest.decode(manifest.bytes);
      expect(decodedManifest.snapshotId, outcome.snapshotId);
      expect(decodedManifest.version, cloudSyncSchemaVersion);
      expect(
        fixture.source.base!.records['note'],
        fixture.source.local.records['note'],
      );
      final uploads = progress
          .where((value) => value.phase == SyncPhase.uploading)
          .toList();
      expect(uploads, isNotEmpty);
      expect(uploads.last.bytesCompleted, uploads.last.bytesTotal);
      expect(uploads.last.objectsCompleted, uploads.last.objectsTotal);
      for (var index = 1; index < uploads.length; index++) {
        expect(
          uploads[index].bytesCompleted,
          greaterThanOrEqualTo(uploads[index - 1].bytesCompleted),
        );
      }
      expect(progress.last.phase, SyncPhase.completed);
    },
  );

  test('download rechecks HEAD around the local apply', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    await fixture.coordinator.uploadLocal();
    fixture.source.local = CloudSyncSnapshotData([
      _record('note', [9]),
    ]);
    fixture.source.beforeApply = () async {
      final head = fixture.backend.head!;
      fixture.backend.head = CloudHeadRead(
        bytes: head.bytes,
        revision: 'external-revision',
      );
    };

    await expectLater(
      fixture.coordinator.downloadRemote(),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.conflict,
        ),
      ),
    );
    expect(await fixture.source.local.records['note']!.readBytes(), [9]);
  });

  test('uploadLocal stages no recovery point', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);

    await fixture.coordinator.uploadLocal();

    expect(fixture.source.captureCount, 1);
    expect(fixture.source.stagedRecoveryPoints, [isNull]);
  });

  test('download rejects a HEAD advanced while reading its snapshot', () async {
    final backend = _AdvancingHeadBackend();
    final fixture = await _Fixture.create(backend: backend);
    addTearDown(fixture.dispose);
    await fixture.coordinator.uploadLocal();
    fixture.source.local = CloudSyncSnapshotData([
      _record('note', [9]),
    ]);
    backend.advanceAfterNextHeadRead = true;

    await expectLater(
      fixture.coordinator.downloadRemote(),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.conflict,
        ),
      ),
    );

    expect(fixture.source.local.records['note']!.bytes, [9]);
    expect(fixture.source.stages, isEmpty);
    expect(await fixture.journal.read(), isNull);
  });

  test('WebDAV-style backends use bounded concurrent object uploads', () async {
    final backend = _ConcurrentTestBackend();
    final fixture = await _Fixture.create(
      backend: backend,
      local: CloudSyncSnapshotData([
        for (var index = 0; index < 12; index++)
          CloudSyncRecord(
            id: 'record-$index',
            kind: 'resource',
            binary: true,
            deleted: false,
            bytes: Uint8List.fromList([index]),
          ),
      ]),
    );
    addTearDown(fixture.dispose);

    await fixture.coordinator.uploadLocal();

    expect(backend.maxActiveUploads, 4);
  });

  test(
    'download merge is idempotent and history restore creates a new snapshot',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final first = await fixture.coordinator.synchronize();
      final second = await fixture.coordinator.synchronize();
      expect(second.uploaded, isFalse);
      expect(second.snapshotId, first.snapshotId);

      fixture.source.local = CloudSyncSnapshotData([
        _record('note', [9]),
      ]);
      final changed = await fixture.coordinator.synchronize();
      expect(changed.snapshotId, isNot(first.snapshotId));
      final restored = await fixture.coordinator.restore(first.snapshotId);
      expect(restored.snapshotId, isNot(first.snapshotId));
      expect(fixture.source.local.records['note']!.bytes, [1, 2, 3]);
      expect(
        (await fixture.coordinator.history()).length,
        greaterThanOrEqualTo(3),
      );
    },
  );

  test('preview confirmation reuses downloaded remote objects', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    await fixture.coordinator.uploadLocal();
    fixture.source.local = CloudSyncSnapshotData([
      _record('note', Uint8List.fromList([9, 8, 7])),
    ]);

    final preview = await fixture.coordinator.preview();
    expect(preview.canApply, isTrue);
    final readsAfterPreview = fixture.backend.objectReads;
    expect(readsAfterPreview, greaterThan(0));

    final rebuilt = SyncCoordinator(
      backend: fixture.backend,
      dataSource: fixture.source,
      journalStore: fixture.journal,
    );
    await rebuilt.synchronize();

    expect(fixture.backend.objectReads, readsAfterPreview);
  });

  test(
    'preview confirmation rejects local data changed after review',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      await fixture.coordinator.uploadLocal();
      fixture.source.local = CloudSyncSnapshotData([
        _record('note', Uint8List.fromList([2])),
      ]);
      await fixture.coordinator.preview();
      fixture.source.local = CloudSyncSnapshotData([
        _record('note', Uint8List.fromList([3])),
      ]);

      await expectLater(
        fixture.coordinator.synchronize(),
        throwsA(isA<CloudPreviewStaleException>()),
      );
    },
  );

  test(
    'restore confirmation reuses the prepared historical snapshot',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final original = await fixture.coordinator.uploadLocal();
      fixture.source.local = CloudSyncSnapshotData([
        _record('note', Uint8List.fromList([4, 5, 6])),
      ]);
      await fixture.coordinator.uploadLocal();

      await fixture.coordinator.previewRestore(original.snapshotId);
      final readsAfterPreview = fixture.backend.objectReads;
      final rebuilt = SyncCoordinator(
        backend: fixture.backend,
        dataSource: fixture.source,
        journalStore: fixture.journal,
      );
      await rebuilt.restore(original.snapshotId);

      expect(fixture.backend.objectReads, readsAfterPreview);
    },
  );

  test(
    'restore confirmation rejects a remote HEAD changed after review',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final original = await fixture.coordinator.uploadLocal();

      await fixture.coordinator.previewRestore(original.snapshotId);
      final head = fixture.backend.head!;
      fixture.backend.head = CloudHeadRead(
        bytes: head.bytes,
        revision: '${head.revision}-changed',
      );

      await expectLater(
        fixture.coordinator.restore(original.snapshotId),
        throwsA(isA<CloudPreviewStaleException>()),
      );
    },
  );

  test('cancellation rolls back staging and leaves HEAD uncommitted', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    final token = OperationToken()..cancel();

    await expectLater(
      fixture.coordinator.synchronize(token: token),
      throwsA(isA<OperationCancelledException>()),
    );
    expect(fixture.backend.head, isNull);
    expect(fixture.source.rollbacks, 0);
    expect(await fixture.journal.read(), isNull);
  });

  test(
    'discardPending removes staged legacy work without replaying it',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      const operationId = 'legacy-pending';
      await fixture.source.stage(operationId, fixture.source.local);
      await fixture.journal.write(
        SyncJournal(
          operationId: operationId,
          operation: JournalOperation.uploadLocal,
          phase: JournalPhase.prepared,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: 'legacy-snapshot',
          targetFingerprint: await fixture.source.stagedFingerprint(
            operationId,
          ),
          expectedRevision: null,
          uploadRequired: true,
        ),
      );

      await fixture.coordinator.discardPending();

      expect(await fixture.journal.read(), isNull);
      expect(fixture.source.stages, isEmpty);
      expect(fixture.backend.head, isNull);
    },
  );

  test(
    'recovering applying replays apply then saves base by snapshot id',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final uploaded = await fixture.coordinator.synchronize();
      const operationId = 'recover-apply';
      await fixture.source.stage(operationId, uploaded.snapshot);
      fixture.source.local = CloudSyncSnapshotData([
        _record('note', [9]),
      ]);
      fixture.source.base = null;
      await fixture.journal.write(
        SyncJournal(
          operationId: operationId,
          operation: JournalOperation.synchronize,
          phase: JournalPhase.applyStarted,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: uploaded.snapshotId,
          targetFingerprint: await fixture.source.stagedFingerprint(
            operationId,
          ),
          expectedRevision: fixture.backend.head!.revision,
          uploadRequired: false,
        ),
      );

      await fixture.coordinator.recoverPending();

      expect(fixture.source.local.records['note']!.bytes, [1, 2, 3]);
      expect(fixture.source.savedSnapshotId, uploaded.snapshotId);
      expect(await fixture.journal.read(), isNull);
    },
  );

  test(
    'recovery resumes a committed remote write still marked staging',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final uploaded = await fixture.coordinator.synchronize();
      const operationId = 'restore-crash';
      await fixture.source.stage(operationId, uploaded.snapshot);
      fixture.source.local = CloudSyncSnapshotData([
        _record('note', [8]),
      ]);
      await fixture.journal.write(
        SyncJournal(
          operationId: operationId,
          operation: JournalOperation.restore,
          phase: JournalPhase.applyStarted,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: uploaded.snapshotId,
          targetFingerprint: await fixture.source.stagedFingerprint(
            operationId,
          ),
          expectedRevision: fixture.backend.head!.revision,
          uploadRequired: false,
        ),
      );

      await fixture.coordinator.recoverPending();

      expect(fixture.source.local.records['note']!.bytes, [1, 2, 3]);
      expect(fixture.source.savedSnapshotId, uploaded.snapshotId);
      expect(await fixture.journal.read(), isNull);
    },
  );

  test('rollbackStarted recovery restores local data before cleanup', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    final previous = CloudSyncSnapshotData([
      _record('note', [8]),
    ]);
    final target = CloudSyncSnapshotData([
      _record('note', [1, 2, 3]),
    ]);
    const operationId = 'rollback-crash';
    await fixture.source.stage(operationId, target, recoveryPoint: previous);
    fixture.source.local = target;
    await fixture.journal.write(
      SyncJournal(
        operationId: operationId,
        operation: JournalOperation.downloadRemote,
        phase: JournalPhase.rollbackStarted,
        updatedAt: DateTime.now().toUtc(),
        snapshotId: 'rollback-target',
        targetFingerprint: await fixture.source.stagedFingerprint(operationId),
        expectedRevision: null,
        uploadRequired: false,
      ),
    );

    await fixture.coordinator.recoverPending();

    expect(fixture.source.local.records['note']!.bytes, [8]);
    expect(await fixture.journal.read(), isNull);
    expect(fixture.source.stages, isEmpty);
  });

  test(
    'discard after base publication crash restores local and previous base',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final previous = CloudSyncSnapshotData([
        _record('note', [1]),
      ]);
      final target = CloudSyncSnapshotData([
        _record('note', [2]),
      ]);
      const operationId = 'crash-after-base-publication';
      fixture.source.local = previous;
      fixture.source.base = previous;
      await fixture.source.stage(operationId, target, recoveryPoint: previous);
      await fixture.source.apply(operationId);
      await fixture.journal.write(
        SyncJournal(
          operationId: operationId,
          operation: JournalOperation.downloadRemote,
          phase: JournalPhase.savingBase,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: 'new-base',
          targetFingerprint: await fixture.source.stagedFingerprint(
            operationId,
          ),
          expectedRevision: null,
          uploadRequired: false,
        ),
      );
      await fixture.source.saveBase(target, 'new-base');

      await fixture.coordinator.discardPending();

      expect(fixture.source.local.records['note']!.bytes, [1]);
      expect(fixture.source.base!.records['note']!.bytes, [1]);
      expect(await fixture.journal.read(), isNull);
      expect(fixture.source.stages, isEmpty);
    },
  );

  test(
    'discard only cleans a completed operation after cleanup crash',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final previous = CloudSyncSnapshotData([
        _record('note', [1]),
      ]);
      final target = CloudSyncSnapshotData([
        _record('note', [2]),
      ]);
      const operationId = 'completed-before-cleanup';
      fixture.source.local = previous;
      fixture.source.base = previous;
      await fixture.source.stage(operationId, target, recoveryPoint: previous);
      await fixture.source.apply(operationId);
      await fixture.source.saveBase(target, 'new-base');
      await fixture.journal.write(
        SyncJournal(
          operationId: operationId,
          operation: JournalOperation.downloadRemote,
          phase: JournalPhase.completed,
          updatedAt: DateTime.now().toUtc(),
          snapshotId: 'new-base',
          targetFingerprint: await fixture.source.stagedFingerprint(
            operationId,
          ),
          expectedRevision: null,
          uploadRequired: false,
        ),
      );

      await fixture.coordinator.discardPending();

      expect(fixture.source.local.records['note']!.bytes, [2]);
      expect(fixture.source.base!.records['note']!.bytes, [2]);
      expect(await fixture.journal.read(), isNull);
      expect(fixture.source.stages, isEmpty);
    },
  );

  test('uploadLocal base save failure remains recoverable', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.source.failSaveBaseOnce = true;

    await expectLater(fixture.coordinator.uploadLocal(), throwsStateError);
    final pending = await fixture.journal.read();
    expect(pending!.phase, JournalPhase.savingBase);
    expect(pending.operation, JournalOperation.uploadLocal);

    await fixture.coordinator.recoverPending();

    expect(fixture.source.savedSnapshotId, pending.snapshotId);
    expect(await fixture.journal.read(), isNull);
  });

  test(
    'completed operation cleanup failure never rolls back committed data',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      fixture.source.failCompleteOnce = true;

      await expectLater(fixture.coordinator.uploadLocal(), throwsStateError);
      final pending = await fixture.journal.read();
      expect(pending!.phase, JournalPhase.completed);
      expect(fixture.source.rollbacks, 0);
      expect(fixture.source.base, isNotNull);

      await fixture.coordinator.recoverPending();

      expect(fixture.source.rollbacks, 0);
      expect(await fixture.journal.read(), isNull);
    },
  );

  test(
    'cancellation after HEAD commit stays recoverable and is rethrown',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      final token = OperationToken();
      fixture.backend.cancelAfterHeadToken = token;

      await expectLater(
        fixture.coordinator.uploadLocal(token: token),
        throwsA(isA<OperationCancelledException>()),
      );

      final pending = await fixture.journal.read();
      expect(fixture.backend.head, isNotNull);
      expect(pending!.phase, JournalPhase.savingBase);
      expect(fixture.source.rollbacks, 0);

      await fixture.coordinator.recoverPending();
      expect(fixture.source.savedSnapshotId, pending.snapshotId);
      expect(await fixture.journal.read(), isNull);
    },
  );

  test('plain record objects never exceed the 4 MiB limit', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.source.local = CloudSyncSnapshotData([
      _record('large', Uint8List(maxCloudRecordPayloadBytes)),
    ]);

    await fixture.coordinator.uploadLocal();

    final records = fixture.backend.objects.entries.where(
      (entry) => !entry.key.startsWith('snapshot.'),
    );
    expect(records, isNotEmpty);
    expect(
      records.first.value.bytes.length,
      greaterThan(maxCloudObjectBytes - 1024),
    );
    expect(
      records.every((entry) => entry.value.bytes.length <= maxCloudObjectBytes),
      isTrue,
    );
    expect(
      () => CloudSyncRecord(
        id: 'too-large-after-encoding',
        kind: 'resource',
        binary: true,
        deleted: false,
        bytes: Uint8List(maxCloudRecordPayloadBytes + 1),
      ),
      throwsA(isA<CloudFormatException>()),
    );
  });

  test(
    'uploadLocal resumes a response-lost object with identical bytes',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      fixture.backend.loseFirstObjectResponse = true;

      await expectLater(
        fixture.coordinator.uploadLocal(),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.network,
          ),
        ),
      );
      final pending = await fixture.journal.read();
      expect(pending, isNotNull);
      expect(pending!.phase, JournalPhase.prepared);
      final objectId = fixture.backend.putAttempts.keys.single;
      final firstBytes = fixture.backend.putAttempts[objectId]!.single;

      await fixture.coordinator.recoverPending();

      expect(fixture.backend.putAttempts[objectId], hasLength(1));
      expect(fixture.backend.objects[objectId]!.bytes, firstBytes);
      expect(fixture.backend.head, isNotNull);
      expect(await fixture.journal.read(), isNull);
      expect(fixture.source.stages, isEmpty);
      expect(fixture.source.artifacts, isEmpty);
    },
  );

  test(
    'HEAD response loss is detected without applying a competing HEAD',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.dispose);
      fixture.backend.loseHeadResponse = true;

      await expectLater(
        fixture.coordinator.synchronize(),
        throwsA(isA<CloudBackendException>()),
      );
      final committedId = SnapshotHead.decode(
        fixture.backend.head!.bytes,
      ).snapshotId;
      expect(fixture.source.base, isNull);

      await fixture.coordinator.recoverPending();

      expect(fixture.source.savedSnapshotId, committedId);
      expect(await fixture.journal.read(), isNull);
    },
  );

  test('a pending journal is recovered before the next write', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.backend.loseFirstObjectResponse = true;
    await expectLater(
      fixture.coordinator.uploadLocal(),
      throwsA(isA<CloudBackendException>()),
    );

    final outcome = await fixture.coordinator.synchronize();

    expect(outcome.snapshotId, isNotEmpty);
    expect(await fixture.journal.read(), isNull);
    expect(fixture.source.savedSnapshotId, outcome.snapshotId);
  });

  test('recovery rejects a HEAD advanced by another device', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.backend.loseFirstObjectResponse = true;
    await expectLater(
      fixture.coordinator.synchronize(),
      throwsA(isA<CloudBackendException>()),
    );
    fixture.backend.head = CloudHeadRead(
      bytes: Uint8List.fromList(
        SnapshotHead(
          snapshotId: 'other-device-snapshot',
          manifestSha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          updatedAt: DateTime.now().toUtc(),
        ).encode(),
      ),
      revision: 'other-revision',
    );

    await expectLater(
      fixture.coordinator.recoverPending(),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.conflict,
        ),
      ),
    );

    expect(fixture.source.base, isNull);
    expect(await fixture.journal.read(), isNull);
  });

  test('out-of-order upload checkpoints resume as a safe object set', () async {
    final backend = _OutOfOrderFailureBackend();
    final snapshot = CloudSyncSnapshotData([
      for (final entry in {'a': 1, 'b': 2, 'c': 3}.entries)
        CloudSyncRecord(
          id: entry.key,
          kind: 'resource',
          binary: true,
          deleted: false,
          bytes: Uint8List.fromList([entry.value]),
        ),
    ]);
    final source = _MemorySource(snapshot);
    var journal = SyncJournal(
      operationId: 'operation',
      operation: JournalOperation.uploadLocal,
      phase: JournalPhase.prepared,
      updatedAt: DateTime.utc(2025),
      snapshotId: 'snapshot',
      targetFingerprint:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      expectedRevision: null,
      uploadRequired: true,
    );
    final checkpoints = <SyncJournal>[];
    final uploader = ResumableSnapshotUploader(
      backend: backend,
      dataSource: source,
      now: () => DateTime.utc(2025),
    );

    await expectLater(
      uploader.resume(
        journal: journal,
        snapshot: snapshot,
        token: OperationToken(),
        checkpoint: (value) async {
          journal = value;
          checkpoints.add(value);
        },
      ),
      throwsA(isA<StateError>()),
    );

    final failedId = hashes.sha256.convert([1]).toString();
    final completed = journal.completedObjectIds;
    expect(completed, orderedEquals([...completed]..sort()));
    expect(completed, hasLength(2));
    expect(completed, isNot(contains(failedId)));
    expect(checkpoints, isNotEmpty);

    final recovered = await uploader.resume(
      journal: journal,
      snapshot: snapshot,
      token: OperationToken(),
      checkpoint: (value) async => journal = value,
    );

    expect(recovered.phase, JournalPhase.savingBase);
    expect(backend.starts[failedId], 2);
    expect(backend.events.last, 'head');
    expect(backend.events.where((event) => event == 'head'), hasLength(1));
  });

  test(
    'content addressing deduplicates 1000 records and unchanged snapshots',
    () async {
      CloudSyncSnapshotData snapshot(int changed) => CloudSyncSnapshotData([
        for (var index = 0; index < 1000; index++)
          CloudSyncRecord(
            id: 'record-$index',
            kind: index.isEven ? 'metadata' : 'resource',
            binary: index.isOdd,
            deleted: false,
            bytes: Uint8List.fromList(
              index < changed ? [9, index & 0xff] : [1, 2, 3],
            ),
          ),
      ]);

      final fixture = await _Fixture.create(local: snapshot(0));
      addTearDown(fixture.dispose);
      Iterable<String> payloadObjectIds() => fixture.backend.putAttempts.keys
          .where((id) => !id.startsWith('snapshot.'));
      int payloadPutAttempts() => fixture.backend.putAttempts.entries
          .where((entry) => !entry.key.startsWith('snapshot.'))
          .fold(0, (total, entry) => total + entry.value.length);
      await fixture.coordinator.uploadLocal();
      expect(payloadObjectIds(), hasLength(1));
      expect(payloadPutAttempts(), 1);
      final sharedId = payloadObjectIds().single;
      expect(fixture.backend.objects[sharedId]!.bytes, [1, 2, 3]);

      fixture.source.local = snapshot(1);
      await fixture.coordinator.uploadLocal();
      expect(payloadObjectIds(), hasLength(2));
      expect(payloadPutAttempts(), 2);

      await fixture.coordinator.uploadLocal();
      expect(payloadObjectIds(), hasLength(2));
      expect(payloadPutAttempts(), 2);
      expect(fixture.backend.inventoryCalls, 3);
      expect(fixture.backend.objectReads, 0);

      final head = SnapshotHead.decode(fixture.backend.head!.bytes);
      final manifest = SnapshotManifest.decode(
        fixture.backend.objects['snapshot.${head.snapshotId}']!.bytes,
      );
      expect(manifest.records, hasLength(1000));
      expect(
        manifest.records.where((record) => record.objectId == sharedId),
        hasLength(999),
      );
    },
  );

  test(
    '10k small records share one pack and unchanged uploads reuse it',
    () async {
      CloudSyncSnapshotData snapshot({int? changedIndex}) =>
          CloudSyncSnapshotData([
            for (var index = 0; index < 10000; index++)
              CloudSyncRecord(
                id: 'record-$index',
                kind: 'metadata',
                binary: false,
                deleted: false,
                bytes: Uint8List.fromList([
                  index >> 24,
                  index >> 16,
                  index >> 8,
                  index,
                  if (index == changedIndex) 1,
                ]),
              ),
          ]);

      final fixture = await _Fixture.create(local: snapshot());
      addTearDown(fixture.dispose);
      final watch = Stopwatch()..start();
      await fixture.coordinator.uploadLocal();
      final firstUpload = watch.elapsed;
      int payloadIds() => fixture.backend.putAttempts.keys
          .where((id) => !id.startsWith('snapshot.'))
          .length;
      int payloadAttempts() => fixture.backend.putAttempts.entries
          .where((entry) => !entry.key.startsWith('snapshot.'))
          .fold(0, (total, entry) => total + entry.value.length);
      expect(payloadIds(), 1);
      expect(payloadAttempts(), 1);

      watch.reset();
      await fixture.coordinator.uploadLocal();
      final unchangedUpload = watch.elapsed;
      expect(payloadIds(), 1);
      expect(payloadAttempts(), 1);

      fixture.source.local = snapshot(changedIndex: 5000);
      watch.reset();
      await fixture.coordinator.uploadLocal();
      final oneChangedUpload = watch.elapsed;
      expect(payloadIds(), 2);
      expect(payloadAttempts(), 2);
      // A changed setting replaces its pack; unchanged snapshots reuse it.
      // ignore: avoid_print
      print(
        'cloud-sync 10k benchmark: first=${firstUpload.inMilliseconds}ms, '
        'unchanged=${unchangedUpload.inMilliseconds}ms, '
        'oneChanged=${oneChangedUpload.inMilliseconds}ms',
      );
    },
  );

  test(
    '20 MiB benchmark streams bounded records without duplicate writes',
    () async {
      final snapshot = CloudSyncSnapshotData([
        for (var index = 0; index < 20; index++)
          CloudSyncRecord(
            id: 'binary-$index',
            kind: 'resource',
            binary: true,
            deleted: false,
            bytes: Uint8List(1024 * 1024)..[0] = index,
          ),
      ]);
      final fixture = await _Fixture.create(local: snapshot);
      addTearDown(fixture.dispose);
      final watch = Stopwatch()..start();
      await fixture.coordinator.uploadLocal();
      final firstUpload = watch.elapsed;
      int payloadIds() => fixture.backend.putAttempts.keys
          .where((id) => !id.startsWith('snapshot.'))
          .length;
      int payloadAttempts() => fixture.backend.putAttempts.entries
          .where((entry) => !entry.key.startsWith('snapshot.'))
          .fold(0, (total, entry) => total + entry.value.length);
      expect(payloadIds(), 20);
      expect(payloadAttempts(), 20);

      watch.reset();
      await fixture.coordinator.uploadLocal();
      final unchangedUpload = watch.elapsed;
      expect(payloadIds(), 20);
      expect(payloadAttempts(), 20);
      // ignore: avoid_print
      print(
        'cloud-sync 20MiB benchmark: first=${firstUpload.inMilliseconds}ms, '
        'unchanged=${unchangedUpload.inMilliseconds}ms',
      );
    },
  );
}

CloudSyncRecord _record(String id, List<int> bytes) => CloudSyncRecord(
  id: id,
  kind: 'json',
  binary: false,
  deleted: false,
  bytes: Uint8List.fromList(bytes),
);

class _Fixture {
  _Fixture(
    this.directory,
    this.backend,
    this.source,
    this.journal,
    this.coordinator,
  );

  final Directory directory;
  final CoordinatorTestBackend backend;
  final _MemorySource source;
  final JournalStore journal;
  final SyncCoordinator coordinator;

  static Future<_Fixture> create({
    CoordinatorTestBackend? backend,
    CloudSyncSnapshotData? local,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'cloud-sync-coordinator-',
    );
    final effectiveBackend = backend ?? CoordinatorTestBackend();
    final source = _MemorySource(
      local ??
          CloudSyncSnapshotData([
            _record('note', [1, 2, 3]),
          ]),
    );
    final journal = JournalStore(File('${directory.path}/journal.json'));
    final coordinator = SyncCoordinator(
      backend: effectiveBackend,
      dataSource: source,
      journalStore: journal,
    );
    return _Fixture(directory, effectiveBackend, source, journal, coordinator);
  }

  Future<void> dispose() => directory.delete(recursive: true);
}

class _AdvancingHeadBackend extends CoordinatorTestBackend {
  bool advanceAfterNextHeadRead = false;

  @override
  Future<CloudHeadRead?> readHead() async {
    final current = await super.readHead();
    if (advanceAfterNextHeadRead && current != null) {
      advanceAfterNextHeadRead = false;
      head = CloudHeadRead(
        bytes: Uint8List.fromList(current.bytes),
        revision: 'r${++revision}',
      );
    }
    return current;
  }
}

class _OutOfOrderFailureBackend extends CoordinatorTestBackend
    implements ConcurrentCloudObjectUploadBackend {
  final Map<String, int> starts = {};
  var failFirst = true;

  @override
  int get maxConcurrentObjectUploads => 3;

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) async {
    starts.update(objectId, (value) => value + 1, ifAbsent: () => 1);
    if (bytes.length == 1 && bytes.single == 1 && failFirst) {
      failFirst = false;
      await Future<void>.delayed(const Duration(milliseconds: 8));
      throw StateError('original upload failure');
    }
    await Future<void>.delayed(
      Duration(milliseconds: bytes.length == 1 && bytes.single == 2 ? 20 : 1),
    );
    return super.putObject(
      objectId,
      bytes,
      sha256: sha256,
      payloadVerified: payloadVerified,
    );
  }
}

class _ConcurrentTestBackend extends CoordinatorTestBackend
    implements ConcurrentCloudObjectUploadBackend {
  var activeUploads = 0;
  var maxActiveUploads = 0;

  @override
  int get maxConcurrentObjectUploads => 4;

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) async {
    activeUploads++;
    if (activeUploads > maxActiveUploads) maxActiveUploads = activeUploads;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return await super.putObject(
        objectId,
        bytes,
        sha256: sha256,
        payloadVerified: payloadVerified,
      );
    } finally {
      activeUploads--;
    }
  }
}

class _MemorySource implements CloudSyncDataSource, CloudSyncPreviewStore {
  _MemorySource(this.local);
  CloudSyncSnapshotData local;
  CloudSyncSnapshotData? base;
  CloudSyncSnapshotData? staged;
  int rollbacks = 0;
  String? savedSnapshotId;
  bool failSaveBaseOnce = false;
  bool failCompleteOnce = false;
  int captureCount = 0;
  Future<void> Function()? beforeApply;
  final List<CloudSyncSnapshotData?> stagedRecoveryPoints = [];
  final Map<String, Uint8List> artifacts = {};
  final Map<String, CloudSyncSnapshotData> stages = {};
  final Map<String, CloudSyncSnapshotData?> recoveryPoints = {};
  final Map<String, CloudSyncSnapshotData?> baseRecoveryPoints = {};
  CloudSyncPreparedPreview? syncPreview;
  final Map<String, CloudSyncPreparedRestore> restorePreviews = {};

  @override
  Future<void> saveSyncPreview(CloudSyncPreparedPreview preview) async {
    syncPreview = preview;
  }

  @override
  Future<CloudSyncPreparedPreview?> readSyncPreview() async => syncPreview;

  @override
  Future<void> deleteSyncPreview() async => syncPreview = null;

  @override
  Future<void> saveRestorePreview(
    String snapshotId,
    CloudSyncPreparedRestore preview,
  ) async {
    restorePreviews[snapshotId] = preview;
  }

  @override
  Future<CloudSyncPreparedRestore?> readRestorePreview(
    String snapshotId,
  ) async => restorePreviews[snapshotId];

  @override
  Future<void> deleteRestorePreviews() async => restorePreviews.clear();

  @override
  Future<CloudSyncSnapshotData> captureLocal() async {
    captureCount++;
    return local;
  }

  @override
  Future<CloudSyncSnapshotData?> readBase() async => base;
  @override
  Future<void> stage(
    String operationId,
    CloudSyncSnapshotData snapshot, {
    CloudSyncSnapshotData? recoveryPoint,
  }) async {
    staged = snapshot;
    stagedRecoveryPoints.add(recoveryPoint);
    stages[operationId] = snapshot;
    recoveryPoints[operationId] = recoveryPoint;
    baseRecoveryPoints[operationId] = base;
  }

  @override
  Future<CloudSyncSnapshotData> readStaged(String operationId) async =>
      stages[operationId]!;
  @override
  Future<String> stagedFingerprint(String operationId) async =>
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  @override
  Future<void> apply(String operationId) async {
    await beforeApply?.call();
    local = staged!;
  }

  @override
  Future<void> rollback(String operationId) async {
    rollbacks++;
    staged = null;
    stages.remove(operationId);
    recoveryPoints.remove(operationId);
    baseRecoveryPoints.remove(operationId);
    artifacts.removeWhere((key, _) => key.startsWith('$operationId/'));
  }

  @override
  Future<void> rollbackForRecovery(String operationId) async {
    rollbacks++;
    final recovery = recoveryPoints[operationId];
    if (recovery != null) local = recovery;
  }

  @override
  Future<void> restoreBaseForRecovery(String operationId) async {
    if (!baseRecoveryPoints.containsKey(operationId)) {
      throw StateError('base recovery state is missing');
    }
    base = baseRecoveryPoints[operationId];
  }

  @override
  Future<void> saveBase(
    CloudSyncSnapshotData snapshot,
    String snapshotId,
  ) async {
    if (failSaveBaseOnce) {
      failSaveBaseOnce = false;
      throw StateError('simulated base write crash');
    }
    base = snapshot;
    savedSnapshotId = snapshotId;
  }

  @override
  Future<void> writeUploadArtifact(
    String operationId,
    String name,
    List<int> bytes,
  ) async => artifacts['$operationId/$name'] = Uint8List.fromList(bytes);

  @override
  Future<List<int>?> readUploadArtifact(
    String operationId,
    String name,
  ) async => artifacts['$operationId/$name'];

  @override
  Future<void> deleteUploadArtifact(String operationId, String name) async =>
      artifacts.remove('$operationId/$name');

  @override
  Future<void> completeOperation(String operationId) async {
    if (failCompleteOnce) {
      failCompleteOnce = false;
      throw StateError('simulated operation cleanup failure');
    }
    stages.remove(operationId);
    recoveryPoints.remove(operationId);
    baseRecoveryPoints.remove(operationId);
    artifacts.removeWhere((key, _) => key.startsWith('$operationId/'));
  }
}
