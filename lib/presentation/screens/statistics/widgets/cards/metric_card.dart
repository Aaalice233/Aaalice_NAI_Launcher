import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../themes/theme_extension.dart';

/// Metric card with value, trend indicator and optional sparkline
/// Enhanced with gradient backgrounds, glow effects, and smooth animations
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

class _MetricCardState extends State<MetricCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final effectiveIconColor = widget.iconColor ?? colorScheme.primary;
    final shadowIntensity = extension?.shadowIntensity ?? 0.12;
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final glowValue = _glowAnimation.value * 0.3 + 0.7;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isHovered
                    ? [
                        colorScheme.surfaceContainerHigh,
                        colorScheme.surfaceContainerHighest.withOpacity(0.8),
                      ]
                    : [
                        colorScheme.surfaceContainerLow,
                        colorScheme.surfaceContainer,
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? effectiveIconColor.withOpacity(0.4 * glowValue)
                    : colorScheme.outlineVariant.withOpacity(0.15),
                width: _isHovered ? 1.5 : 1,
              ),
              boxShadow: [
                // Base shadow
                BoxShadow(
                  color: Colors.black.withOpacity(
                    _isHovered ? shadowIntensity * 1.8 : shadowIntensity,
                  ),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: Offset(0, _isHovered ? 6 : 3),
                  spreadRadius: _isHovered ? -2 : -4,
                ),
                // Colored glow effect on hover
                if (_isHovered)
                  BoxShadow(
                    color: effectiveIconColor
                        .withOpacity(0.15 * glowValue * (isDark ? 1.5 : 1)),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                    spreadRadius: -4,
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                splashColor: effectiveIconColor.withOpacity(0.1),
                highlightColor: effectiveIconColor.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: icon + label
                      Row(
                        children: [
                          // Enhanced icon container with gradient and glow
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  effectiveIconColor.withOpacity(
                                    _isHovered ? 0.25 : 0.15,
                                  ),
                                  effectiveIconColor.withOpacity(
                                    _isHovered ? 0.15 : 0.08,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: effectiveIconColor.withOpacity(
                                    _isHovered ? 0.25 * glowValue : 0.12,
                                  ),
                                  blurRadius: _isHovered ? 12 : 8,
                                  offset: const Offset(0, 2),
                                  spreadRadius: _isHovered ? 0 : -2,
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.icon,
                              size: 20,
                              color: effectiveIconColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Value row with animated text
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _isHovered
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface
                                            .withOpacity(0.95),
                                    letterSpacing: -0.5,
                                  ) ??
                                  const TextStyle(),
                              child: Text(
                                widget.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (widget.trend != null)
                            TrendIndicator(data: widget.trend!),
                        ],
                      ),
                      // Sparkline with enhanced styling
                      if (widget.sparklineData != null &&
                          widget.sparklineData!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 36,
                          child: MiniSparkline(
                            data: widget.sparklineData!,
                            color: effectiveIconColor,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
/// Enhanced with gradient backgrounds and improved styling
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
    final isDark = theme.brightness == Brightness.dark;

    // Enhanced color selection with better contrast
    final Color primaryColor;
    final Color secondaryColor;
    final IconData icon;

    if (data.isPositive) {
      primaryColor = const Color(0xFF10B981); // Emerald green
      secondaryColor = const Color(0xFF34D399);
      icon = Icons.trending_up_rounded;
    } else if (data.isNegative) {
      primaryColor = const Color(0xFFEF4444); // Red
      secondaryColor = const Color(0xFFF87171);
      icon = Icons.trending_down_rounded;
    } else {
      primaryColor = theme.colorScheme.onSurfaceVariant;
      secondaryColor = theme.colorScheme.outline;
      icon = Icons.trending_flat_rounded;
    }

    final displayValue = data.isPercentage
        ? '${data.value.abs().toStringAsFixed(1)}%'
        : data.value.abs().toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(isDark ? 0.2 : 0.12),
            secondaryColor.withOpacity(isDark ? 0.1 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: primaryColor),
          const SizedBox(width: 5),
          Text(
            displayValue,
            style: textStyle ??
                theme.textTheme.labelSmall?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
          ),
          if (data.label != null) ...[
            const SizedBox(width: 3),
            Text(
              data.label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: primaryColor.withOpacity(0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini sparkline chart for metric cards
/// Enhanced with smooth gradients and refined styling
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
    this.strokeWidth = 2.5,
    this.showDots = false,
    this.showArea = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    // Calculate min/max with proper padding
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final padding = range > 0 ? range * 0.15 : 1;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        minY: minValue - padding,
        maxY: maxValue + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: color,
            barWidth: strokeWidth,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: showDots,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: showArea
                ? BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withOpacity(0.35),
                        color.withOpacity(0.08),
                        color.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  )
                : BarAreaData(show: false),
            shadow: Shadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ),
        ],
      ),
    );
  }
}
