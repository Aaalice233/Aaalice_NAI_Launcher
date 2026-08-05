import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = widget.primaryColor ?? colorScheme.primary;

    if (widget.weekdayData.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text(context.l10n.statistics_noData)),
      );
    }

    final maxValue = widget.weekdayData.values.isEmpty
        ? 1.0
        : widget.weekdayData.values.reduce((a, b) => a > b ? a : b).toDouble();

    final dayLabels = widget.dayLabels ?? _localizedWeekdays(context);

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
                            ? colorScheme.error.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isTouched
                            ? FontWeight.bold
                            : FontWeight.normal,
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
            checkToShowHorizontalLine: (value) => true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
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
                      ? colorScheme.error.withValues(alpha: 0.6)
                      : color.withValues(alpha: 0.6),
                  width: 28,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValue * 1.2,
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  List<String> _localizedWeekdays(BuildContext context) => [
    context.l10n.statistics_monday,
    context.l10n.statistics_tuesday,
    context.l10n.statistics_wednesday,
    context.l10n.statistics_thursday,
    context.l10n.statistics_friday,
    context.l10n.statistics_saturday,
    context.l10n.statistics_sunday,
  ];
}

/// Weekday summary widget showing most/least active days
/// Enhanced with gradient backgrounds and improved visual hierarchy
class WeekdaySummary extends StatelessWidget {
  final Map<int, int> weekdayData;

  const WeekdaySummary({super.key, required this.weekdayData});

  @override
  Widget build(BuildContext context) {
    if (weekdayData.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = weekdayData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final mostActive = sorted.first;
    final leastActive = sorted.last;
    final dayNames = {
      1: context.l10n.statistics_monday,
      2: context.l10n.statistics_tuesday,
      3: context.l10n.statistics_wednesday,
      4: context.l10n.statistics_thursday,
      5: context.l10n.statistics_friday,
      6: context.l10n.statistics_saturday,
      7: context.l10n.statistics_sunday,
    };

    return Row(
      children: [
        Expanded(
          child: _DaySummaryCard(
            label: context.l10n.statistics_mostActiveDay,
            dayName: dayNames[mostActive.key] ?? '',
            count: mostActive.value,
            color: const Color(0xFF10B981), // Emerald green
            secondaryColor: const Color(0xFF34D399),
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DaySummaryCard(
            label: context.l10n.statistics_leastActiveDay,
            dayName: dayNames[leastActive.key] ?? '',
            count: leastActive.value,
            color: const Color(0xFFF59E0B), // Amber
            secondaryColor: const Color(0xFFFBBF24),
            icon: Icons.trending_down_rounded,
          ),
        ),
      ],
    );
  }
}

class _DaySummaryCard extends StatefulWidget {
  final String label;
  final String dayName;
  final int count;
  final Color color;
  final Color secondaryColor;
  final IconData icon;

  const _DaySummaryCard({
    required this.label,
    required this.dayName,
    required this.count,
    required this.color,
    required this.secondaryColor,
    required this.icon,
  });

  @override
  State<_DaySummaryCard> createState() => _DaySummaryCardState();
}

class _DaySummaryCardState extends State<_DaySummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color.withValues(alpha: isDark ? 0.2 : 0.12),
              widget.secondaryColor.withValues(alpha: isDark ? 0.1 : 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.color.withValues(alpha: _isHovered ? 0.4 : 0.2),
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.dayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.count}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
