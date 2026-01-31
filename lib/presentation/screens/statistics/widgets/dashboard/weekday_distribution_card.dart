import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../../data/models/gallery/local_image_record.dart';
import '../cards/chart_card.dart';
import '../charts/weekday_bar_chart.dart';

/// 星期分布卡片 - 柱状图展示一周活动分布
/// Weekday distribution card - displays weekly activity distribution as bar chart
class WeekdayDistributionCard extends StatelessWidget {
  final List<LocalImageRecord> records;

  const WeekdayDistributionCard({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (records.isEmpty) {
      return ChartCard(
        title: l10n.statistics_chartWeekdayDistribution,
        titleIcon: Icons.date_range_outlined,
        child: ChartEmptyState(title: l10n.statistics_noData),
      );
    }

    // 统计每周几的活动量
    final weekdayData = <int, int>{};
    for (final record in records) {
      final weekday = record.modifiedAt.weekday;
      weekdayData[weekday] = (weekdayData[weekday] ?? 0) + 1;
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
