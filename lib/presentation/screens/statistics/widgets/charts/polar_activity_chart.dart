import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Polar activity chart for 24-hour distribution
/// Enhanced with animations and improved visual effects
class PolarActivityChart extends StatefulWidget {
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
  State<PolarActivityChart> createState() => _PolarActivityChartState();
}

class _PolarActivityChartState extends State<PolarActivityChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
    final colorScheme = theme.colorScheme;
    final color = widget.primaryColor ?? colorScheme.primary;

    if (widget.hourlyData.isEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Text(
            'No activity data',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final maxValue = widget.hourlyData.values.isEmpty
        ? 1.0
        : widget.hourlyData.values.reduce((a, b) => a > b ? a : b).toDouble();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _PolarChartPainter(
              data: widget.hourlyData,
              maxValue: maxValue,
              color: color,
              backgroundColor: colorScheme.surfaceContainerHighest,
              textColor: colorScheme.onSurfaceVariant,
              showLabels: widget.showLabels,
              animationValue: _animation.value,
              isDark: theme.brightness == Brightness.dark,
            ),
          ),
        );
      },
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
  final double animationValue;
  final bool isDark;

  _PolarChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
    required this.backgroundColor,
    required this.textColor,
    required this.showLabels,
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 24;

    // Draw background circles with subtle gradient effect
    for (var i = 4; i >= 1; i--) {
      final bgPaint = Paint()
        ..color = backgroundColor.withOpacity(0.15 + (4 - i) * 0.05)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * i / 4, bgPaint);
    }

    // Draw concentric circle guides
    final guidePaint = Paint()
      ..color = backgroundColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, guidePaint);
    }

    // Draw radial lines for hours with gradient opacity
    for (var hour = 0; hour < 24; hour++) {
      final angle = (hour * 15 - 90) * math.pi / 180;
      final isMainHour = hour % 3 == 0;
      final linePaint = Paint()
        ..color = backgroundColor.withOpacity(isMainHour ? 0.5 : 0.2)
        ..strokeWidth = isMainHour ? 1.5 : 0.5;

      final startPoint = center;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(startPoint, endPoint, linePaint);
    }

    // Draw data polygon with animation
    final path = Path();
    var firstPoint = true;

    for (var hour = 0; hour < 24; hour++) {
      final value = data[hour] ?? 0;
      final normalizedValue = maxValue > 0 ? value / maxValue : 0.0;
      final barRadius =
          radius * normalizedValue.clamp(0.05, 1.0) * animationValue;
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

    // Draw filled area with gradient
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(isDark ? 0.6 : 0.5),
          color.withOpacity(isDark ? 0.3 : 0.2),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, gradientPaint);

    // Draw stroke with glow effect
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Draw subtle glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    // Draw hour labels
    if (showLabels) {
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      for (var hour = 0; hour < 24; hour += 3) {
        final angle = (hour * 15 - 90) * math.pi / 180;
        final labelRadius = radius + 18;
        final point = Offset(
          center.dx + labelRadius * math.cos(angle),
          center.dy + labelRadius * math.sin(angle),
        );

        textPainter.text = TextSpan(
          text: hour.toString().padLeft(2, '0'),
          style: TextStyle(
            color: textColor.withOpacity(animationValue),
            fontSize: 11,
            fontWeight: FontWeight.w600,
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
        color != oldDelegate.color ||
        animationValue != oldDelegate.animationValue;
  }
}

/// Peak time indicator widget
/// Enhanced with animations and improved visual styling
class PeakTimeIndicator extends StatefulWidget {
  final int peakHour;
  final int count;
  final String? label;
  final String? morningLabel;
  final String? afternoonLabel;
  final String? eveningLabel;
  final String? nightLabel;

  const PeakTimeIndicator({
    super.key,
    required this.peakHour,
    required this.count,
    this.label,
    this.morningLabel,
    this.afternoonLabel,
    this.eveningLabel,
    this.nightLabel,
  });

  @override
  State<PeakTimeIndicator> createState() => _PeakTimeIndicatorState();
}

class _PeakTimeIndicatorState extends State<PeakTimeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    String timeLabel;
    IconData timeIcon;
    Color primaryColor;
    Color secondaryColor;

    if (widget.peakHour >= 6 && widget.peakHour < 12) {
      timeLabel = widget.morningLabel ?? 'Morning';
      timeIcon = Icons.wb_sunny_rounded;
      primaryColor = const Color(0xFFF59E0B); // Amber
      secondaryColor = const Color(0xFFFBBF24);
    } else if (widget.peakHour >= 12 && widget.peakHour < 18) {
      timeLabel = widget.afternoonLabel ?? 'Afternoon';
      timeIcon = Icons.wb_sunny_outlined;
      primaryColor = const Color(0xFFEF6C00); // Deep Orange
      secondaryColor = const Color(0xFFFF9800);
    } else if (widget.peakHour >= 18 && widget.peakHour < 22) {
      timeLabel = widget.eveningLabel ?? 'Evening';
      timeIcon = Icons.nightlight_round;
      primaryColor = const Color(0xFF3B82F6); // Blue (twilight sky)
      secondaryColor = const Color(0xFF60A5FA);
    } else {
      timeLabel = widget.nightLabel ?? 'Night';
      timeIcon = Icons.dark_mode_rounded;
      primaryColor = const Color(0xFFFBBF24); // Moon yellow
      secondaryColor = const Color(0xFFF59E0B);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isHovered ? _pulseAnimation.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withOpacity(isDark ? 0.25 : 0.15),
                    secondaryColor.withOpacity(isDark ? 0.15 : 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: primaryColor.withOpacity(_isHovered ? 0.5 : 0.3),
                  width: _isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(_isHovered ? 0.25 : 0.15),
                    blurRadius: _isHovered ? 16 : 10,
                    offset: const Offset(0, 4),
                    spreadRadius: _isHovered ? 0 : -2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      timeIcon,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label ?? 'Peak Activity',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.peakHour.toString().padLeft(2, '0')}:00 - $timeLabel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
