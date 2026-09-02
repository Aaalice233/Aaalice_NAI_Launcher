import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';

void main() {
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
    expect(json.keys, ['version', 'snapshotId', 'createdAt', 'records']);
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
