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
        final buttonIndex = index;
        final reversedIndex = widget.buttons.length - 1 - index;

        final startTime = reversedIndex * 0.1;
        final endTime = startTime + 0.6;

        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (startTime * 0.5).clamp(0.0, 1.0),
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
              child: _CardActionButton(config: widget.buttons[buttonIndex]),
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
          onTap: widget.config.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(6),
            transform: Matrix4.identity()..scale(_isHovering ? 1.15 : 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isHovering
                  ? Colors.white.withOpacity(0.25)
                  : Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
              border: _isHovering
                  ? Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(
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
