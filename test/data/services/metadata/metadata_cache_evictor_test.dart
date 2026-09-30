import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/services/metadata/metadata_cache_entry_codec.dart';
import 'package:nai_launcher/data/services/metadata/metadata_cache_evictor.dart';

const _boxName = 'local_metadata_cache';
const _versionKey = '_cacheVersion';

String _hash(int index) => index.toRadixString(16).padLeft(64, '0');

final _payload = jsonEncode({'prompt': 'masterpiece, ' * 150});

/// 写入时间为 null 的条目按旧版本格式写入
Future<void> _seed(Box<String> box, Map<int, int?> writtenAtByIndex) async {
  await box.putAll({
    for (final entry in writtenAtByIndex.entries)
      _hash(entry.key): entry.value == null
          ? _payload
          : MetadataCacheEntryCodec.encode(
              _payload,
              writtenAtMillis: entry.value!,
            ),
  });
  await box.put(_versionKey, '8');
}

Set<int> _remainingIndexes(Box<String> box, Iterable<int> indexes) =>
    {for (final index in indexes) if (box.containsKey(_hash(index))) index};

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metadata-evictor-');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<Box<String>> openCache() => Hive.openBox<String>(_boxName);

  test('evicts the oldest entries first and keeps the newest', () async {
    final box = await openCache();
    await _seed(box, {
      for (var index = 0; index < 20; index++) index: 1000 + index,
    });
    final before = await MetadataCacheEvictor.fileBytes(box);
    final target = before ~/ 2;

    final result = await const MetadataCacheEvictor(
      batchSize: 3,
    ).evictToTarget(box, targetBytes: target);

    final remaining = _remainingIndexes(box, List.generate(20, (i) => i));
    expect(result.evictedEntries, greaterThan(0));
    expect(remaining, contains(19));
    expect(remaining, isNot(contains(0)));
    final oldestKept = remaining.reduce((a, b) => a < b ? a : b);
    expect(remaining, {for (var i = oldestKept; i < 20; i++) i});
    expect(result.bytesAfter, lessThanOrEqualTo(target));
    expect(await MetadataCacheEvictor.fileBytes(box), result.bytesAfter);
    expect(box.get(_versionKey), '8');
  });

  test('legacy entries go before any entry with a write time', () async {
    final box = await openCache();
    await _seed(box, {
      for (var index = 0; index < 6; index++) index: null,
      for (var index = 6; index < 20; index++) index: 5000 + index,
    });
    final before = await MetadataCacheEvictor.fileBytes(box);

    await const MetadataCacheEvictor().evictToTarget(
      box,
      targetBytes: before * 3 ~/ 5,
    );

    expect(_remainingIndexes(box, List.generate(6, (i) => i)), isEmpty);
    expect(_remainingIndexes(box, [19]), {19});
  });

  test('entries from a previous session are evicted on reopen', () async {
    final previous = await openCache();
    await _seed(previous, {
      for (var index = 0; index < 10; index++) index: null,
      for (var index = 10; index < 20; index++) index: 2000 + index,
    });
    await Hive.close();

    final reopened = await openCache();
    final before = await MetadataCacheEvictor.fileBytes(reopened);
    final result = await const MetadataCacheEvictor().evictToTarget(
      reopened,
      targetBytes: before ~/ 4,
    );

    expect(result.evictedEntries, greaterThanOrEqualTo(10));
    expect(_remainingIndexes(reopened, List.generate(10, (i) => i)), isEmpty);
    expect(_remainingIndexes(reopened, [19]), {19});
    expect(result.bytesAfter, lessThanOrEqualTo(before ~/ 4));
  });

  test('a cache that already fits is left alone', () async {
    final box = await openCache();
    await _seed(box, {for (var index = 0; index < 5; index++) index: index});
    final before = await MetadataCacheEvictor.fileBytes(box);

    final result = await const MetadataCacheEvictor().evictToTarget(
      box,
      targetBytes: before,
    );

    expect(result.evictedEntries, 0);
    expect(_remainingIndexes(box, List.generate(5, (i) => i)), hasLength(5));
  });

  test('compaction alone can bring the file under target', () async {
    final box = await openCache();
    await _seed(box, {for (var index = 0; index < 5; index++) index: index});
    final live = await MetadataCacheEvictor.fileBytes(box);
    // 反复覆盖同一批键，文件里堆出失效帧
    for (var round = 0; round < 3; round++) {
      await _seed(box, {for (var index = 0; index < 5; index++) index: index});
    }
    expect(await MetadataCacheEvictor.fileBytes(box), greaterThan(live));

    final result = await const MetadataCacheEvictor().evictToTarget(
      box,
      targetBytes: live,
    );

    expect(result.evictedEntries, 0);
    expect(result.bytesAfter, lessThanOrEqualTo(live));
    expect(_remainingIndexes(box, List.generate(5, (i) => i)), hasLength(5));
  });
}
