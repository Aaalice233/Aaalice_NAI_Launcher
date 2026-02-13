import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';
import 'inset_shadow_painter.dart';

/// 主题化开关组件
///
/// 使用立体效果设计，轨道带有内阴影凹槽感，滑块带有外阴影凸起感。
/// 支持三种交互风格（Material/Physical/Digital），自动适配主题。
class ThemedSwitch extends StatefulWidget {
  /// 当前值
  final bool value;

  /// 值改变回调
  final ValueChanged<bool>? onChanged;

  /// 是否启用
  final bool enabled;

  /// 激活时的颜色（轨道颜色）
  final Color? activeColor;

  /// 未激活时的颜色（轨道颜色）
  final Color? inactiveColor;

  /// 滑块颜色
  final Color? thumbColor;

  /// 开关大小缩放因子
  final double scale;

  const ThemedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.scale = 1.0,
  });

  @override
  State<ThemedSwitch> createState() => _ThemedSwitchState();
}

class _ThemedSwitchState extends State<ThemedSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _position;

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.value ? 1.0 : 0.0,
    );
    _position = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(ThemedSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled || widget.onChanged == null) return;
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appExt = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    // 尺寸
    final trackWidth = 48.0 * widget.scale;
    final trackHeight = 26.0 * widget.scale;
    final thumbSize = 20.0 * widget.scale;
    final thumbPadding = 3.0 * widget.scale;

    // 颜色
    final activeTrackColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveTrackColor = widget.inactiveColor ??
        (isDark
            ? Color.lerp(theme.colorScheme.surface, Colors.black, 0.4)!
            : Color.lerp(theme.colorScheme.surface, Colors.black, 0.08)!);
    final thumbColorBase = widget.thumbColor ?? theme.colorScheme.onPrimary;

    // 内阴影参数
    final shadowDepth = appExt?.insetShadowDepth ?? 0.12;
    final shadowBlur = appExt?.insetShadowBlur ?? 8.0;
    final enableInsetShadow = appExt?.enableInsetShadow ?? true;

    // 禁用状态透明度
    final opacity = widget.enabled ? 1.0 : 0.5;

    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: Opacity(
          opacity: opacity,
          child: AnimatedBuilder(
            animation: _position,
            builder: (context, child) {
              // 计算当前轨道颜色
              final currentTrackColor = Color.lerp(
                inactiveTrackColor,
                activeTrackColor,
                _position.value,
              )!;

              // 计算滑块位置
              final thumbOffset = thumbPadding +
                  (_position.value *
                      (trackWidth - thumbSize - thumbPadding * 2));

              return SizedBox(
                width: trackWidth,
                height: trackHeight,
                child: Stack(
                  children: [
                    // 轨道（带内阴影）
                    _buildTrack(
                      trackWidth: trackWidth,
                      trackHeight: trackHeight,
                      trackColor: currentTrackColor,
                      isDark: isDark,
                      shadowDepth: shadowDepth,
                      shadowBlur: shadowBlur,
                      enableInsetShadow: enableInsetShadow,
                      theme: theme,
                    ),
                    // 滑块
                    Positioned(
                      left: thumbOffset,
                      top: thumbPadding,
                      child: _buildThumb(
                        thumbSize: thumbSize,
                        thumbColor: thumbColorBase,
                        isDark: isDark,
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTrack({
    required double trackWidth,
    required double trackHeight,
    required Color trackColor,
    required bool isDark,
    required double shadowDepth,
    required double shadowBlur,
    required bool enableInsetShadow,
    required ThemeData theme,
  }) {
    final borderRadius = BorderRadius.circular(trackHeight / 2);
    final borderColor = theme.colorScheme.outline.withOpacity(0.2);

    // 内阴影颜色
    final shadowColor = isDark
        ? Colors.black.withOpacity(shadowDepth * 1.5)
        : Colors.black.withOpacity(shadowDepth);

    return Container(
      width: trackWidth,
      height: trackHeight,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: enableInsetShadow
          ? ClipRRect(
              borderRadius: borderRadius,
              child: CustomPaint(
                painter: InsetShadowPainter(
                  shadowColor: shadowColor,
                  shadowBlur: shadowBlur * 0.6,
                  borderRadius: trackHeight / 2,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildThumb({
    required double thumbSize,
    required Color thumbColor,
    required bool isDark,
    required ThemeData theme,
  }) {
    // 悬浮/按下状态的阴影变化
    final shadowOpacity = _isPressed
        ? 0.15
        : _isHovered
            ? 0.25
            : 0.2;
    final shadowBlur = _isPressed
        ? 2.0
        : _isHovered
            ? 6.0
            : 4.0;
    final shadowOffset = _isPressed ? const Offset(0, 1) : const Offset(0, 2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: thumbSize,
      height: thumbSize,
      decoration: BoxDecoration(
        color: thumbColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
    );
  }
}

