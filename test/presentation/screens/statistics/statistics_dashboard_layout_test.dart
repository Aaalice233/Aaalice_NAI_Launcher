import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_dashboard_snapshot.dart';
import 'package:nai_launcher/data/models/gallery/gallery_parameter.dart';
import 'package:nai_launcher/data/models/gallery/gallery_statistics.dart';
import 'package:nai_launcher/data/services/anlas_statistics_service.dart';
import 'package:nai_launcher/data/services/statistics_service.dart';
import 'package:nai_launcher/presentation/screens/statistics/utils/statistics_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'statistics_dashboard_harness.dart';

void main() {
  final stats = _dashboardStatistics();

  setUp(() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    SharedPreferences.setMockInitialValues({
      'anlas_daily_stats': jsonEncode([
        for (var day = 0; day < 60; day++)
          DailyAnlasStat(
            date: today.subtract(Duration(days: day)),
            cost: 98765 + day,
          ).toJson(),
      ]),
      'anlas_stats_coverage_start': today
          .subtract(const Duration(days: 400))
          .toIso8601String(),
    });
  });

  for (final locale in const [Locale('zh'), Locale('en')]) {
    for (final textScale in const [1.0, 3.0]) {
      for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        final config =
            '${width.toInt()}px ${textScale}x ${locale.languageCode}';
        testWidgets('dashboard at $config keeps every card and number whole', (
          tester,
        ) async {
          await pumpStatisticsDashboard(
            tester,
            stats,
            size: Size(width, 900),
            textScale: textScale,
            locale: locale,
          );

          expect(tester.takeException(), isNull, reason: config);
          // Narrow 3x may break a word to keep it visible; 1x, or 3x with a
          // wide single column, has room to keep every word whole.
          expect(
            _hiddenTexts(
              tester,
              width,
              wordsMustStayWhole: textScale == 1 || width >= 1180,
            ),
            isEmpty,
            reason: config,
          );

          final keyNumbers = [
            find.text('123456'),
            find.text(StatisticsFormatter.formatBytes(stats.totalSizeBytes)),
            find.text('4321 (3.5%)'),
            find.text(
              StatisticsFormatter.formatBytes(
                stats.totalSizeBytes ~/ stats.totalImages,
              ),
            ),
            find.text('120456'),
            find.byKey(const ValueKey('anlas-period-total')),
            find.byKey(const ValueKey('anlas-period-average')),
          ];
          for (final number in keyNumbers) {
            expect(number, findsOneWidget, reason: '$config $number');
          }
        });
      }
    }
  }

  testWidgets('weekday chart switches to rows when a day slot is too narrow', (
    tester,
  ) async {
    await pumpStatisticsDashboard(
      tester,
      stats,
      size: const Size(320, 900),
      textScale: 3,
    );

    final rows = find.byKey(const ValueKey('weekday-distribution-rows'));
    expect(rows, findsOneWidget);
    expect(
      find.byKey(const ValueKey('weekday-distribution-bars')),
      findsNothing,
    );
    for (final day in ['周一', '周二', '周三', '周四', '周五', '周六', '周日']) {
      expect(
        find.descendant(of: rows, matching: find.text(day)),
        findsOneWidget,
      );
    }
    for (var weekday = 1; weekday <= 7; weekday++) {
      expect(
        find.descendant(of: rows, matching: find.text('${17000 + weekday}')),
        findsOneWidget,
      );
    }

    await pumpStatisticsDashboard(
      tester,
      stats,
      size: const Size(1600, 900),
      textScale: 1,
    );

    expect(
      find.byKey(const ValueKey('weekday-distribution-bars')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('weekday-distribution-rows')),
      findsNothing,
    );
  });
}

