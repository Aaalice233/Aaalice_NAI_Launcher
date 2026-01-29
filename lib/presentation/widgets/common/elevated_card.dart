import 'package:flutter/material.dart';

/// 层叠卡片层级枚举
enum CardElevation {
  /// 基础层级 - 轻微阴影
  level1,

  /// 中等层级 - 标准阴影
  level2,

  /// 高层级 - 明显阴影
  level3,

  /// 最高层级 - 强烈阴影
  level4,
}

/// Dimensional Layering 风格的层叠卡片组件
///
/// 支持4级阴影系统、悬停提升效果、渐变边框和动态背景
class ElevatedCard extends StatefulWidget {
  const ElevatedCard({
    super.key,
    required this.child,
    this.elevation = CardElevation.level1,
    this.hoverElevation,
    this.enableHoverEffect = true,
    this.hoverTranslateY = -4.0,
    this.hoverScale = 1.0,
    this.borderRadius = 12.0,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradientBorder,
    this.gradientBorderWidth = 1.5,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutCubic,
  });

  /// 子组件
  final Widget child;

  /// 默认层级
  final CardElevation elevation;

  /// 悬停时的层级 (默认为当前层级+1)
  final CardElevation? hoverElevation;

  /// 是否启用悬停效果
  final bool enableHoverEffect;

  /// 悬停时的Y轴位移
  final double hoverTranslateY;

  /// 悬停时的缩放比例 (1.0表示不缩放)
  final double hoverScale;

  /// 圆角半径
  final double borderRadius;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 背景颜色 (默认使用主题色)
  final Color? backgroundColor;

  /// 渐变边框 (可选)
  final Gradient? gradientBorder;

  /// 渐变边框宽度
  final double gradientBorderWidth;

  /// 点击回调
  final VoidCallback? onTap;

  /// 双击回调
  final VoidCallback? onDoubleTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 动画时长
  final Duration animationDuration;

  /// 动画曲线
  final Curve animationCurve;

  @override
  State<ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<ElevatedCard> {
  bool _isHovered = false;

  CardElevation get _currentElevation {
    if (!_isHovered || !widget.enableHoverEffect) {
      return widget.elevation;
    }
    return widget.hoverElevation ?? _getNextElevation(widget.elevation);
  }

  CardElevation _getNextElevation(CardElevation current) {
    switch (current) {
      case CardElevation.level1:
        return CardElevation.level2;
      case CardElevation.level2:
        return CardElevation.level3;
      case CardElevation.level3:
        return CardElevation.level4;
      case CardElevation.level4:
        return CardElevation.level4;
    }
  }

  List<BoxShadow> _getShadows(ColorScheme colorScheme) {
    final shadowColor = colorScheme.shadow;
    switch (_currentElevation) {
      case CardElevation.level1:
        return [
          BoxShadow(
            color: shadowColor.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];
      case CardElevation.level2:
        return [
          BoxShadow(
            color: shadowColor.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
      case CardElevation.level3:
        return [
          BoxShadow(
            color: shadowColor.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ];
      case CardElevation.level4:
        return [
          BoxShadow(
            color: shadowColor.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final translateY =
        _isHovered && widget.enableHoverEffect ? widget.hoverTranslateY : 0.0;
    final scale =
        _isHovered && widget.enableHoverEffect ? widget.hoverScale : 1.0;

    final backgroundColor =
        widget.backgroundColor ?? colorScheme.surfaceContainerLow;

    Widget card = AnimatedContainer(
      duration: widget.animationDuration,
      curve: widget.animationCurve,
      transform: Matrix4.identity()
        ..translate(0.0, translateY)
        ..scale(scale),
      transformAlignment: Alignment.center,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: _getShadows(colorScheme),
        border: widget.gradientBorder == null
            ? Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              )
            : null,
      ),
      child: widget.gradientBorder != null
          ? _GradientBorderWrapper(
              gradient: widget.gradientBorder!,
              borderRadius: widget.borderRadius,
              borderWidth: widget.gradientBorderWidth,
              child: _buildContent(),
            )
          : _buildContent(),
    );

    // 添加悬停检测
    if (widget.enableHoverEffect) {
      card = MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: card,
      );
    }

    // 添加点击事件
    if (widget.onTap != null ||
        widget.onDoubleTap != null ||
        widget.onLongPress != null) {
      card = GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: card,
      );
    }

    return card;
  }

  Widget _buildContent() {
    if (widget.padding != null) {
      return Padding(
        padding: widget.padding!,
        child: widget.child,
      );
    }
    return widget.child;
  }
}

/// 渐变边框包装器
class _GradientBorderWrapper extends StatelessWidget {
  const _GradientBorderWrapper({
    required this.gradient,
    required this.borderRadius,
    required this.borderWidth,
    required this.child,
  });

  final Gradient gradient;
  final double borderRadius;
  final double borderWidth;
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
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        ),
        child: child,
      ),
    );
  }
}

/// 预设的渐变边框样式
class CardGradients {
  CardGradients._();

  /// 主题色渐变边框
  static Gradient primary(ColorScheme colorScheme) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colorScheme.primary.withOpacity(0.6),
        colorScheme.secondary.withOpacity(0.4),
      ],
    );
  }

  /// 彩虹渐变边框
  static const Gradient rainbow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF6B6B),
      Color(0xFFFFE66D),
      Color(0xFF4ECDC4),
      Color(0xFF45B7D1),
      Color(0xFF96CEB4),
    ],
  );

  /// 极光渐变边框
  static const Gradient aurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00FFFF),
      Color(0xFF0080FF),
      Color(0xFFFF00FF),
    ],
  );

  /// 金色渐变边框
  static const Gradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFD700),
      Color(0xFFFFA500),
      Color(0xFFFF8C00),
    ],
  );

  /// 成功状态渐变边框
  static const Gradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF22C55E),
      Color(0xFF16A34A),
    ],
  );

  /// 警告状态渐变边框
  static const Gradient warning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF59E0B),
      Color(0xFFD97706),
    ],
  );
}
