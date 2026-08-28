import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/coordinator.dart';
import 'package:nai_launcher/core/cloud_sync/crypto.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_test_backend.dart';

void main() {
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
      final manifestText = utf8.decode(manifest.bytes, allowMalformed: true);
      expect(manifestText, isNot(contains(outcome.snapshotId)));
      expect(manifestText, isNot(contains('json')));
      expect(
        fixture.source.base!.records['note'],
        fixture.source.local.records['note'],
      );
      expect(
        progress.any((value) => value.phase == SyncPhase.uploading),
        isTrue,
      );
      expect(progress.last.phase, SyncPhase.completed);
    },
  );

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

  test('encrypted record objects never exceed the 4 MiB limit', () async {
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
    'uploadLocal resumes a response-lost object with identical ciphertext',
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
      final firstCiphertext = fixture.backend.putAttempts[objectId]!.single;

      await fixture.coordinator.recoverPending();

      expect(fixture.backend.putAttempts[objectId], hasLength(2));
      expect(fixture.backend.putAttempts[objectId]![1], firstCiphertext);
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

  test('a pending journal blocks every new write operation', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.backend.loseFirstObjectResponse = true;
    await expectLater(
      fixture.coordinator.uploadLocal(),
      throwsA(isA<CloudBackendException>()),
    );

    await expectLater(fixture.coordinator.synchronize(), throwsStateError);
    await expectLater(fixture.coordinator.uploadLocal(), throwsStateError);
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

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'cloud-sync-coordinator-',
    );
    final backend = CoordinatorTestBackend();
    final source = _MemorySource(
      CloudSyncSnapshotData([
        _record('note', [1, 2, 3]),
      ]),
    );
    final crypto = CloudCrypto();
    final key = (await crypto.create('password')).masterKey;
    final journal = JournalStore(File('${directory.path}/journal.json'));
    final coordinator = SyncCoordinator(
      backend: backend,
      dataSource: source,
      crypto: crypto,
      masterKey: key,
      journalStore: journal,
    );
    return _Fixture(directory, backend, source, journal, coordinator);
  }

  Future<void> dispose() => directory.delete(recursive: true);
}

class _MemorySource implements CloudSyncDataSource {
  _MemorySource(this.local);
  CloudSyncSnapshotData local;
  CloudSyncSnapshotData? base;
  CloudSyncSnapshotData? staged;
  int rollbacks = 0;
  String? savedSnapshotId;
  bool failSaveBaseOnce = false;
  final Map<String, Uint8List> artifacts = {};
  final Map<String, CloudSyncSnapshotData> stages = {};

  @override
  Future<CloudSyncSnapshotData> captureLocal() async => local;
  @override
  Future<CloudSyncSnapshotData?> readBase() async => base;
  @override
  Future<void> stage(String operationId, CloudSyncSnapshotData snapshot) async {
    staged = snapshot;
    stages[operationId] = snapshot;
  }

  @override
  Future<CloudSyncSnapshotData> readStaged(String operationId) async =>
      stages[operationId]!;
  @override
  Future<String> stagedFingerprint(String operationId) async =>
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  @override
  Future<void> apply(String operationId) async => local = staged!;
  @override
  Future<void> rollback(String operationId) async {
    rollbacks++;
    staged = null;
    stages.remove(operationId);
    artifacts.removeWhere((key, _) => key.startsWith('$operationId/'));
  }

  @override
  Future<void> rollbackForRecovery(String operationId) async {
    rollbacks++;
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
    stages.remove(operationId);
    artifacts.removeWhere((key, _) => key.startsWith('$operationId/'));
  }
}
