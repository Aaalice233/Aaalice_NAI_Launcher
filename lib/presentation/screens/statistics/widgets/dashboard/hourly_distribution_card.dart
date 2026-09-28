import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../cards/chart_card.dart';
import '../charts/polar_activity_chart.dart';

/// 小时分布卡片 - 极坐标雷达图展示24小时活动分布
/// Hourly distribution card - displays 24-hour activity distribution as polar chart
class HourlyDistributionCard extends StatelessWidget {
  final Map<int, int> hourlyData;

  const HourlyDistributionCard({super.key, required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (hourlyData.isEmpty) {
      return ChartCard(
        title: l10n.statistics_chartHourlyDistribution,
        titleIcon: Icons.schedule_outlined,
        child: ChartEmptyState(title: l10n.statistics_noData),
      );
    }

    // 找到峰值小时
    int peakHour = 0;
    int peakCount = 0;
    hourlyData.forEach((hour, count) {
      if (count > peakCount) {
        peakHour = hour;
        peakCount = count;
      }
    });

    final chart = PolarActivityChart(
      key: const ValueKey('hourly-distribution-chart'),
      hourlyData: hourlyData,
      size: 180,
    );
    final summary = PeakTimeIndicator(
      key: const ValueKey('hourly-distribution-summary'),
      peakHour: peakHour,
      count: peakCount,
      label: l10n.statistics_peakActivity,
      morningLabel: l10n.statistics_timeMorning,
      afternoonLabel: l10n.statistics_timeAfternoon,
      eveningLabel: l10n.statistics_timeEvening,
      nightLabel: l10n.statistics_timeNight,
    );

    return ChartCard(
      title: l10n.statistics_chartHourlyDistribution,
      titleIcon: Icons.schedule_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              key: const ValueKey('hourly-distribution-narrow-layout'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: chart),
                const SizedBox(height: 16),
                summary,
              ],
            );
          }

          return Row(
            key: const ValueKey('hourly-distribution-wide-layout'),
            children: [
              chart,
              const SizedBox(width: 16),
              Expanded(child: summary),
            ],
          );
        },
      ),
    );
  }
}
