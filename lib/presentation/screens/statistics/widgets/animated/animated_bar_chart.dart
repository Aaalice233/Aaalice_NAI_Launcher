import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Animated bar chart widget
/// 动画柱状图组件
class AnimatedBarChart extends StatefulWidget {
  final BarChartData data;
  final double height;
  final Duration duration;

  const AnimatedBarChart({
    super.key,
    required this.data,
    required this.height,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
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
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Animate bar growth from zero
          final animatedData = BarChartData(
            alignment: widget.data.alignment,
            maxY: widget.data.maxY,
            minY: widget.data.minY,
            barTouchData: widget.data.barTouchData,
            titlesData: widget.data.titlesData,
            gridData: widget.data.gridData,
            borderData: widget.data.borderData,
            barGroups: widget.data.barGroups.map((group) {
              return BarChartGroupData(
                x: group.x,
                barRods: group.barRods.map((rod) {
                  return BarChartRodData(
                    toY: rod.toY * _animation.value,
                    color: rod.color,
                    width: rod.width,
                    borderRadius: rod.borderRadius,
                  );
                }).toList(),
              );
            }).toList(),
          );

          return BarChart(animatedData);
        },
      ),
    );
  }
}
