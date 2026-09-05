import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:nai_launcher/core/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_transfer.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_uploader.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';

import '../../core/cloud_sync/coordinator_test_backend.dart';
import '../../core/cloud_sync/packed_snapshot_contract.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cloud-data-source-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'packed download persists original payloads across reconstruction',
    () async {
      final adapter = _Adapter();
      adapter.exported = [
        for (var index = 0; index < 80; index++)
          PortableSyncRecord(
            adapterId: adapter.id,
            id: 'config-$index',
            kind: 'item',
            data: {'value': index},
          ),
      ];
      final registry = CloudSyncDataAdapterRegistry([adapter]);
      final writer = AppCloudSyncDataSource(
        registry: registry,
        root: Directory('${root.path}/writer'),
      );
      final snapshot = await writer.captureLocal();
      final backend = CoordinatorTestBackend();
      await ResumableSnapshotUploader(
        backend: backend,
        dataSource: writer,
        now: () => DateTime.utc(2026),
      ).resume(
        journal: uploadJournal(),
        snapshot: snapshot,
        token: OperationToken(),
        checkpoint: (_) async {},
      );
      final head = SnapshotHead.decode((await backend.readHead())!.bytes);
      final manifest = SnapshotManifest.decode(
        (await backend.readSnapshotManifest(head.snapshotId))!.bytes,
      );
      expect(manifest.packs, hasLength(1));
      final readerRoot = Directory('${root.path}/reader');
      final reader = AppCloudSyncDataSource(
        registry: registry,
        root: readerRoot,
      );
      final downloaded = await CloudSnapshotTransfer(
        backend: backend,
        dataSource: reader,
      ).downloadHead(head, OperationToken(), null);
      expect(downloaded.records, snapshot.records);
      expect(
        downloaded.records.values.every((record) => record.bytes == null),
        isTrue,
      );
      await reader.saveBase(downloaded, head.snapshotId);
      final rebuilt = AppCloudSyncDataSource(
        registry: registry,
        root: readerRoot,
      );
      final base = (await rebuilt.readBase())!;
      expect(base.records, snapshot.records);
      for (final record in snapshot.records.values) {
        expect(
          await base.records[record.id]!.readBytes(),
          await record.readBytes(),
        );
      }
    },
  );

  test('verified remote object revisions survive reconstruction', () async {
    final registry = CloudSyncDataAdapterRegistry([_Adapter()]);
    final first = AppCloudSyncDataSource(registry: registry, root: root);
    final objectId = List.filled(64, 'a').join();

    await first.writeVerifiedCloudObjects({objectId: 'revision-1'});
    final reconstructed = AppCloudSyncDataSource(
      registry: registry,
      root: root,
    );

    expect(await reconstructed.readVerifiedCloudObjects(), {
      objectId: 'revision-1',
    });
  });

  test(
    'capture externalizes every resource chunk instead of retaining library',
    () async {
      final adapter = _Adapter();
      var active = 0;
      var maxActive = 0;
      adapter.exported = [
        PortableSyncRecord(
          adapterId: adapter.id,
          id: 'large',
          kind: 'item',
          resource: PortableSyncResource(
            relativePath: 'large.bin',
            length: 10,
            openRead: () async* {
              active++;
              if (active > maxActive) maxActive = active;
              try {
                yield Uint8List.fromList([1, 2, 3, 4, 5]);
                yield Uint8List.fromList([6, 7, 8, 9, 10]);
              } finally {
                active--;
              }
            },
          ),
        ),
      ];
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 4,
      );

      final snapshot = await source.captureLocal();
      final resources = snapshot.records.values
          .where((record) => record.kind == 'resource')
          .toList();
      expect(resources, hasLength(3));
      expect(resources.every((record) => record.bytes == null), isTrue);
      expect(resources.every((record) => record.payload != null), isTrue);
      expect(maxActive, 1);
      expect(await resources.last.readBytes(), [9, 10]);
    },
  );

  test(
    'capture reads source once and stage/base publish refs without payload copies',
    () async {
      final adapter = _Adapter();
      var sourceOpens = 0;
      adapter.exported = [
        PortableSyncRecord(
          adapterId: adapter.id,
          id: 'single-pass',
          kind: 'item',
          resource: PortableSyncResource(
            relativePath: 'single-pass.bin',
            length: 4,
            openRead: () {
              sourceOpens++;
              return Stream.value(const [1, 2, 3, 4]);
            },
          ),
        ),
      ];
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );

      CloudSyncTelemetrySnapshot? metrics;
      late CloudSyncSnapshotData captured;
      await CloudSyncTelemetry.trace(
        'production-single-pass-capture',
        () async {
          captured = await source.captureLocal();
          await source.stage(
            'single-pass-op',
            captured,
            recoveryPoint: captured,
          );
          await source.saveBase(captured, 'single-pass-base');
        },
        onComplete: (value) => metrics = value,
      );

      expect(sourceOpens, 1);
      expect(
        metrics!.hashPasses,
        captured.records.values
            .where((record) => record.payload != null)
            .length,
      );
      expect(adapter.exportCalls, 1);
      expect(
        Directory('${root.path}/staging/single-pass-op')
            .listSync(recursive: true)
            .whereType<File>()
            .any((file) => file.path.endsWith('.payload')),
        isFalse,
      );
      for (final directory in [
        Directory('${root.path}/staging/single-pass-op'),
        Directory('${root.path}/recovery/single-pass-op'),
        Directory('${root.path}/base'),
      ]) {
        final refs = directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.ref'))
            .toList();
        expect(refs, hasLength(1));
        final ready = directory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('READY'))
            .toList();
        expect(ready, hasLength(1));
      }
    },
  );

  test('failed blob validation cannot publish a READY descriptor', () async {
    final adapter = _Adapter()
      ..exported = [
        _portable('test-adapter', 'asset', [1, 2, 3]),
      ];
    final source = AppCloudSyncDataSource(
      registry: CloudSyncDataAdapterRegistry([adapter]),
      root: root,
      chunkSize: 2,
    );
    final captured = await source.captureLocal();
    await Directory(
      '${root.path}/blobs',
    ).list().first.then((entity) => (entity as File).delete());

    await expectLater(
      source.stage('failed-stage', captured, recoveryPoint: captured),
      throwsA(isA<CloudFormatException>()),
    );
    expect(
      await Directory('${root.path}/staging/failed-stage/refs').exists(),
      isFalse,
    );
  });

  test(
    'downloaded tombstone carries identity without a local common base',
    () async {
      final adapter = _Adapter();
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
      );
      final tombstone = PortableSyncRecord(
        adapterId: adapter.id,
        id: 'gone',
        kind: 'item',
        deleted: true,
      );
      final remote = CloudSyncSnapshotData([
        CloudSyncRecord(
          id: _stableId(adapter.id, 'gone'),
          kind: 'metadata',
          binary: false,
          deleted: true,
          tombstoneIdentity: PortableRecordCodec.tombstoneIdentity(tombstone),
        ),
      ]);

      final binaryTombstone = CloudSyncSnapshotData([
        CloudSyncRecord(
          id: _stableId(adapter.id, 'gone'),
          kind: 'metadata',
          binary: true,
          deleted: true,
          tombstoneIdentity: PortableRecordCodec.tombstoneIdentity(tombstone),
        ),
      ]);
      await expectLater(
        source.stage('invalid-tombstone', binaryTombstone),
        throwsA(isA<CloudFormatException>()),
      );

      final recovery = await source.buildRecoveryPoint(
        local: await source.captureLocal(),
        target: remote,
      );
      await source.stage('download-op', remote, recoveryPoint: recovery);
      await source.apply('download-op');

      expect(adapter.applied, hasLength(1));
      expect(adapter.applied.single.adapterId, adapter.id);
      expect(adapter.applied.single.id, 'gone');
      expect(adapter.applied.single.deleted, isTrue);
    },
  );

  test('recovery tombstones bound large newly introduced metadata', () async {
    final adapter = _Adapter();
    final source = AppCloudSyncDataSource(
      registry: CloudSyncDataAdapterRegistry([adapter]),
      root: root,
    );
    final metadata = utf8.encode(
      jsonEncode({
        'version': 2,
        'adapterId': adapter.id,
        'portableId': 'new-local-record',
        'kind': 'item',
        'data': <String, Object?>{'large': 'x' * 70000},
        'deleted': false,
        'resource': null,
      }),
    );
    final metadataBytes = Uint8List.fromList(metadata);
    final metadataSha = sha256.convert(metadataBytes).toString();
    final target = CloudSyncSnapshotData([
      CloudSyncRecord(
        id: _stableId(adapter.id, 'new-local-record'),
        kind: 'metadata',
        binary: false,
        deleted: false,
        payload: await source.materializeRemotePayload(
          metadataBytes,
          expectedLength: metadataBytes.length,
          expectedSha256: metadataSha,
        ),
      ),
    ]);
    final recovery = await source.buildRecoveryPoint(
      local: await source.captureLocal(),
      target: target,
    );

    await source.stage('partial-apply', target, recoveryPoint: recovery);
    await source.rollbackForRecovery('partial-apply');

    expect(adapter.applied, hasLength(1));
    expect(adapter.applied.single.id, 'new-local-record');
    expect(adapter.applied.single.deleted, isTrue);
    expect(adapter.applied.single.data, isEmpty);
  });

  test('corrupt staged ref cannot block durable recovery rollback', () async {
    final adapter = _Adapter();
    final source = AppCloudSyncDataSource(
      registry: CloudSyncDataAdapterRegistry([adapter]),
      root: root,
    );
    final recovery = await source.captureLocal();
    final target = await source.captureLocal();
    await source.stage('corrupt-ref', target, recoveryPoint: recovery);
    final ref = Directory('${root.path}/staging/corrupt-ref/refs')
        .listSync()
        .whereType<File>()
        .singleWhere((file) => file.path.endsWith('.ref'));
    await ref.writeAsString('{broken', flush: true);

    await source.rollbackForRecovery('corrupt-ref');

    expect(adapter.applied, isEmpty);
  });

  test('resource chunks cannot exceed the plain object payload budget', () {
    final adapter = _Adapter();

    expect(
      () => AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: maxCloudRecordPayloadBytes + 1,
      ),
      throwsArgumentError,
    );
  });

  test(
    'remote adapters outside local scope remain opaque and are not applied',
    () async {
      final remoteAdapter = _Adapter('remote-adapter')
        ..exported = [
          _portable('remote-adapter', 'remote', [1, 2, 3]),
        ];
      final remoteSource = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([remoteAdapter]),
        root: Directory('${root.path}/remote'),
        chunkSize: 2,
      );
      final remoteCapture = await remoteSource.captureLocal();
      final localAdapter = _Adapter('local-adapter');
      final localSource = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([localAdapter]),
        root: Directory('${root.path}/local'),
        chunkSize: 2,
      );
      final remote = CloudSyncSnapshotData(
        await Future.wait(
          remoteCapture.records.values.map(
            (record) => _materializeRecord(localSource, record),
          ),
        ),
      );

      final recovery = await localSource.buildRecoveryPoint(
        local: await localSource.captureLocal(),
        target: remote,
      );
      await localSource.stage('remote-range', remote, recoveryPoint: recovery);
      await localSource.apply('remote-range');
      await localSource.rollbackForRecovery('remote-range');
      await localSource.saveBase(remote, 'snapshot');
      final next = await localSource.captureLocal();

      expect(localAdapter.applied, isEmpty);
      expect(next.records.keys, unorderedEquals(remote.records.keys));
      expect(next.records.values.every((record) => !record.deleted), isTrue);
    },
  );

  test(
    'deselecting a known adapter tombstones it while unknown adapters stay opaque',
    () async {
      final retained = _Adapter('retained')
        ..exported = [
          _portable('retained', 'one', [1, 2]),
        ];
      final removed = _Adapter('removed')
        ..exported = [
          _portable('removed', 'two', [3, 4]),
        ];
      final initial = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([retained, removed]),
        root: root,
        chunkSize: 2,
      );
      final base = await initial.captureLocal();
      await initial.saveBase(base, 'base');
      retained.exported = [];
      final narrowed = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry(
          [retained, removed],
          activeAdapterIds: {'retained'},
        ),
        root: root,
        chunkSize: 2,
      );

      final captured = await narrowed.captureLocal();
      final decoded = await const PortableRecordCodec(
        stableId: _stableId,
      ).decode(captured);

      expect(
        decoded.records.values
            .singleWhere(
              (record) => record.adapterId == 'retained' && record.id == 'one',
            )
            .deleted,
        isTrue,
      );
      expect(decoded.records[_stableId('removed', 'two')]!.deleted, isTrue);
      expect(decoded.metadataChunks[_stableId('removed', 'two')], isEmpty);
    },
  );

  test(
    'strict metadata rejection occurs before staging or adapter mutation',
    () async {
      final adapter = _Adapter()
        ..exported = [
          _portable('test-adapter', 'bad', [1]),
        ];
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
      );
      final valid = await source.captureLocal();
      final metadata = valid.records.values.singleWhere(
        (record) => record.kind == 'metadata',
      );
      final document =
          jsonDecode(utf8.decode((await metadata.readBytes())!))
              as Map<String, dynamic>;
      final resource = document['resource'] as Map<String, dynamic>;
      final invalidDocuments = <Map<String, dynamic>>[
        {
          ...document,
          'resource': {...resource, 'path': '../escape.bin'},
        },
        {...document, 'unexpected': true},
        {
          ...document,
          'resource': {...resource, 'length': '1'},
        },
        {
          ...document,
          'resource': {
            ...resource,
            'chunks': ['${metadata.id}.c0', '${metadata.id}.c0'],
          },
        },
      ];
      for (var index = 0; index < invalidDocuments.length; index++) {
        await expectLater(
          source.stage(
            'malformed-$index',
            _replaceMetadata(valid, metadata, invalidDocuments[index]),
          ),
          throwsA(isA<CloudFormatException>()),
        );
      }
      final mismatchedMetadata = CloudSyncSnapshotData([
        for (final record in valid.records.values)
          if (record.id == metadata.id)
            CloudSyncRecord(
              id: record.id,
              kind: record.kind,
              binary: !record.binary,
              deleted: false,
              payload: record.payload,
            )
          else
            record,
      ]);
      await expectLater(
        source.stage('mismatched-metadata', mismatchedMetadata),
        throwsA(isA<CloudFormatException>()),
      );
      final resourceChunk = valid.records.values.singleWhere(
        (record) => record.kind == 'resource',
      );
      final nonBinaryResource = CloudSyncSnapshotData([
        for (final record in valid.records.values)
          if (record.id == resourceChunk.id)
            CloudSyncRecord(
              id: record.id,
              kind: record.kind,
              binary: false,
              deleted: false,
              payload: record.payload,
            )
          else
            record,
      ]);
      await expectLater(
        source.stage('non-binary-resource', nonBinaryResource),
        throwsA(isA<CloudFormatException>()),
      );
      final orphan = CloudSyncSnapshotData([
        ...valid.records.values,
        CloudSyncRecord(
          id: 'orphan',
          kind: 'resource',
          binary: true,
          deleted: false,
          bytes: Uint8List.fromList([9]),
        ),
      ]);
      await expectLater(
        source.stage('orphan', orphan),
        throwsA(isA<CloudFormatException>()),
      );
      expect(adapter.applied, isEmpty);
      expect(await Directory('${root.path}/staging').exists(), isFalse);
    },
  );

  test(
    'keepBoth copies metadata and every resource chunk as one record',
    () async {
      final adapter = _Adapter();
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );
      adapter.exported = [
        _portable(adapter.id, 'asset', [1, 1, 1]),
      ];
      final base = await source.captureLocal();
      adapter.exported = [
        _portable(adapter.id, 'asset', [2, 2, 2]),
      ];
      final local = await source.captureLocal();
      adapter.exported = [
        _portable(adapter.id, 'asset', [3, 3, 3]),
      ];
      final remote = await source.captureLocal();

      final merged = await const CloudRecordMerger().merge(
        base: base,
        local: local,
        remote: remote,
        resolve: (_) => ConflictChoice.keepBoth,
        conflictCopier: source,
      );
      final decoded = await const PortableRecordCodec(
        stableId: _stableId,
      ).decode(merged.snapshot);

      expect(merged.conflicts, isEmpty);
      expect(decoded.records, hasLength(2));
      expect(
        decoded.records.values.map((record) => record.id).toSet(),
        hasLength(2),
      );
      expect(
        decoded.records.values
            .map((record) => record.resource!.relativePath)
            .toSet(),
        hasLength(2),
      );
      expect(
        decoded.metadataChunks.values.expand((ids) => ids).toSet(),
        hasLength(4),
      );
      await source.stage('keep-both', merged.snapshot);
      await source.apply('keep-both');
      expect(adapter.applied, hasLength(2));
      expect(
        await Future.wait(
          adapter.applied.map((record) => _readAll(record.resource!)),
        ),
        containsAll(<List<int>>[
          [2, 2, 2],
          [3, 3, 3],
        ]),
      );
    },
  );

  test(
    'propagated resource deletion leaves only its metadata tombstone',
    () async {
      final adapter = _Adapter();
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );
      adapter.exported = [
        _portable(adapter.id, 'asset', [1, 2, 3]),
      ];
      final base = await source.captureLocal();
      await source.saveBase(base, 'base');
      adapter.exported = [];
      final local = await source.captureLocal();

      final merged = await const CloudRecordMerger().merge(
        base: base,
        local: local,
        remote: base,
        conflictCopier: source,
      );
      final decoded = await const PortableRecordCodec(
        stableId: _stableId,
      ).decode(merged.snapshot);

      expect(merged.snapshot.records.values, hasLength(1));
      expect(decoded.records.values.single.deleted, isTrue);
      expect(decoded.metadataChunks.values.single, isEmpty);
    },
  );

  test(
    'staged target survives data source reconstruction and cleanup',
    () async {
      final adapter = _Adapter()
        ..exported = [
          _portable('test-adapter', 'asset', [1, 2, 3, 4]),
        ];
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );
      final target = await source.captureLocal();
      await source.stage('durable-op', target);
      final fingerprint = await source.stagedFingerprint('durable-op');

      final rebuilt = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );
      final recovered = await rebuilt.readStaged('durable-op');
      expect(await rebuilt.stagedFingerprint('durable-op'), fingerprint);
      expect(recovered.records.keys, unorderedEquals(target.records.keys));

      final applying = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );
      CloudSyncTelemetrySnapshot? applyMetrics;
      await CloudSyncTelemetry.trace(
        'durable-apply-test',
        () => applying.apply('durable-op'),
        onComplete: (value) => applyMetrics = value,
      );
      expect(
        applyMetrics!.payloadReads,
        target.records.values
            .where((record) => record.kind == 'metadata')
            .length,
      );
      expect(
        applyMetrics!.hashPasses,
        target.records.values.where((record) => record.payload != null).length,
      );

      await applying.writeUploadArtifact('durable-op', 'object-0.bin', [7, 8]);
      await applying.completeOperation('durable-op');
      expect(
        await Directory('${root.path}/staging/durable-op').exists(),
        isFalse,
      );
      expect(
        await Directory('${root.path}/recovery/durable-op').exists(),
        isFalse,
      );
      expect(
        await Directory('${root.path}/upload/durable-op').exists(),
        isFalse,
      );
    },
  );

  test(
    'sync and restore previews survive data source reconstruction',
    () async {
      final adapter = _Adapter()
        ..exported = [
          _portable('test-adapter', 'asset', [1, 2, 3]),
        ];
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );
      final snapshot = await source.captureLocal();
      final head = SnapshotHead(
        snapshotId: 'snapshot-1',
        manifestSha256: List.filled(64, 'a').join(),
        updatedAt: DateTime.utc(2026),
      );
      await source.saveSyncPreview(
        CloudSyncPreparedPreview(
          local: snapshot,
          base: const CloudSyncSnapshotData.empty(),
          remoteRevision: 'revision-1',
          remoteHead: head,
          remote: snapshot,
        ),
      );
      await source.saveRestorePreview(
        'snapshot-1',
        CloudSyncPreparedRestore(
          local: snapshot,
          target: snapshot,
          remoteRevision: 'remote-revision',
        ),
      );

      final rebuilt = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
        chunkSize: 2,
      );
      final syncPreview = await rebuilt.readSyncPreview();
      final restorePreview = await rebuilt.readRestorePreview('snapshot-1');

      expect(syncPreview!.remoteRevision, 'revision-1');
      expect(syncPreview.remoteHead!.snapshotId, 'snapshot-1');
      expect(
        syncPreview.local.records.keys,
        unorderedEquals(snapshot.records.keys),
      );
      expect(
        restorePreview!.target.records.keys,
        unorderedEquals(snapshot.records.keys),
      );

      await rebuilt.deleteSyncPreview();
      await rebuilt.deleteRestorePreviews();
      expect(await rebuilt.readSyncPreview(), isNull);
      expect(await rebuilt.readRestorePreview('snapshot-1'), isNull);
    },
  );

  test(
    'startup GC preserves blobs referenced only by a durable preview',
    () async {
      final registry = CloudSyncDataAdapterRegistry([_Adapter()]);
      final source = AppCloudSyncDataSource(registry: registry, root: root);
      const bytes = [9, 8, 7];
      final payload = await source.materializeRemotePayload(
        bytes,
        expectedLength: bytes.length,
        expectedSha256: sha256.convert(bytes).toString(),
      );
      final remote = CloudSyncSnapshotData([
        CloudSyncRecord(
          id: 'remote-only',
          kind: 'resource',
          binary: true,
          deleted: false,
          payload: payload,
        ),
      ]);
      await source.saveSyncPreview(
        CloudSyncPreparedPreview(
          local: const CloudSyncSnapshotData.empty(),
          base: const CloudSyncSnapshotData.empty(),
          remoteRevision: 'revision',
          remoteHead: SnapshotHead(
            snapshotId: 'remote-snapshot',
            manifestSha256: List.filled(64, 'a').join(),
            updatedAt: DateTime.utc(2026),
          ),
          remote: remote,
        ),
      );
      final blob = File('${root.path}/blobs/${payload.sha256}');
      await blob.setLastModified(
        DateTime.now().toUtc().subtract(const Duration(days: 8)),
      );

      final rebuilt = AppCloudSyncDataSource(registry: registry, root: root);
      await rebuilt.captureLocal();
      final preview = await rebuilt.readSyncPreview();

      expect(await preview!.remote!.records['remote-only']!.readBytes(), [
        9,
        8,
        7,
      ]);
    },
  );

  test(
    'base recovery survives a crash after publishing the replacement base',
    () async {
      final adapter = _Adapter()
        ..exported = [
          _portable('test-adapter', 'asset', [1]),
        ];
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
      );
      final previous = await source.captureLocal();
      await source.saveBase(previous, 'previous-base');
      adapter.exported = [
        _portable('test-adapter', 'asset', [2]),
      ];
      final target = await source.captureLocal();
      await source.stage(
        'base-publication-crash',
        target,
        recoveryPoint: previous,
      );
      await source.apply('base-publication-crash');
      await source.saveBase(target, 'replacement-base');

      final rebuilt = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
      );
      await rebuilt.rollbackForRecovery('base-publication-crash');
      await rebuilt.restoreBaseForRecovery('base-publication-crash');

      final restoredBase = await rebuilt.readBase();
      expect(
        restoredBase!.records.keys,
        unorderedEquals(previous.records.keys),
      );
      for (final entry in previous.records.entries) {
        expect(restoredBase.records[entry.key], entry.value);
      }
      expect(await adapter.applied.last.resource!.openRead().single, [1]);
      await rebuilt.completeOperation('base-publication-crash');
      expect(
        await Directory(
          '${root.path}/base-recovery/base-publication-crash',
        ).exists(),
        isFalse,
      );
    },
  );

  test('same-size blob corruption is rejected after reconstruction', () async {
    final adapter = _Adapter()
      ..exported = [
        _portable('test-adapter', 'asset', [1, 2, 3]),
      ];
    final source = AppCloudSyncDataSource(
      registry: CloudSyncDataAdapterRegistry([adapter]),
      root: root,
      chunkSize: 2,
    );
    await source.stage('truncated-op', await source.captureLocal());
    final blobs = Directory(
      '${root.path}/blobs',
    ).listSync().whereType<File>().toList();
    final resourceBlob = blobs.singleWhere((blob) => blob.lengthSync() == 2);
    final original = await resourceBlob.readAsBytes();
    original[0] ^= 0xff;
    await resourceBlob.writeAsBytes(original, flush: true);
    final rebuilt = AppCloudSyncDataSource(
      registry: CloudSyncDataAdapterRegistry([adapter]),
      root: root,
      chunkSize: 2,
    );

    await expectLater(
      rebuilt.readStaged('truncated-op'),
      throwsA(isA<CloudFormatException>()),
    );
    expect(adapter.applied, isEmpty);
  });

  test(
    'startup maintenance removes expired orphan and temporary blobs',
    () async {
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([_Adapter()]),
        root: root,
      );
      final bytes = Uint8List.fromList([9, 8, 7]);
      final digest = sha256.convert(bytes).toString();
      await source.materializeRemotePayload(
        bytes,
        expectedLength: bytes.length,
        expectedSha256: digest,
      );
      final old = DateTime.now().subtract(const Duration(days: 8));
      final orphan = File('${root.path}/blobs/$digest');
      await orphan.setLastModified(old);
      final temporary = File('${root.path}/blob-temporary/interrupted');
      await temporary.parent.create(recursive: true);
      await temporary.writeAsBytes([1]);
      await temporary.setLastModified(old);

      final rebuilt = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([_Adapter()]),
        root: root,
      );
      await rebuilt.captureLocal();

      expect(await orphan.exists(), isFalse);
      expect(await temporary.exists(), isFalse);
    },
  );

  test(
    'apply skips unchanged live records and sends only changed records',
    () async {
      final adapter = _Adapter();
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
      );
      adapter.exported = [
        _portable(adapter.id, 'unchanged', [1]),
        _portable(adapter.id, 'changed', [2]),
      ];
      final local = await source.captureLocal();
      final equivalentTarget = await source.captureLocal();

      await source.stage(
        'unchanged-op',
        equivalentTarget,
        recoveryPoint: local,
      );
      await source.apply('unchanged-op');
      expect(adapter.applyCalls, 0);

      adapter.exported = [
        _portable(adapter.id, 'unchanged', [1]),
        _portable(adapter.id, 'changed', [3]),
      ];
      final target = await source.captureLocal();
      await source.stage('changed-op', target, recoveryPoint: local);
      await source.apply('changed-op');

      expect(adapter.applyCalls, 1);
      expect(adapter.applied.map((record) => record.id), ['changed']);
    },
  );

  test('apply deletes a live baseline record omitted by the target', () async {
    final adapter = _Adapter();
    final source = AppCloudSyncDataSource(
      registry: CloudSyncDataAdapterRegistry([adapter]),
      root: root,
    );
    adapter.exported = [
      PortableSyncRecord(
        adapterId: adapter.id,
        id: 'removed',
        kind: 'item',
        data: const {'name': 'local'},
      ),
    ];
    final local = await source.captureLocal();
    final target = CloudSyncSnapshotData(const []);
    final recovery = await source.buildRecoveryPoint(
      local: local,
      target: target,
    );

    await source.stage('removed-op', target, recoveryPoint: recovery);
    await source.apply('removed-op');

    expect(adapter.applyCalls, 1);
    expect(adapter.applied, hasLength(1));
    final deletion = adapter.applied.single;
    expect(deletion.adapterId, adapter.id);
    expect(deletion.id, 'removed');
    expect(deletion.kind, 'item');
    expect(deletion.data, isEmpty);
    expect(deletion.deleted, isTrue);
    expect(deletion.resource, isNull);
  });
}

