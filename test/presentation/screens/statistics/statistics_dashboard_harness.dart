import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_screen.dart';
import 'package:nai_launcher/presentation/screens/statistics/statistics_state.dart';

/// Pumps the full statistics page already showing [stats].
Future<void> pumpStatisticsDashboard(
  WidgetTester tester,
  GalleryStatistics stats, {
  required Size size,
  required double textScale,
  Locale locale = const Locale('zh'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        statisticsNotifierProvider.overrideWith(
          () => _LoadedStatisticsNotifier(stats),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const StatisticsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _LoadedStatisticsNotifier extends StatisticsNotifier {
  _LoadedStatisticsNotifier(this._statistics);

  final GalleryStatistics _statistics;

  @override
  StatisticsData build() =>
      StatisticsData(statistics: _statistics, isLoading: false);

  @override
  Future<void> whenLoaded() async {}
}
