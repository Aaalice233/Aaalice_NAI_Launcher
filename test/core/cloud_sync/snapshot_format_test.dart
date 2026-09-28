import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';

void main() {
  test('published schema 2 remains readable without a packs field', () {
    const json =
        '{"version":2,"snapshotId":"legacy","createdAt":"2025-01-01T00:00:00.000Z","records":[]}';
    final manifest = SnapshotManifest.decode(utf8.encode(json));
    expect(manifest.version, 2);
    expect(manifest.packs, isEmpty);
    expect(manifest.toJson().containsKey('packs'), isFalse);
    final head = SnapshotHead.decode(
      utf8.encode(
        '{"version":2,"snapshotId":"legacy","manifestSha256":"${'a' * 64}","updatedAt":"2025-01-01T00:00:00.000Z"}',
      ),
    );
    expect(head.version, 2);
  });

  test(
    'pack schema rejects unknown members, duplicates, overlap and oversize',
    () {
      final first = 'a' * 64;
      final second = 'b' * 64;
      final pack = 'c' * 64;
      List<SnapshotRecordRef> records({int size = 1}) => [
        SnapshotRecordRef(
          recordId: 'a',
          kind: 'metadata',
          binary: false,
          deleted: false,
          objectId: first,
          size: size,
        ),
        SnapshotRecordRef(
          recordId: 'b',
          kind: 'metadata',
          binary: false,
          deleted: false,
          objectId: second,
          size: size,
        ),
      ];
      for (final packs in [
        {
          pack: [first, 'd' * 64],
        },
        {
          pack: [first, first],
        },
        {
          first: [first, second],
        },
        {
          pack: [first, second],
          'd' * 64: [first, second],
        },
        {
          pack: [first],
        },
      ]) {
        expect(
          () => SnapshotManifest(
            snapshotId: 'invalid',
            createdAt: DateTime.utc(2026),
            records: records(),
            packs: packs,
          ),
          throwsA(isA<CloudFormatException>()),
        );
      }
      expect(
        () => SnapshotManifest(
          snapshotId: 'oversize',
          createdAt: DateTime.utc(2026),
          records: records(size: maxCloudObjectBytes),
          packs: {
            pack: [first, second],
          },
        ),
        throwsA(isA<CloudFormatException>()),
      );
      final legacy = SnapshotManifest(
        version: 2,
        snapshotId: 'legacy',
        createdAt: DateTime.utc(2026),
        records: records(),
      ).toJson();
      expect(
        () => SnapshotManifest.fromJson({...legacy, 'packs': {}}),
        throwsA(isA<CloudFormatException>()),
      );
    },
  );

  test('manifest is canonical plaintext and describes raw objects', () {
    final payload = utf8.encode('{not-an-envelope: true}');
    final objectId = sha256.convert(payload).toString();
    final manifest = SnapshotManifest(
      snapshotId: 'snapshot-1',
      createdAt: DateTime.utc(2026),
      records: [
        SnapshotRecordRef(
          recordId: 'live',
          kind: 'resource',
          binary: true,
          deleted: false,
          objectId: objectId,
          size: payload.length,
        ),
        SnapshotRecordRef(
          recordId: 'tombstone',
          kind: 'metadata',
          binary: false,
          deleted: true,
        ),
      ],
    );
    final encoded = manifest.encode();
    final json = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;

    expect(json['version'], cloudSyncSchemaVersion);
    expect(json.keys, [
      'version',
      'snapshotId',
      'createdAt',
      'records',
      'packs',
    ]);
    expect(SnapshotManifest.decode(encoded).snapshotId, manifest.snapshotId);
    expect(jsonEncode(json), isNot(contains(base64Encode(payload))));
  });

  test('manifest requires canonical record order and tombstone shape', () {
    expect(
      () => SnapshotManifest(
        snapshotId: 'snapshot-1',
        createdAt: DateTime.utc(2026),
        records: [
          SnapshotRecordRef(
            recordId: 'z',
            kind: 'metadata',
            binary: false,
            deleted: true,
          ),
          SnapshotRecordRef(
            recordId: 'a',
            kind: 'metadata',
            binary: false,
            deleted: true,
          ),
        ],
      ),
      throwsA(isA<CloudFormatException>()),
    );
    expect(
      () => SnapshotRecordRef(
        recordId: 'deleted',
        kind: 'metadata',
        binary: false,
        deleted: true,
        objectId: List.filled(64, '0').join(),
        size: 0,
      ),
      throwsA(isA<CloudFormatException>()),
    );
  });
}
