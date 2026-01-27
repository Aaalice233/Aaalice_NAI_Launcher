import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/statistics_service.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';

void main() {
  group('StatisticsService', () {
    late StatisticsService service;

    setUp(() {
      service = StatisticsService();
    });

    group('calculateStatistics', () {
      test('returns correct statistics for sample data', () {
        // Arrange: Create sample records with various properties
        final records = createSampleRecords(count: 100);

        // Act
        final result = service.calculateStatistics(records);

        // Assert
        expect(result.totalImages, equals(100));
        expect(result.totalSizeBytes, greaterThan(0));
        expect(result.averageFileSizeBytes, greaterThan(0));
        expect(result.resolutionDistribution, isNotEmpty);
        expect(result.modelDistribution, isNotEmpty);
        expect(result.samplerDistribution, isNotEmpty);
        expect(result.sizeDistribution, isNotEmpty);
      });

      test('handles empty dataset', () {
        final result = service.calculateStatistics([]);

        expect(result.totalImages, equals(0));
        expect(result.totalSizeBytes, equals(0));
        expect(result.averageFileSizeBytes, equals(0.0));
        expect(result.resolutionDistribution, isEmpty);
        expect(result.modelDistribution, isEmpty);
        expect(result.samplerDistribution, isEmpty);
      });

      test('handles dataset with no metadata', () {
        final records = createRecordsWithoutMetadata(count: 50);
        final result = service.calculateStatistics(records);

        expect(result.totalImages, equals(50));
        expect(result.modelDistribution, isEmpty);
        expect(result.samplerDistribution, isEmpty);
        expect(result.resolutionDistribution, isEmpty);
      });

      test('calculates favorite statistics correctly', () {
        final records = createRecordsWithFavorites(count: 100, favoriteCount: 25);
        final result = service.calculateStatistics(records);

        expect(result.favoriteCount, equals(25));
        expect(result.favoritePercentage, equals(25.0));
      });

      test('calculates tagged image statistics correctly', () {
        final records = createRecordsWithTags(count: 100, taggedCount: 60);
        final result = service.calculateStatistics(records);

        expect(result.taggedImageCount, equals(60));
        expect(result.taggedImagePercentage, equals(60.0));
      });

      test('calculates metadata statistics correctly', () {
        final records = createRecordsWithMetadata(count: 100, metadataCount: 80);
        final result = service.calculateStatistics(records);

        expect(result.imagesWithMetadata, equals(80));
        expect(result.metadataPercentage, equals(80.0));
      });
    });

    group('computeAllStatistics', () {
      test('returns correct statistics for sample data', () async {
        // Arrange: Create 100 sample records with various properties
        final records = createSampleRecords(count: 100);

        // Act
        final result = await service.computeAllStatistics(records);

        // Assert
        expect(result.totalImages, equals(100));
        expect(result.dailyTrends, isNotEmpty);
        expect(result.weeklyTrends, isEmpty); // Not calculated by default
        expect(result.monthlyTrends, isEmpty); // Not calculated by default
        expect(result.tagDistribution, isNotEmpty);
        expect(result.parameterDistribution, isNotEmpty);
        expect(result.favoritesStatistics, isNotNull);
        expect(result.recentActivity, isNotEmpty);
      });

      test('handles empty dataset', () async {
        final result = await service.computeAllStatistics([]);

        expect(result.totalImages, equals(0));
        expect(result.totalSizeBytes, equals(0));
        expect(result.dailyTrends, isEmpty);
        expect(result.tagDistribution, isEmpty);
      });

      test('handles dataset with no tags', () async {
        final records = createRecordsWithoutTags(count: 50);
        final result = await service.computeAllStatistics(records);

        expect(result.tagDistribution, isEmpty);
        expect(result.totalImages, equals(50));
      });

      test('handles dataset with single day data', () async {
        final records = createRecordsForSingleDay(count: 30);
        final result = await service.computeAllStatistics(records);

        expect(result.dailyTrends.length, equals(1));
        expect(result.dailyTrends.first.count, equals(30));
      });

      test('calculates percentages correctly', () async {
        final records = createSampleRecords(count: 100);
        final result = await service.computeAllStatistics(records);

        final totalPercentage = result.modelDistribution
            .fold(0.0, (sum, stat) => sum + stat.percentage);

        expect(totalPercentage, closeTo(100.0, 0.1));
      });
    });

    group('computeTimeTrends', () {
      test('groups data by day correctly', () async {
        final records = createRecordsOverMultipleDays(days: 7);
        final trends = await service.computeTimeTrends(records, groupBy: 'daily');

        expect(trends.length, equals(7));
        expect(trends.every((trend) => trend.count >= 0), isTrue);
      });

      test('groups data by week correctly', () async {
        final records = createRecordsOverMultipleWeeks(weeks: 4);
        final trends = await service.computeTimeTrends(records, groupBy: 'weekly');

        expect(trends.length, equals(4));
      });

      test('groups data by month correctly', () async {
        final records = createRecordsOverMultipleMonths(months: 6);
        final trends = await service.computeTimeTrends(records, groupBy: 'monthly');

        expect(trends.length, equals(6));
      });

      test('handles empty dataset', () async {
        final trends = await service.computeTimeTrends([], groupBy: 'daily');

        expect(trends, isEmpty);
      });
    });

    group('computeTagStatistics', () {
      test('returns top N most used tags', () async {
        final records = createRecordsWithVariousTags(count: 100);
        final tags = await service.computeTagStatistics(records, limit: 20);

        expect(tags.length, lessThanOrEqualTo(20));
        expect(tags, isNotEmpty);
        if (tags.length > 1) {
          expect(tags.first.count, greaterThanOrEqualTo(tags.last.count));
        }
      });

      test('calculates tag percentages correctly', () async {
        final records = createRecordsWithVariousTags(count: 50);
        final tags = await service.computeTagStatistics(records, limit: 10);

        final totalPercentage = tags.fold(0.0, (sum, tag) => sum + tag.percentage);
        expect(totalPercentage, lessThanOrEqualTo(100.0));
      });

      test('handles empty dataset', () async {
        final tags = await service.computeTagStatistics([], limit: 10);

        expect(tags, isEmpty);
      });

      test('handles dataset with no tags', () async {
        final records = createRecordsWithoutTags(count: 50);
        final tags = await service.computeTagStatistics(records, limit: 10);

        expect(tags, isEmpty);
      });
    });

    group('computeParameterDistribution', () {
      test('computes distribution for all parameters', () async {
        final records = createRecordsWithVariousParameters(count: 100);
        final params = await service.computeParameterDistribution(records);

        expect(params, isNotEmpty);
        expect(params.any((p) => p.parameterName == 'steps'), isTrue);
        expect(params.any((p) => p.parameterName == 'scale'), isTrue);
        expect(params.any((p) => p.parameterName == 'sampler'), isTrue);
      });

      test('handles empty dataset', () async {
        final params = await service.computeParameterDistribution([]);

        expect(params, isEmpty);
      });

      test('handles dataset with no metadata', () async {
        final records = createRecordsWithoutMetadata(count: 50);
        final params = await service.computeParameterDistribution(records);

        expect(params, isEmpty);
      });
    });

    group('computeFavoritesStatistics', () {
      test('calculates favorite statistics correctly', () async {
        final records = createRecordsWithFavorites(count: 100, favoriteCount: 30);
        final stats = await service.computeFavoritesStatistics(records);

        expect(stats['favoriteCount'], equals(30));
        expect(stats['percentage'], equals(30.0));
        expect(stats['totalSizeBytes'], greaterThan(0));
      });

      test('handles empty dataset', () async {
        final stats = await service.computeFavoritesStatistics([]);

        expect(stats['favoriteCount'], equals(0));
        expect(stats['percentage'], equals(0.0));
      });

      test('handles dataset with no favorites', () async {
        final records = createRecordsWithFavorites(count: 100, favoriteCount: 0);
        final stats = await service.computeFavoritesStatistics(records);

        expect(stats['favoriteCount'], equals(0));
        expect(stats['percentage'], equals(0.0));
      });
    });

    group('computeRecentActivity', () {
      test('returns recent activity within specified days', () async {
        final records = createRecordsOverMultipleDays(days: 30);
        final activity = await service.computeRecentActivity(records, days: 30);

        expect(activity, isNotEmpty);
        expect(activity.length, lessThanOrEqualTo(records.length));
      });

      test('handles empty dataset', () async {
        final activity = await service.computeRecentActivity([], days: 30);

        expect(activity, isEmpty);
      });

      test('sorts by most recent first', () async {
        final records = createRecordsOverMultipleDays(days: 5);
        final activity = await service.computeRecentActivity(records, days: 30);

        if (activity.length > 1) {
          final firstDate = DateTime.parse(activity[0]['modifiedAt'] as String);
          final lastDate = DateTime.parse(activity[activity.length - 1]['modifiedAt'] as String);
          expect(firstDate.isAfter(lastDate), isTrue);
        }
      });
    });
  });
}

