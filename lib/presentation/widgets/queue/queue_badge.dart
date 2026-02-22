import 'package:flutter/material.dart';

/// 队列数字徽章组件
class QueueBadge extends StatelessWidget {
  /// 显示的数字
  final int count;

  /// 背景颜色
  final Color? backgroundColor;

  /// 文字颜色
  final Color? textColor;

  /// 徽章尺寸
  final double size;

  /// 字体大小
  final double? fontSize;

  const QueueBadge({
    super.key,
    required this.count,
    this.backgroundColor,
    this.textColor,
    this.size = 40.0,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.primaryContainer;
    final fgColor = textColor ?? theme.colorScheme.onPrimaryContainer;

    // 根据数字位数调整字体大小
    final displayText = count > 99 ? '99+' : count.toString();
    final effectiveFontSize =
        fontSize ?? _calculateFontSize(displayText.length);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: effectiveFontSize,
            fontWeight: FontWeight.bold,
            color: fgColor,
          ),
        ),
      ),
    );
  }

  double _calculateFontSize(int length) {
    if (length == 1) return size * 0.45;
    if (length == 2) return size * 0.38;
    return size * 0.30; // 3+ 位数
  }
}

/// 带动画的脉冲徽章（用于执行中状态）
class PulsingBadge extends StatefulWidget {
  final int count;
  final Color? backgroundColor;
  final Color? textColor;
  final double size;

  const PulsingBadge({
    super.key,
    required this.count,
    this.backgroundColor,
    this.textColor,
    this.size = 40.0,
  });

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: QueueBadge(
            count: widget.count,
            backgroundColor: widget.backgroundColor,
            textColor: widget.textColor,
            size: widget.size,
          ),
        );
      },
    );
  }
}
