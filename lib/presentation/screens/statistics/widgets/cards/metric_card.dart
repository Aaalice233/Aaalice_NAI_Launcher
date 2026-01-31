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
  final bool compact; // 单行紧凑布局

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.trend,
    this.sparklineData,
    this.onTap,
    this.compact = false,
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
    final shadowIntensity = extension?.shadowIntensity ?? 0.08;
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          // 深度层叠风格：使用主题中明确定义的最亮容器色
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          // 多层阴影替代边框
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                _isHovered ? shadowIntensity * 1.5 : shadowIntensity,
              ),
              blurRadius: _isHovered ? 16 : 12,
              offset: Offset(0, _isHovered ? 6 : 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(shadowIntensity * 0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            splashColor: effectiveIconColor.withOpacity(0.08),
            highlightColor: effectiveIconColor.withOpacity(0.04),
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 14 : 18),
              child: widget.compact
                  ? _buildCompactLayout(
                      theme,
                      colorScheme,
                      effectiveIconColor,
                      isDark,
                    )
                  : _buildDefaultLayout(
                      theme,
                      colorScheme,
                      effectiveIconColor,
                      isDark,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// 紧凑单行布局
  Widget _buildCompactLayout(
    ThemeData theme,
    ColorScheme colorScheme,
    Color effectiveIconColor,
    bool isDark,
  ) {
    return Row(
      children: [
        // Icon container
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: effectiveIconColor.withOpacity(isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: effectiveIconColor,
          ),
        ),
        const SizedBox(width: 12),
        // Label
        Text(
          widget.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        // Value
        Text(
          widget.value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        if (widget.trend != null) ...[
          const SizedBox(width: 10),
          TrendIndicator(data: widget.trend!),
        ],
      ],
    );
  }

  /// 默认两行布局
  Widget _buildDefaultLayout(
    ThemeData theme,
    ColorScheme colorScheme,
    Color effectiveIconColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: icon + label
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: effectiveIconColor.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(6),
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
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.trend != null) TrendIndicator(data: widget.trend!),
          ],
        ),
        // Sparkline
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
        borderRadius: BorderRadius.circular(6),
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
