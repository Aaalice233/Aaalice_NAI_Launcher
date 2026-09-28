import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

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
  bool _reducedMotion = false;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion == _reducedMotion && _controller.value != 0) return;
    _reducedMotion = reducedMotion;
    if (reducedMotion) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
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
            context.l10n.statistics_noData,
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
        ..color = backgroundColor.withValues(alpha: 0.15 + (4 - i) * 0.05)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * i / 4, bgPaint);
    }

    // Draw concentric circle guides
    final guidePaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.4)
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
        ..color = backgroundColor.withValues(alpha: isMainHour ? 0.5 : 0.2)
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
          color.withValues(alpha: isDark ? 0.6 : 0.5),
          color.withValues(alpha: isDark ? 0.3 : 0.2),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, gradientPaint);

    // 清晰的单层描边比发光更适合高频查看的数据图表。
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

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
            color: textColor.withValues(alpha: animationValue),
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

class _PeakTimeIndicatorState extends State<PeakTimeIndicator> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    String timeLabel;
    IconData timeIcon;
    Color primaryColor;
    Color secondaryColor;

    if (widget.peakHour >= 5 && widget.peakHour < 12) {
      // 早晨：温暖的橙黄色（日出）
      timeLabel = widget.morningLabel ?? 'Morning';
      timeIcon = Icons.wb_twilight_rounded;
      primaryColor = const Color(0xFFF97316); // 橙红色
      secondaryColor = const Color(0xFFFBBF24); // 金黄色
    } else if (widget.peakHour >= 12 && widget.peakHour < 17) {
      // 下午：明亮的天蓝色（正午阳光）
      timeLabel = widget.afternoonLabel ?? 'Afternoon';
      timeIcon = Icons.wb_sunny_rounded;
      primaryColor = const Color(0xFF0EA5E9); // 天蓝色
      secondaryColor = const Color(0xFF38BDF8); // 浅天蓝
    } else if (widget.peakHour >= 17 && widget.peakHour < 21) {
      // 晚上：紫红色/夕阳色（黄昏）
      timeLabel = widget.eveningLabel ?? 'Evening';
      timeIcon = Icons.wb_twilight_rounded;
      primaryColor = const Color(0xFF9333EA); // 紫色
      secondaryColor = const Color(0xFFEC4899); // 粉红色（夕阳）
    } else {
      // 深夜：深蓝紫色（夜空）
      timeLabel = widget.nightLabel ?? 'Night';
      timeIcon = Icons.nights_stay_rounded;
      primaryColor = const Color(0xFF4F46E5); // 靛蓝色
      secondaryColor = const Color(0xFF7C3AED); // 紫罗兰
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: reducedMotion ? Duration.zero : theme.appTheme.fastDuration,
        curve: theme.appTheme.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withValues(
                alpha: isDark
                    ? (_isHovered ? 0.24 : 0.2)
                    : (_isHovered ? 0.14 : 0.11),
              ),
              secondaryColor.withValues(alpha: isDark ? 0.1 : 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: primaryColor.withValues(alpha: _isHovered ? 0.42 : 0.24),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(timeIcon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label ?? context.l10n.statistics_peakActivity,
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
  }
}
