import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../../data/services/anlas_statistics_service.dart';
import '../cards/chart_card.dart';

/// 点数花费统计卡片 - 按日期统计Anlas消耗趋势
/// Anlas cost card - displays Anlas consumption trend by date
class AnlasCostCard extends ConsumerWidget {
  const AnlasCostCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    final anlasStats = ref.watch(anlasStatisticsServiceProvider);

    return anlasStats.when(
      data: (service) {
        final dailyStats = service.getDailyStats(days: 14);
        final totalCost = service.totalCost;

        if (dailyStats.isEmpty || totalCost == 0) {
          return ChartCard(
            title: l10n.statistics_anlasCost,
            titleIcon: Icons.paid_outlined,
            accentColor: Colors.amber,
            child: _buildEmptyState(context, l10n),
          );
        }

        return ChartCard(
          title: l10n.statistics_anlasCost,
          titleIcon: Icons.paid_outlined,
          accentColor: Colors.amber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 总消耗和平均消耗
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: l10n.statistics_totalAnlasCost,
                      value: _formatAnlas(totalCost),
                      isDark: isDark,
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      label: l10n.statistics_avgDailyCost,
                      value: _formatAnlas(
                        dailyStats.isNotEmpty
                            ? totalCost ~/ dailyStats.where((s) => s.cost > 0).length.clamp(1, 999)
                            : 0,
                      ),
                      isDark: isDark,
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 日趋势图
              SizedBox(
                height: 120,
                child: _buildTrendChart(
                  context,
                  dailyStats,
                  colorScheme,
                  isDark,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => ChartCard(
        title: l10n.statistics_anlasCost,
        titleIcon: Icons.paid_outlined,
        accentColor: Colors.amber,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => ChartCard(
        title: l10n.statistics_anlasCost,
        titleIcon: Icons.paid_outlined,
        accentColor: Colors.amber,
        child: _buildEmptyState(context, l10n),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.statistics_noAnlasData,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    List<DailyAnlasStat> dailyStats,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (dailyStats.isEmpty) return const SizedBox.shrink();

    final spots = dailyStats.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.cost.toDouble());
    }).toList();

    final maxValue =
        dailyStats.map((e) => e.cost).reduce((a, b) => a > b ? a : b);
    final minValue =
        dailyStats.map((e) => e.cost).reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    final padding = range > 0 ? range * 0.15 : maxValue * 0.15;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxValue / 3).clamp(1, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final stat = dailyStats[spot.spotIndex];
                return LineTooltipItem(
                  '${stat.date.month}/${stat.date.day}\n${_formatAnlas(stat.cost)}',
                  TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        minY: (minValue - padding).clamp(0, double.infinity),
        maxY: maxValue + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.amber,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: Colors.amber,
                strokeWidth: 2,
                strokeColor: isDark ? colorScheme.surface : Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.amber.withOpacity(0.3),
                  Colors.amber.withOpacity(0.05),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAnlas(int value) {
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StatBox({
    required this.label,
    required this.value,
    required this.isDark,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
