import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/dashboard/hourly_distribution_card.dart';

void main() {
  const hourlyData = <int, int>{0: 2, 6: 5, 12: 12, 18: 8, 23: 3};

  Future<void> pumpCard(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HourlyDistributionCard(hourlyData: hourlyData),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('390px 宽度使用上下布局且无 RenderFlex overflow', (tester) async {
    await pumpCard(tester, 390);

    expect(
      find.byKey(const ValueKey('hourly-distribution-narrow-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('hourly-distribution-wide-layout')),
      findsNothing,
    );

    final chart = tester.getRect(
      find.byKey(const ValueKey('hourly-distribution-chart')),
    );
    final summary = tester.getRect(
      find.byKey(const ValueKey('hourly-distribution-summary')),
    );
    expect(summary.top, greaterThan(chart.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('桌面宽度保持横排', (tester) async {
    await pumpCard(tester, 760);

    expect(
      find.byKey(const ValueKey('hourly-distribution-wide-layout')),
      findsOneWidget,
    );
    final chart = tester.getRect(
      find.byKey(const ValueKey('hourly-distribution-chart')),
    );
    final summary = tester.getRect(
      find.byKey(const ValueKey('hourly-distribution-summary')),
    );
    expect(summary.left, greaterThan(chart.right));
    expect(tester.takeException(), isNull);
  });
}