// Helper functions to create test data

List<LocalImageRecord> createSampleRecords({required int count}) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    final dayOffset = index % 30;
    return LocalImageRecord(
      path: '/test/image_$index.png',
      size: 1024 * 1024 * (1 + (index % 5)), // 1-5 MB
      modifiedAt: now.subtract(Duration(days: dayOffset)),
      metadata: NaiImageMetadata(
        model: ['NAI Diffusion V4', 'SDXL 1.0', 'NAI Diffusion V3'][index % 3],
        sampler: ['k_euler_ancestral', 'k_euler', 'k_dpmpp_2m'][index % 3],
        steps: 28,
        scale: 5.0,
        width: [1024, 512, 768][index % 3],
        height: [1024, 768, 512][index % 3],
        seed: 123456789 + index,
      ),
      isFavorite: index % 4 == 0,
      tags: index % 2 == 0
          ? ['anime', 'girl', 'portrait', 'landscape', 'fantasy'][index % 5] != ''
              ? ['anime', 'girl', 'portrait', 'landscape', 'fantasy'][index % 5].split(',')
              : []
          : [],
    );
  });
}

List<LocalImageRecord> createRecordsWithoutMetadata({required int count}) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/no_metadata_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: now.subtract(Duration(days: index % 10)),
      metadata: null,
      isFavorite: false,
      tags: [],
    );
  });
}

