import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../themes/theme_extension.dart';

/// Metric card with value, trend indicator and optional sparkline
class MetricCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final TrendData? trend;
  final List<double>? sparklineData;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.trend,
    this.sparklineData,
    this.onTap,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final effectiveIconColor = widget.iconColor ?? colorScheme.primary;
    final shadowIntensity = extension?.shadowIntensity ?? 0.12;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _isHovered
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? colorScheme.primary.withOpacity(0.3)
                : colorScheme.outlineVariant.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                _isHovered ? shadowIntensity * 1.5 : shadowIntensity,
              ),
              blurRadius: _isHovered ? 16 : 8,
              offset: Offset(0, _isHovered ? 4 : 2),
              spreadRadius: _isHovered ? -2 : -4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: icon + label
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: effectiveIconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: effectiveIconColor.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.icon,
                          size: 18,
                          color: effectiveIconColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Value row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          widget.value,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.trend != null)
                        TrendIndicator(data: widget.trend!),
                    ],
                  ),
                  // Sparkline
                  if (widget.sparklineData != null &&
                      widget.sparklineData!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 32,
                      child: MiniSparkline(
                        data: widget.sparklineData!,
                        color: effectiveIconColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Trend data model
class TrendData {
  final double value;
  final String? label;
  final bool isPercentage;

  const TrendData({
    required this.value,
    this.label,
    this.isPercentage = true,
  });

  bool get isPositive => value > 0;
  bool get isNegative => value < 0;
  bool get isNeutral => value == 0;
}

/// Trend indicator widget showing up/down/neutral trend
class TrendIndicator extends StatelessWidget {
  final TrendData data;
  final double iconSize;
  final TextStyle? textStyle;

  const TrendIndicator({
    super.key,
    required this.data,
    this.iconSize = 14,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = data.isPositive
        ? Colors.green
        : data.isNegative
            ? Colors.red
            : theme.colorScheme.onSurfaceVariant;

    final icon = data.isPositive
        ? Icons.trending_up
        : data.isNegative
            ? Icons.trending_down
            : Icons.trending_flat;

    final displayValue = data.isPercentage
        ? '${data.value.abs().toStringAsFixed(1)}%'
        : data.value.abs().toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            displayValue,
            style: textStyle ??
                theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (data.label != null) ...[
            const SizedBox(width: 2),
            Text(
              data.label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini sparkline chart for metric cards
class MiniSparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double strokeWidth;
  final bool showDots;
  final bool showArea;

  const MiniSparkline({
    super.key,
    required this.data,
    required this.color,
    this.strokeWidth = 2,
    this.showDots = false,
    this.showArea = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        minY: data.reduce((a, b) => a < b ? a : b) * 0.9,
        maxY: data.reduce((a, b) => a > b ? a : b) * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: strokeWidth,
            isStrokeCapRound: true,
            dotData: FlDotData(show: showDots),
            belowBarData: showArea
                ? BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.0),
                      ],
                    ),
                  )
                : BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
