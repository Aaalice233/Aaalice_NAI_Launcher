import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_screen.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_state.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';

void main() {
  test('statistics dashboard columns account for 3x text scale', () {
    expect(statisticsDashboardColumnCount(520, 1), 1);
    expect(statisticsDashboardColumnCount(840, 1), 2);
    expect(statisticsDashboardColumnCount(1180, 1), 3);
    expect(statisticsDashboardColumnCount(1600, 3), 1);
  });

  testWidgets('statistics empty page remains usable at 360px and 3x text', (
    tester,
  ) async {
    await _pumpEmptyStatistics(tester, textScaler: const TextScaler.linear(3));

    expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    expect(find.byType(IconButton), findsWidgets);
    _expectStatisticsTonalToolbar(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics toolbar stays on one row at normal compact width', (
    tester,
  ) async {
    await _pumpEmptyStatistics(tester);

    final titleCenter = tester.getCenter(find.byIcon(Icons.bar_chart_rounded));
    final exportCenter = tester.getCenter(find.byIcon(Icons.download_outlined));
    expect((titleCenter.dy - exportCenter.dy).abs(), lessThan(1));
    _expectStatisticsTonalToolbar(tester);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpEmptyStatistics(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        statisticsNotifierProvider.overrideWith(_EmptyStatisticsNotifier.new),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const StatisticsScreen(),
      ),
    ),
  );
  await tester.pump();
}

void _expectStatisticsTonalToolbar(WidgetTester tester) {
  final finder = find.byKey(const ValueKey('statistics-toolbar-tonal-surface'));
  final toolbar = tester.widget<Container>(finder);
  final colorScheme = Theme.of(tester.element(finder)).colorScheme;
  expect(toolbar.color, sectionSurfaceColor(colorScheme));
  expect(toolbar.decoration, isNull);
}

class _EmptyStatisticsNotifier extends StatisticsNotifier {
  @override
  StatisticsData build() => const StatisticsData(isLoading: false);
}
