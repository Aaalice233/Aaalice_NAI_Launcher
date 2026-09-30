import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/daily_trend_statistics.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_state.dart';

void main() {
  final complete = GalleryStatistics(
    totalImages: 2,
    totalSizeBytes: 2048,
    averageFileSizeBytes: 1024,
    samplerDistribution: const [
      SamplerStatistics(samplerName: 'Euler', count: 2, percentage: 100),
    ],
    parameterDistribution: const [
      ParameterStatistics(
        parameterName: 'sampler',
        value: 'k_euler',
        count: 2,
        percentage: 100,
      ),
    ],
    dailyTrends: [DailyTrendStatistics(date: DateTime(2026, 9, 30), count: 2)],
    hourlyDistribution: const {10: 2},
    weekdayDistribution: const {DateTime.wednesday: 2},
    calculatedAt: DateTime(2026, 9, 30),
  );

  test('a cache with parameter distribution can be shown directly', () {
    expect(hasCompleteDashboardStatistics(complete), isTrue);
  });

  test('a cache from before parameter distribution waits for recompute', () {
    expect(
      hasCompleteDashboardStatistics(
        complete.copyWith(parameterDistribution: const []),
      ),
      isFalse,
    );
  });

  test('a library without samplers needs no parameter distribution', () {
    expect(
      hasCompleteDashboardStatistics(
        complete.copyWith(
          samplerDistribution: const [],
          parameterDistribution: const [],
        ),
      ),
      isTrue,
    );
  });
}