List<LocalImageRecord> createRecordsWithFavorites({
  required int count,
  required int favoriteCount,
}) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/fav_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: now.subtract(Duration(days: index % 10)),
      metadata: NaiImageMetadata(
        model: 'NAI Diffusion V4',
        sampler: 'k_euler_ancestral',
        steps: 28,
        scale: 5.0,
      ),
      isFavorite: index < favoriteCount,
      tags: [],
    );
  });
}

List<LocalImageRecord> createRecordsWithTags({
  required int count,
  required int taggedCount,
}) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/tagged_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: now.subtract(Duration(days: index % 10)),
      metadata: NaiImageMetadata(
        model: 'NAI Diffusion V4',
        sampler: 'k_euler_ancestral',
      ),
      isFavorite: false,
      tags: index < taggedCount ? ['anime', 'girl'] : [],
    );
  });
}

List<LocalImageRecord> createRecordsWithMetadata({
  required int count,
  required int metadataCount,
}) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/metadata_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: now.subtract(Duration(days: index % 10)),
      metadata: index < metadataCount
          ? NaiImageMetadata(
              model: 'NAI Diffusion V4',
              sampler: 'k_euler_ancestral',
            )
          : null,
      isFavorite: false,
      tags: [],
    );
  });
}

List<LocalImageRecord> createRecordsWithoutTags({required int count}) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/no_tags_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: now.subtract(Duration(days: index % 10)),
      metadata: NaiImageMetadata(
        model: 'NAI Diffusion V4',
        sampler: 'k_euler_ancestral',
      ),
      isFavorite: false,
      tags: [],
    );
  });
}

