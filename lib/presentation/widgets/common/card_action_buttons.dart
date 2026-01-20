import 'dart:async';
import 'package:flutter/material.dart';

/// 卡片操作按钮配置
class CardActionButtonConfig {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;

  const CardActionButtonConfig({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
  });
}

/// 卡片操作按钮组
class CardActionButtons extends StatefulWidget {
  final List<CardActionButtonConfig> buttons;
  final bool visible;
  final Duration hoverDelay;
  final Duration animationDuration;

  const CardActionButtons({
    super.key,
    required this.buttons,
    required this.visible,
    this.hoverDelay = const Duration(milliseconds: 300),
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  State<CardActionButtons> createState() => _CardActionButtonsState();
}

class _CardActionButtonsState extends State<CardActionButtons> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _hoverTimer;
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
  }

  @override
  void didUpdateWidget(CardActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      _handleVisibilityChange();
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibilityChange() {
    _hoverTimer?.cancel();
    if (widget.visible) {
      _hoverTimer = Timer(widget.hoverDelay, () {
        if (mounted) {
          setState(() => _shouldShow = true);
          _controller.forward();
        }
      });
    } else {
      setState(() => _shouldShow = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果完全不可见且动画已结束，则不构建（优化性能）
    // 但为了反向动画流畅，我们只在不可见且动画dismissed时隐藏
    if (!_shouldShow && _controller.isDismissed) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: List.generate(widget.buttons.length, (index) {
        // 从右向左展开：右边的按钮先出现
        // 假设 buttons 列表顺序是从左到右显示的 (A, B, C, D, E)
        // E 是最右边。
        // 我们希望 E 先出现，然后 D，然后 C...
        // 列表索引: 0..4. 长度 5.
        // index 4 (E) delay 0
        // index 3 (D) delay 1
        // ...
        // delay = (length - 1 - index) * 50ms
        
        final buttonIndex = index;
        final reversedIndex = widget.buttons.length - 1 - index;
        // Delay calculated but applied via Interval animation below
        // final delay = Duration(milliseconds: reversedIndex * 50);
        
        // 计算每个按钮的动画区间
        // 总时长 = 基础时长 + 最大延迟
        // 这里简化处理：使用 SlideTransition/ScaleTransition 配合 Interval
        
        // 实际上，为了简单的 staggered 效果，我们可以让每个按钮有自己的动画进度
        // 或者使用同一个 controller 但不同的 Interval
        
        final startTime = reversedIndex * 0.1; // 0.0, 0.1, 0.2...
        final endTime = startTime + 0.6; // 持续 0.6 的时间片段
        // 归一化到 0.0 - 1.0
        
        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (startTime * 0.5).clamp(0.0, 1.0), // 压缩一下时间以适应 controller
            (endTime * 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOutBack,
          ),
        );

        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _buildButton(widget.buttons[buttonIndex]),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildButton(CardActionButtonConfig config) {
    return Tooltip(
      message: config.tooltip,
      child: GestureDetector(
        onTap: config.onPressed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            config.icon,
            color: config.iconColor ?? Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
