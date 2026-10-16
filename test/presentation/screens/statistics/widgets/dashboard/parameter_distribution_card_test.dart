import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_dashboard_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/gallery_parameter.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/services/statistics_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/cards/chart_card.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/charts/parameter_distribution_bar.dart';
import 'package:nai_launcher/presentation/screens/statistics/widgets/dashboard/parameter_distribution_card.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_segmented_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../statistics_dashboard_harness.dart';

void main() {
  final samplerCounts = {
    'k_euler_ancestral': 14,
    'k_euler': 8,
    'k_dpmpp_2m_sde': 6,
    'k_dpmpp_2s_ancestral': 4,
    'k_dpmpp_2m': 2,
    'ddim_v3': 2,
  };
  final stats = StatisticsService().fromDashboardSnapshot(
    GalleryDashboardSnapshot(
      totalImages: 40,
      totalSizeBytes: 80 * 1024 * 1024,
      favoriteCount: 5,
      taggedImageCount: 10,
      imagesWithMetadata: 36,
      resolutionCounts: {'832x1216': 20, '1216x832': 10, '1024x1024': 6},
      modelCounts: {'nai-diffusion-4-5-full': 36},
      samplerCounts: samplerCounts,
      sizeCounts: {'1-2 MB': 30, '2-5 MB': 10},
      tagCounts: {'1girl': 10},
      dailyCounts: {20260928: 10, 20260929: 12, 20260930: 18},
      hourlyCounts: {10: 20, 22: 20},
      weekdayCounts: {DateTime.monday: 20, DateTime.friday: 20},
      parameterCounts: {
        GalleryParameter.sampler: samplerCounts,
        GalleryParameter.steps: {
          '28': 20,
          '23': 6,
          '30': 4,
          '40': 2,
          '50': 2,
          '12': 1,
          '20': 1,
        },
        GalleryParameter.scale: {'5.0': 20, '5.5': 10, '6.0': 6},
        GalleryParameter.noiseSchedule: {'karras': 30, 'exponential': 6},
        GalleryParameter.cfgRescale: {'0.0': 30, '0.2': 6},
      },
    ),
    calculatedAt: DateTime(2026, 9, 30),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the sampler tab shows the former sampler card numbers', (
    tester,
  ) async {
    await _pumpCard(tester, stats);

    expect(_selected(tester), GalleryParameter.sampler);
    expect(stats.samplerDistribution, hasLength(samplerCounts.length));
    expect(
      [
        for (final item in _items(tester))
          (item.label, item.count, item.percentage),
      ],
      [
        for (final sampler in stats.samplerDistribution)
          (sampler.samplerName, sampler.count, sampler.percentage),
      ],
    );
    for (final sampler in stats.samplerDistribution) {
      expect(find.text(sampler.samplerName), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching parameters swaps the rows under a fixed title', (
    tester,
  ) async {
    await _pumpCard(tester, stats);

    await _select(tester, 'Steps');
    expect(_selected(tester), GalleryParameter.steps);
    expect(_items(tester).map((item) => (item.label, item.count)), [
      ('28', 20),
      ('23', 6),
      ('30', 4),
      ('40', 2),
      ('50', 2),
      ('Other', 2),
    ]);

    await _select(tester, 'CFG Scale');
    expect(_items(tester).map((item) => item.label), ['5.0', '5.5', '6.0']);

    await _select(tester, 'Noise Schedule');
    expect(_items(tester).map((item) => item.label), ['karras', 'exponential']);

    await _select(tester, 'CFG Rescale');
    expect(_items(tester).map((item) => item.label), ['0.0', '0.2']);

    await _select(tester, 'Sampler');
    expect(_items(tester).first.label, 'Euler Ancestral');

    expect(find.text('Parameter Distribution'), findsOneWidget);
    expect(find.text('Sampler Distribution'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a gallery without generation parameters shows the empty state', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      stats.copyWith(
        samplerDistribution: const [],
        parameterDistribution: const [],
      ),
    );

    expect(find.byType(ChartEmptyState), findsOneWidget);
    expect(find.byType(ParameterDistributionBar), findsNothing);
    expect(find.byKey(_selectorKey), findsOneWidget);

    await _select(tester, 'Steps');
    expect(find.byType(ChartEmptyState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a parameter without values shows the empty state until switched',
    (tester) async {
      await _pumpCard(
        tester,
        stats.copyWith(
          parameterDistribution: [
            for (final entry in stats.parameterDistribution)
              if (entry.parameterName != GalleryParameter.cfgRescale.key) entry,
          ],
        ),
      );

      await _select(tester, 'CFG Rescale');
      expect(find.byType(ChartEmptyState), findsOneWidget);
      expect(find.byType(ParameterDistributionBar), findsNothing);

      await _select(tester, 'CFG Scale');
      expect(find.byType(ChartEmptyState), findsNothing);
      expect(_items(tester), hasLength(3));
    },
  );

  // The test font draws every glyph 1em wide, so English runs about twice its
  // real width; that stress case targets this card alone.
  testWidgets('the card alone keeps every parameter reachable under '
      'English 3x text at 320px', (tester) async {
    await _pumpCard(tester, stats, size: const Size(320, 900), textScale: 3);

    await _expectEveryParameterReachable(tester, _labels);
  });

  for (final textScale in [1.0, 3.0]) {
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      testWidgets('every parameter stays reachable in the dashboard column at '
          '${width.toInt()}px ${textScale}x text', (tester) async {
        final size = Size(width, 900);
        final cardWidth = await _dashboardCardWidth(
          tester,
          stats,
          size,
          textScale,
        );
        expect(cardWidth, lessThanOrEqualTo(width));

        await _pumpCard(
          tester,
          stats,
          size: size,
          textScale: textScale,
          cardWidth: cardWidth,
          locale: const Locale('zh'),
        );

        await _expectEveryParameterReachable(tester, _zhLabels);
      });
    }
  }
}

const _selectorKey = ValueKey('statistics-parameter-selector');

const _labels = {
  GalleryParameter.sampler: 'Sampler',
  GalleryParameter.steps: 'Steps',
  GalleryParameter.scale: 'CFG Scale',
  GalleryParameter.noiseSchedule: 'Noise Schedule',
  GalleryParameter.cfgRescale: 'CFG Rescale',
};

const _zhLabels = {
  GalleryParameter.sampler: '采样器',
  GalleryParameter.steps: '步数',
  GalleryParameter.scale: 'CFG 强度',
  GalleryParameter.noiseSchedule: '噪声调度',
  GalleryParameter.cfgRescale: 'CFG 重缩放',
};

Future<void> _expectEveryParameterReachable(
  WidgetTester tester,
  Map<GalleryParameter, String> labels,
) async {
  final card = find.byType(ParameterDistributionCard);
  final viewWidth = tester.view.physicalSize.width;
  expect(tester.getRect(card).left, greaterThanOrEqualTo(0));
  expect(tester.getRect(card).right, lessThanOrEqualTo(viewWidth));
  expect(find.byType(ParameterDistributionBar), findsOneWidget);
  expect(tester.takeException(), isNull);

  for (final parameter in GalleryParameter.values) {
    final label = labels[parameter]!;
    await _select(tester, label);
    expect(_selected(tester), parameter, reason: label);
    expect(_items(tester), isNotEmpty, reason: label);
    expect(tester.takeException(), isNull, reason: label);
  }
}

Finder _segment(String label) => find.ancestor(
  of: find.descendant(of: find.byKey(_selectorKey), matching: find.text(label)),
  matching: find.byType(TextButton),
);

/// Taps the part of the segment visible in the scrolling strip: segments share
/// the widest label's width, so a long one can exceed the strip.
Future<void> _select(WidgetTester tester, String label) async {
  final segment = _segment(label);
  await tester.ensureVisible(segment);
  await tester.pumpAndSettle();
  final strip = tester.getRect(find.byType(HorizontalSegmentedControl));
  final visible = tester.getRect(segment).intersect(strip);
  expect(visible.height, greaterThanOrEqualTo(48), reason: label);
  expect(visible.width, greaterThanOrEqualTo(48), reason: label);
  await tester.tapAt(visible.center);
  await tester.pumpAndSettle();
}

GalleryParameter _selected(WidgetTester tester) => tester
    .widget<SegmentedButton<GalleryParameter>>(find.byKey(_selectorKey))
    .selected
    .single;

List<ParameterBarItem> _items(WidgetTester tester) => tester
    .widget<ParameterDistributionBar>(find.byType(ParameterDistributionBar))
    .items;

Future<void> _pumpCard(
  WidgetTester tester,
  GalleryStatistics stats, {
  Size size = const Size(480, 900),
  double textScale = 1,
  double? cardWidth,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: cardWidth ?? size.width,
              child: ParameterDistributionCard(stats: stats),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Width the real dashboard grid gives this card. Only the width is read:
/// overflow in the other dashboard cards is outside this card's contract.
Future<double> _dashboardCardWidth(
  WidgetTester tester,
  GalleryStatistics stats,
  Size size,
  double textScale,
) async {
  await pumpStatisticsDashboard(
    tester,
    stats,
    size: size,
    textScale: textScale,
  );
  final width = tester.getSize(find.byType(ParameterDistributionCard)).width;
  tester.takeException();
  return width;
}
