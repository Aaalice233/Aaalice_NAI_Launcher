import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';

import '../../helpers/gallery_statistics_probe.dart';

void main() {
  final manager = GalleryCacheManager();
  final statistics = useGalleryStatisticsProbe();

  test('有效期内重复读取复用缓存', () async {
    final first = await manager.getStatistics();
    final second = await manager.getStatistics();

    expect(statistics.computations, 1);
    expect(identical(first, second), isTrue);
    expect(statistics.invalidations, 0);
  });

  test('invalidateStatistics 通知一次，下次读取重新计算', () async {
    await manager.getStatistics();

    manager.invalidateStatistics();
    final refreshed = await manager.getStatistics();

    expect(statistics.invalidations, 1);
    expect(statistics.computations, 2);
    expect(refreshed.l3DatabaseImageCount, 2);
  });

  test('计算期间发生失效时，旧结果不写回缓存', () async {
    final gate = Completer<void>();
    manager.debugSetStatisticsComputerForTesting(() async {
      final count = ++statistics.computations;
      if (count == 1) await gate.future;
      return cacheStatisticsWithImages(count);
    });

    final stale = manager.getStatistics();
    manager.invalidateStatistics();
    gate.complete();
    expect((await stale).l3DatabaseImageCount, 1);

    final next = await manager.getStatistics();

    expect(statistics.computations, 2);
    expect(next.l3DatabaseImageCount, 2);
  });

  test('重置统计通知监听者并重新计算', () async {
    await manager.getStatistics();

    await manager.resetStatistics();
    await manager.getStatistics();

    expect(statistics.invalidations, 1);
    expect(statistics.computations, 2);
  });
}
