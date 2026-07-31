import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../../data/models/gallery/daily_trend_statistics.dart';
import '../cards/chart_card.dart';
import '../charts/heatmap_chart.dart';

/// 活动热力图卡片 - GitHub风格热力图展示26周活动
/// Activity heatmap card - displays 26-week activity heatmap in GitHub style
class ActivityHeatmapCard extends StatelessWidget {
  final List<DailyTrendStatistics> dailyTrends;

  const ActivityHeatmapCard({super.key, required this.dailyTrends});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (dailyTrends.isEmpty) {
      return ChartCard(
        title: l10n.statistics_chartActivityHeatmap,
        titleIcon: Icons.grid_on_outlined,
        child: ChartEmptyState(title: l10n.statistics_noData),
      );
    }

    // 统计每日图片数量
    final dateCounts = <DateTime, int>{};
    for (final trend in dailyTrends) {
      final date = DateTime(trend.date.year, trend.date.month, trend.date.day);
      dateCounts[date] = (dateCounts[date] ?? 0) + trend.count;
    }

    final heatmapResult = generateHeatmapData(dateCounts, weeks: 14);

    return ChartCard(
      title: l10n.statistics_chartActivityHeatmap,
      titleIcon: Icons.grid_on_outlined,
      child: HeatmapChart(
        data: heatmapResult.data,
        cellSize: 20,
        cellSpacing: 4,
        todayPosition: heatmapResult.todayPosition,
        onCellTap: (week, day, value) {},
      ),
    );
  }
}
