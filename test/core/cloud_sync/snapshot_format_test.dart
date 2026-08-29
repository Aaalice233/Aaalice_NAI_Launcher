import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/object_codec.dart';

void main() {
  test('new snapshots are self-describing plaintext v2 documents', () async {
    const codec = PlainCloudObjectCodec();
    final manifest = SnapshotManifest(
      snapshotId: 'snapshot-1',
      createdAt: DateTime.utc(2026),
      objects: const [],
      encoding: codec.encoding,
    );
    final encoded = await codec.encode(
      manifest.encode(),
      objectId: manifest.snapshotId,
      kind: 'manifest',
    );
    final json = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;

    expect(json['version'], cloudSyncPlainSnapshotVersion);
    expect(json['encoding'], 'plain');
    expect(SnapshotManifest.decode(encoded).encoding, codec.encoding);
  });

  test('v1 heads remain classified as legacy encrypted backups', () {
    final head = SnapshotHead(
      snapshotId: 'legacy-1',
      manifestSha256: List.filled(64, '0').join(),
      updatedAt: DateTime.utc(2026),
    );

    expect(
      SnapshotHead.decode(head.encode()).encoding,
      CloudSnapshotEncoding.encrypted,
    );
    expect(jsonDecode(utf8.decode(head.encode())), isNot(contains('encoding')));
  });
}
