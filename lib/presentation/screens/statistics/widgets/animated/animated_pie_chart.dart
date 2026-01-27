import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Animated pie chart widget
/// 动画饼图组件
class AnimatedPieChart extends StatefulWidget {
  final PieChartData data;
  final double height;
  final Duration duration;

  const AnimatedPieChart({
    super.key,
    required this.data,
    required this.height,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<AnimatedPieChart> createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<AnimatedPieChart>
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
  void didUpdateWidget(AnimatedPieChart oldWidget) {
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
          // Animate pie growth from zero
          final animatedData = PieChartData(
            sectionsSpace: widget.data.sectionsSpace,
            centerSpaceRadius: widget.data.centerSpaceRadius,
            sections: widget.data.sections.map((section) {
              return PieChartSectionData(
                color: section.color,
                value: section.value * _animation.value,
                title: section.title,
                radius: section.radius,
                titleStyle: section.titleStyle,
                showTitle: section.showTitle,
              );
            }).toList(),
            pieTouchData: widget.data.pieTouchData,
          );

          return PieChart(animatedData);
        },
      ),
    );
  }
}
