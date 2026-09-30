import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_dashboard_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/gallery_parameter.dart';
import 'package:nai_launcher/data/services/statistics_service.dart';

void main() {
  test('converts aggregate dashboard counts into display statistics', () {
    final calculatedAt = DateTime(2026, 7, 31, 12);
    final snapshot = GalleryDashboardSnapshot(
      totalImages: 4,
      totalSizeBytes: 8 * 1024 * 1024,
      favoriteCount: 1,
      taggedImageCount: 2,
      imagesWithMetadata: 3,
      resolutionCounts: {'1024x1024': 3, '512x768': 1},
      modelCounts: {'model-a': 3},
      samplerCounts: {'k_euler_ancestral': 3},
      sizeCounts: {'1-2 MB': 4},
      tagCounts: {'landscape': 2},
      dailyCounts: {20260730: 1, 20260731: 3},
      hourlyCounts: {10: 1, 20: 3},
      weekdayCounts: {DateTime.thursday: 1, DateTime.friday: 3},
    );

    final statistics = StatisticsService().fromDashboardSnapshot(
      snapshot,
      calculatedAt: calculatedAt,
    );

    expect(statistics.totalImages, 4);
    expect(statistics.averageFileSizeBytes, 2 * 1024 * 1024);
    expect(statistics.favoritePercentage, 25);
    expect(statistics.resolutionDistribution.first.label, '1024x1024');
    expect(
      statistics.samplerDistribution.single.samplerName,
      'Euler Ancestral',
    );
    expect(statistics.tagDistribution.single.percentage, 50);
    expect(statistics.dailyTrends.map((trend) => trend.date), [
      DateTime(2026, 7, 30),
      DateTime(2026, 7, 31),
    ]);
    expect(statistics.hourlyDistribution, {10: 1, 20: 3});
    expect(statistics.weekdayDistribution, {
      DateTime.thursday: 1,
      DateTime.friday: 3,
    });
    expect(statistics.calculatedAt, calculatedAt);
  });

  test('parameter distribution keeps raw values grouped per parameter', () {
    final snapshot = _snapshot(
      samplerCounts: {'k_euler_ancestral': 3, 'k_euler': 1},
      parameterCounts: {
        GalleryParameter.steps: {'23': 1, '28': 3},
        GalleryParameter.sampler: {'k_euler_ancestral': 3, 'k_euler': 1},
        GalleryParameter.cfgRescale: {'0.0': 2},
      },
    );

    final statistics = StatisticsService().fromDashboardSnapshot(snapshot);

    expect(
      [
        for (final entry in statistics.parameterDistribution)
          '${entry.parameterName}=${entry.value}:${entry.count}',
      ],
      [
        'sampler=k_euler_ancestral:3',
        'sampler=k_euler:1',
        'steps=28:3',
        'steps=23:1',
        'cfg_rescale=0.0:2',
      ],
    );
    expect(statistics.parameterDistribution.first.percentage, 75);
  });

  test('the sampler parameter matches the sampler distribution numbers', () {
    final counts = {'k_euler_ancestral': 5, 'k_dpmpp_2m': 2, 'k_euler': 1};
    final statistics = StatisticsService().fromDashboardSnapshot(
      _snapshot(
        totalImages: 10,
        imagesWithMetadata: 8,
        samplerCounts: counts,
        parameterCounts: {GalleryParameter.sampler: counts},
      ),
    );

    final samplerEntries = statistics.parameterDistribution.where(
      (entry) => entry.parameterName == GalleryParameter.sampler.key,
    );
    expect(
      [
        for (final entry in samplerEntries)
          (
            StatisticsService.formatSamplerName(entry.value),
            entry.count,
            entry.percentage,
          ),
      ],
      [
        for (final sampler in statistics.samplerDistribution)
          (sampler.samplerName, sampler.count, sampler.percentage),
      ],
    );
  });

  test('recent activity keeps one entry per image with the original keys', () {
    final modifiedAt = DateTime(2026, 9, 29, 8, 30);
    final statistics = StatisticsService().fromDashboardSnapshot(
      _snapshot(
        recentImages: [
          GalleryRecentImage(
            path: '/gallery/a.png',
            size: 2048,
            modifiedAt: modifiedAt,
            isFavorite: true,
            tags: const ['portrait'],
            hasMetadata: true,
            width: 832,
            height: 1216,
            model: 'model-a',
            sampler: 'k_euler',
            steps: 28,
            scale: 5,
          ),
          GalleryRecentImage(
            path: '/gallery/b.png',
            size: 1024,
            modifiedAt: modifiedAt,
            isFavorite: false,
            tags: const [],
            hasMetadata: false,
          ),
        ],
      ),
    );

    expect(statistics.recentActivity, [
      {
        'path': '/gallery/a.png',
        'size': 2048,
        'modifiedAt': modifiedAt.toIso8601String(),
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
      {
        'path': '/gallery/b.png',
        'size': 1024,
        'modifiedAt': modifiedAt.toIso8601String(),
        'isFavorite': false,
        'tags': <String>[],
        'hasMetadata': false,
        'width': null,
        'height': null,
        'model': null,
        'sampler': null,
        'steps': null,
        'scale': null,
      },
    ]);
  });
}

GalleryDashboardSnapshot _snapshot({
  int totalImages = 4,
  int imagesWithMetadata = 4,
  Map<String, int> samplerCounts = const {},
  Map<GalleryParameter, Map<String, int>> parameterCounts = const {},
  List<GalleryRecentImage> recentImages = const [],
}) {
  return GalleryDashboardSnapshot(
    totalImages: totalImages,
    totalSizeBytes: 4096,
    favoriteCount: 0,
    taggedImageCount: 0,
    imagesWithMetadata: imagesWithMetadata,
    resolutionCounts: const {},
    modelCounts: const {},
    samplerCounts: samplerCounts,
    sizeCounts: const {},
    tagCounts: const {},
    dailyCounts: const {},
    hourlyCounts: const {},
    weekdayCounts: const {},
    parameterCounts: parameterCounts,
    recentImages: recentImages,
  );
}
