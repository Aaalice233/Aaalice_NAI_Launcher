import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/gallery/daily_trend_statistics.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/services/statistics_cache_service.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'statistics_cache_service_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox(StorageKeys.statisticsCacheBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.statisticsCacheBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('round-trips dashboard activity distributions', () async {
    final calculatedAt = DateTime(2026, 7, 31, 12);
    final statistics = GalleryStatistics(
      totalImages: 3,
      totalSizeBytes: 6 * 1024 * 1024,
      averageFileSizeBytes: 2 * 1024 * 1024,
      dailyTrends: [
        DailyTrendStatistics(date: DateTime(2026, 7, 31), count: 3),
      ],
      hourlyDistribution: const {10: 1, 20: 2},
      weekdayDistribution: const {DateTime.friday: 3},
      calculatedAt: calculatedAt,
    );
    final service = StatisticsCacheService();

    await service.saveCache(statistics, statistics.totalImages);
    final restored = service.getCache();

    expect(restored, isNotNull);
    expect(restored!.hourlyDistribution, {10: 1, 20: 2});
    expect(restored.weekdayDistribution, {DateTime.friday: 3});
    expect(restored.dailyTrends.single.count, 3);
    expect(service.isCacheValid(3), isTrue);
  });

  test('round-trips parameter distribution and recent activity', () async {
    final statistics = GalleryStatistics(
      totalImages: 2,
      totalSizeBytes: 2048,
      averageFileSizeBytes: 1024,
      parameterDistribution: const [
        ParameterStatistics(
          parameterName: 'sampler',
          value: 'k_euler',
          count: 2,
          percentage: 100,
        ),
        ParameterStatistics(
          parameterName: 'scale',
          value: '5.0',
          count: 1,
          percentage: 50,
        ),
      ],
      recentActivity: const [
        {
          'path': '/gallery/a.png',
          'size': 1024,
          'modifiedAt': '2026-09-29T08:30:00.000',
          'isFavorite': true,
          'tags': ['portrait'],
          'hasMetadata': true,
          'width': 832,
          'height': 1216,
          'model': 'model-a',
          'sampler': 'k_euler',
          'steps': 28,
          'scale': 5.0,
        },
      ],
      calculatedAt: DateTime(2026, 9, 30),
    );
    final service = StatisticsCacheService();

    await service.saveCache(statistics, statistics.totalImages);
    final restored = service.getCache()!;

    expect(restored.parameterDistribution, statistics.parameterDistribution);
    expect(restored.recentActivity, statistics.recentActivity);
  });

  test('a cache written before the new fields were filled still reads', () async {
    final statistics = GalleryStatistics(
      totalImages: 1,
      totalSizeBytes: 1024,
      averageFileSizeBytes: 1024,
      samplerDistribution: const [
        SamplerStatistics(samplerName: 'Euler', count: 1, percentage: 100),
      ],
      calculatedAt: DateTime(2026, 9, 30),
    );
    final service = StatisticsCacheService();

    await service.saveCache(statistics, statistics.totalImages);
    final restored = service.getCache()!;

    expect(restored.samplerDistribution.single.count, 1);
    expect(restored.parameterDistribution, isEmpty);
    expect(restored.recentActivity, isEmpty);
  });
}
