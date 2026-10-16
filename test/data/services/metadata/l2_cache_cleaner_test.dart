import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/data/services/metadata/l2_cache_cleaner.dart';
import 'package:nai_launcher/data/services/metadata/metadata_cache_evictor.dart';

const _cacheBoxName = 'local_metadata_cache';

final _payload = jsonEncode({'prompt': 'best quality, ' * 150});

void main() {
  late Directory directory;
  late LazyBox<String> cache;
  late Box<dynamic> settings;
  late DateTime now;
  late _RecordingEvictor evictor;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('l2-cache-cleaner-');
    Hive.init(directory.path);
    cache = await Hive.openLazyBox<String>(_cacheBoxName);
    settings = await Hive.openBox<dynamic>('cleaner_settings');
    now = DateTime(2026, 9, 30, 12);
    evictor = _RecordingEvictor();
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
    evictor: evictor,
  );

  Future<int> cacheBytes() => MetadataCacheEvictor.fileBytes(cache);

  Future<void> seed(int count) => cache.putAll({
    for (var index = 0; index < count; index++)
      index.toRadixString(16).padLeft(64, '0'): _payload,
  });

  test(
    'evicts to the target only once the file exceeds the threshold',
    () async {
      await seed(10);
      final bytes = await cacheBytes();

      expect(await cleanerWithThreshold(bytes).enforceSizeLimit(), isNull);
      expect(evictor.targets, isEmpty);

      final cleaner = cleanerWithThreshold(bytes - 1);
      expect(await cleaner.enforceSizeLimit(), isNotNull);
      expect(evictor.targets, [cleaner.targetBytes]);
      expect(cleaner.targetBytes, ((bytes - 1) * 0.8).floor());
    },
  );

  test('size checks run at most once an hour', () async {
    await seed(10);
    final cleaner = cleanerWithThreshold(1);

    await cleaner.checkAndClean();
    expect(evictor.targets, hasLength(1));

    now = now.add(const Duration(minutes: 30));
    await cleaner.checkAndClean();
    expect(evictor.targets, hasLength(1));

    now = now.add(const Duration(hours: 1));
    await cleaner.checkAndClean();
    expect(evictor.targets, hasLength(2));
  });

  test('a clock moved backwards does not postpone the next check', () async {
    await seed(10);
    final cleaner = cleanerWithThreshold(1);
    await cleaner.checkAndClean();

    now = now.subtract(const Duration(days: 1));
    await cleaner.checkAndClean();

    expect(evictor.targets, hasLength(2));
  });

  test('compacts dead frames once a week', () async {
    await seed(5);
    final live = await cacheBytes();
    Future<void> overwrite() async {
      for (var round = 0; round < 3; round++) {
        await seed(5);
      }
    }

    await overwrite();
    final cleaner = cleanerWithThreshold(await cacheBytes() * 2);
    await cleaner.checkAndClean();
    expect(await cacheBytes(), live);

    await overwrite();
    final grown = await cacheBytes();
    now = now.add(const Duration(days: 6));
    await cleaner.checkAndClean();
    expect(await cacheBytes(), grown);

    now = now.add(const Duration(days: 1));
    await cleaner.checkAndClean();
    expect(await cacheBytes(), live);
    expect(evictor.targets, isEmpty);
  });

  test('does nothing before the metadata cache is opened', () async {
    final cleaner = L2CacheCleaner(
      cacheBox: () => null,
      settingsBox: () async => settings,
      clock: () => now,
      evictor: evictor,
    );

    await cleaner.checkAndClean();

    expect(await cleaner.enforceSizeLimit(), isNull);
    expect(settings.isEmpty, isTrue);
    expect(evictor.targets, isEmpty);
  });
}

class _RecordingEvictor extends MetadataCacheEvictor {
  final targets = <int>[];

  @override
  Future<MetadataCacheEvictionResult> evictToTarget(
    LazyBox<String> box, {
    required int targetBytes,
  }) async {
    targets.add(targetBytes);
    return const MetadataCacheEvictionResult(
      bytesBefore: 0,
      bytesAfter: 0,
      scannedEntries: 0,
      evictedEntries: 0,
    );
  }
}
