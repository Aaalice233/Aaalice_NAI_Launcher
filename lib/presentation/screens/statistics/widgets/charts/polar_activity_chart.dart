import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Polar activity chart for 24-hour distribution
class PolarActivityChart extends StatelessWidget {
  final Map<int, int> hourlyData; // hour (0-23) -> count
  final double size;
  final Color? primaryColor;
  final bool showLabels;

  const PolarActivityChart({
    super.key,
    required this.hourlyData,
    this.size = 200,
    this.primaryColor,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = primaryColor ?? colorScheme.primary;

    if (hourlyData.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: Text('No activity data')),
      );
    }

    final maxValue = hourlyData.values.isEmpty
        ? 1.0
        : hourlyData.values.reduce((a, b) => a > b ? a : b).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PolarChartPainter(
          data: hourlyData,
          maxValue: maxValue,
          color: color,
          backgroundColor: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurfaceVariant,
          showLabels: showLabels,
        ),
      ),
    );
  }
}

class _PolarChartPainter extends CustomPainter {
  final Map<int, int> data;
  final double maxValue;
  final Color color;
  final Color backgroundColor;
  final Color textColor;
  final bool showLabels;

  _PolarChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
    required this.backgroundColor,
    required this.textColor,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    // Draw background circles
    final bgPaint = Paint()
      ..color = backgroundColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, bgPaint);
    }

    // Draw radial lines for hours
    final linePaint = Paint()
      ..color = backgroundColor.withOpacity(0.3)
      ..strokeWidth = 1;

    for (var hour = 0; hour < 24; hour++) {
      final angle = (hour * 15 - 90) * math.pi / 180;
      final startPoint = center;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(startPoint, endPoint, linePaint);
    }

    // Draw data segments
    final dataPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    var firstPoint = true;

    for (var hour = 0; hour < 24; hour++) {
      final value = data[hour] ?? 0;
      final normalizedValue = maxValue > 0 ? value / maxValue : 0.0;
      final barRadius = radius * normalizedValue.clamp(0.05, 1.0);
      final angle = (hour * 15 - 90) * math.pi / 180;
      final point = Offset(
        center.dx + barRadius * math.cos(angle),
        center.dy + barRadius * math.sin(angle),
      );

      if (firstPoint) {
        path.moveTo(point.dx, point.dy);
        firstPoint = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, dataPaint);

    // Draw stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, strokePaint);

    // Draw hour labels
    if (showLabels) {
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      for (var hour = 0; hour < 24; hour += 3) {
        final angle = (hour * 15 - 90) * math.pi / 180;
        final labelRadius = radius + 15;
        final point = Offset(
          center.dx + labelRadius * math.cos(angle),
          center.dy + labelRadius * math.sin(angle),
        );

        textPainter.text = TextSpan(
          text: hour.toString().padLeft(2, '0'),
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            point.dx - textPainter.width / 2,
            point.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PolarChartPainter oldDelegate) {
    return data != oldDelegate.data ||
        maxValue != oldDelegate.maxValue ||
        color != oldDelegate.color;
  }
}

/// Peak time indicator widget
class PeakTimeIndicator extends StatelessWidget {
  final int peakHour;
  final int count;
  final String? label;

  const PeakTimeIndicator({
    super.key,
    required this.peakHour,
    required this.count,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String timeLabel;
    IconData timeIcon;
    Color timeColor;

    if (peakHour >= 6 && peakHour < 12) {
      timeLabel = 'Morning';
      timeIcon = Icons.wb_sunny;
      timeColor = Colors.orange;
    } else if (peakHour >= 12 && peakHour < 18) {
      timeLabel = 'Afternoon';
      timeIcon = Icons.wb_sunny_outlined;
      timeColor = Colors.amber;
    } else if (peakHour >= 18 && peakHour < 22) {
      timeLabel = 'Evening';
      timeIcon = Icons.nights_stay_outlined;
      timeColor = Colors.deepPurple;
    } else {
      timeLabel = 'Night';
      timeIcon = Icons.nights_stay;
      timeColor = Colors.indigo;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: timeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: timeColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(timeIcon, color: timeColor, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label ?? 'Peak Activity',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${peakHour.toString().padLeft(2, '0')}:00 - $timeLabel',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: timeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
