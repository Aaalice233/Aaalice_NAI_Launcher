import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';

import '../../adaptive/interaction_policy.dart';

/// 卡片语义层级。
enum CardElevation { level1, level2, level3, level4 }

/// 项目统一的 surface card。
///
/// 默认卡片只使用语义色面，不绘制完整边框或阴影。可点击卡片默认响应
/// hover，静态卡片仅在显式启用时响应；焦点、选中等明确状态可显示状态边界。
class ElevatedCard extends StatefulWidget {
  const ElevatedCard({
    super.key,
    required this.child,
    this.elevation = CardElevation.level1,
    this.hoverElevation,
    this.enableHoverEffect,
    this.hoverTranslateY = -2,
    this.hoverScale = 1,
    this.borderRadius,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradientBorder,
    this.gradientBorderWidth = 1.5,
    this.enableSubtleBorder = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.animationDuration,
    this.animationCurve,
  });

  final Widget child;
  final CardElevation elevation;
  final CardElevation? hoverElevation;

  /// null 时只让卡片级可点击组件响应 hover；静态卡片可显式设为 true。
  final bool? enableHoverEffect;
  final double hoverTranslateY;
  final double hoverScale;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradientBorder;
  final double gradientBorderWidth;
  final bool enableSubtleBorder;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final Duration? animationDuration;
  final Curve? animationCurve;

  @override
  State<ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<ElevatedCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isInteractive =>
      widget.onTap != null ||
      widget.onDoubleTap != null ||
      widget.onLongPress != null;

  bool get _hoverEnabled => widget.enableHoverEffect ?? _isInteractive;

  CardElevation get _currentElevation {
    if (!_isHovered || !_hoverEnabled) {
      return widget.elevation;
    }
    return widget.hoverElevation ??
        switch (widget.elevation) {
          CardElevation.level1 => CardElevation.level2,
          CardElevation.level2 => CardElevation.level3,
          CardElevation.level3 || CardElevation.level4 => CardElevation.level4,
        };
  }

  List<BoxShadow> _shadows(ThemeData theme) {
    final opacity = theme.brightness == Brightness.dark ? 0.18 : 0.1;
    return switch (_currentElevation) {
      CardElevation.level1 => const [],
      CardElevation.level2 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity * 0.55),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
      CardElevation.level3 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity * 0.75),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
      CardElevation.level4 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity),
          blurRadius: 20,
          offset: const Offset(0, 9),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.appTheme;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final radius = widget.borderRadius ?? tokens.cardRadius;
    final hoverActive = _isHovered && _hoverEnabled;
    final background =
        widget.backgroundColor ??
        (hoverActive
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerLow);
    final statusBorder =
        _isFocused && context.interactionPolicy.keyboardNavigationActive
        ? Border.all(color: theme.colorScheme.primary, width: 1)
        : widget.enableSubtleBorder
        ? Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.16),
          )
        : null;

    Widget content = widget.padding == null
        ? widget.child
        : Padding(padding: widget.padding!, child: widget.child);

    if (_isInteractive) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onLongPress: widget.onLongPress,
          onFocusChange: (value) {
            if (_isFocused != value) setState(() => _isFocused = value);
          },
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }

    Widget card = AnimatedContainer(
      duration: reducedMotion
          ? Duration.zero
          : widget.animationDuration ?? tokens.normalDuration,
      curve: widget.animationCurve ?? tokens.standardCurve,
      transform: Matrix4.identity()
        ..translateByDouble(
          0,
          reducedMotion || !hoverActive ? 0 : widget.hoverTranslateY,
          0,
          1,
        )
        ..scaleByDouble(
          reducedMotion || !hoverActive ? 1 : widget.hoverScale,
          reducedMotion || !hoverActive ? 1 : widget.hoverScale,
          1,
          1,
        ),
      transformAlignment: Alignment.center,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _shadows(theme),
        border: statusBorder,
      ),
      child: widget.gradientBorder == null
          ? content
          : _GradientBorderWrapper(
              gradient: widget.gradientBorder!,
              borderRadius: radius,
              borderWidth: widget.gradientBorderWidth,
              backgroundColor: background,
              child: content,
            ),
    );

    if (_hoverEnabled) {
      card = MouseRegion(
        cursor: _isInteractive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          if (!_isHovered) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (_isHovered) setState(() => _isHovered = false);
        },
        child: card,
      );
    }
    if (_isInteractive) {
      card = Semantics(button: true, enabled: true, child: card);
    }
    return card;
  }
}

class _GradientBorderWrapper extends StatelessWidget {
  const _GradientBorderWrapper({
    required this.gradient,
    required this.borderRadius,
    required this.borderWidth,
    required this.backgroundColor,
    required this.child,
  });

  final Gradient gradient;
  final double borderRadius;
  final double borderWidth;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Container(
        margin: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(
            (borderRadius - borderWidth).clamp(0, double.infinity),
          ),
        ),
        child: child,
      ),
    );
  }
}

class CardGradients {
  CardGradients._();

  static Gradient primary(ColorScheme colorScheme) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colorScheme.primary.withValues(alpha: 0.6),
        colorScheme.secondary.withValues(alpha: 0.4),
      ],
    );
  }
}