GalleryStatistics _dashboardStatistics() {
  final now = DateTime.now();
  final dailyCounts = <int, int>{
    for (var day = 0; day < 365; day++)
      _dayKey(now.subtract(Duration(days: day))): 300 + day,
  };
  final samplerCounts = {
    'k_euler_ancestral': 64000,
    'k_euler': 32000,
    'k_dpmpp_2m_sde': 12000,
    'k_dpmpp_2s_ancestral': 8000,
    'k_dpmpp_2m': 3000,
    'ddim_v3': 1000,
    'k_dpmpp_sde': 456,
  };
  return StatisticsService().fromDashboardSnapshot(
    GalleryDashboardSnapshot(
      totalImages: 123456,
      totalSizeBytes: 987654321098,
      favoriteCount: 4321,
      taggedImageCount: 23456,
      imagesWithMetadata: 120456,
      resolutionCounts: {
        '832x1216': 60000,
        '1216x832': 30000,
        '1024x1024': 20000,
        '1472x1472': 8000,
        '640x640': 5456,
      },
      modelCounts: {'nai-diffusion-4-5-full': 100000, 'nai-diffusion-3': 20456},
      samplerCounts: samplerCounts,
      sizeCounts: {'1-2 MB': 80000, '2-5 MB': 40000, '> 10 MB': 3456},
      tagCounts: {'1girl': 60000, 'solo': 50000},
      dailyCounts: dailyCounts,
      hourlyCounts: {for (var hour = 0; hour < 24; hour++) hour: 5000 + hour},
      weekdayCounts: {for (var day = 1; day <= 7; day++) day: 17000 + day},
      parameterCounts: {
        GalleryParameter.sampler: samplerCounts,
        GalleryParameter.steps: {'28': 90000, '23': 20000, '50': 10456},
        GalleryParameter.scale: {'5.0': 80000, '5.5': 40456},
        GalleryParameter.noiseSchedule: {
          'karras': 100000,
          'exponential': 20456,
        },
        GalleryParameter.cfgRescale: {'0.0': 110000, '0.2': 10456},
      },
    ),
  );
}

int _dayKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

bool _insideHorizontalScroll(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Scrollable &&
        axisDirectionToAxis(widget.axisDirection) == Axis.horizontal) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Element? _enclosingChart(Element element) {
  Element? chart;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is BarChart || widget is LineChart || widget is PieChart) {
      chart = ancestor;
      return false;
    }
    return true;
  });
  return chart;
}

/// Texts that lose information: truncated, clipped, off screen, spilling out
/// of their chart, or — when [wordsMustStayWhole] — split inside a word.
List<String> _hiddenTexts(
  WidgetTester tester,
  double viewWidth, {
  required bool wordsMustStayWhole,
}) {
  final icons = find
      .descendant(of: find.byType(Icon), matching: find.byType(RichText))
      .evaluate()
      .toSet();
  final problems = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    if (icons.contains(element)) continue;
    final paragraph = element.renderObject! as RenderParagraph;
    if (!paragraph.hasSize) continue;
    final text = paragraph.text.toPlainText().replaceAll('\n', ' ');
    if (text.trim().isEmpty) continue;
    final size = paragraph.size;
    final rect = tester.getRect(
      find.byElementPredicate((e) => identical(e, element)),
    );
    if (paragraph.didExceedMaxLines) problems.add('"$text" truncated');
    if (wordsMustStayWhole &&
        paragraph.getMinIntrinsicWidth(double.infinity) > size.width + 0.5) {
      problems.add('"$text" split inside a word');
    }
    final chart = _enclosingChart(element);
    if (chart != null) {
      final chartRect = tester.getRect(
        find.byElementPredicate((e) => identical(e, chart)),
      );
      // Top tick labels straddle the plot edge by design; only a label wider
      // than the space reserved for it spills sideways.
      if (rect.left < chartRect.left - 0.5 ||
          rect.right > chartRect.right + 0.5) {
        problems.add('"$text" spills out of its chart');
      }
    }
    if (paragraph.getMinIntrinsicHeight(size.width) > size.height + 0.5) {
      problems.add(
        '"$text" clipped vertically ${size.height.toStringAsFixed(1)}',
      );
    }
    if (!paragraph.softWrap &&
        paragraph.getMaxIntrinsicWidth(double.infinity) > size.width + 0.5) {
      problems.add('"$text" clipped horizontally');
    }
    if (!_insideHorizontalScroll(element) &&
        (rect.left < -0.5 || rect.right > viewWidth + 0.5)) {
      problems.add(
        '"$text" outside view ${rect.left.toStringAsFixed(0)}..${rect.right.toStringAsFixed(0)}',
      );
    }
  }
  return problems;
}
