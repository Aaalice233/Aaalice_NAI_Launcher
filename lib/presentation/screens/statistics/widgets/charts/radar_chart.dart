import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Radar chart data point
class RadarDataPoint {
  final String label;
  final double value; // 0.0 to 1.0
  final double? maxValue;

  const RadarDataPoint({
    required this.label,
    required this.value,
    this.maxValue,
  });
}

/// Custom Radar chart widget for multi-dimensional data comparison
/// 自定义雷达图组件，用于多维度数据对比
class CustomRadarChart extends StatefulWidget {
  final List<RadarDataPoint> data;
  final Color? fillColor;
  final Color? strokeColor;
  final double strokeWidth;
  final bool showLabels;
  final bool showValues;
  final bool showGrid;
  final int gridLevels;
  final Duration animationDuration;
  final void Function(int index, RadarDataPoint point)? onPointTap;

  const CustomRadarChart({
    super.key,
    required this.data,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 2,
    this.showLabels = true,
    this.showValues = false,
    this.showGrid = true,
    this.gridLevels = 5,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.onPointTap,
  });

  @override
  State<CustomRadarChart> createState() => _CustomRadarChartState();
}

class _CustomRadarChartState extends State<CustomRadarChart>
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
    final fillColor =
        widget.fillColor ?? theme.colorScheme.primary.withOpacity(0.3);
    final strokeColor = widget.strokeColor ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, constraints.maxHeight);
            final center = Offset(size / 2, size / 2);
            final radius = size / 2 - 40; // Leave space for labels

            return SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _RadarChartPainter(
                  data: widget.data,
                  center: center,
                  radius: radius,
                  fillColor: fillColor,
                  strokeColor: strokeColor,
                  strokeWidth: widget.strokeWidth,
                  showGrid: widget.showGrid,
                  gridLevels: widget.gridLevels,
                  gridColor: theme.dividerColor,
                  animationValue: _animation.value,
                ),
                child: widget.showLabels
                    ? Stack(
                        children: _buildLabels(theme, center, radius + 25),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildLabels(
      ThemeData theme, Offset center, double labelRadius,) {
    final labels = <Widget>[];
    final count = widget.data.length;

    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      labels.add(
        Positioned(
          left: x - 40,
          top: y - 10,
          child: SizedBox(
            width: 80,
            child: Text(
              widget.data[i].label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return labels;
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<RadarDataPoint> data;
  final Offset center;
  final double radius;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool showGrid;
  final int gridLevels;
  final Color gridColor;
  final double animationValue;

  _RadarChartPainter({
    required this.data,
    required this.center,
    required this.radius,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.showGrid,
    required this.gridLevels,
    required this.gridColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = data.length;
    if (count < 3) return;

    // Draw grid
    if (showGrid) {
      _drawGrid(canvas, count);
    }

    // Draw data polygon
    _drawDataPolygon(canvas, count);
  }

  void _drawGrid(Canvas canvas, int count) {
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = gridColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw concentric polygons
    for (int level = 1; level <= gridLevels; level++) {
      final levelRadius = radius * level / gridLevels;
      final path = Path();

      for (int i = 0; i <= count; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / count);
        final x = center.dx + levelRadius * math.cos(angle);
        final y = center.dy + levelRadius * math.sin(angle);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axes
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }
  }

  void _drawDataPolygon(Canvas canvas, int count) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i <= count; i++) {
      final index = i % count;
      final value = data[index].value.clamp(0.0, 1.0) * animationValue;
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final pointRadius = radius * value;
      final x = center.dx + pointRadius * math.cos(angle);
      final y = center.dy + pointRadius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      if (i < count) {
        points.add(Offset(x, y));
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw data points
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.data != data;
  }
}
