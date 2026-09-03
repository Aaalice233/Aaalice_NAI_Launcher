import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/cards/chart_card.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/charts/heatmap_chart.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/charts/polar_activity_chart.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

void main() {
  testWidgets(
    'statistics cards use fast theme motion without moving on hover',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          const SizedBox(
            width: 320,
            child: ChartCard(title: 'Chart', child: SizedBox(height: 80)),
          ),
        ),
      );

      final card = find.byType(ChartCard);
      final animated = find.descendant(
        of: card,
        matching: find.byType(AnimatedContainer),
      );
      final before = tester.widget<AnimatedContainer>(animated);
      final beforeDecoration = before.decoration! as BoxDecoration;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(card));
      await tester.pump();

      final after = tester.widget<AnimatedContainer>(animated);
      final afterDecoration = after.decoration! as BoxDecoration;
      expect(after.duration, const Duration(milliseconds: 120));
      expect(after.transform, isNull);
      expect(afterDecoration.boxShadow, isNull);
      expect(afterDecoration.color, isNot(beforeDecoration.color));
    },
  );

  testWidgets('heatmap hover keeps cell geometry stable and removes glow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const SizedBox(
          width: 320,
          child: HeatmapChart(
            data: [
              [1, 0, 0, 0, 0, 0, 0],
            ],
            cellSize: 24,
            showDayLabels: false,
            showMonthLabels: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstRegion = find
        .descendant(
          of: find.byType(HeatmapChart),
          matching: find.byType(MouseRegion),
        )
        .first;
    final firstCell = find.descendant(
      of: firstRegion,
      matching: find.byType(AnimatedContainer),
    );
    final before = tester.widget<AnimatedContainer>(firstCell);
    final beforeDecoration = before.decoration! as BoxDecoration;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(firstRegion));
    await tester.pump();

    final after = tester.widget<AnimatedContainer>(firstCell);
    final afterDecoration = after.decoration! as BoxDecoration;
    expect(after.duration, const Duration(milliseconds: 120));
    expect(after.transform, isNull);
    expect(afterDecoration.boxShadow, isNull);
    expect(
      afterDecoration.border!.top.width,
      beforeDecoration.border!.top.width,
    );
    expect(
      afterDecoration.border!.top.color,
      isNot(beforeDecoration.border!.top.color),
    );
  });

  testWidgets('peak time hover uses color feedback without pulse or shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const PeakTimeIndicator(
          peakHour: 16,
          count: 12,
          afternoonLabel: 'Afternoon',
        ),
      ),
    );

    final indicator = find.byType(PeakTimeIndicator);
    final animated = find.descendant(
      of: indicator,
      matching: find.byType(AnimatedContainer),
    );
    final before = tester.widget<AnimatedContainer>(animated);
    final beforeDecoration = before.decoration! as BoxDecoration;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: tester.getCenter(indicator));
    await tester.pump();

    final after = tester.widget<AnimatedContainer>(animated);
    final afterDecoration = after.decoration! as BoxDecoration;
    expect(after.duration, const Duration(milliseconds: 120));
    expect(after.transform, isNull);
    expect(afterDecoration.boxShadow, isNull);
    expect(
      afterDecoration.border!.top.color,
      isNot(beforeDecoration.border!.top.color),
    );
    expect(
      find.descendant(of: indicator, matching: find.byType(ScaleTransition)),
      findsNothing,
    );
  });

  testWidgets('reduced motion settles statistics hover immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const ChartCard(child: SizedBox(width: 200, height: 80)),
        disableAnimations: true,
      ),
    );

    final animated = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ChartCard),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(animated.duration, Duration.zero);
  });
}

Widget _testApp(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: ThemeData(
      extensions: const [
        AppThemeExtension(fastDuration: Duration(milliseconds: 120)),
      ],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: appChild!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}
