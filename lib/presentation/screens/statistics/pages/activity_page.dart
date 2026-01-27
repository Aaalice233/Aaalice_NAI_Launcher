import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../statistics_state.dart';
import '../widgets/widgets.dart';

/// Activity analysis page - heatmap and time distributions
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final data = ref.watch(statisticsNotifierProvider);

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.filteredRecords.isEmpty) {
      return Center(
        child: ChartEmptyState(
          icon: Icons.access_time_outlined,
          title: l10n.statistics_noData,
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeatmap(theme, data, l10n),
        const SizedBox(height: 20),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildHourlyActivity(theme, data, l10n)),
              const SizedBox(width: 20),
              Expanded(child: _buildWeekdayActivity(theme, data, l10n)),
            ],
          )
        else ...[
          _buildHourlyActivity(theme, data, l10n),
          const SizedBox(height: 20),
          _buildWeekdayActivity(theme, data, l10n),
        ],
      ],
    );
  }

  Widget _buildHeatmap(
    ThemeData theme,
    StatisticsData data,
    AppLocalizations l10n,
  ) {
    final dateCounts = <DateTime, int>{};
    for (final record in data.filteredRecords) {
      final date = DateTime(
        record.modifiedAt.year,
        record.modifiedAt.month,
        record.modifiedAt.day,
      );
      dateCounts[date] = (dateCounts[date] ?? 0) + 1;
    }

    return ChartCard(
      title: l10n.statistics_chartActivityHeatmap,
      titleIcon: Icons.grid_on_outlined,
      child: HeatmapChart(
        data: generateHeatmapData(dateCounts, weeks: 26),
        cellSize: 14,
        onCellTap: (week, day, value) {},
      ),
    );
  }

  Widget _buildHourlyActivity(
    ThemeData theme,
    StatisticsData data,
    AppLocalizations l10n,
  ) {
    final hourlyData = <int, int>{};
    for (final record in data.filteredRecords) {
      final hour = record.modifiedAt.hour;
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }

    // Find peak hour
    int peakHour = 0;
    int peakCount = 0;
    hourlyData.forEach((hour, count) {
      if (count > peakCount) {
        peakHour = hour;
        peakCount = count;
      }
    });

    return ChartCard(
      title: l10n.statistics_chartHourlyDistribution,
      titleIcon: Icons.schedule_outlined,
      child: Column(
        children: [
          PolarActivityChart(hourlyData: hourlyData, size: 220),
          const SizedBox(height: 16),
          PeakTimeIndicator(peakHour: peakHour, count: peakCount),
        ],
      ),
    );
  }

  Widget _buildWeekdayActivity(
    ThemeData theme,
    StatisticsData data,
    AppLocalizations l10n,
  ) {
    final weekdayData = <int, int>{};
    for (final record in data.filteredRecords) {
      final weekday = record.modifiedAt.weekday;
      weekdayData[weekday] = (weekdayData[weekday] ?? 0) + 1;
    }

    return ChartCard(
      title: l10n.statistics_chartWeekdayDistribution,
      titleIcon: Icons.date_range_outlined,
      child: Column(
        children: [
          WeekdayBarChart(weekdayData: weekdayData, height: 200),
          const SizedBox(height: 16),
          WeekdaySummary(weekdayData: weekdayData),
        ],
      ),
    );
  }
}
