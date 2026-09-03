import 'package:flutter/material.dart';

/// Animated number display widget
/// 动画数字显示组件
class AnimatedNumber extends StatefulWidget {
  final int targetValue;
  final String suffix;
  final TextStyle style;
  final Duration duration;

  const AnimatedNumber({
    super.key,
    required this.targetValue,
    this.suffix = '',
    required this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
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
  void didUpdateWidget(AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetValue != widget.targetValue) {
      if (_reducedMotion) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = (_animation.value * widget.targetValue).toInt();
        return Text('$value${widget.suffix}', style: widget.style);
      },
    );
  }
}