class _Adapter extends ValidatingCloudSyncDataAdapter
    implements CloudSyncConflictCopyAdapter {
  _Adapter([this.id = 'test-adapter']);

  List<PortableSyncRecord> exported = [];
  List<PortableSyncRecord> applied = [];
  int exportCalls = 0;
  int applyCalls = 0;

  @override
  final String id;

  @override
  Set<String> get allowedKinds => const {'item'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    exportCalls++;
    yield* Stream.fromIterable(exported);
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    applyCalls++;
    applied = records;
  }

  @override
  PortableSyncRecord copyForConflict(
    PortableSyncRecord source, {
    required String newPortableId,
  }) => PortableSyncRecord(
    adapterId: id,
    id: newPortableId,
    kind: source.kind,
    data: source.data,
    resource: source.resource == null
        ? null
        : PortableSyncResource(
            relativePath: '$id/$newPortableId.bin',
            length: source.resource!.length,
            openRead: source.resource!.openRead,
          ),
  );
}

PortableSyncRecord _portable(String adapterId, String id, List<int> bytes) =>
    PortableSyncRecord(
      adapterId: adapterId,
      id: id,
      kind: 'item',
      data: {'revision': bytes.isEmpty ? 0 : bytes.first},
      resource: PortableSyncResource(
        relativePath: '$adapterId/$id.bin',
        length: bytes.length,
        openRead: () => Stream.value(bytes),
      ),
    );

Future<CloudSyncRecord> _materializeRecord(
  AppCloudSyncDataSource source,
  CloudSyncRecord record,
) async {
  if (record.deleted) return record;
  final bytes = await record.payload!.readBytes();
  return CloudSyncRecord(
    id: record.id,
    kind: record.kind,
    binary: record.binary,
    deleted: false,
    payload: await source.materializeRemotePayload(
      bytes,
      expectedLength: record.payload!.length,
      expectedSha256: record.payload!.sha256,
    ),
  );
}

String _stableId(String adapterId, String id) =>
    'r-${sha256.convert(utf8.encode('$adapterId\u0000$id'))}';

Future<List<int>> _readAll(PortableSyncResource resource) => resource
    .openRead()
    .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));

CloudSyncSnapshotData _replaceMetadata(
  CloudSyncSnapshotData source,
  CloudSyncRecord metadata,
  Map<String, dynamic> document,
) => CloudSyncSnapshotData([
  for (final record in source.records.values)
    record.id == metadata.id
        ? CloudSyncRecord(
            id: record.id,
            kind: record.kind,
            binary: record.binary,
            deleted: record.deleted,
            bytes: Uint8List.fromList(utf8.encode(jsonEncode(document))),
          )
        : record,
]);
