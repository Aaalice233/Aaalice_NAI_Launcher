import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/services/fixed_tag/fixed_tag_usage_record_store.dart';

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _hashC =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

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

void main() {
  late Directory directory;
  late FixedTagUsageRecordStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fixed-tag-usage-store-');
    Hive.init(directory.path);
    store = FixedTagUsageRecordStore();
    await store.initialize();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('records and looks up a snapshot by content hash', () async {
    await store.record(contentHash: _hashA, snapshot: _snapshot);

    expect(store.lookup(_hashA)?.entries.single.fixedTagId, 'fixed-a');
    expect(store.lookup(_hashB), isNull);
  });

  test('an empty snapshot stays an authoritative record', () async {
    await store.record(
      contentHash: _hashA,
      snapshot: const FixedTagUsageSnapshot(),
    );

    final recorded = store.lookup(_hashA);
    expect(recorded, isNotNull);
    expect(recorded!.entries, isEmpty);
  });

  test('copy propagates only when the source has a record', () async {
    await store.record(contentHash: _hashA, snapshot: _snapshot);

    await store.copy(fromHash: _hashA, toHash: _hashB);
    await store.copy(fromHash: _hashC, toHash: _hashC.replaceFirst('c', 'd'));

    expect(store.lookup(_hashB)?.entries.single.fixedTagId, 'fixed-a');
    expect(store.lookup(_hashC.replaceFirst('c', 'd')), isNull);
  });

  test('rejects identifiers that are not lowercase sha-256 digests', () async {
    await expectLater(
      store.record(contentHash: 'not-a-hash', snapshot: _snapshot),
      throwsArgumentError,
    );
    await expectLater(
      store.record(contentHash: _hashA.toUpperCase(), snapshot: _snapshot),
      throwsArgumentError,
    );
    await expectLater(
      store.copy(fromHash: _hashA, toHash: 'short'),
      throwsArgumentError,
    );
  });

  test('the newer recordedAt wins for the same content hash', () async {
    const later = FixedTagUsageSnapshot(
      entries: [
        FixedTagUsageEntry(
          fixedTagId: 'fixed-b',
          name: 'B',
          content: 'best quality',
          weight: 1,
          renderedContent: 'best quality',
          position: FixedTagPosition.suffix,
          promptType: FixedTagPromptType.positive,
          order: 0,
        ),
      ],
    );

    await store.record(
      contentHash: _hashA,
      snapshot: _snapshot,
      recordedAt: DateTime.utc(2026, 1, 2),
    );
    await store.record(
      contentHash: _hashA,
      snapshot: later,
      recordedAt: DateTime.utc(2026, 1, 1),
    );
    expect(store.lookup(_hashA)?.entries.single.fixedTagId, 'fixed-a');

    await store.record(
      contentHash: _hashA,
      snapshot: later,
      recordedAt: DateTime.utc(2026, 1, 3),
    );
    expect(store.lookup(_hashA)?.entries.single.fixedTagId, 'fixed-b');
  });

  test(
    'export and applySync round-trip usage with deduplicated snapshots',
    () async {
      await store.record(contentHash: _hashA, snapshot: _snapshot);
      await store.record(contentHash: _hashB, snapshot: _snapshot);

      final usage = store.exportUsage();
      final snapshots = store.exportSnapshots();

      expect(usage.map((record) => record.contentHash), [_hashA, _hashB]);
      expect(snapshots, hasLength(1));
      expect(snapshots.keys.single, _snapshot.fingerprint);

      await store.removeUsage(_hashA);
      expect(store.lookup(_hashA), isNull);

      await store.applySync(snapshots: snapshots, usage: usage);
      expect(store.lookup(_hashA)?.entries.single.fixedTagId, 'fixed-a');
    },
  );

  test('applySync overwrites a newer local record', () async {
    const older = FixedTagUsageSnapshot();

    await store.record(
      contentHash: _hashA,
      snapshot: _snapshot,
      recordedAt: DateTime.utc(2026, 1, 2),
    );
    await store.applySync(
      snapshots: {older.fingerprint: older.toJson()},
      usage: [
        FixedTagUsageRecord(
          contentHash: _hashA,
          fingerprint: older.fingerprint,
          recordedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );

    final restored = store.lookup(_hashA);
    expect(restored, isNotNull);
    expect(restored!.entries, isEmpty);
  });

  test('applySync refuses usage whose snapshot is unknown', () async {
    await expectLater(
      store.applySync(
        usage: [
          FixedTagUsageRecord(
            contentHash: _hashA,
            fingerprint: _snapshot.fingerprint,
            recordedAt: DateTime.utc(2026),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
