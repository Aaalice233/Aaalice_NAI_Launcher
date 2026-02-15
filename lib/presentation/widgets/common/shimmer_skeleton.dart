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
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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

    // Dark mode: use lighter shimmer on dark surface
    // Light mode: use darker shimmer on light surface
    final baseColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.2)
        : colorScheme.surfaceContainerHighest.withOpacity(0.3);
    final highlightColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
        : colorScheme.surfaceContainerHighest.withOpacity(0.6);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(
                -1.0 + (_controller.value * 2),
                -0.3,
              ),
              end: Alignment(
                1.0 + (_controller.value * 2),
                0.3,
              ),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
