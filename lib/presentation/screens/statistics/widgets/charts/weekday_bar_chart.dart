import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Weekday bar chart for showing activity distribution across days
class WeekdayBarChart extends StatefulWidget {
  final Map<int, int> weekdayData; // 1=Monday to 7=Sunday -> count
  final double height;
  final Color? primaryColor;
  final List<String>? dayLabels;

  const WeekdayBarChart({
    super.key,
    required this.weekdayData,
    this.height = 180,
    this.primaryColor,
    this.dayLabels,
  });

  @override
  State<WeekdayBarChart> createState() => _WeekdayBarChartState();
}

class _WeekdayBarChartState extends State<WeekdayBarChart> {
  int? _touchedIndex;

  static const _defaultDayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _defaultDayLabelsCN = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = widget.primaryColor ?? colorScheme.primary;

    if (widget.weekdayData.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('No data')),
      );
    }

    final maxValue = widget.weekdayData.values.isEmpty
        ? 1.0
        : widget.weekdayData.values.reduce((a, b) => a > b ? a : b).toDouble();

    // Detect locale for labels
    final locale = Localizations.localeOf(context).languageCode;
    final dayLabels = widget.dayLabels ??
        (locale == 'zh' ? _defaultDayLabelsCN : _defaultDayLabels);

    return SizedBox(
      height: widget.height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dayIndex = group.x.toInt();
                final count = widget.weekdayData[dayIndex + 1] ?? 0;
                return BarTooltipItem(
                  '${dayLabels[dayIndex]}\n$count',
                  theme.textTheme.bodySmall!,
                );
              },
            ),
            touchCallback: (event, response) {
              setState(() {
                if (response?.spot != null &&
                    event is! FlPointerExitEvent &&
                    event is! FlLongPressEnd) {
                  _touchedIndex = response!.spot!.touchedBarGroupIndex;
                } else {
                  _touchedIndex = null;
                }
              });
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= 7) {
                    return const SizedBox.shrink();
                  }
                  final isTouched = _touchedIndex == index;
                  final isWeekend = index >= 5;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dayLabels[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isTouched
                            ? color
                            : isWeekend
                                ? colorScheme.error.withOpacity(0.7)
                                : colorScheme.onSurfaceVariant,
                        fontWeight:
                            isTouched ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (index) {
            final dayNum = index + 1;
            final count = widget.weekdayData[dayNum] ?? 0;
            final isTouched = _touchedIndex == index;
            final isWeekend = index >= 5;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: count.toDouble(),
                  color: isTouched
                      ? color
                      : isWeekend
                          ? colorScheme.error.withOpacity(0.6)
                          : color.withOpacity(0.6),
                  width: 28,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValue * 1.2,
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Weekday summary widget showing most/least active days
class WeekdaySummary extends StatelessWidget {
  final Map<int, int> weekdayData;

  const WeekdaySummary({
    super.key,
    required this.weekdayData,
  });

  static const _dayNames = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  static const _dayNamesCN = {
    1: '周一',
    2: '周二',
    3: '周三',
    4: '周四',
    5: '周五',
    6: '周六',
    7: '周日',
  };

  @override
  Widget build(BuildContext context) {
    if (weekdayData.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = weekdayData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mostActive = sorted.first;
    final leastActive = sorted.last;
    final locale = Localizations.localeOf(context).languageCode;
    final dayNames = locale == 'zh' ? _dayNamesCN : _dayNames;

    return Row(
      children: [
        Expanded(
          child: _DaySummaryCard(
            label: locale == 'zh' ? '最活跃' : 'Most Active',
            dayName: dayNames[mostActive.key] ?? '',
            count: mostActive.value,
            color: Colors.green,
            icon: Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DaySummaryCard(
            label: locale == 'zh' ? '最不活跃' : 'Least Active',
            dayName: dayNames[leastActive.key] ?? '',
            count: leastActive.value,
            color: Colors.orange,
            icon: Icons.trending_down,
          ),
        ),
      ],
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  final String label;
  final String dayName;
  final int count;
  final Color color;
  final IconData icon;

  const _DaySummaryCard({
    required this.label,
    required this.dayName,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  dayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
