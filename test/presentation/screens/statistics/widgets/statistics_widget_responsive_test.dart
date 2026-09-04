import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/animated/animated_number.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/cards/chart_card.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/cards/metric_card.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/charts/aspect_ratio_chart.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/charts/heatmap_chart.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/charts/top_tags_ranking.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/common/section_container.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';

void main() {
  testWidgets(
    'statistics cards keep tonal grouping when theme container roles collapse',
    (tester) async {
      const canvas = Color(0xFF181818);
      final collapsedScheme = const ColorScheme.dark(
        surface: canvas,
      ).copyWith(surfaceContainerLow: canvas, surfaceContainer: canvas);
      final sectionKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: collapsedScheme),
          home: Scaffold(
            body: Column(
              children: [
                const MetricCard(
                  key: ValueKey('grouped-metric-card'),
                  icon: Icons.photo_outlined,
                  label: 'Images',
                  value: '42',
                  compact: true,
                ),
                const ChartCard(
                  key: ValueKey('grouped-chart-card'),
                  title: 'Activity',
                  child: SizedBox(height: 20),
                ),
                SectionContainer(
                  sectionKey: sectionKey,
                  title: 'Section',
                  icon: Icons.bar_chart,
                  child: const SizedBox(height: 20),
                ),
              ],
            ),
          ),
        ),
      );

      final metricSurface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('grouped-metric-card')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final chartSurface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const ValueKey('grouped-chart-card')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final sectionSurface = tester.widget<Container>(find.byKey(sectionKey));
      final expectedSurface = sectionSurfaceColor(collapsedScheme);

      expect(
        (metricSurface.decoration! as BoxDecoration).color,
        expectedSurface,
      );
      expect(
        (chartSurface.decoration! as BoxDecoration).color,
        expectedSurface,
      );
      expect(
        (sectionSurface.decoration! as BoxDecoration).color,
        expectedSurface,
      );
      expect(expectedSurface, isNot(canvas));
      expect(find.byType(Divider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'statistics containers use their local width at 700, 840, and 1180',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final width in [700.0, 840.0, 1180.0]) {
        final sectionKey = GlobalKey();
        const sectionChildKey = ValueKey('section-child');
        const cardChildKey = ValueKey('card-child');

        await tester.pumpWidget(
          _testApp(
            SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SectionContainer(
                    sectionKey: sectionKey,
                    title: 'Section',
                    icon: Icons.bar_chart,
                    child: const SizedBox(key: sectionChildKey, height: 20),
                  ),
                  const ChartCard(
                    title: 'Chart',
                    child: SizedBox(key: cardChildKey, height: 20),
                  ),
                ],
              ),
            ),
          ),
        );

        final expectedSectionPadding = width >= 840 ? 24.0 : 16.0;
        final expectedCardPadding = width >= 840 ? 22.0 : 18.0;
        expect(
          tester.getTopLeft(find.byKey(sectionChildKey)).dx -
              tester.getTopLeft(find.byKey(sectionKey)).dx,
          expectedSectionPadding,
        );
        expect(
          tester.getTopLeft(find.byKey(cardChildKey)).dx -
              tester.getTopLeft(find.byType(ChartCard)).dx,
          expectedCardPadding,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'statistics grids reflow from local width at defined breakpoints',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final width in [700.0, 840.0, 1180.0]) {
        await tester.pumpWidget(
          _testApp(
            SizedBox(
              width: width,
              child: StatsGrid(
                children: List.generate(
                  4,
                  (index) => SizedBox(key: ValueKey('grid-$index'), height: 20),
                ),
              ),
            ),
          ),
        );

        final firstY = tester
            .getTopLeft(find.byKey(const ValueKey('grid-0')))
            .dy;
        final thirdY = tester
            .getTopLeft(find.byKey(const ValueKey('grid-2')))
            .dy;
        if (width < 840) {
          expect(thirdY, greaterThan(firstY));
        } else {
          expect(thirdY, firstY);
        }

        await tester.pumpWidget(
          _testApp(
            SizedBox(
              width: width,
              child: const ResponsiveTwoColumn(
                left: SizedBox(key: ValueKey('left'), height: 20),
                right: SizedBox(key: ValueKey('right'), height: 20),
              ),
            ),
          ),
        );
        final leftY = tester.getTopLeft(find.byKey(const ValueKey('left'))).dy;
        final rightY = tester
            .getTopLeft(find.byKey(const ValueKey('right')))
            .dy;
        if (width < 840) {
          expect(rightY, greaterThan(leftY));
        } else {
          expect(rightY, leftY);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'top tag columns depend on ranking width and preserve every item',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final width in [700.0, 840.0, 1180.0]) {
        await tester.pumpWidget(
          _testApp(
            SizedBox(
              width: width,
              child: const TopTagsRanking(items: _rankingItems),
            ),
          ),
        );

        for (final item in _rankingItems) {
          expect(find.text(item.tag), findsOneWidget);
        }
        final firstY = tester.getTopLeft(find.text('tag-1')).dy;
        final fourthY = tester.getTopLeft(find.text('tag-4')).dy;
        if (width < 840) {
          expect(fourthY, greaterThan(firstY));
        } else {
          expect(fourthY, firstY);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'aspect ratio chart stacks its legend on narrow large-text surfaces',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _testApp(
          const SizedBox(
            width: 280,
            child: AspectRatioChart(
              height: 140,
              items: [
                AspectRatioItem(
                  ratio: '16:9',
                  label: 'Landscape with a long translated label',
                  count: 10,
                  percentage: 100,
                ),
              ],
            ),
          ),
          textScaler: const TextScaler.linear(3),
        ),
      );

      expect(find.text('16:9'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('16:9')).dy,
        greaterThan(tester.getTopLeft(find.byType(AspectRatioChart)).dy + 140),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('interactive heatmap cells expose 48px touch targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: SizedBox(
            width: 280,
            child: HeatmapChart(
              data: const [
                [0, 0, 0, 0, 0, 0, 0],
              ],
              cellSize: 20,
              cellSpacing: 4,
              showDayLabels: false,
              showMonthLabels: false,
              onCellTap: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Tooltip).first).height, 48);
    expect(tester.getSize(find.byType(AnimatedContainer).first).height, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pointer heatmap keeps requested visual cell size and spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: false,
            precisePointerAvailable: true,
          ),
          child: SizedBox(
            width: 400,
            child: HeatmapChart(
              data: List.generate(14, (_) => List.filled(7, 0.0)),
              cellSize: 20,
              cellSpacing: 4,
              showDayLabels: false,
              showMonthLabels: false,
              onCellTap: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Tooltip).first), const Size.square(24));
    expect(
      tester.getSize(find.byType(AnimatedContainer).first),
      const Size.square(20),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'animated statistics values render their final state with reduced motion',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          const AnimatedNumber(targetValue: 42, style: TextStyle()),
          disableAnimations: true,
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow top tag ranking remains complete at 3x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        const SizedBox(width: 320, child: TopTagsRanking(items: _rankingItems)),
        textScaler: const TextScaler.linear(3),
      ),
    );

    for (final item in _rankingItems) {
      expect(find.text(item.tag), findsOneWidget);
      expect(find.text('${item.count}'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler, disableAnimations: disableAnimations),
      child: appChild!,
    ),
    home: Scaffold(
      body: Align(alignment: Alignment.topCenter, child: child),
    ),
  );
}

const _rankingItems = [
  TagRankItem(tag: 'tag-1', count: 60, percentage: 0.6, trend: 1),
  TagRankItem(tag: 'tag-2', count: 50, percentage: 0.5, trend: -1),
  TagRankItem(tag: 'tag-3', count: 40, percentage: 0.4, trend: 0),
  TagRankItem(tag: 'tag-4', count: 30, percentage: 0.3, trend: 1),
  TagRankItem(tag: 'tag-5', count: 20, percentage: 0.2, trend: -1),
  TagRankItem(tag: 'tag-6', count: 10, percentage: 0.1, trend: 0),
];
