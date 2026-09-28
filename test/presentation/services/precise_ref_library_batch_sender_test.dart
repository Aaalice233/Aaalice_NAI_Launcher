import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/presentation/services/precise_ref_library_batch_sender.dart';

void main() {
  test('按当前排序发送配置，允许部分失败且只记录成功项', () async {
    final entries = [
      _entry('third', PreciseRefType.style, 0.3, 0.4),
      _entry('missing', PreciseRefType.character, 0.5, 0.6),
      _entry('first', PreciseRefType.characterAndStyle, 0.7, 0.8),
    ];
    final sent = <String>[];
    final used = <String>[];
    final configs = <String, (PreciseRefType, double, double)>{};

    final result = await const PreciseRefLibraryBatchSender().send(
      orderedEntries: entries,
      selectedIds: entries.map((entry) => entry.id).toSet(),
      loadBytes: (id) async =>
          id == 'missing' ? null : Uint8List.fromList(id.codeUnits),
      sendEntry: (bytes, entry) async {
        sent.add(entry.id);
        configs[entry.id] = (entry.type, entry.strength, entry.fidelity);
      },
      recordUsage: (id) async => used.add(id),
    );

    expect(sent, ['third', 'first']);
    expect(used, sent);
    expect(configs['third'], (PreciseRefType.style, 0.3, 0.4));
    expect(configs['first'], (PreciseRefType.characterAndStyle, 0.7, 0.8));
    expect(result.successfulEntries.map((entry) => entry.id), [
      'third',
      'first',
    ]);
    expect(result.failedEntries.single.id, 'missing');
    expect(result.usageRecordFailures, isEmpty);
  });

  test('发送回调失败不会记录使用次数并继续后续项', () async {
    final entries = [
      _entry('broken', PreciseRefType.style, 1, 1),
      _entry('ok', PreciseRefType.character, 1, 1),
    ];
    final used = <String>[];

    final result = await const PreciseRefLibraryBatchSender().send(
      orderedEntries: entries,
      selectedIds: {'broken', 'ok'},
      loadBytes: (_) async => Uint8List.fromList([1]),
      sendEntry: (_, entry) async {
        if (entry.id == 'broken') throw StateError('rejected');
      },
      recordUsage: (id) async => used.add(id),
    );

    expect(used, ['ok']);
    expect(result.failedEntries.single.id, 'broken');
    expect(result.successfulEntries.single.id, 'ok');
  });

  test('使用次数持久化失败不把已发送项目误报为发送失败', () async {
    final entry = _entry('sent', PreciseRefType.style, 1, 1);
    final result = await const PreciseRefLibraryBatchSender().send(
      orderedEntries: [entry],
      selectedIds: {'sent'},
      loadBytes: (_) async => Uint8List.fromList([1]),
      sendEntry: (_, _) async {},
      recordUsage: (_) async => throw StateError('disk failure'),
    );

    expect(result.successfulEntries.single.id, 'sent');
    expect(result.failedEntries, isEmpty);
    expect(result.usageRecordFailures.single.id, 'sent');
  });
}

PreciseRefLibraryEntry _entry(
  String id,
  PreciseRefType type,
  double strength,
  double fidelity,
) => PreciseRefLibraryEntry(
  id: id,
  name: id,
  imagePath: '$id.png',
  typeIndex: type.index,
  strength: strength,
  fidelity: fidelity,
  createdAt: DateTime(2026),
);
