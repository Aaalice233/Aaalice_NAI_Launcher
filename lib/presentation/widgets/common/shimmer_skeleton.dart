import 'package:flutter/material.dart';

/// Shimmer skeleton loading animation widget
/// 闪烁骨架屏加载动画组件
class ShimmerSkeleton extends StatefulWidget {
  /// Height of the skeleton
  /// 骨架屏高度
  final double height;

  /// Width of the skeleton (defaults to full width)
  /// 骨架屏宽度（默认全宽）
  final double? width;

  /// Border radius of the skeleton
  /// 骨架屏圆角
  final BorderRadius? borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: 0.5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 0.5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final baseColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final highlightColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    Widget skeleton(double animationValue) => Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        gradient: _animationsDisabled == true
            ? LinearGradient(colors: [baseColor, highlightColor])
            : LinearGradient(
                begin: Alignment(-1 + animationValue * 2, -0.3),
                end: Alignment(1 + animationValue * 2, 0.3),
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0.1, 0.5, 0.9],
              ),
      ),
    );

    return ExcludeSemantics(
      child: _animationsDisabled == true
          ? skeleton(0.5)
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => skeleton(_controller.value),
            ),
    );
  }
}
