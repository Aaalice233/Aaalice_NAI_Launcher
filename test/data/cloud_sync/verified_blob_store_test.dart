import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_operation_storage.dart';
import 'package:nai_launcher/data/cloud_sync/verified_blob_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('verified-blob-store-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('identical input reuses one immutable content-addressed blob', () async {
    final store = VerifiedBlobStore(root);
    var opens = 0;
    const bytes = [1, 2, 3, 4];
    final digest = sha256.convert(bytes).toString();

    for (var index = 0; index < 2; index++) {
      final handle = await store.putStream(
        () {
          opens++;
          return Stream.value(bytes);
        },
        expectedLength: bytes.length,
        expectedSha256: digest,
      );
      expect(handle.sha256, digest);
      expect(handle, isA<VerifiedCloudSyncPayload>());
    }

    expect(opens, 2);
    expect(Directory('${root.path}/blobs').listSync(), hasLength(1));
  });

  test('verified handle hashes new bytes once across repeated reads', () async {
    final store = VerifiedBlobStore(root);
    CloudSyncTelemetrySnapshot? metrics;

    await CloudSyncTelemetry.trace('verified-blob-single-hash', () async {
      final handle = await store.putBytes(const [1, 2, 3, 4]);
      expect(await handle.readBytes(), const [1, 2, 3, 4]);
      expect(await handle.readBytes(), const [1, 2, 3, 4]);
    }, onComplete: (value) => metrics = value);

    expect(metrics!.hashPasses, 1);
  });

  test('existing corrupted blob is rejected and never overwritten', () async {
    final first = VerifiedBlobStore(root);
    const bytes = [1, 2, 3, 4];
    final digest = sha256.convert(bytes).toString();
    await first.putBytes(bytes);
    final blob = File('${root.path}/blobs/$digest');
    await blob.writeAsBytes(const [4, 3, 2, 1], flush: true);

    final rebuilt = VerifiedBlobStore(root);
    await expectLater(
      rebuilt.putStream(
        () => Stream.value(bytes),
        expectedLength: bytes.length,
        expectedSha256: digest,
      ),
      throwsA(isA<CloudFormatException>()),
    );
    expect(await blob.readAsBytes(), const [4, 3, 2, 1]);
  });

  test('same-process cache rejects same-size blob replacement', () async {
    final store = VerifiedBlobStore(root);
    const bytes = [1, 2, 3, 4];
    final digest = sha256.convert(bytes).toString();
    final handle = await store.putBytes(bytes);
    final blob = File('${root.path}/blobs/$digest');
    await blob.writeAsBytes(const [4, 3, 2, 1], flush: true);
    await blob.setLastModified(DateTime.now().add(const Duration(seconds: 1)));

    await expectLater(
      store.assertVerifiedHandle(handle),
      throwsA(isA<CloudFormatException>()),
    );
  });

  test(
    'published snapshot descriptors expose all reachable blob refs',
    () async {
      final store = VerifiedBlobStore(root);
      final storage = CloudSyncOperationStorage(root, store);
      final first = await store.putBytes(const [1]);
      final second = await store.putBytes(const [2, 3]);
      final snapshot = CloudSyncSnapshotData([
        CloudSyncRecord(
          id: 'first',
          kind: 'item',
          binary: true,
          deleted: false,
          payload: first,
        ),
        CloudSyncRecord(
          id: 'second',
          kind: 'item',
          binary: true,
          deleted: false,
          payload: second,
        ),
      ]);

      await storage.writeSnapshot(storage.stage('op'), snapshot);

      final refs = await storage.descriptorRefs().toList();
      expect(
        refs.map((ref) => '${ref.sha256}:${ref.length}'),
        unorderedEquals(['${first.sha256}:1', '${second.sha256}:2']),
      );
    },
  );

  test('blob GC preserves shared and pending descriptor references', () async {
    final store = VerifiedBlobStore(root);
    final storage = CloudSyncOperationStorage(root, store);
    final shared = await store.putBytes(const [1, 2, 3]);
    final orphan = await store.putBytes(const [9, 8, 7]);
    CloudSyncSnapshotData snapshot(String id) => CloudSyncSnapshotData([
      CloudSyncRecord(
        id: id,
        kind: 'resource',
        binary: true,
        deleted: false,
        payload: shared,
      ),
    ]);
    await storage.writeSnapshot(storage.stage('pending-a'), snapshot('a'));
    await storage.writeSnapshot(storage.stage('pending-b'), snapshot('b'));
    final part = File('${root.path}/blobs/unfinished.part');
    await part.writeAsBytes(const [4]);

    expect(
      await storage.collectUnreferencedBlobs(gracePeriod: Duration.zero),
      1,
    );
    expect(File('${root.path}/blobs/${shared.sha256}').existsSync(), isTrue);
    expect(File('${root.path}/blobs/${orphan.sha256}').existsSync(), isFalse);
    expect(part.existsSync(), isTrue);
  });

  test('snapshot publication is atomic with local blob GC', () async {
    final store = VerifiedBlobStore(root);
    final storage = CloudSyncOperationStorage(root, store);
    final payload = await store.putBytes(const [1, 2, 3]);
    final snapshot = CloudSyncSnapshotData([
      CloudSyncRecord(
        id: 'record',
        kind: 'resource',
        binary: true,
        deleted: false,
        payload: payload,
      ),
    ]);
    final stage = storage.stage('concurrent');

    await Future.wait([
      storage.writeSnapshot(stage, snapshot),
      storage.collectUnreferencedBlobs(gracePeriod: Duration.zero),
    ]);

    expect(await storage.readSnapshot(stage), isNotNull);
    expect(File('${root.path}/blobs/${payload.sha256}').existsSync(), isTrue);
  });

  test('clock rollback cannot hide a newly published generation', () async {
    final store = VerifiedBlobStore(root);
    var now = DateTime.utc(2030);
    final storage = CloudSyncOperationStorage(root, store, now: () => now);
    final first = await store.putBytes(const [1]);
    final second = await store.putBytes(const [2]);
    CloudSyncSnapshotData snapshot(String id, CloudSyncPayload payload) =>
        CloudSyncSnapshotData([
          CloudSyncRecord(
            id: id,
            kind: 'resource',
            binary: true,
            deleted: false,
            payload: payload,
          ),
        ]);
    final base = Directory('${root.path}/base');

    await storage.writeSnapshot(base, snapshot('before', first));
    now = DateTime.utc(2020);
    await storage.writeSnapshot(base, snapshot('after', second));

    final restored = await storage.readSnapshot(base);
    expect(restored?.records.keys, ['after']);
    final refNames =
        Directory('${base.path}/refs')
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    expect(refNames, hasLength(2));
    final firstSequence = int.parse(refNames.first.split('.').first);
    final secondSequence = int.parse(refNames.last.split('.').first);
    expect(secondSequence, greaterThan(firstSequence));
  });

  test('blob GC prunes superseded generations and their blobs', () async {
    final store = VerifiedBlobStore(root);
    final storage = CloudSyncOperationStorage(root, store);
    final oldPayload = await store.putBytes(const [1]);
    final currentPayload = await store.putBytes(const [2]);
    CloudSyncSnapshotData snapshot(CloudSyncPayload payload) =>
        CloudSyncSnapshotData([
          CloudSyncRecord(
            id: 'record',
            kind: 'resource',
            binary: true,
            deleted: false,
            payload: payload,
          ),
        ]);

    final base = Directory('${root.path}/base');
    await storage.writeSnapshot(base, snapshot(oldPayload));
    await storage.writeSnapshot(base, snapshot(currentPayload));

    expect(
      await storage.collectUnreferencedBlobs(gracePeriod: Duration.zero),
      1,
    );
    expect(
      File('${root.path}/blobs/${oldPayload.sha256}').existsSync(),
      isFalse,
    );
    expect(
      File('${root.path}/blobs/${currentPayload.sha256}').existsSync(),
      isTrue,
    );
    expect(Directory('${base.path}/refs').listSync(), hasLength(1));
    expect(Directory('${base.path}/generations').listSync(), hasLength(1));
  });

  test(
    'blob GC prunes aged pending refs and unpublished generations',
    () async {
      final store = VerifiedBlobStore(root);
      final storage = CloudSyncOperationStorage(root, store);
      final owner = storage.stage('interrupted');
      final pending = File('${owner.path}/refs/00000000000000000000.pending');
      final generation = Directory(
        '${owner.path}/generations/00000000000000000000-00000000',
      );
      await pending.parent.create(recursive: true);
      await pending.writeAsString('reserved');
      await generation.create(recursive: true);
      await File('${generation.path}/index.json').writeAsString('{}');

      await storage.collectUnreferencedBlobs(gracePeriod: Duration.zero);

      expect(pending.existsSync(), isFalse);
      expect(generation.existsSync(), isFalse);
    },
  );

  test('invalid published descriptor makes blob GC delete nothing', () async {
    final store = VerifiedBlobStore(root);
    final storage = CloudSyncOperationStorage(root, store);
    final orphan = await store.putBytes(const [7, 7, 7]);
    final refs = Directory('${storage.stage('broken').path}/refs');
    await refs.create(recursive: true);
    await File('${refs.path}/000.ref').writeAsString('{broken');

    await expectLater(
      storage.collectUnreferencedBlobs(gracePeriod: Duration.zero),
      throwsA(anything),
    );
    expect(File('${root.path}/blobs/${orphan.sha256}').existsSync(), isTrue);
  });
}
