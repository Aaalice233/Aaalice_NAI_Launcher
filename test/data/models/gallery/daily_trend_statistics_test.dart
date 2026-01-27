import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/daily_trend_statistics.dart';

void main() {
  group('DailyTrendStatistics', () {
    test('creates instance with all required fields', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      expect(trend.date, equals(DateTime(2026, 1, 15)));
      expect(trend.count, equals(10));
    });

    test('creates instance with all optional fields', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
        totalSizeBytes: 1024 * 1024 * 5,
        favoriteCount: 2,
        taggedImageCount: 5,
        percentage: 10.0,
      );

      expect(trend.totalSizeBytes, equals(1024 * 1024 * 5));
      expect(trend.favoriteCount, equals(2));
      expect(trend.taggedImageCount, equals(5));
      expect(trend.percentage, equals(10.0));
    });

    test('uses default values for optional fields', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      expect(trend.totalSizeBytes, equals(0));
      expect(trend.favoriteCount, equals(0));
      expect(trend.taggedImageCount, equals(0));
      expect(trend.percentage, equals(0.0));
    });

    test('getFormattedDate returns correct format in Chinese', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      final formatted = trend.getFormattedDate('zh_CN');
      expect(formatted, equals('2026年01月15日'));
    });

    test('getFormattedDate returns correct format in English', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      final formatted = trend.getFormattedDate('en');
      expect(formatted, equals('01/15/2026'));
    });

    test('getFormattedDate handles single digit months and days in Chinese', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 5),
        count: 10,
      );

      final formatted = trend.getFormattedDate('zh_CN');
      expect(formatted, equals('2026年01月05日'));
    });

    test('getFormattedDate handles single digit months and days in English', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 5),
        count: 10,
      );

      final formatted = trend.getFormattedDate('en');
      expect(formatted, equals('01/05/2026'));
    });

    test('getFormattedDateShort returns correct format in Chinese', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      final formatted = trend.getFormattedDateShort('zh_CN');
      expect(formatted, equals('01/15'));
    });

    test('getFormattedDateShort returns correct format in English', () {
      final trend = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      final formatted = trend.getFormattedDateShort('en');
      expect(formatted, equals('01/15'));
    });

    test('totalSizeFormatted formats bytes correctly', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 0,
        totalSizeBytes: 500, // 500 B
      );

      expect(trend.totalSizeFormatted, contains('B'));
    });

    test('totalSizeFormatted formats kilobytes correctly', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 0,
        totalSizeBytes: 1024 * 5, // 5 KB
      );

      expect(trend.totalSizeFormatted, contains('KB'));
    });

    test('totalSizeFormatted formats megabytes correctly', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 0,
        totalSizeBytes: 1024 * 1024 * 5, // 5 MB
      );

      expect(trend.totalSizeFormatted, contains('MB'));
    });

    test('totalSizeFormatted formats gigabytes correctly', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 0,
        totalSizeBytes: 1024 * 1024 * 1024 * 2, // 2 GB
      );

      expect(trend.totalSizeFormatted, contains('GB'));
    });

    test('favoritePercentage calculates correctly', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 100,
        favoriteCount: 25,
      );

      expect(trend.favoritePercentage, equals(25.0));
    });

    test('favoritePercentage returns 0 when count is 0', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 0,
        favoriteCount: 0,
      );

      expect(trend.favoritePercentage, equals(0.0));
    });

    test('favoritePercentage handles decimal values', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 3,
        favoriteCount: 1,
      );

      expect(trend.favoritePercentage, closeTo(33.33, 0.01));
    });

    test('taggedImagePercentage calculates correctly', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 100,
        taggedImageCount: 60,
      );

      expect(trend.taggedImagePercentage, equals(60.0));
    });

    test('taggedImagePercentage returns 0 when count is 0', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 0,
        taggedImageCount: 0,
      );

      expect(trend.taggedImagePercentage, equals(0.0));
    });

    test('taggedImagePercentage handles decimal values', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 3,
        taggedImageCount: 2,
      );

      expect(trend.taggedImagePercentage, closeTo(66.67, 0.01));
    });

    test('percentages handle zero count gracefully', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 0,
        favoriteCount: 0,
        taggedImageCount: 0,
      );

      expect(trend.favoritePercentage, equals(0.0));
      expect(trend.taggedImagePercentage, equals(0.0));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      final updated = original.copyWith(
        count: 20,
        favoriteCount: 5,
      );

      expect(original.count, equals(10));
      expect(updated.count, equals(20));
      expect(updated.favoriteCount, equals(5));
      expect(updated.date, equals(original.date));
    });

    test('equality works correctly', () {
      final trend1 = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      final trend2 = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      expect(trend1, equals(trend2));
    });

    test('inequality works correctly', () {
      final trend1 = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 10,
      );

      final trend2 = DailyTrendStatistics(
        date: DateTime(2026, 1, 15),
        count: 20,
      );

      expect(trend1, isNot(equals(trend2)));
    });

    test('formats size for realistic image sizes', () {
      final trend = DailyTrendStatistics(
        date: DateTime.now(),
        count: 10,
        totalSizeBytes: (1024 * 1024 * 2.5).toInt(), // 2.5 MB
      );

      final formatted = trend.totalSizeFormatted;
      expect(formatted, contains('MB'));
    });
  });

  group('WeeklyTrendStatistics', () {
    test('creates instance with all required fields', () {
      final trend = WeeklyTrendStatistics(
        weekStart: DateTime(2026, 1, 10),
        weekEnd: DateTime(2026, 1, 16),
        count: 50,
      );

      expect(trend.weekStart, equals(DateTime(2026, 1, 10)));
      expect(trend.weekEnd, equals(DateTime(2026, 1, 16)));
      expect(trend.count, equals(50));
    });

    test('uses default values for optional fields', () {
      final trend = WeeklyTrendStatistics(
        weekStart: DateTime(2026, 1, 10),
        weekEnd: DateTime(2026, 1, 16),
        count: 50,
      );

      expect(trend.totalSizeBytes, equals(0));
      expect(trend.favoriteCount, equals(0));
      expect(trend.taggedImageCount, equals(0));
      expect(trend.percentage, equals(0.0));
    });

    test('getFormattedWeekRange returns correct format in Chinese', () {
      final trend = WeeklyTrendStatistics(
        weekStart: DateTime(2026, 1, 10),
        weekEnd: DateTime(2026, 1, 16),
        count: 50,
      );

      final formatted = trend.getFormattedWeekRange('zh_CN');
      expect(formatted, equals('01月10日 - 01月16日'));
    });

    test('getFormattedWeekRange returns correct format in English', () {
      final trend = WeeklyTrendStatistics(
        weekStart: DateTime(2026, 1, 10),
        weekEnd: DateTime(2026, 1, 16),
        count: 50,
      );

      final formatted = trend.getFormattedWeekRange('en');
      expect(formatted, equals('01/10 - 01/16'));
    });

    test('getFormattedWeekRange handles different months', () {
      final trend = WeeklyTrendStatistics(
        weekStart: DateTime(2026, 1, 30),
        weekEnd: DateTime(2026, 2, 5),
        count: 50,
      );

      final formatted = trend.getFormattedWeekRange('zh_CN');
      expect(formatted, equals('01月30日 - 02月05日'));
    });

    test('equality works correctly', () {
      final trend1 = WeeklyTrendStatistics(
        weekStart: DateTime(2026, 1, 10),
        weekEnd: DateTime(2026, 1, 16),
        count: 50,
      );

      final trend2 = WeeklyTrendStatistics(
        weekStart: DateTime(2026, 1, 10),
        weekEnd: DateTime(2026, 1, 16),
        count: 50,
      );

      expect(trend1, equals(trend2));
    });
  });

  group('MonthlyTrendStatistics', () {
    test('creates instance with all required fields', () {
      final trend = MonthlyTrendStatistics(
        year: 2026,
        month: 1,
        count: 200,
      );

      expect(trend.year, equals(2026));
      expect(trend.month, equals(1));
      expect(trend.count, equals(200));
    });

    test('uses default values for optional fields', () {
      final trend = MonthlyTrendStatistics(
        year: 2026,
        month: 1,
        count: 200,
      );

      expect(trend.totalSizeBytes, equals(0));
      expect(trend.favoriteCount, equals(0));
      expect(trend.taggedImageCount, equals(0));
      expect(trend.percentage, equals(0.0));
    });

    test('getFormattedMonth returns correct format in Chinese', () {
      final trend = MonthlyTrendStatistics(
        year: 2026,
        month: 1,
        count: 200,
      );

      final formatted = trend.getFormattedMonth('zh_CN');
      expect(formatted, equals('2026年01月'));
    });

    test('getFormattedMonth returns correct format in English', () {
      final trend = MonthlyTrendStatistics(
        year: 2026,
        month: 1,
        count: 200,
      );

      final formatted = trend.getFormattedMonth('en');
      expect(formatted, equals('Jan 2026'));
    });

    test('getFormattedMonth returns all month names correctly in English', () {
      final months = [
        'Jan 2026',
        'Feb 2026',
        'Mar 2026',
        'Apr 2026',
        'May 2026',
        'Jun 2026',
        'Jul 2026',
        'Aug 2026',
        'Sep 2026',
        'Oct 2026',
        'Nov 2026',
        'Dec 2026',
      ];

      for (int i = 1; i <= 12; i++) {
        final trend = MonthlyTrendStatistics(
          year: 2026,
          month: i,
          count: 100,
        );

        final formatted = trend.getFormattedMonth('en');
        expect(formatted, equals(months[i - 1]));
      }
    });

    test('getFormattedMonth handles single digit month in Chinese', () {
      final trend = MonthlyTrendStatistics(
        year: 2026,
        month: 3,
        count: 200,
      );

      final formatted = trend.getFormattedMonth('zh_CN');
      expect(formatted, equals('2026年03月'));
    });

    test('equality works correctly', () {
      final trend1 = MonthlyTrendStatistics(
        year: 2026,
        month: 1,
        count: 200,
      );

      final trend2 = MonthlyTrendStatistics(
        year: 2026,
        month: 1,
        count: 200,
      );

      expect(trend1, equals(trend2));
    });

    test('inequality works correctly', () {
      final trend1 = MonthlyTrendStatistics(
        year: 2026,
        month: 1,
        count: 200,
      );

      final trend2 = MonthlyTrendStatistics(
        year: 2026,
        month: 2,
        count: 200,
      );

      expect(trend1, isNot(equals(trend2)));
    });
  });
}
