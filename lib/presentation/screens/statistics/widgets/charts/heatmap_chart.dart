import 'package:flutter/material.dart';
import '../../utils/chart_colors.dart';

/// Heatmap chart widget for displaying activity distribution
/// 热力图组件，用于展示活动分布
class HeatmapChart extends StatefulWidget {
  /// Data matrix [week][dayOfWeek] with values 0.0 to 1.0
  final List<List<double>> data;

  /// Cell size
  final double cellSize;

  /// Cell spacing
  final double cellSpacing;

  /// Show month labels
  final bool showMonthLabels;

  /// Show day labels
  final bool showDayLabels;

  /// Callback when cell is tapped
  final void Function(int week, int day, double value)? onCellTap;

  /// Animation duration
  final Duration animationDuration;

  const HeatmapChart({
    super.key,
    required this.data,
    this.cellSize = 14,
    this.cellSpacing = 3,
    this.showMonthLabels = true,
    this.showDayLabels = true,
    this.onCellTap,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<HeatmapChart>
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
    final dayLabels = ['Mon', '', 'Wed', '', 'Fri', '', 'Sun'];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels row
            if (widget.showDayLabels)
              Padding(
                padding: EdgeInsets.only(
                  left: widget.showMonthLabels ? 30 : 0,
                  bottom: 4,
                ),
                child: Row(
                  children: List.generate(7, (dayIndex) {
                    return SizedBox(
                      width: widget.cellSize + widget.cellSpacing,
                      child: Text(
                        dayLabels[dayIndex],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }),
                ),
              ),
            // Heatmap grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month labels (vertical)
                if (widget.showMonthLabels)
                  SizedBox(
                    width: 30,
                    child: Column(
                      children: _buildMonthLabels(theme),
                    ),
                  ),
                // Grid
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(widget.data.length, (weekIndex) {
                        return Column(
                          children: List.generate(7, (dayIndex) {
                            final value =
                                dayIndex < widget.data[weekIndex].length
                                    ? widget.data[weekIndex][dayIndex]
                                    : 0.0;
                            final animatedValue = value * _animation.value;

                            return GestureDetector(
                              onTap: widget.onCellTap != null
                                  ? () => widget.onCellTap!(
                                      weekIndex, dayIndex, value,)
                                  : null,
                              child: Tooltip(
                                message: '${(value * 100).toInt()} activities',
                                child: Container(
                                  width: widget.cellSize,
                                  height: widget.cellSize,
                                  margin:
                                      EdgeInsets.all(widget.cellSpacing / 2),
                                  decoration: BoxDecoration(
                                    color: value > 0
                                        ? ChartColors.getHeatmapColor(
                                            animatedValue,)
                                        : theme.colorScheme
                                            .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
            // Legend
            const SizedBox(height: 12),
            _buildLegend(theme),
          ],
        );
      },
    );
  }

  List<Widget> _buildMonthLabels(ThemeData theme) {
    // Simplified month labels
    return [
      SizedBox(
        height: (widget.cellSize + widget.cellSpacing) * 7,
        child: Center(
          child: Text(
            'Week',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Less',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(5, (index) {
          final value = index / 4;
          return Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: index == 0
                  ? theme.colorScheme.surfaceContainerHighest
                  : ChartColors.getHeatmapColor(value),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          'More',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Generate heatmap data from date-count map
/// 从日期-计数映射生成热力图数据
List<List<double>> generateHeatmapData(
  Map<DateTime, int> dateCounts, {
  int weeks = 52,
  DateTime? endDate,
}) {
  endDate ??= DateTime.now();
  final startDate = endDate.subtract(Duration(days: weeks * 7));

  // Find max count for normalization
  final maxCount = dateCounts.values.isEmpty
      ? 1
      : dateCounts.values.reduce((a, b) => a > b ? a : b);

  final data = <List<double>>[];
  var currentDate = startDate;

  for (int week = 0; week < weeks; week++) {
    final weekData = <double>[];
    for (int day = 0; day < 7; day++) {
      final dateKey =
          DateTime(currentDate.year, currentDate.month, currentDate.day);
      final count = dateCounts[dateKey] ?? 0;
      weekData.add(count / maxCount);
      currentDate = currentDate.add(const Duration(days: 1));
    }
    data.add(weekData);
  }

  return data;
}
