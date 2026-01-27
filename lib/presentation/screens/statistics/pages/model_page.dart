import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../data/models/gallery/gallery_statistics.dart';
import '../statistics_state.dart';
import '../widgets/widgets.dart';
import '../utils/utils.dart';

/// Model analysis page - model distribution and rankings
class ModelPage extends ConsumerStatefulWidget {
  const ModelPage({super.key});

  @override
  ConsumerState<ModelPage> createState() => _ModelPageState();
}

class _ModelPageState extends ConsumerState<ModelPage>
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

    final stats = data.statistics;
    if (stats == null || stats.modelDistribution.isEmpty) {
      return Center(
        child: ChartEmptyState(
          icon: Icons.category_outlined,
          title: l10n.statistics_noData,
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPieChart(theme, stats, l10n)),
              const SizedBox(width: 20),
              Expanded(child: _buildRanking(theme, stats, l10n)),
            ],
          )
        else ...[
          _buildPieChart(theme, stats, l10n),
          const SizedBox(height: 20),
          _buildRanking(theme, stats, l10n),
        ],
        const SizedBox(height: 20),
        _buildTimeline(theme, data, l10n),
      ],
    );
  }

  Widget _buildPieChart(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final distribution = stats.modelDistribution;

    return ChartCard(
      title: l10n.statistics_chartUsageDistribution,
      titleIcon: Icons.pie_chart_outline,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: AnimatedPieChart(
              height: 220,
              data: PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: distribution.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return PieChartSectionData(
                    color: ChartColors.getColorForIndex(index),
                    value: data.count.toDouble(),
                    title: '${data.percentage.toStringAsFixed(0)}%',
                    radius: 50,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: distribution.take(5).map((model) {
              final color =
                  ChartColors.getColorForIndex(distribution.indexOf(model));
              return LegendItem(color: color, label: model.modelName);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRanking(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final items = stats.modelDistribution.map((m) {
      return ModelRankItem(
        name: m.modelName,
        count: m.count,
        percentage: m.percentage,
      );
    }).toList();

    return ChartCard(
      title: l10n.statistics_chartModelRanking,
      titleIcon: Icons.leaderboard_outlined,
      child: ModelRankingList(items: items, maxItems: 8),
    );
  }

  Widget _buildTimeline(
    ThemeData theme,
    StatisticsData data,
    AppLocalizations l10n,
  ) {
    final stats = data.statistics;
    if (stats == null) return const SizedBox.shrink();

    final weeklyData = <int, Map<String, int>>{};
    for (final record in data.filteredRecords) {
      final week = StatisticsFormatter.getWeekOfYear(record.modifiedAt);
      final model = record.metadata?.model ?? l10n.statistics_unknown;
      weeklyData.putIfAbsent(week, () => {});
      weeklyData[week]![model] = (weeklyData[week]![model] ?? 0) + 1;
    }

    if (weeklyData.isEmpty) return const SizedBox.shrink();

    final sortedWeeks = weeklyData.keys.toList()..sort();
    final models =
        stats.modelDistribution.take(5).map((m) => m.modelName).toList();

    final series = models.map((model) {
      return StackedAreaSeries(
        name: model,
        values: sortedWeeks.map((week) {
          return (weeklyData[week]?[model] ?? 0).toDouble();
        }).toList(),
      );
    }).toList();

    return ChartCard(
      title: l10n.statistics_chartModelUsageOverTime,
      titleIcon: Icons.stacked_line_chart,
      child: StackedAreaChart(
        series: series,
        xLabels: sortedWeeks
            .map((w) => l10n.statistics_weekLabel(w.toString()))
            .toList(),
        height: 260,
      ),
    );
  }
}
