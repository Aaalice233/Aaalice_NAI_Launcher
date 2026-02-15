import 'dart:async';
import 'package:flutter/material.dart';

/// 卡片操作按钮配置
class CardActionButtonConfig {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final bool isLoading;

  const CardActionButtonConfig({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.isLoading = false,
  });
}

/// 卡片操作按钮组
class CardActionButtons extends StatefulWidget {
  final List<CardActionButtonConfig> buttons;
  final bool visible;
  final Duration hoverDelay;
  final Duration animationDuration;
  final Axis direction;

  const CardActionButtons({
    super.key,
    required this.buttons,
    required this.visible,
    this.hoverDelay = const Duration(milliseconds: 300),
    this.animationDuration = const Duration(milliseconds: 150),
    this.direction = Axis.horizontal,
  });

  @override
  State<CardActionButtons> createState() => _CardActionButtonsState();
}

class _CardActionButtonsState extends State<CardActionButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _hoverTimer;
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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

    return Flex(
      direction: widget.direction,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: List.generate(widget.buttons.length, (index) {
        // 依次展开：第一个按钮先出现
        final staggerDelay = index * 0.12;
        final startTime = staggerDelay.clamp(0.0, 0.6);
        final endTime = (startTime + 0.4).clamp(0.0, 1.0);

        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(startTime, endTime, curve: Curves.elasticOut),
        );

        // 根据布局方向决定滑动方向：
        // 垂直布局：从上往下滑入
        // 水平布局：从左往右滑入
        final slideAnimation = Tween<Offset>(
          begin: widget.direction == Axis.vertical
              ? const Offset(0, -0.5)
              : const Offset(-0.5, 0),
          end: Offset.zero,
        ).animate(animation);

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.direction == Axis.horizontal ? 4 : 0,
                top: widget.direction == Axis.vertical ? 4 : 0,
              ),
              child: _CardActionButton(config: widget.buttons[index]),
            ),
          ),
        );
      }),
    );
  }
}

/// 单个卡片操作按钮（带悬浮动效）
class _CardActionButton extends StatefulWidget {
  final CardActionButtonConfig config;

  const _CardActionButton({required this.config});

  @override
  State<_CardActionButton> createState() => _CardActionButtonState();
}

class _CardActionButtonState extends State<_CardActionButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.config.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          onTap: widget.config.isLoading ? null : widget.config.onPressed,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isHovering
                  ? Colors.white.withOpacity(0.25)
                  : Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: widget.config.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    widget.config.icon,
                    color: widget.config.iconColor ?? Colors.white,
                    size: 16,
                  ),
          ),
        ),
      ),
    );
  }
}
