import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';

void main() {
  final manager = GalleryCacheManager();
  late int computeCount;
  late int invalidations;

  void countInvalidation() => invalidations++;

  setUp(() {
    computeCount = 0;
    invalidations = 0;
    manager.debugSetStatisticsComputerForTesting(() async {
      computeCount++;
      return statisticsWithImages(computeCount);
    });
    manager.registerOnStatisticsInvalidated(countInvalidation);
  });

  tearDown(() {
    manager.unregisterOnStatisticsInvalidated(countInvalidation);
    manager.debugSetStatisticsComputerForTesting(null);
  });

  test('有效期内重复读取复用缓存', () async {
    final first = await manager.getStatistics();
    final second = await manager.getStatistics();

    expect(computeCount, 1);
    expect(identical(first, second), isTrue);
    expect(invalidations, 0);
  });

  test('invalidateStatistics 通知一次，下次读取重新计算', () async {
    await manager.getStatistics();

    manager.invalidateStatistics();
    final refreshed = await manager.getStatistics();

    expect(invalidations, 1);
    expect(computeCount, 2);
    expect(refreshed.l3DatabaseImageCount, 2);
  });

  test('计算期间发生失效时，旧结果不写回缓存', () async {
    final gate = Completer<void>();
    manager.debugSetStatisticsComputerForTesting(() async {
      computeCount++;
      final count = computeCount;
      if (count == 1) await gate.future;
      return statisticsWithImages(count);
    });

    final stale = manager.getStatistics();
    manager.invalidateStatistics();
    gate.complete();
    expect((await stale).l3DatabaseImageCount, 1);

    final next = await manager.getStatistics();

    expect(computeCount, 2);
    expect(next.l3DatabaseImageCount, 2);
  });

  test('重置统计通知监听者并重新计算', () async {
    await manager.getStatistics();

    await manager.resetStatistics();
    await manager.getStatistics();

    expect(invalidations, 1);
    expect(computeCount, 2);
  });
}

CacheStatistics statisticsWithImages(int imageCount) => CacheStatistics(
  l1MemorySize: 0,
  l1HitRate: 0,
  l1MemoryBytes: 0,
  l2HiveSize: 0,
  l2HitRate: 0,
  l2HiveBytes: 0,
  l3DatabaseImageCount: imageCount,
  l3DatabaseMetadataCount: 0,
  totalHitRate: 0,
  lastUpdated: DateTime(2026),
);
