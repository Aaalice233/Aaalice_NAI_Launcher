import 'package:flutter/material.dart';
import '../../utils/chart_colors.dart';

/// Funnel chart data item
class FunnelDataItem {
  final String label;
  final double value;
  final Color? color;

  const FunnelDataItem({
    required this.label,
    required this.value,
    this.color,
  });
}

/// Funnel chart widget for showing conversion flow
/// 漏斗图组件，用于展示转化流程
class FunnelChart extends StatefulWidget {
  final List<FunnelDataItem> data;
  final double height;
  final bool showLabels;
  final bool showValues;
  final bool showPercentages;
  final Duration animationDuration;
  final void Function(int index, FunnelDataItem item)? onItemTap;

  const FunnelChart({
    super.key,
    required this.data,
    this.height = 300,
    this.showLabels = true,
    this.showValues = true,
    this.showPercentages = true,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.onItemTap,
  });

  @override
  State<FunnelChart> createState() => _FunnelChartState();
}

class _FunnelChartState extends State<FunnelChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _hoveredIndex;

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

    if (widget.data.isEmpty) {
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
        return SizedBox(
          height: widget.height,
          child: Row(
            children: [
              // Funnel visualization
              Expanded(
                flex: 3,
                child: CustomPaint(
                  painter: _FunnelChartPainter(
                    data: widget.data,
                    animationValue: _animation.value,
                    hoveredIndex: _hoveredIndex,
                    theme: theme,
                  ),
                  child: GestureDetector(
                    onTapUp: (details) => _handleTap(details, context),
                  ),
                ),
              ),
              // Labels and values
              if (widget.showLabels || widget.showValues)
                Expanded(
                  flex: 2,
                  child: _buildLabels(theme),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabels(ThemeData theme) {
    final maxValue = widget.data.first.value;
    final segmentHeight = widget.height / widget.data.length;

    return Column(
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final color = item.color ?? ChartColors.getColorForIndex(index);
        final percentage = maxValue > 0 ? (item.value / maxValue * 100) : 0.0;
        final isHovered = _hoveredIndex == index;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: GestureDetector(
            onTap: widget.onItemTap != null
                ? () => widget.onItemTap!(index, item)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: segmentHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isHovered
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.showLabels)
                          Text(
                            item.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isHovered
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (widget.showValues || widget.showPercentages)
                          Row(
                            children: [
                              if (widget.showValues)
                                Text(
                                  item.value.toInt().toString(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              if (widget.showValues && widget.showPercentages)
                                const SizedBox(width: 4),
                              if (widget.showPercentages)
                                Text(
                                  '(${percentage.toStringAsFixed(1)}%)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context) {
    if (widget.onItemTap == null) return;

    final box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final segmentHeight = widget.height / widget.data.length;
    final index = (localPosition.dy / segmentHeight).floor();

    if (index >= 0 && index < widget.data.length) {
      widget.onItemTap!(index, widget.data[index]);
    }
  }
}

class _FunnelChartPainter extends CustomPainter {
  final List<FunnelDataItem> data;
  final double animationValue;
  final int? hoveredIndex;
  final ThemeData theme;

  _FunnelChartPainter({
    required this.data,
    required this.animationValue,
    required this.hoveredIndex,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.first.value;
    final segmentHeight = size.height / data.length;
    final centerX = size.width / 2;
    final maxWidth = size.width * 0.9;
    final minWidth = size.width * 0.3;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final color = item.color ?? ChartColors.getColorForIndex(i);

      // Calculate widths with animation
      final topWidth = (i == 0
              ? maxWidth
              : _getWidthForIndex(i - 1, maxValue, maxWidth, minWidth)) *
          animationValue;
      final bottomWidth =
          _getWidthForIndex(i, maxValue, maxWidth, minWidth) * animationValue;

      final y = segmentHeight * i;
      final isHovered = hoveredIndex == i;

      // Draw trapezoid
      final path = Path()
        ..moveTo(centerX - topWidth / 2, y)
        ..lineTo(centerX + topWidth / 2, y)
        ..lineTo(centerX + bottomWidth / 2, y + segmentHeight - 2)
        ..lineTo(centerX - bottomWidth / 2, y + segmentHeight - 2)
        ..close();

      final paint = Paint()
        ..color = isHovered ? color : color.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      // Draw border for hovered item
      if (isHovered) {
        final borderPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  double _getWidthForIndex(
    int index,
    double maxValue,
    double maxWidth,
    double minWidth,
  ) {
    if (index < 0 || index >= data.length) return maxWidth;
    final ratio = maxValue > 0 ? data[index].value / maxValue : 0.0;
    return minWidth + (maxWidth - minWidth) * ratio;
  }

  @override
  bool shouldRepaint(covariant _FunnelChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.data != data;
  }
}
