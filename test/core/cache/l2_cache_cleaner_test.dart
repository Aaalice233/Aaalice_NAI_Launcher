import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/data/services/metadata/metadata_cache_entry_codec.dart';
import 'package:nai_launcher/data/services/metadata/metadata_cache_evictor.dart';

const _cacheBoxName = 'local_metadata_cache';

String _hash(int index) => index.toRadixString(16).padLeft(64, '0');

final _payload = jsonEncode({'prompt': 'best quality, ' * 150});

/// 写入时间为 null 的条目按旧版本格式写入
Future<void> _seed(Box<String> box, Map<int, int?> writtenAtByIndex) =>
    box.putAll({
      for (final entry in writtenAtByIndex.entries)
        _hash(entry.key): entry.value == null
            ? _payload
            : MetadataCacheEntryCodec.encode(
                _payload,
                writtenAtMillis: entry.value!,
              ),
    });

void main() {
  late Directory directory;
  late Box<String> cache;
  late Box<dynamic> settings;
  late DateTime now;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('l2-cache-cleaner-');
    Hive.init(directory.path);
    cache = await Hive.openBox<String>(_cacheBoxName);
    settings = await Hive.openBox<dynamic>('cleaner_settings');
    now = DateTime(2026, 9, 30, 12);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  L2CacheCleaner cleanerWithThreshold(int thresholdBytes) => L2CacheCleaner(
    cacheBox: () => cache,
    settingsBox: () async => settings,
    clock: () => now,
    sizeThresholdBytes: thresholdBytes,
  );

  Future<int> cacheBytes() => MetadataCacheEvictor.fileBytes(cache);

  bool isCached(int index) => cache.containsKey(_hash(index));

  test('history from a previous session is evicted after restart', () async {
    await _seed(cache, {
      for (var index = 0; index < 10; index++) index: null,
      for (var index = 10; index < 30; index++) index: 1000 + index,
    });
    await Hive.close();
    cache = await Hive.openBox<String>(_cacheBoxName);
    settings = await Hive.openBox<dynamic>('cleaner_settings');
    final cleaner = cleanerWithThreshold(await cacheBytes() ~/ 2);

    await cleaner.checkAndClean();

    expect(await cacheBytes(), lessThanOrEqualTo(cleaner.targetBytes));
    expect([for (var i = 0; i < 10; i++) isCached(i)], everyElement(isFalse));
    expect(isCached(29), isTrue);
  });

  test('a cache far above the threshold is still evicted', () async {
    await _seed(cache, {for (var index = 0; index < 40; index++) index: index});
    final cleaner = cleanerWithThreshold(await cacheBytes() ~/ 10);

    final result = await cleaner.enforceSizeLimit();

    expect(result, isNotNull);
    expect(result!.bytesAfter, lessThanOrEqualTo(cleaner.targetBytes));
    expect(isCached(39), isTrue);
    expect(isCached(0), isFalse);
  });

  test('a cache under the threshold is left untouched', () async {
    await _seed(cache, {for (var index = 0; index < 10; index++) index: index});
    final cleaner = cleanerWithThreshold(await cacheBytes() + 1);

    await cleaner.checkAndClean();

    expect([for (var i = 0; i < 10; i++) isCached(i)], everyElement(isTrue));
  });

  test('size checks run at most once an hour', () async {
    await _seed(cache, {for (var index = 0; index < 20; index++) index: index});
    final cleaner = cleanerWithThreshold(await cacheBytes() ~/ 2);
    await cleaner.checkAndClean();
    expect(await cacheBytes(), lessThanOrEqualTo(cleaner.targetBytes));

    await _seed(cache, {
      for (var index = 20; index < 40; index++) index: index,
    });
    final grown = await cacheBytes();
    expect(grown, greaterThan(cleaner.sizeThresholdBytes));

    now = now.add(const Duration(minutes: 30));
    await cleaner.checkAndClean();
    expect(await cacheBytes(), grown);

    now = now.add(const Duration(hours: 1));
    await cleaner.checkAndClean();
    expect(await cacheBytes(), lessThanOrEqualTo(cleaner.targetBytes));
    expect(isCached(39), isTrue);
  });

  test('the weekly run compacts dead frames below the threshold', () async {
    await _seed(cache, {for (var index = 0; index < 5; index++) index: index});
    final live = await cacheBytes();
    for (var round = 0; round < 3; round++) {
      await _seed(cache, {
        for (var index = 0; index < 5; index++) index: index,
      });
    }
    expect(await cacheBytes(), greaterThan(live));
    final cleaner = cleanerWithThreshold(await cacheBytes() * 2);

    await cleaner.checkAndClean();

    expect(await cacheBytes(), live);
    expect([for (var i = 0; i < 5; i++) isCached(i)], everyElement(isTrue));
  });
}
