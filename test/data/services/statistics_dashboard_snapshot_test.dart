import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_dashboard_snapshot.dart';
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
}
