import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Parameter distribution bar data
class ParameterBarItem {
  final String label;
  final int count;
  final double percentage;
  final Color? color;

  const ParameterBarItem({
    required this.label,
    required this.count,
    required this.percentage,
    this.color,
  });
}

/// Parameter distribution bar chart widget
class ParameterDistributionBar extends StatefulWidget {
  final String title;
  final List<ParameterBarItem> items;
  final double height;
  final bool horizontal;
  final ValueChanged<ParameterBarItem>? onItemTap;

  const ParameterDistributionBar({
    super.key,
    required this.title,
    required this.items,
    this.height = 200,
    this.horizontal = false,
    this.onItemTap,
  });

  @override
  State<ParameterDistributionBar> createState() =>
      _ParameterDistributionBarState();
}

class _ParameterDistributionBarState extends State<ParameterDistributionBar> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('No data')),
      );
    }

    final maxValue = widget.items
        .map((e) => e.count.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.height,
          child: widget.horizontal
              ? _buildHorizontalBars(maxValue, colorScheme, theme)
              : _buildVerticalBars(maxValue, colorScheme, theme),
        ),
      ],
    );
  }

  Widget _buildVerticalBars(
    double maxValue,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = widget.items[group.x.toInt()];
              return BarTooltipItem(
                '${item.label}\n${item.count} (${item.percentage.toStringAsFixed(1)}%)',
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= widget.items.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    widget.items[index].label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _touchedIndex == index
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        barGroups: widget.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isTouched = _touchedIndex == index;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item.count.toDouble(),
                color: item.color ??
                    (isTouched
                        ? colorScheme.primary
                        : colorScheme.primary.withOpacity(0.7)),
                width: 24,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxValue * 1.2,
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHorizontalBars(
    double maxValue,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return _HorizontalBarRow(
          item: item,
          maxValue: maxValue,
          color: item.color ?? colorScheme.primary,
          onTap:
              widget.onItemTap != null ? () => widget.onItemTap!(item) : null,
        );
      },
    );
  }
}

class _HorizontalBarRow extends StatelessWidget {
  final ParameterBarItem item;
  final double maxValue;
  final Color color;
  final VoidCallback? onTap;

  const _HorizontalBarRow({
    required this.item,
    required this.maxValue,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                item.label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (item.count / maxValue).clamp(0.0, 1.0),
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: Text(
                '${item.count}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