List<LocalImageRecord> createRecordsForSingleDay({required int count}) {
  final today = DateTime.now();
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/same_day_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: DateTime(today.year, today.month, today.day, index % 24),
      metadata: NaiImageMetadata(
        model: 'NAI Diffusion V4',
        sampler: 'k_euler_ancestral',
      ),
      isFavorite: false,
      tags: [],
    );
  });
}

List<LocalImageRecord> createRecordsOverMultipleDays({required int days}) {
  final now = DateTime.now();
  final records = <LocalImageRecord>[];
  for (int day = 0; day < days; day++) {
    final count = 5 + (day % 10); // Variable number of images per day
    for (int i = 0; i < count; i++) {
      records.add(LocalImageRecord(
        path: '/test/day_${day}_$i.png',
        size: 1024 * 1024 * 2,
        modifiedAt: now.subtract(Duration(days: day)),
        metadata: NaiImageMetadata(
          model: 'NAI Diffusion V4',
          sampler: 'k_euler_ancestral',
        ),
        isFavorite: false,
        tags: ['test'],
      ));
    }
  }
  return records;
}

List<LocalImageRecord> createRecordsOverMultipleWeeks({required int weeks}) {
  final now = DateTime.now();
  final records = <LocalImageRecord>[];
  for (int week = 0; week < weeks; week++) {
    for (int day = 0; day < 7; day++) {
      records.add(LocalImageRecord(
        path: '/test/week_${week}_day_${day}.png',
        size: 1024 * 1024 * 2,
        modifiedAt: now.subtract(Duration(days: week * 7 + day)),
        metadata: NaiImageMetadata(
          model: 'NAI Diffusion V4',
          sampler: 'k_euler_ancestral',
        ),
        isFavorite: false,
        tags: ['test'],
      ));
    }
  }
  return records;
}

List<LocalImageRecord> createRecordsOverMultipleMonths({required int months}) {
  final now = DateTime.now();
  final records = <LocalImageRecord>[];
  for (int month = 0; month < months; month++) {
    for (int day = 0; day < 28; day++) {
      records.add(LocalImageRecord(
        path: '/test/month_${month}_day_${day}.png',
        size: 1024 * 1024 * 2,
        modifiedAt: DateTime(now.year, now.month - month, 1).add(Duration(days: day)),
        metadata: NaiImageMetadata(
          model: 'NAI Diffusion V4',
          sampler: 'k_euler_ancestral',
        ),
        isFavorite: false,
        tags: ['test'],
      ));
    }
  }
  return records;
}

List<LocalImageRecord> createRecordsWithVariousTags({required int count}) {
  final now = DateTime.now();
  final allTags = [
    'anime',
    'girl',
    'boy',
    'portrait',
    'landscape',
    'fantasy',
    'sci-fi',
    'action',
    'school',
    'summer'
  ];
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/various_tags_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: now.subtract(Duration(days: index % 20)),
      metadata: NaiImageMetadata(
        model: 'NAI Diffusion V4',
        sampler: 'k_euler_ancestral',
      ),
      isFavorite: false,
      tags: [allTags[index % allTags.length], allTags[(index + 1) % allTags.length]],
    );
  });
}

List<LocalImageRecord> createRecordsWithVariousParameters({required int count}) {
  final now = DateTime.now();
  return List.generate(count, (index) {
    return LocalImageRecord(
      path: '/test/various_params_$index.png',
      size: 1024 * 1024 * 2,
      modifiedAt: now.subtract(Duration(days: index % 20)),
      metadata: NaiImageMetadata(
        model: 'NAI Diffusion V4',
        sampler: ['k_euler_ancestral', 'k_euler', 'k_dpmpp_2m'][index % 3],
        steps: [20, 28, 32][index % 3],
        scale: [4.0, 5.0, 6.0][index % 3],
        noiseSchedule: ['native', 'karras'][index % 2],
      ),
      isFavorite: false,
      tags: [],
    );
  });
}
