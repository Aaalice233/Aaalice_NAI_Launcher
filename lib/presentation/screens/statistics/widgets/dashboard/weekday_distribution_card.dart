import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../cards/chart_card.dart';
import '../charts/weekday_bar_chart.dart';

/// 星期分布卡片 - 柱状图展示一周活动分布
/// Weekday distribution card - displays weekly activity distribution as bar chart
class WeekdayDistributionCard extends StatelessWidget {
  final Map<int, int> weekdayData;

  const WeekdayDistributionCard({super.key, required this.weekdayData});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (weekdayData.isEmpty) {
      return ChartCard(
        title: l10n.statistics_chartWeekdayDistribution,
        titleIcon: Icons.date_range_outlined,
        child: ChartEmptyState(title: l10n.statistics_noData),
      );
    }

    return ChartCard(
      title: l10n.statistics_chartWeekdayDistribution,
      titleIcon: Icons.date_range_outlined,
      child: Column(
        children: [
          WeekdayBarChart(weekdayData: weekdayData, height: 180),
          const SizedBox(height: 16),
          WeekdaySummary(weekdayData: weekdayData),
        ],
      ),
    );
  }
}
