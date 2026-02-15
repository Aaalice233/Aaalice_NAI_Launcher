import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../utils/chart_colors.dart';

/// Stacked area chart data series
class StackedAreaSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const StackedAreaSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

/// Stacked area chart widget for showing cumulative trends
/// 堆叠面积图组件，用于展示累积趋势
class StackedAreaChart extends StatefulWidget {
  final List<StackedAreaSeries> series;
  final List<String>? xLabels;
  final double height;
  final bool showLegend;
  final bool showGrid;
  final Duration animationDuration;
  final void Function(int seriesIndex, int dataIndex)? onDataPointTap;

  const StackedAreaChart({
    super.key,
    required this.series,
    this.xLabels,
    this.height = 250,
    this.showLegend = true,
    this.showGrid = true,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.onDataPointTap,
  });

  @override
  State<StackedAreaChart> createState() => _StackedAreaChartState();
}

class _StackedAreaChartState extends State<StackedAreaChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.series.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'No data available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            SizedBox(
              height: widget.height,
              child: LineChart(
                _buildChartData(theme),
              ),
            ),
            if (widget.showLegend) ...[
              const SizedBox(height: 16),
              _buildLegend(theme),
            ],
          ],
        );
      },
    );
  }

  LineChartData _buildChartData(ThemeData theme) {
    final maxDataPoints = widget.series
        .map((s) => s.values.length)
        .reduce((a, b) => a > b ? a : b);

    // Calculate stacked values
    final stackedSeries = <List<double>>[];
    for (int i = 0; i < widget.series.length; i++) {
      final values = <double>[];
      for (int j = 0; j < maxDataPoints; j++) {
        double stackedValue = 0;
        for (int k = 0; k <= i; k++) {
          if (j < widget.series[k].values.length) {
            stackedValue += widget.series[k].values[j];
          }
        }
        values.add(stackedValue * _animation.value);
      }
      stackedSeries.add(values);
    }

    // Find max Y value
    double maxY = 0;
    for (final values in stackedSeries) {
      for (final value in values) {
        if (value > maxY) maxY = value;
      }
    }
    maxY = maxY * 1.1; // Add 10% padding

    // Build line chart bars (reversed order for proper stacking)
    final lineBarsData = <LineChartBarData>[];
    for (int i = widget.series.length - 1; i >= 0; i--) {
      final color = widget.series[i].color ??
          ChartColors.getColorForIndex(i,
              palette: ChartColors.stackedAreaPalette,);

      lineBarsData.add(
        LineChartBarData(
          spots: List.generate(maxDataPoints, (j) {
            return FlSpot(j.toDouble(), stackedSeries[i][j]);
          }),
          isCurved: true,
          curveSmoothness: 0.3,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withOpacity(0.4),
          ),
        ),
      );
    }

    return LineChartData(
      minX: 0,
      maxX: (maxDataPoints - 1).toDouble(),
      minY: 0,
      maxY: maxY,
      gridData: FlGridData(
        show: widget.showGrid,
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
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: widget.xLabels != null,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (widget.xLabels == null ||
                  index < 0 ||
                  index >= widget.xLabels!.length) {
                return const SizedBox.shrink();
              }
              // Show every nth label
              final step = (widget.xLabels!.length / 6).ceil();
              if (index % step != 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.xLabels![index],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
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
              if (value == meta.max) {
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
      lineBarsData: lineBarsData,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final seriesIndex =
                  widget.series.length - 1 - touchedSpots.indexOf(spot);
              if (seriesIndex < 0 || seriesIndex >= widget.series.length) {
                return null;
              }
              final series = widget.series[seriesIndex];
              final color = series.color ??
                  ChartColors.getColorForIndex(seriesIndex,
                      palette: ChartColors.stackedAreaPalette,);
              return LineTooltipItem(
                '${series.name}: ${spot.y.toInt()}',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: widget.series.asMap().entries.map((entry) {
        final index = entry.key;
        final series = entry.value;
        final color = series.color ??
            ChartColors.getColorForIndex(index,
                palette: ChartColors.stackedAreaPalette,);

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
              series.name,
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}
