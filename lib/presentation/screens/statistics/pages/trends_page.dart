import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../data/models/gallery/gallery_statistics.dart';
import '../../../../data/models/gallery/daily_trend_statistics.dart';
import '../statistics_state.dart';
import '../widgets/widgets.dart';

/// Trends analysis page - time-based trends
class TrendsPage extends ConsumerStatefulWidget {
  const TrendsPage({super.key});

  @override
  ConsumerState<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends ConsumerState<TrendsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final data = ref.watch(statisticsNotifierProvider);
    final notifier = ref.read(statisticsNotifierProvider.notifier);

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = data.statistics;
    if (stats == null || stats.dailyTrends.isEmpty) {
      return Center(
        child: ChartEmptyState(
          icon: Icons.show_chart_outlined,
          title: l10n.statistics_noData,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildGranularitySelector(theme, l10n, notifier),
        const SizedBox(height: 20),
        _buildTrendChart(context, theme, stats, l10n),
        const SizedBox(height: 20),
        _buildTrendSummary(theme, stats, l10n),
      ],
    );
  }

  Widget _buildGranularitySelector(
    ThemeData theme,
    AppLocalizations l10n,
    StatisticsNotifier notifier,
  ) {
    return ChartCard(
      child: Row(
        children: [
          Text(
            '${l10n.statistics_granularity}:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'day',
                label: Text(l10n.statistics_granularityDay),
              ),
              ButtonSegment(
                value: 'week',
                label: Text(l10n.statistics_granularityWeek),
              ),
              ButtonSegment(
                value: 'month',
                label: Text(l10n.statistics_granularityMonth),
              ),
            ],
            selected: {notifier.filter.timeGranularity},
            onSelectionChanged: (selection) {
              notifier.setTimeGranularity(selection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final trends = stats.dailyTrends;
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return ChartCard(
      child: SizedBox(
        height: 300,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: colorScheme.outlineVariant.withOpacity(0.2),
                strokeWidth: 1,
              ),
            ),
            titlesData: _buildTitles(theme, trends, isMobile),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: trends.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value.count.toDouble(),
                  );
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: colorScheme.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: trends.length < 30,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: colorScheme.primary,
                      strokeWidth: 2,
                      strokeColor: colorScheme.surface,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primary.withOpacity(0.3),
                      colorScheme.primary.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
            minY: 0,
            maxX: (trends.length - 1).toDouble(),
          ),
        ),
      ),
    );
  }

  FlTitlesData _buildTitles(
    ThemeData theme,
    List<DailyTrendStatistics> trends,
    bool isMobile,
  ) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= trends.length) {
              return const SizedBox.shrink();
            }
            final step = (trends.length / (isMobile ? 4 : 6)).ceil();
            if (index % step != 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                trends[index].getFormattedDateShort(),
                style: theme.textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (value == meta.max) return const SizedBox.shrink();
            return Text(
              value.toInt().toString(),
              style: theme.textTheme.labelSmall,
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildTrendSummary(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final trends = stats.dailyTrends;
    final peak = trends.map((t) => t.count).reduce((a, b) => a > b ? a : b);
    final avg =
        trends.map((t) => t.count).reduce((a, b) => a + b) / trends.length;

    return ChartCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          TrendSummaryItem(
            icon: Icons.calendar_today,
            label: l10n.statistics_labelTotalDays,
            value: '${trends.length}',
          ),
          TrendSummaryItem(
            icon: Icons.trending_up,
            label: l10n.statistics_labelPeak,
            value: '$peak',
          ),
          TrendSummaryItem(
            icon: Icons.analytics,
            label: l10n.statistics_labelAverage,
            value: avg.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }
}
