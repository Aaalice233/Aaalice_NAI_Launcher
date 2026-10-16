import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

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
  final List<ParameterBarItem> items;

  /// Vertical chart height; horizontal bars size to their rows.
  final double height;
  final bool horizontal;
  final ValueChanged<ParameterBarItem>? onItemTap;

  const ParameterDistributionBar({
    super.key,
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
        child: Center(child: Text(context.l10n.statistics_noData)),
      );
    }

    final maxValue = widget.items
        .map((e) => e.count.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return widget.horizontal
        ? _buildHorizontalBars(maxValue, colorScheme)
        : SizedBox(
            height: widget.height,
            child: _buildVerticalBars(maxValue, colorScheme, theme),
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
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
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
                color:
                    item.color ??
                    (isTouched
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.7)),
                width: 24,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxValue * 1.2,
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHorizontalBars(double maxValue, ColorScheme colorScheme) {
    final onItemTap = widget.onItemTap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in widget.items.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _HorizontalBarRow(
            item: item,
            maxValue: maxValue,
            color: item.color ?? colorScheme.primary,
            onTap: onItemTap == null ? null : () => onItemTap(item),
          ),
        ],
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The count drops below the label when both do not fit; labels
            // wrap instead of being truncated.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(item.label, style: theme.textTheme.bodySmall),
                  Text(
                    '${item.count}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: maxValue > 0
                      ? (item.count / maxValue).clamp(0.0, 1.0)
                      : 0,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
