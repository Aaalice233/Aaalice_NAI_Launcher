import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';

/// 只有图库图片数非零的统计快照。
CacheStatistics cacheStatisticsWithImages(int imageCount) => CacheStatistics(
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

/// 当前用例里 [GalleryCacheManager] 发出的失效通知次数与统计重算次数。
final class GalleryStatisticsProbe {
  int invalidations = 0;
  int computations = 0;
}

/// 每个用例接管 [GalleryCacheManager] 的统计计算并计数，结束后恢复真实统计。
///
/// [imageCount] 为空时第 n 次重算报告 n 张图。
GalleryStatisticsProbe useGalleryStatisticsProbe({
  Future<int> Function()? imageCount,
}) {
  final probe = GalleryStatisticsProbe();
  void countInvalidation() => probe.invalidations++;

  setUp(() {
    probe
      ..invalidations = 0
      ..computations = 0;
    GalleryCacheManager()
      ..debugSetStatisticsComputerForTesting(() async {
        probe.computations++;
        return cacheStatisticsWithImages(
          imageCount == null ? probe.computations : await imageCount(),
        );
      })
      ..registerOnStatisticsInvalidated(countInvalidation);
  });

  tearDown(() {
    GalleryCacheManager()
      ..unregisterOnStatisticsInvalidated(countInvalidation)
      ..debugSetStatisticsComputerForTesting(null);
  });

  return probe;
}
