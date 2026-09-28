import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';

/// 统一收藏按钮。
///
/// 复用 Material [IconButton] 的键盘、焦点、禁用和语义行为；收藏成功只播放
/// 一次短促的确认缩放，不使用弹跳或常驻发光。
class AnimatedFavoriteButton extends StatelessWidget {
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

  final bool isFavorite;
  final VoidCallback? onToggle;
  final double size;
  final Color? inactiveColor;
  final Color? activeColor;
  final bool showBackground;
  final Color? backgroundColor;
  final String? tooltip;
  final bool enableHapticFeedback;

  @override
  Widget build(BuildContext context) {
    return _FavoriteIconButton(
      isFavorite: isFavorite,
      onToggle: onToggle,
      size: size,
      inactiveColor: inactiveColor,
      activeColor: activeColor,
      showBackground: showBackground,
      backgroundColor: backgroundColor,
      tooltip: tooltip,
      enableHapticFeedback: enableHapticFeedback,
    );
  }
}

/// 图片卡片右上角使用的高对比收藏按钮。
class CardFavoriteButton extends StatelessWidget {
  const CardFavoriteButton({
    super.key,
    required this.isFavorite,
    this.onToggle,
    this.size = 16,
    this.enableHapticFeedback = true,
    this.borderRadius = 16,
  });

  final bool isFavorite;
  final VoidCallback? onToggle;
  final double size;
  final bool enableHapticFeedback;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return _FavoriteIconButton(
      isFavorite: isFavorite,
      onToggle: onToggle,
      size: size,
      enableHapticFeedback: enableHapticFeedback,
      borderRadius: borderRadius,
      cardOverlay: true,
    );
  }
}

class _FavoriteIconButton extends StatefulWidget {
  const _FavoriteIconButton({
    required this.isFavorite,
    required this.onToggle,
    required this.size,
    required this.enableHapticFeedback,
    this.inactiveColor,
    this.activeColor,
    this.showBackground = false,
    this.backgroundColor,
    this.tooltip,
    this.borderRadius,
    this.cardOverlay = false,
  });

  final bool isFavorite;
  final VoidCallback? onToggle;
  final double size;
  final Color? inactiveColor;
  final Color? activeColor;
  final bool showBackground;
  final Color? backgroundColor;
  final String? tooltip;
  final bool enableHapticFeedback;
  final double? borderRadius;
  final bool cardOverlay;

  @override
  State<_FavoriteIconButton> createState() => _FavoriteIconButtonState();
}

class _FavoriteIconButtonState extends State<_FavoriteIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scale = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 1.12),
          weight: 45,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.12, end: 1),
          weight: 55,
        ),
      ],
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(_FavoriteIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite && !oldWidget.isFavorite) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.value = 0;
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

  void _handlePressed() {
    if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeColor = widget.activeColor ?? colors.error;
    final inactiveColor = widget.inactiveColor ?? colors.onSurfaceVariant;
    final tooltip =
        widget.tooltip ??
        (widget.isFavorite
            ? context.l10n.common_unfavorite
            : context.l10n.common_favorite);

    final interaction = context.interactionPolicy;

    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return colors.onSurface.withValues(alpha: 0.38);
      }
      if (widget.isFavorite) return activeColor;
      if (widget.cardOverlay) return Colors.white;
      return inactiveColor;
    }

    Color background(Set<WidgetState> states) {
      final interactive = interaction.isControlHighlighted(states);
      if (states.contains(WidgetState.disabled) && !widget.cardOverlay) {
        return Colors.transparent;
      }
      if (widget.cardOverlay) {
        return Colors.black.withValues(alpha: interactive ? 0.68 : 0.5);
      }
      if (widget.showBackground) {
        if (widget.isFavorite) {
          return interactive
              ? colors.errorContainer
              : activeColor.withValues(alpha: 0.14);
        }
        return interactive
            ? widget.backgroundColor ?? colors.surfaceContainerHighest
            : Colors.transparent;
      }
      return interactive ? colors.surfaceContainerHigh : Colors.transparent;
    }

    final radius = widget.borderRadius ?? widget.size * 0.5;
    return IconButton(
      onPressed: widget.onToggle == null ? null : _handlePressed,
      tooltip: tooltip,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(foreground),
        backgroundColor: WidgetStateProperty.resolveWith(background),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide.none),
        minimumSize: const WidgetStatePropertyAll(Size.square(40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      icon: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: widget.isFavorite ? _scale.value : 1,
          child: child,
        ),
        child: Icon(
          widget.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: widget.size,
        ),
      ),
    );
  }
}
