import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../utils/chart_colors.dart';

/// Heatmap chart widget for displaying activity distribution
/// Enhanced with hover effects, animations and improved visual styling
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

  /// Today's position (weekIndex, dayIndex) for highlighting
  final (int, int)? todayPosition;

  const HeatmapChart({
    super.key,
    required this.data,
    this.cellSize = 14,
    this.cellSpacing = 3,
    this.showMonthLabels = true,
    this.showDayLabels = true,
    this.onCellTap,
    this.animationDuration = const Duration(milliseconds: 800),
    this.todayPosition,
  });

  @override
  State<HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<HeatmapChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _hoveredWeek;
  int? _hoveredDay;

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
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // Use abbreviated weekday names from l10n
    final dayLabels = [
      l10n.statistics_monday,
      l10n.statistics_tuesday,
      l10n.statistics_wednesday,
      l10n.statistics_thursday,
      l10n.statistics_friday,
      l10n.statistics_saturday,
      l10n.statistics_sunday,
    ];

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heatmap grid with day labels on left
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day labels (vertical, on left side)
                if (widget.showDayLabels)
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: List.generate(7, (dayIndex) {
                        return SizedBox(
                          height: widget.cellSize + widget.cellSpacing,
                          child: Center(
                            child: Text(
                              dayLabels[dayIndex],
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.8),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        );
                      }),
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
                            final isHovered = _hoveredWeek == weekIndex &&
                                _hoveredDay == dayIndex;
                            final isToday = widget.todayPosition != null &&
                                widget.todayPosition!.$1 == weekIndex &&
                                widget.todayPosition!.$2 == dayIndex;

                            return MouseRegion(
                              onEnter: (_) => setState(() {
                                _hoveredWeek = weekIndex;
                                _hoveredDay = dayIndex;
                              }),
                              onExit: (_) => setState(() {
                                _hoveredWeek = null;
                                _hoveredDay = null;
                              }),
                              cursor: widget.onCellTap != null
                                  ? SystemMouseCursors.click
                                  : MouseCursor.defer,
                              child: GestureDetector(
                                onTap: widget.onCellTap != null
                                    ? () => widget.onCellTap!(
                                          weekIndex,
                                          dayIndex,
                                          value,
                                        )
                                    : null,
                                child: Tooltip(
                                  message: value > 0
                                      ? l10n.statistics_heatmapActivities(
                                          (value * 100).toInt(),
                                        )
                                      : l10n.statistics_heatmapNoActivity,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  textStyle: theme.textTheme.bodySmall,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: widget.cellSize,
                                    height: widget.cellSize,
                                    margin:
                                        EdgeInsets.all(widget.cellSpacing / 2),
                                    decoration: BoxDecoration(
                                      color: value > 0
                                          ? ChartColors.getHeatmapColor(
                                              animatedValue,
                                            )
                                          : colorScheme.surfaceContainerHighest
                                              .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(
                                        isHovered || isToday ? 4 : 3,
                                      ),
                                      border: Border.all(
                                        color: isToday
                                            ? colorScheme.primary
                                            : isHovered
                                                ? colorScheme.primary
                                                    .withOpacity(0.6)
                                                : colorScheme.outlineVariant
                                                    .withOpacity(0.3),
                                        width: isToday
                                            ? 2
                                            : (isHovered ? 1.5 : 0.5),
                                      ),
                                      boxShadow: isHovered && value > 0
                                          ? [
                                              BoxShadow(
                                                color:
                                                    ChartColors.getHeatmapColor(
                                                  value,
                                                ).withOpacity(0.4),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    transform: isHovered
                                        ? Matrix4.identity()
                                            .scaled(1.15, 1.15, 1.0)
                                        : null,
                                    transformAlignment: Alignment.center,
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
            const SizedBox(height: 16),
            _buildLegend(theme, colorScheme, l10n),
          ],
        );
      },
    );
  }

  Widget _buildLegend(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          l10n.statistics_heatmapLess,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(5, (index) {
          final value = index / 4;
          return Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: index == 0
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : ChartColors.getHeatmapColor(value),
              borderRadius: BorderRadius.circular(3),
              boxShadow: index > 0
                  ? [
                      BoxShadow(
                        color:
                            ChartColors.getHeatmapColor(value).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          l10n.statistics_heatmapMore,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

/// Generate heatmap data from date-count map
/// 从日期-计数映射生成热力图数据
/// Returns a record containing the data and today's position
({
  List<List<double>> data,
  (int, int)? todayPosition,
}) generateHeatmapData(
  Map<DateTime, int> dateCounts, {
  int weeks = 52,
  DateTime? endDate,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  endDate ??= now;
  final startDate = endDate.subtract(Duration(days: weeks * 7));

  // Find max count for normalization
  final maxCount = dateCounts.values.isEmpty
      ? 1
      : dateCounts.values.reduce((a, b) => a > b ? a : b);

  final data = <List<double>>[];
  var currentDate = startDate;
  (int, int)? todayPosition;

  for (int week = 0; week < weeks; week++) {
    final weekData = <double>[];
    for (int day = 0; day < 7; day++) {
      final dateKey =
          DateTime(currentDate.year, currentDate.month, currentDate.day);
      final count = dateCounts[dateKey] ?? 0;
      weekData.add(count / maxCount);

      // Check if this is today
      if (dateKey.year == today.year &&
          dateKey.month == today.month &&
          dateKey.day == today.day) {
        todayPosition = (week, day);
      }

      currentDate = currentDate.add(const Duration(days: 1));
    }
    data.add(weekData);
  }

  return (data: data, todayPosition: todayPosition);
}
