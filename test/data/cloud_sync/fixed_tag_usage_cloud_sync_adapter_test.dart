import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter.dart';
import 'package:nai_launcher/data/cloud_sync/fixed_tag_usage_cloud_sync_adapter.dart';
import 'package:nai_launcher/data/cloud_sync/portable_sync_record.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

const _snapshot = FixedTagUsageSnapshot(
  entries: [
    FixedTagUsageEntry(
      fixedTagId: 'fixed-a',
      name: 'A',
      content: 'masterpiece',
      weight: 1,
      renderedContent: 'masterpiece',
      position: FixedTagPosition.prefix,
      promptType: FixedTagPromptType.positive,
      order: 0,
    ),
  ],
);

PortableSyncRecord _snapshotRecord({
  String? fingerprint,
  String? id,
  Map<String, dynamic>? snapshot,
}) {
  final effective = fingerprint ?? _snapshot.fingerprint;
  return PortableSyncRecord(
    adapterId: 'fixed-tag-usage',
    id: id ?? 'snapshot:$effective',
    kind: 'snapshot',
    data: {
      'fingerprint': effective,
      'snapshot': snapshot ?? _snapshot.toJson(),
    },
  );
}

PortableSyncRecord _usageRecord({
  String contentHash = _hashA,
  String? fingerprint,
  String? id,
  int recordedAt = 1000,
  bool deleted = false,
}) => PortableSyncRecord(
  adapterId: 'fixed-tag-usage',
  id: id ?? 'usage:$contentHash',
  kind: 'usage',
  deleted: deleted,
  data: deleted
      ? {'contentHash': contentHash}
      : {
          'contentHash': contentHash,
          'fingerprint': fingerprint ?? _snapshot.fingerprint,
          'recordedAt': recordedAt,
        },
);

void main() {
  late Directory directory;
  late FixedTagUsageRecordStore store;
  late FixedTagUsageCloudSyncAdapter adapter;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fixed-tag-usage-sync-');
    Hive.init(directory.path);
    store = FixedTagUsageRecordStore();
    await store.initialize();
    adapter = FixedTagUsageCloudSyncAdapter(store);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'exports deduplicated snapshots plus one usage record per image',
    () async {
      await store.record(contentHash: _hashA, snapshot: _snapshot);
      await store.record(contentHash: _hashB, snapshot: _snapshot);

      final records = await adapter.exportRecords().toList();

      expect(
        records.where((record) => record.kind == 'snapshot'),
        hasLength(1),
      );
      final usage = records.where((record) => record.kind == 'usage').toList();
      expect(usage.map((record) => record.id), [
        'usage:$_hashA',
        'usage:$_hashB',
      ]);
      expect(usage.first.data.keys.toSet(), {
        'contentHash',
        'fingerprint',
        'recordedAt',
      });
      await adapter.preflight(records);
    },
  );

  test('rejects malformed identities and mismatched payloads', () async {
    await expectLater(
      adapter.preflight([_usageRecord(contentHash: 'nope', id: 'usage:nope')]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
    await expectLater(
      adapter.preflight([_usageRecord(id: 'usage:$_hashB')]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
    await expectLater(
      adapter.preflight([
        _snapshotRecord(snapshot: const FixedTagUsageSnapshot().toJson()),
      ]),
      throwsA(isA<CloudSyncPreflightException>()),
    );
  });

  test('preflight requires the referenced snapshot to exist', () async {
    await expectLater(
      adapter.preflight([_usageRecord()]),
      throwsA(isA<CloudSyncPreflightException>()),
    );

    await adapter.preflight([_snapshotRecord(), _usageRecord()]);

    await store.record(contentHash: _hashB, snapshot: _snapshot);
    await adapter.preflight([_usageRecord()]);
  });

  test('apply lands the target usage regardless of recordedAt', () async {
    const other = FixedTagUsageSnapshot();

    await adapter.apply([_snapshotRecord(), _usageRecord(recordedAt: 2000)]);
    expect(store.lookup(_hashA)?.entries.single.fixedTagId, 'fixed-a');

    await adapter.apply([
      _snapshotRecord(fingerprint: other.fingerprint, snapshot: other.toJson()),
      _usageRecord(fingerprint: other.fingerprint, recordedAt: 1000),
    ]);
    final restored = store.lookup(_hashA);
    expect(restored, isNotNull);
    expect(restored!.entries, isEmpty);

    await adapter.apply([_snapshotRecord(), _usageRecord(recordedAt: 3000)]);
    expect(store.lookup(_hashA)?.entries.single.fixedTagId, 'fixed-a');
  });

  test('rollback reapplies the earlier target', () async {
    const other = FixedTagUsageSnapshot();

    await adapter.apply([_snapshotRecord(), _usageRecord(recordedAt: 3000)]);
    expect(store.lookup(_hashA)?.entries.single.fixedTagId, 'fixed-a');

    await adapter.apply([
      _snapshotRecord(fingerprint: other.fingerprint, snapshot: other.toJson()),
      _usageRecord(fingerprint: other.fingerprint, recordedAt: 2000),
    ]);
    final rolledBack = store.lookup(_hashA);
    expect(rolledBack, isNotNull);
    expect(rolledBack!.entries, isEmpty);
  });

  test('apply honours usage tombstones', () async {
    await adapter.apply([_snapshotRecord(), _usageRecord(recordedAt: 2000)]);
    expect(store.lookup(_hashA), isNotNull);

    await adapter.apply([_usageRecord(deleted: true)]);
    expect(store.lookup(_hashA), isNull);
  });
}
