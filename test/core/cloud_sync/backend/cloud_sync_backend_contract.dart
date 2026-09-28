import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';

typedef CloudSyncBackendFactory = CloudSyncBackend Function();

class CloudSyncBackendContractExpectations {
  const CloudSyncBackendContractExpectations({
    required this.mode,
    this.supportsHistory = true,
    this.supportsDelete = true,
    this.rejectsStaleHeadRevision = true,
  });

  final CloudBackendMode mode;
  final bool supportsHistory;
  final bool supportsDelete;
  final bool rejectsStaleHeadRevision;
}

void runCloudSyncBackendContract({
  required String provider,
  required CloudSyncBackendFactory createBackend,
  required CloudSyncBackendContractExpectations expectations,
}) {
  group('$provider CloudSyncBackend contract', () {
    test('empty reads return no records', () async {
      final backend = createBackend();

      expect(await backend.readHead(), isNull);
      expect(await backend.readObject('missing-object'), isNull);
      expect(await backend.readSnapshotManifest('missing-snapshot'), isNull);
      expect(await backend.listSnapshotIds(), isEmpty);
    });

    test(
      'immutable object and manifest roundtrip and reject conflicts',
      () async {
        final backend = createBackend();
        final object = _bytes('object-v1');
        final manifest = _bytes('manifest-v1');
        final head = _bytes('head-v1');

        final objectId = _hash(object);
        await backend.putObject(objectId, object, sha256: objectId);
        await backend.putSnapshotManifest(
          'snapshot-01',
          manifest,
          sha256: _hash(manifest),
        );
        await backend.commitHead(head, expectedRevision: null);

        expect((await backend.readObject(objectId))?.bytes, object);
        expect(
          (await backend.readSnapshotManifest('snapshot-01'))?.bytes,
          manifest,
        );

        await expectLater(
          backend.putObject(
            objectId,
            _bytes('object-v2'),
            sha256: _hash(_bytes('object-v2')),
          ),
          throwsA(_conflict),
        );
        await expectLater(
          backend.putSnapshotManifest(
            'snapshot-01',
            _bytes('manifest-v2'),
            sha256: _hash(_bytes('manifest-v2')),
          ),
          throwsA(_conflict),
        );
      },
    );

    test('verified payload upload performs no provider SHA-256 pass', () async {
      final backend = createBackend();
      final object = _bytes('already-verified-payload');
      final objectId = _hash(object);
      CloudSyncTelemetrySnapshot? metrics;

      await CloudSyncTelemetry.trace(
        'verified-provider-upload',
        () => backend.putObject(
          objectId,
          object,
          sha256: objectId,
          payloadVerified: true,
        ),
        onComplete: (value) => metrics = value,
      );

      expect(metrics?.hashPasses, 0);
    });

    test('HEAD create, update, and stale revision semantics', () async {
      final backend = createBackend();
      final first = await backend.commitHead(
        _bytes('head-v1'),
        expectedRevision: null,
      );
      final second = await backend.commitHead(
        _bytes('head-v2'),
        expectedRevision: first.revision,
      );

      expect(second.revision, isNot(first.revision));
      expect((await backend.readHead())?.bytes, _bytes('head-v2'));

      final staleWrite = backend.commitHead(
        _bytes('head-stale'),
        expectedRevision: first.revision,
      );
      if (expectations.rejectsStaleHeadRevision) {
        await expectLater(staleWrite, throwsA(_conflict));
        expect((await backend.readHead())?.bytes, _bytes('head-v2'));
      } else {
        await expectLater(staleWrite, completes);
      }
    });

    test('snapshot history is newest-first and honors limit', () async {
      final backend = createBackend();
      String? revision;
      for (final id in ['snapshot-01', 'snapshot-03', 'snapshot-02']) {
        final manifest = _bytes('manifest-$id');
        await backend.putSnapshotManifest(
          id,
          manifest,
          sha256: _hash(manifest),
        );
        revision = (await backend.commitHead(
          _bytes('head-$id'),
          expectedRevision: revision,
        )).revision;
      }

      expect(await backend.listSnapshotIds(), [
        'snapshot-03',
        'snapshot-02',
        'snapshot-01',
      ]);
      expect(await backend.listSnapshotIds(limit: 2), [
        'snapshot-03',
        'snapshot-02',
      ]);
      expect(await backend.listSnapshotIds(limit: 0), isEmpty);
    });

    test('namespace delete removes all public records', () async {
      final backend = createBackend();
      final object = _bytes('delete-object');
      final manifest = _bytes('delete-manifest');
      final objectId = _hash(object);
      await backend.putObject(objectId, object, sha256: objectId);
      await backend.putSnapshotManifest(
        'delete',
        manifest,
        sha256: _hash(manifest),
      );
      await backend.commitHead(_bytes('delete-head'), expectedRevision: null);

      await backend.deleteNamespace();

      expect(await backend.readHead(), isNull);
      expect(await backend.readObject(objectId), isNull);
      expect(await backend.readSnapshotManifest('delete'), isNull);
      expect(await backend.listSnapshotIds(), isEmpty);
    });

    test('reports the declared capability mode', () async {
      final capability = await createBackend().testCapability();

      expect(capability.mode, expectations.mode);
      expect(capability.supportsHistory, expectations.supportsHistory);
      expect(capability.supportsDelete, expectations.supportsDelete);
      expect(
        capability.supportsBidirectional,
        expectations.mode == CloudBackendMode.bidirectional,
      );
    });
  });
}

final Matcher _conflict = isA<CloudBackendException>().having(
  (error) => error.kind,
  'kind',
  CloudBackendErrorKind.conflict,
);

Uint8List _bytes(String value) => Uint8List.fromList(utf8.encode(value));

String _hash(Uint8List bytes) => sha256.convert(bytes).toString();
