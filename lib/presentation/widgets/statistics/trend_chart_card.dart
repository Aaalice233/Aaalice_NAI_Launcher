import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../data/models/gallery/daily_trend_statistics.dart';

/// 趋势图表卡片
///
/// 用于显示时间序列趋势数据的卡片组件，支持：
/// - 每日/每周/每月趋势切换
/// - 交互式折线图
/// - 点击数据点查看详情
/// - 响应式布局
class TrendChartCard extends StatelessWidget {
  /// 趋势数据列表
  final List<DailyTrendStatistics> trends;

  /// 图表标题
  final String title;

  /// 时间聚合类型（日/周/月）
  final TrendInterval interval;

  /// 点击数据点回调
  final void Function(DailyTrendStatistics trend)? onTrendTap;

  /// 是否显示动画
  final bool animate;

  const TrendChartCard({
    super.key,
    required this.trends,
    required this.title,
    this.interval = TrendInterval.daily,
    this.onTrendTap,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 处理空数据情况
    if (trends.isEmpty) {
      return _buildEmptyState(theme, l10n);
    }

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和图例
            _buildHeader(context, theme, l10n),
            const SizedBox(height: 16),

            // 图表
            SizedBox(
              height: 200,
              child: LineChart(
                _buildChartData(theme, l10n),
                duration:
                    animate ? const Duration(milliseconds: 800) : Duration.zero,
              ),
            ),

            // X轴标签（日期）
            const SizedBox(height: 8),
            _buildDateLabels(theme, l10n),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.statistics_noData,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片头部（标题和图例）
  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Icon(
          Icons.show_chart,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 图例
        _buildLegendItem(
          theme,
          theme.colorScheme.primary,
          l10n.statistics_generatedCount,
        ),
        const SizedBox(width: 16),
        if (trends.any((t) => t.favoriteCount > 0))
          _buildLegendItem(
            theme,
            Colors.red,
            l10n.statistics_favoriteCount,
          ),
      ],
    );
  }

  /// 构建图例项
  Widget _buildLegendItem(ThemeData theme, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// 构建图表数据
  LineChartData _buildChartData(ThemeData theme, AppLocalizations l10n) {
    final sortedTrends = trends..sort((a, b) => a.date.compareTo(b.date));

    // 计算Y轴范围
    final maxCount =
        sortedTrends.map((t) => t.count).reduce((a, b) => a > b ? a : b) * 1.2;

    // 主线（生成数量）
    final mainSpots = sortedTrends.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.count.toDouble(),
      );
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: theme.dividerColor.withOpacity(0.3),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              if (value == meta.max || value == 0) {
                return const SizedBox.shrink();
              }
              return Text(
                value.toInt().toString(),
                style: theme.textTheme.bodySmall,
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (sortedTrends.length - 1).toDouble(),
      minY: 0,
      maxY: maxCount,
      lineBarsData: [
        // 主线：生成数量
        LineChartBarData(
          spots: mainSpots,
          isCurved: true,
          color: theme.colorScheme.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: theme.colorScheme.primary,
                strokeWidth: 2,
                strokeColor: theme.colorScheme.surface,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),

        // 如果有收藏数据，显示收藏线
        if (sortedTrends.any((t) => t.favoriteCount > 0))
          LineChartBarData(
            spots: sortedTrends.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value.favoriteCount.toDouble(),
              );
            }).toList(),
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.red,
                  strokeWidth: 2,
                  strokeColor: theme.colorScheme.surface,
                );
              },
            ),
          ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index < 0 || index >= sortedTrends.length) {
                return null;
              }

              final trend = sortedTrends[index];

              return LineTooltipItem(
                '${trend.getFormattedDateShort()}\n'
                '${l10n.statistics_tooltipGenerated(trend.count)}'
                '${trend.favoriteCount > 0 ? '\n${l10n.statistics_tooltipFavorite(trend.favoriteCount)}' : ''}',
                TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          if (event is FlTapUpEvent &&
              response != null &&
              response.lineBarSpots != null &&
              response.lineBarSpots!.isNotEmpty) {
            final index = response.lineBarSpots!.first.x.toInt();
            if (index >= 0 && index < sortedTrends.length) {
              onTrendTap?.call(sortedTrends[index]);
            }
          }
        },
      ),
    );
  }

  /// 构建日期标签
  Widget _buildDateLabels(ThemeData theme, AppLocalizations l10n) {
    final sortedTrends = trends..sort((a, b) => a.date.compareTo(b.date));

    // 根据数据量决定显示哪些标签
    final labelInterval = sortedTrends.length > 10
        ? (sortedTrends.length / 5).ceil()
        : (sortedTrends.length > 5 ? 2 : 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(sortedTrends.length, (index) {
        // 只显示间隔标签
        if (index % labelInterval != 0 && index != sortedTrends.length - 1) {
          return const SizedBox.shrink();
        }

        final trend = sortedTrends[index];
        return Expanded(
          child: Center(
            child: Text(
              trend.getFormattedDateShort(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }),
    );
  }
}

/// 时间聚合类型
enum TrendInterval {
  /// 每日
  daily,

  /// 每周
  weekly,

  /// 每月
  monthly,
}

/// TrendChartCard 的扩展方法
extension TrendChartCardExtensions on TrendChartCard {
  /// 创建每日趋势图表
  static TrendChartCard daily({
    Key? key,
    required List<DailyTrendStatistics> trends,
    required String title,
    void Function(DailyTrendStatistics trend)? onTrendTap,
    bool animate = true,
  }) {
    return TrendChartCard(
      key: key,
      trends: trends,
      title: title,
      interval: TrendInterval.daily,
      onTrendTap: onTrendTap,
      animate: animate,
    );
  }

  /// 创建每周趋势图表
  static TrendChartCard weekly({
    Key? key,
    required List<DailyTrendStatistics> trends,
    required String title,
    void Function(DailyTrendStatistics trend)? onTrendTap,
    bool animate = true,
  }) {
    return TrendChartCard(
      key: key,
      trends: trends,
      title: title,
      interval: TrendInterval.weekly,
      onTrendTap: onTrendTap,
      animate: animate,
    );
  }

  /// 创建每月趋势图表
  static TrendChartCard monthly({
    Key? key,
    required List<DailyTrendStatistics> trends,
    required String title,
    void Function(DailyTrendStatistics trend)? onTrendTap,
    bool animate = true,
  }) {
    return TrendChartCard(
      key: key,
      trends: trends,
      title: title,
      interval: TrendInterval.monthly,
      onTrendTap: onTrendTap,
      animate: animate,
    );
  }
}
