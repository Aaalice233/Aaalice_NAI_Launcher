import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/object_codec.dart';

void main() {
  test('snapshots are self-describing plaintext documents', () async {
    const codec = PlainCloudObjectCodec();
    final manifest = SnapshotManifest(
      snapshotId: 'snapshot-1',
      createdAt: DateTime.utc(2026),
      objects: const [],
    );
    final encoded = await codec.encode(
      manifest.encode(),
      objectId: manifest.snapshotId,
      kind: 'manifest',
    );
    final json = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;

    expect(json['version'], cloudSyncSchemaVersion);
    expect(json, isNot(contains('encoding')));
    expect(SnapshotManifest.decode(encoded).snapshotId, manifest.snapshotId);
  });
}
