import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/anlas_statistics_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/dashboard/anlas_cost_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    SharedPreferences.setMockInitialValues({
      'anlas_daily_stats': jsonEncode([
        DailyAnlasStat(date: today, cost: 70).toJson(),
        DailyAnlasStat(
          date: today.subtract(const Duration(days: 6)),
          cost: 30,
        ).toJson(),
        DailyAnlasStat(
          date: today.subtract(const Duration(days: 20)),
          cost: 500,
        ).toJson(),
      ]),
      'anlas_stats_coverage_start': today
          .subtract(const Duration(days: 400))
          .toIso8601String(),
    });
  });

  testWidgets('period selector updates total, daily average, and custom days', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Center(child: SizedBox(width: 520, child: AnlasCostCard())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_textForKey(tester, 'anlas-period-total'), '600');
    expect(_textForKey(tester, 'anlas-period-average'), '20');

    await tester.tap(find.byKey(const ValueKey('anlas-period-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anlas-period-week')));
    await tester.pumpAndSettle();

    expect(_textForKey(tester, 'anlas-period-total'), '100');
    expect(_textForKey(tester, 'anlas-period-average'), '14');

    await tester.tap(find.byKey(const ValueKey('anlas-period-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('anlas-period-custom')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('anlas-custom-days-field')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('anlas-custom-days-apply')));
    await tester.pumpAndSettle();

    expect(find.text('最近 10 天'), findsOneWidget);
    expect(_textForKey(tester, 'anlas-period-total'), '100');
    expect(_textForKey(tester, 'anlas-period-average'), '10');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('anlas_statistics_period'), 'custom');
    expect(prefs.getInt('anlas_statistics_custom_days'), 10);
  });
}

String? _textForKey(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey(key))).data;
}
