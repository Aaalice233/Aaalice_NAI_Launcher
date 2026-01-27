import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/models/gallery/daily_trend_statistics.dart';

void main() {
  group('GalleryStatistics', () {
    test('creates instance with all required fields', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.totalImages, equals(100));
      expect(stats.totalSizeBytes, equals(1000000));
      expect(stats.averageFileSizeBytes, equals(10000.0));
    });

    test('creates instance with default values', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.favoriteCount, equals(0));
      expect(stats.taggedImageCount, equals(0));
      expect(stats.imagesWithMetadata, equals(0));
      expect(stats.resolutionDistribution, isEmpty);
      expect(stats.modelDistribution, isEmpty);
      expect(stats.samplerDistribution, isEmpty);
      expect(stats.sizeDistribution, isEmpty);
      expect(stats.tagDistribution, isEmpty);
      expect(stats.parameterDistribution, isEmpty);
      expect(stats.dailyTrends, isEmpty);
      expect(stats.weeklyTrends, isEmpty);
      expect(stats.monthlyTrends, isEmpty);
      expect(stats.favoritesStatistics, isEmpty);
      expect(stats.recentActivity, isEmpty);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(
        totalImages: 200,
        favoriteCount: 50,
      );

      expect(original.totalImages, equals(100));
      expect(updated.totalImages, equals(200));
      expect(updated.totalSizeBytes, equals(original.totalSizeBytes));
      expect(updated.averageFileSizeBytes, equals(original.averageFileSizeBytes));
      expect(updated.favoriteCount, equals(50));
    });

    test('copyWith retains collections when not provided', () {
      final original = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
        modelDistribution: [
          ModelStatistics(
            modelName: 'NAI Diffusion V4',
            count: 80,
            percentage: 80.0,
          ),
        ],
      );

      final updated = original.copyWith(totalImages: 200);

      expect(updated.modelDistribution.length, equals(1));
      expect(updated.modelDistribution.first.modelName, equals('NAI Diffusion V4'));
    });

    test('favoritePercentage calculates correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        favoriteCount: 25,
        calculatedAt: DateTime.now(),
      );

      expect(stats.favoritePercentage, equals(25.0));
    });

    test('favoritePercentage returns 0 when no images', () {
      final stats = GalleryStatistics(
        totalImages: 0,
        totalSizeBytes: 0,
        averageFileSizeBytes: 0.0,
        favoriteCount: 0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.favoritePercentage, equals(0.0));
    });

    test('taggedImagePercentage calculates correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        taggedImageCount: 60,
        calculatedAt: DateTime.now(),
      );

      expect(stats.taggedImagePercentage, equals(60.0));
    });

    test('taggedImagePercentage returns 0 when no images', () {
      final stats = GalleryStatistics(
        totalImages: 0,
        totalSizeBytes: 0,
        averageFileSizeBytes: 0.0,
        taggedImageCount: 0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.taggedImagePercentage, equals(0.0));
    });

    test('metadataPercentage calculates correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        imagesWithMetadata: 80,
        calculatedAt: DateTime.now(),
      );

      expect(stats.metadataPercentage, equals(80.0));
    });

    test('metadataPercentage returns 0 when no images', () {
      final stats = GalleryStatistics(
        totalImages: 0,
        totalSizeBytes: 0,
        averageFileSizeBytes: 0.0,
        imagesWithMetadata: 0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.metadataPercentage, equals(0.0));
    });

    test('totalSizeFormatted formats bytes correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 500, // 500 B
        averageFileSizeBytes: 5.0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.totalSizeFormatted, contains('B'));
    });

    test('totalSizeFormatted formats kilobytes correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1024 * 5, // 5 KB
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.totalSizeFormatted, contains('KB'));
    });

    test('totalSizeFormatted formats megabytes correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1024 * 1024 * 5, // 5 MB
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.totalSizeFormatted, contains('MB'));
    });

    test('totalSizeFormatted formats gigabytes correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1024 * 1024 * 1024 * 2, // 2 GB
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      expect(stats.totalSizeFormatted, contains('GB'));
    });

    test('averageSizeFormatted formats bytes correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 500.0, // 500 B
        calculatedAt: DateTime.now(),
      );

      expect(stats.averageSizeFormatted, contains('B'));
    });

    test('averageSizeFormatted formats megabytes correctly', () {
      final stats = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 1024 * 1024 * 3, // 3 MB
        calculatedAt: DateTime.now(),
      );

      expect(stats.averageSizeFormatted, contains('MB'));
    });

    test('equality works correctly', () {
      final stats1 = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime(2026, 1, 1, 12, 0, 0),
      );

      final stats2 = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime(2026, 1, 1, 12, 0, 0),
      );

      expect(stats1, equals(stats2));
    });

    test('inequality works correctly', () {
      final stats1 = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      final stats2 = GalleryStatistics(
        totalImages: 200,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      expect(stats1, isNot(equals(stats2)));
    });

    test('copyWith can update all list fields', () {
      final original = GalleryStatistics(
        totalImages: 100,
        totalSizeBytes: 1000000,
        averageFileSizeBytes: 10000.0,
        calculatedAt: DateTime.now(),
      );

      final dailyTrends = [
        DailyTrendStatistics(
          date: DateTime(2026, 1, 1),
          count: 10,
        ),
      ];

      final updated = original.copyWith(
        dailyTrends: dailyTrends,
        weeklyTrends: [],
        monthlyTrends: [],
        tagDistribution: [],
        parameterDistribution: [],
      );

      expect(updated.dailyTrends.length, equals(1));
      expect(updated.dailyTrends.first.count, equals(10));
    });
  });

  group('ResolutionStatistics', () {
    test('creates instance with all fields', () {
      final stats = ResolutionStatistics(
        label: '1024x1024',
        count: 50,
        percentage: 50.0,
      );

      expect(stats.label, equals('1024x1024'));
      expect(stats.count, equals(50));
      expect(stats.percentage, equals(50.0));
    });

    test('uses default percentage value', () {
      final stats = ResolutionStatistics(
        label: '1024x1024',
        count: 50,
      );

      expect(stats.percentage, equals(0.0));
    });

    test('equality works correctly', () {
      final stats1 = ResolutionStatistics(
        label: '1024x1024',
        count: 50,
        percentage: 50.0,
      );

      final stats2 = ResolutionStatistics(
        label: '1024x1024',
        count: 50,
        percentage: 50.0,
      );

      expect(stats1, equals(stats2));
    });
  });

  group('ModelStatistics', () {
    test('creates instance with all fields', () {
      final stats = ModelStatistics(
        modelName: 'NAI Diffusion V4',
        count: 80,
        percentage: 80.0,
      );

      expect(stats.modelName, equals('NAI Diffusion V4'));
      expect(stats.count, equals(80));
      expect(stats.percentage, equals(80.0));
    });

    test('uses default percentage value', () {
      final stats = ModelStatistics(
        modelName: 'NAI Diffusion V4',
        count: 80,
      );

      expect(stats.percentage, equals(0.0));
    });

    test('equality works correctly', () {
      final stats1 = ModelStatistics(
        modelName: 'NAI Diffusion V4',
        count: 80,
        percentage: 80.0,
      );

      final stats2 = ModelStatistics(
        modelName: 'NAI Diffusion V4',
        count: 80,
        percentage: 80.0,
      );

      expect(stats1, equals(stats2));
    });
  });

  group('SamplerStatistics', () {
    test('creates instance with all fields', () {
      final stats = SamplerStatistics(
        samplerName: 'Euler Ancestral',
        count: 60,
        percentage: 60.0,
      );

      expect(stats.samplerName, equals('Euler Ancestral'));
      expect(stats.count, equals(60));
      expect(stats.percentage, equals(60.0));
    });

    test('uses default percentage value', () {
      final stats = SamplerStatistics(
        samplerName: 'Euler Ancestral',
        count: 60,
      );

      expect(stats.percentage, equals(0.0));
    });

    test('equality works correctly', () {
      final stats1 = SamplerStatistics(
        samplerName: 'Euler Ancestral',
        count: 60,
        percentage: 60.0,
      );

      final stats2 = SamplerStatistics(
        samplerName: 'Euler Ancestral',
        count: 60,
        percentage: 60.0,
      );

      expect(stats1, equals(stats2));
    });
  });

  group('SizeDistributionStatistics', () {
    test('creates instance with all fields', () {
      final stats = SizeDistributionStatistics(
        label: '1-5 MB',
        count: 40,
        percentage: 40.0,
      );

      expect(stats.label, equals('1-5 MB'));
      expect(stats.count, equals(40));
      expect(stats.percentage, equals(40.0));
    });

    test('uses default percentage value', () {
      final stats = SizeDistributionStatistics(
        label: '1-5 MB',
        count: 40,
      );

      expect(stats.percentage, equals(0.0));
    });

    test('equality works correctly', () {
      final stats1 = SizeDistributionStatistics(
        label: '1-5 MB',
        count: 40,
        percentage: 40.0,
      );

      final stats2 = SizeDistributionStatistics(
        label: '1-5 MB',
        count: 40,
        percentage: 40.0,
      );

      expect(stats1, equals(stats2));
    });
  });

  group('TagStatistics', () {
    test('creates instance with all fields', () {
      final stats = TagStatistics(
        tagName: 'anime',
        count: 100,
        percentage: 100.0,
      );

      expect(stats.tagName, equals('anime'));
      expect(stats.count, equals(100));
      expect(stats.percentage, equals(100.0));
    });

    test('uses default percentage value', () {
      final stats = TagStatistics(
        tagName: 'anime',
        count: 100,
      );

      expect(stats.percentage, equals(0.0));
    });

    test('equality works correctly', () {
      final stats1 = TagStatistics(
        tagName: 'anime',
        count: 100,
        percentage: 100.0,
      );

      final stats2 = TagStatistics(
        tagName: 'anime',
        count: 100,
        percentage: 100.0,
      );

      expect(stats1, equals(stats2));
    });
  });

  group('ParameterStatistics', () {
    test('creates instance with all fields', () {
      final stats = ParameterStatistics(
        parameterName: 'steps',
        value: '28',
        count: 80,
        percentage: 80.0,
      );

      expect(stats.parameterName, equals('steps'));
      expect(stats.value, equals('28'));
      expect(stats.count, equals(80));
      expect(stats.percentage, equals(80.0));
    });

    test('uses default percentage value', () {
      final stats = ParameterStatistics(
        parameterName: 'steps',
        value: '28',
        count: 80,
      );

      expect(stats.percentage, equals(0.0));
    });

    test('equality works correctly', () {
      final stats1 = ParameterStatistics(
        parameterName: 'steps',
        value: '28',
        count: 80,
        percentage: 80.0,
      );

      final stats2 = ParameterStatistics(
        parameterName: 'steps',
        value: '28',
        count: 80,
        percentage: 80.0,
      );

      expect(stats1, equals(stats2));
    });
  });
}
