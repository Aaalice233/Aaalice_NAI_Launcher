import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 动画爱心收藏按钮
///
/// 统一的收藏按钮组件，包含：
/// - 未收藏：空心爱心
/// - 已收藏：红色实心爱心 + 跳动脉冲动画
///
/// 使用示例:
/// ```dart
/// AnimatedFavoriteButton(
///   isFavorite: true,
///   onToggle: () => toggleFavorite(),
/// )
/// ```
class AnimatedFavoriteButton extends StatefulWidget {
  /// 是否已收藏
  final bool isFavorite;

  /// 切换收藏状态回调
  final VoidCallback? onToggle;

  /// 图标大小
  final double size;

  /// 未收藏时的图标颜色（默认白色）
  final Color? inactiveColor;

  /// 已收藏时的图标颜色（默认红色）
  final Color? activeColor;

  /// 是否显示背景圆圈
  final bool showBackground;

  /// 背景圆圈颜色
  final Color? backgroundColor;

  /// tooltip 文字
  final String? tooltip;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  const AnimatedFavoriteButton({
    super.key,
    required this.isFavorite,
    this.onToggle,
    this.size = 24,
    this.inactiveColor,
    this.activeColor,
    this.showBackground = false,
    this.backgroundColor,
    this.tooltip,
    this.enableHapticFeedback = true,
  });

  @override
  State<AnimatedFavoriteButton> createState() => _AnimatedFavoriteButtonState();
}

class _AnimatedFavoriteButtonState extends State<AnimatedFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(AnimatedFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite && !oldWidget.isFavorite) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onToggle == null) return;

    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (!widget.isFavorite) {
      _controller.forward(from: 0);
    }

    widget.onToggle!();
  }

  Color get _inactiveColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return widget.inactiveColor ??
        (isDark ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant);
  }

  Color get _activeColor => widget.activeColor ?? Colors.red.shade400;

  Color get _hoverBgColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return widget.isFavorite
        ? _activeColor.withOpacity(0.25)
        : (isDark
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.08));
  }

  Color get _defaultBgColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return widget.backgroundColor ??
        (widget.isFavorite
            ? _activeColor.withOpacity(0.15)
            : (isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.isFavorite ? _activeColor : _inactiveColor;

    Widget iconWidget = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isFavorite
              ? _scaleAnimation.value
              : (_isHovered ? 1.15 : 1.0),
          child: Icon(
            widget.isFavorite ? Icons.favorite : Icons.favorite_border,
            size: widget.size,
            color: _isHovered && !widget.isFavorite ? color : color,
          ),
        );
      },
    );

    if (widget.showBackground) {
      iconWidget = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(widget.size * 0.3),
        decoration: BoxDecoration(
          color: _isHovered ? _hoverBgColor : _defaultBgColor,
          shape: BoxShape.circle,
        ),
        child: iconWidget,
      );
    }

    final button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onToggle != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              widget.showBackground ? EdgeInsets.zero : const EdgeInsets.all(4),
          decoration: !widget.showBackground && _isHovered
              ? BoxDecoration(
                  color:
                      (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(widget.size * 0.4),
                )
              : null,
          child: iconWidget,
        ),
      ),
    );

    return Tooltip(
      message: widget.tooltip ?? (widget.isFavorite ? '取消收藏' : '收藏'),
      child: button,
    );
  }
}

/// 卡片悬浮收藏按钮
///
/// 专为卡片右上角设计的收藏按钮，带有半透明背景和完整hover效果
class CardFavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback? onToggle;
  final double size;
  final bool enableHapticFeedback;
  final double borderRadius;

  const CardFavoriteButton({
    super.key,
    required this.isFavorite,
    this.onToggle,
    this.size = 16,
    this.enableHapticFeedback = true,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseFavoriteButton(
      isFavorite: isFavorite,
      onToggle: onToggle,
      size: size,
      enableHapticFeedback: enableHapticFeedback,
      borderRadius: borderRadius,
    );
  }
}

/// 基础收藏按钮 - 共享动画逻辑
class _BaseFavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback? onToggle;
  final double size;
  final bool enableHapticFeedback;
  final double borderRadius;

  const _BaseFavoriteButton({
    required this.isFavorite,
    this.onToggle,
    required this.size,
    required this.enableHapticFeedback,
    required this.borderRadius,
  });

  @override
  State<_BaseFavoriteButton> createState() => _BaseFavoriteButtonState();
}

class _BaseFavoriteButtonState extends State<_BaseFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_BaseFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite && !oldWidget.isFavorite) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onToggle == null) return;
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    if (!widget.isFavorite) {
      _controller.forward(from: 0);
    }
    widget.onToggle!();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.red.shade400;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onToggle != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: widget.isFavorite ? '取消收藏' : '收藏',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.black.withOpacity(0.7)
                  : Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                if (widget.isFavorite)
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                if (_isHovered && !widget.isFavorite)
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 6,
                  ),
              ],
              border: _isHovered && !widget.isFavorite
                  ? Border.all(color: Colors.white.withOpacity(0.3))
                  : null,
            ),
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isFavorite
                      ? _scaleAnimation.value
                      : (_isHovered ? 1.1 : 1.0),
                  child: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: widget.size,
                    color: widget.isFavorite
                        ? activeColor
                        : (_isHovered
                            ? Colors.white
                            : Colors.white.withOpacity(0.9)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
