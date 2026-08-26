import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/anlas_statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('recordCost keeps entries older than 90 days', () async {
    final oldDate = DateTime(2025, 1, 1);
    SharedPreferences.setMockInitialValues({
      'anlas_daily_stats': jsonEncode([
        DailyAnlasStat(date: oldDate, cost: 40).toJson(),
      ]),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = await container.read(anlasStatisticsServiceProvider.future);
    await service.recordCost(10, date: DateTime(2026, 8, 24));

    final prefs = await SharedPreferences.getInstance();
    final stored = (jsonDecode(prefs.getString('anlas_daily_stats')!) as List)
        .cast<Map<String, dynamic>>();
    expect(stored, hasLength(2));
    expect(
      stored.map((value) => DateTime.parse(value['date'] as String)),
      contains(oldDate),
    );
    expect(
      prefs.getString('anlas_stats_coverage_start'),
      oldDate.toIso8601String(),
    );
  });

  test(
    'period summary uses calendar days and reports partial coverage',
    () async {
      final coverageStart = DateTime(2026, 5, 25);
      final costs = <DateTime, int>{
        DateTime(2026, 8, 18): 35,
        DateTime(2026, 8, 19): 43,
        DateTime(2026, 8, 20): 772,
        DateTime(2026, 8, 21): 250,
        DateTime(2026, 8, 22): 172,
        DateTime(2026, 8, 23): 970,
      };
      SharedPreferences.setMockInitialValues({
        'anlas_daily_stats': jsonEncode(
          costs.entries
              .map(
                (entry) =>
                    DailyAnlasStat(date: entry.key, cost: entry.value).toJson(),
              )
              .toList(),
        ),
        'anlas_stats_coverage_start': coverageStart.toIso8601String(),
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = await container.read(
        anlasStatisticsServiceProvider.future,
      );

      final week = service.getPeriodStats(
        days: 7,
        endDate: DateTime(2026, 8, 24),
      );
      expect(week.coveredDays, 7);
      expect(week.totalCost, 2242);
      expect(week.averageDailyCost, 320);
      expect(week.dailyStats.last.cost, 0);
      expect(week.hasPartialCoverage, isFalse);

      final year = service.getPeriodStats(
        days: 365,
        endDate: DateTime(2026, 8, 24),
      );
      expect(year.startDate, coverageStart);
      expect(year.coveredDays, 92);
      expect(year.totalCost, 2242);
      expect(year.averageDailyCost, 24);
      expect(year.hasPartialCoverage, isTrue);

      final all = service.getPeriodStats(endDate: DateTime(2026, 8, 24));
      expect(all.startDate, coverageStart);
      expect(all.coveredDays, 92);
      expect(all.hasPartialCoverage, isFalse);
    },
  );
}
