import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:nai_launcher/core/cloud_sync/cloud_sync.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cloud-data-source-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
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
    'downloaded tombstone carries identity without a local common base',
    () async {
      final adapter = _Adapter();
      final source = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([adapter]),
        root: root,
      );
      final identity = utf8.encode(
        jsonEncode({
          'version': 1,
          'adapterId': adapter.id,
          'portableId': 'gone',
          'kind': 'item',
          'data': <String, Object?>{},
          'deleted': true,
          'resource': null,
        }),
      );
      final remote = CloudSyncSnapshotData([
        CloudSyncRecord(
          id: _stableId(adapter.id, 'gone'),
          kind: 'metadata',
          binary: false,
          deleted: true,
          bytes: Uint8List.fromList(identity),
        ),
      ]);

      await source.stage('download-op', remote);
      await source.apply('download-op');

      expect(adapter.applied, hasLength(1));
      expect(adapter.applied.single.adapterId, adapter.id);
      expect(adapter.applied.single.id, 'gone');
      expect(adapter.applied.single.deleted, isTrue);
    },
  );

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
      final remote = await _resident(await remoteSource.captureLocal());
      final localAdapter = _Adapter('local-adapter');
      final localSource = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([localAdapter]),
        root: Directory('${root.path}/local'),
        chunkSize: 2,
      );

      await localSource.stage('remote-range', remote);
      await localSource.apply('remote-range');
      await localSource.saveBase(remote, 'snapshot');
      final next = await localSource.captureLocal();

      expect(localAdapter.applied, isEmpty);
      expect(next.records.keys, unorderedEquals(remote.records.keys));
      expect(next.records.values.every((record) => !record.deleted), isTrue);
    },
  );

  test(
    'shrinking scope preserves base groups while real in-scope deletion tombstones',
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
      final base = await _resident(await initial.captureLocal());
      await initial.saveBase(base, 'base');
      retained.exported = [];
      final narrowed = AppCloudSyncDataSource(
        registry: CloudSyncDataAdapterRegistry([retained]),
        root: root,
        chunkSize: 2,
      );

      final captured = await narrowed.captureLocal();
      final decoded = await const PortableRecordCodec(
        stableId: _stableId,
      ).decode(captured);

      expect(decoded.records[_stableId('retained', 'one')]!.deleted, isTrue);
      expect(decoded.records[_stableId('removed', 'two')]!.deleted, isFalse);
      expect(decoded.metadataChunks[_stableId('removed', 'two')], [
        '${_stableId('removed', 'two')}.c0',
      ]);
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
      final valid = await _resident(await source.captureLocal());
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
      final base = await _resident(await source.captureLocal());
      adapter.exported = [
        _portable(adapter.id, 'asset', [2, 2, 2]),
      ];
      final local = await _resident(await source.captureLocal());
      adapter.exported = [
        _portable(adapter.id, 'asset', [3, 3, 3]),
      ];
      final remote = await _resident(await source.captureLocal());

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
      final base = await _resident(await source.captureLocal());
      await source.saveBase(base, 'base');
      adapter.exported = [];
      final local = await _resident(await source.captureLocal());

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

      await rebuilt.writeUploadArtifact('durable-op', 'object-0.bin', [7, 8]);
      await rebuilt.completeOperation('durable-op');
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

  test('truncated staged payload is rejected before apply', () async {
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
    final payloads = Directory('${root.path}/staging/truncated-op')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.payload'))
        .toList();
    await payloads.first.writeAsBytes(const [1], flush: true);

    await expectLater(
      source.readStaged('truncated-op'),
      throwsA(isA<CloudFormatException>()),
    );
    expect(adapter.applied, isEmpty);
  });
}

class _Adapter extends ValidatingCloudSyncDataAdapter
    implements CloudSyncConflictCopyAdapter {
  _Adapter([this.id = 'test-adapter']);

  List<PortableSyncRecord> exported = [];
  List<PortableSyncRecord> applied = [];

  @override
  final String id;

  @override
  Set<String> get allowedKinds => const {'item'};

  @override
  Stream<PortableSyncRecord> exportRecords() => Stream.fromIterable(exported);

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
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

String _stableId(String adapterId, String id) =>
    'r-${sha256.convert(utf8.encode('$adapterId\u0000$id'))}';

Future<List<int>> _readAll(PortableSyncResource resource) => resource
    .openRead()
    .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));

Future<CloudSyncSnapshotData> _resident(CloudSyncSnapshotData source) async =>
    CloudSyncSnapshotData([
      for (final record in source.records.values)
        CloudSyncRecord(
          id: record.id,
          kind: record.kind,
          binary: record.binary,
          deleted: record.deleted,
          bytes: await record.readBytes(),
        ),
    ]);

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
