import 'dart:io';

import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/merge.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent delete and edit is a conflict, not silent deletion', () {
    const merger = ThreeWayMerger<String>(isBinary: _notBinary);
    const old = SyncRecord(id: 'item', value: 'old');
    const deleted = SyncRecord<String>(id: 'item', value: null, deleted: true);
    const edited = SyncRecord(id: 'item', value: 'edited');

    final result = merger.merge(
      base: const {'item': old},
      local: const {'item': deleted},
      remote: const {'item': edited},
    );
    expect(result.records, isEmpty);
    expect(result.conflicts.single.id, 'item');
  });

  test('a tombstone propagates when the other side is unchanged', () {
    const merger = ThreeWayMerger<String>(isBinary: _notBinary);
    const old = SyncRecord(id: 'item', value: 'old');
    const deleted = SyncRecord<String>(id: 'item', value: null, deleted: true);
    final result = merger.merge(
      base: const {'item': old},
      local: const {'item': deleted},
      remote: const {'item': old},
    );
    expect(result.records['item']!.deleted, isTrue);
    expect(result.conflicts, isEmpty);
  });

  test('binary conflicts default to deterministic keepBoth', () {
    const merger = ThreeWayMerger<String>(isBinary: _binary);
    final result = merger.merge(
      base: const {'image': SyncRecord(id: 'image', value: 'base')},
      local: const {'image': SyncRecord(id: 'image', value: 'local')},
      remote: const {'image': SyncRecord(id: 'image', value: 'remote')},
    );
    expect(result.conflicts, isEmpty);
    expect(
      result.records.keys,
      containsAll([
        'image',
        'image.remote-${'remote'.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0')}',
      ]),
    );
  });

  test('journal atomically persists states and original errors', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cloud-sync-journal-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = JournalStore(File('${directory.path}/journal.json'));
    var journal = SyncJournal(
      operationId: 'operation',
      operation: JournalOperation.synchronize,
      phase: JournalPhase.prepared,
      updatedAt: DateTime.utc(2025),
      snapshotId: 'snapshot',
      targetFingerprint:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      expectedRevision: null,
      uploadRequired: true,
    );
    await store.write(journal);
    journal = journal.copyWith(
      phase: JournalPhase.rollbackStarted,
      error: StateError('original'),
      stackTrace: StackTrace.current,
    );
    await store.write(journal);

    final recovered = await store.read();
    expect(recovered!.phase, JournalPhase.rollbackStarted);
    expect(recovered.error, contains('original'));
    expect(await File('${directory.path}/journal.json.part').exists(), isFalse);
  });

  test('legacy and unknown journal values are rejected, never guessed', () {
    expect(
      () => SyncJournal.fromJson({
        'version': 1,
        'operationId': 'operation',
        'state': 'staging',
        'updatedAt': DateTime.utc(2025).toIso8601String(),
        'data': {'operation': 'unknown'},
        'error': null,
        'stackTrace': null,
      }),
      throwsA(isA<CloudFormatException>()),
    );
    final valid = SyncJournal(
      operationId: 'operation',
      operation: JournalOperation.synchronize,
      phase: JournalPhase.prepared,
      updatedAt: DateTime.utc(2025),
      snapshotId: 'snapshot',
      targetFingerprint:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      expectedRevision: null,
      uploadRequired: true,
    ).toJson();
    expect(
      () => SyncJournal.fromJson({...valid, 'operation': 'unknown'}),
      throwsA(isA<CloudFormatException>()),
    );
  });
}

bool _notBinary(SyncRecord<String>? _) => false;
bool _binary(SyncRecord<String>? _) => true;
