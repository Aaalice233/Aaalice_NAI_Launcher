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
    // 当收藏状态从 false 变为 true 时，播放动画
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

    // 如果将要变成收藏状态，预先播放动画
    if (!widget.isFavorite) {
      _controller.forward(from: 0);
    }

    widget.onToggle!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final inactiveColor = widget.inactiveColor ??
        (isDark ? Colors.white : theme.colorScheme.onSurfaceVariant);
    final activeColor = widget.activeColor ?? Colors.red.shade400;

    final icon = widget.isFavorite ? Icons.favorite : Icons.favorite_border;
    final color = widget.isFavorite ? activeColor : inactiveColor;

    Widget iconWidget = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isFavorite
              ? _scaleAnimation.value
              : (_isHovered ? 1.15 : 1.0),
          child: Icon(
            icon,
            size: widget.size,
            color: _isHovered && !widget.isFavorite
                ? color.withOpacity(1.0)
                : color,
          ),
        );
      },
    );

    // 添加背景圆圈
    if (widget.showBackground) {
      final bgColor = widget.backgroundColor ??
          (widget.isFavorite
              ? activeColor.withOpacity(0.15)
              : (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05)));

      iconWidget = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(widget.size * 0.3),
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.isFavorite
                  ? activeColor.withOpacity(0.25)
                  : (isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.08)))
              : bgColor,
          shape: BoxShape.circle,
        ),
        child: iconWidget,
      );
    }

    // 包装为可点击，添加hover效果容器
    Widget button = MouseRegion(
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

    // 添加 tooltip
    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    } else {
      button = Tooltip(
        message: widget.isFavorite ? '取消收藏' : '收藏',
        child: button,
      );
    }

    return button;
  }
}

/// 卡片悬浮收藏按钮
///
/// 专为卡片右上角设计的收藏按钮，带有半透明背景和完整hover效果
/// 
/// 特性：
/// - hover时背景加深、图标放大、添加光晕
/// - 收藏时显示红色发光效果
/// - 点击时播放脉冲动画
class CardFavoriteButton extends StatefulWidget {
  /// 是否已收藏
  final bool isFavorite;

  /// 切换收藏状态回调
  final VoidCallback? onToggle;

  /// 图标大小
  final double size;

  /// 是否启用触觉反馈
  final bool enableHapticFeedback;

  /// 圆角半径（默认16，方形按钮可设为8）
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
  State<CardFavoriteButton> createState() => _CardFavoriteButtonState();
}

class _CardFavoriteButtonState extends State<CardFavoriteButton>
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
  void didUpdateWidget(CardFavoriteButton oldWidget) {
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
    final isFavorite = widget.isFavorite;
    final activeColor = Colors.red.shade400;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onToggle != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: _handleTap,
        child: Tooltip(
          message: isFavorite ? '取消收藏' : '收藏',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.black.withOpacity(0.7)
                  : Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                if (isFavorite)
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                if (_isHovered && !isFavorite)
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
              ],
              border: _isHovered && !isFavorite
                  ? Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isFavorite
                      ? _scaleAnimation.value
                      : (_isHovered ? 1.1 : 1.0),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: widget.size,
                    color: isFavorite
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
