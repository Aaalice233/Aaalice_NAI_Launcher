import 'package:flutter/material.dart';

import '../../themes/theme_extension.dart';

/// 主题化滑块组件
///
/// 使用立体效果设计，轨道带有内阴影凹槽感，
/// 滑块带有外阴影凸起效果。支持连续值和离散值。
class ThemedSlider extends StatefulWidget {
  /// 当前值
  final double value;

  /// 值改变回调（拖动时持续触发）
  final ValueChanged<double>? onChanged;

  /// 拖动开始回调
  final ValueChanged<double>? onChangeStart;

  /// 拖动结束回调
  final ValueChanged<double>? onChangeEnd;

  /// 最小值
  final double min;

  /// 最大值
  final double max;

  /// 分段数（设置后变为离散滑块）
  final int? divisions;

  /// 标签（显示在滑块上方）
  final String? label;

  /// 是否启用
  final bool enabled;

  /// 激活时的颜色（已填充部分）
  final Color? activeColor;

  /// 未激活时的颜色（未填充部分）
  final Color? inactiveColor;

  /// 滑块颜色
  final Color? thumbColor;

  /// 轨道高度
  final double trackHeight;

  /// 滑块大小
  final double thumbSize;

  const ThemedSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.trackHeight = 6.0,
    this.thumbSize = 18.0,
  });

  @override
  State<ThemedSlider> createState() => _ThemedSliderState();
}

class _ThemedSliderState extends State<ThemedSlider> {
  bool _isHovered = false;
  bool _isDragging = false;

  double get _normalizedValue {
    return ((widget.value - widget.min) / (widget.max - widget.min))
        .clamp(0.0, 1.0);
  }

  double _valueFromPosition(double localX, double trackWidth) {
    final fraction = (localX / trackWidth).clamp(0.0, 1.0);
    var newValue = widget.min + fraction * (widget.max - widget.min);

    // 如果有分段，对齐到最近的分段点
    if (widget.divisions != null && widget.divisions! > 0) {
      final step = (widget.max - widget.min) / widget.divisions!;
      newValue = (newValue / step).round() * step;
    }

    return newValue.clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appExt = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    // 颜色
    final activeColorBase = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveColorBase = widget.inactiveColor ??
        (isDark
            ? Color.lerp(theme.colorScheme.surface, Colors.black, 0.4)!
            : Color.lerp(theme.colorScheme.surface, Colors.black, 0.08)!);
    final thumbColorBase = widget.thumbColor ?? activeColorBase;

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
      child: Opacity(
        opacity: opacity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final thumbOffset =
                _normalizedValue * (trackWidth - widget.thumbSize);

            return GestureDetector(
              onHorizontalDragStart: widget.enabled
                  ? (details) {
                      setState(() {
                        _isDragging = true;
                      });
                      widget.onChangeStart?.call(widget.value);
                    }
                  : null,
              onHorizontalDragUpdate: widget.enabled
                  ? (details) {
                      final newValue = _valueFromPosition(
                        details.localPosition.dx - widget.thumbSize / 2,
                        trackWidth - widget.thumbSize,
                      );
                      widget.onChanged?.call(newValue);
                    }
                  : null,
              onHorizontalDragEnd: widget.enabled
                  ? (details) {
                      setState(() => _isDragging = false);
                      widget.onChangeEnd?.call(widget.value);
                    }
                  : null,
              onTapDown: widget.enabled
                  ? (details) {
                      final newValue = _valueFromPosition(
                        details.localPosition.dx - widget.thumbSize / 2,
                        trackWidth - widget.thumbSize,
                      );
                      widget.onChanged?.call(newValue);
                    }
                  : null,
              child: SizedBox(
                height: widget.thumbSize + 8, // 额外空间用于标签
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // 轨道背景（未激活部分）
                    _buildTrack(
                      trackWidth: trackWidth,
                      trackHeight: widget.trackHeight,
                      color: inactiveColorBase,
                      isDark: isDark,
                      shadowDepth: shadowDepth,
                      shadowBlur: shadowBlur,
                      enableInsetShadow: enableInsetShadow,
                      theme: theme,
                    ),
                    // 轨道填充（激活部分）
                    Positioned(
                      left: 0,
                      child: Container(
                        width: thumbOffset + widget.thumbSize / 2,
                        height: widget.trackHeight,
                        decoration: BoxDecoration(
                          color: activeColorBase,
                          borderRadius: BorderRadius.circular(
                            widget.trackHeight / 2,
                          ),
                        ),
                      ),
                    ),
                    // 分段点已移除（保留分段吸附功能，不显示视觉圆点）
                    // 滑块
                    Positioned(
                      left: thumbOffset,
                      child: _buildThumb(
                        thumbColor: thumbColorBase,
                        isDark: isDark,
                      ),
                    ),
                    // 标签（拖动时显示）
                    if (widget.label != null && _isDragging)
                      Positioned(
                        left: thumbOffset + widget.thumbSize / 2 - 20,
                        top: -24,
                        child: _buildLabel(
                          label: widget.label!,
                          color: activeColorBase,
                          theme: theme,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrack({
    required double trackWidth,
    required double trackHeight,
    required Color color,
    required bool isDark,
    required double shadowDepth,
    required double shadowBlur,
    required bool enableInsetShadow,
    required ThemeData theme,
  }) {
    final borderRadius = BorderRadius.circular(trackHeight / 2);
    final borderColor = theme.colorScheme.outline.withOpacity(0.15);

    // 内阴影颜色
    final shadowColor = isDark
        ? Colors.black.withOpacity(shadowDepth * 1.5)
        : Colors.black.withOpacity(shadowDepth);

    return Container(
      width: trackWidth,
      height: trackHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: enableInsetShadow
          ? ClipRRect(
              borderRadius: borderRadius,
              child: CustomPaint(
                painter: _TrackInsetShadowPainter(
                  shadowColor: shadowColor,
                  shadowBlur: shadowBlur * 0.4,
                  borderRadius: trackHeight / 2,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildThumb({
    required Color thumbColor,
    required bool isDark,
  }) {
    // 悬浮/拖动状态的阴影变化
    final shadowOpacity = _isDragging
        ? 0.3
        : _isHovered
            ? 0.25
            : 0.2;
    final shadowBlur = _isDragging
        ? 8.0
        : _isHovered
            ? 6.0
            : 4.0;
    final thumbScale = _isDragging ? 1.1 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: widget.thumbSize * thumbScale,
      height: widget.thumbSize * thumbScale,
      decoration: BoxDecoration(
        color: thumbColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: shadowBlur,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel({
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 轨道内阴影绘制器
class _TrackInsetShadowPainter extends CustomPainter {
  final Color shadowColor;
  final double shadowBlur;
  final double borderRadius;

  _TrackInsetShadowPainter({
    required this.shadowColor,
    required this.shadowBlur,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    canvas.save();
    canvas.clipRRect(rrect);

    // 顶部内阴影
    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        shadowColor,
        Colors.transparent,
      ],
    );

    final topRect = Rect.fromLTWH(0, 0, size.width, shadowBlur * 2);
    final topPaint = Paint()..shader = topGradient.createShader(topRect);
    canvas.drawRect(topRect, topPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrackInsetShadowPainter oldDelegate) {
    return oldDelegate.shadowColor != shadowColor ||
        oldDelegate.shadowBlur != shadowBlur ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// 带标签的主题化滑块
class ThemedSliderListTile extends StatelessWidget {
  /// 当前值
  final double value;

  /// 值改变回调
  final ValueChanged<double>? onChanged;

  /// 拖动结束回调
  final ValueChanged<double>? onChangeEnd;

  /// 标签文本
  final Widget title;

  /// 副标题（通常用于显示当前值）
  final Widget? subtitle;

  /// 最小值
  final double min;

  /// 最大值
  final double max;

  /// 分段数
  final int? divisions;

  /// 是否启用
  final bool enabled;

  /// 内边距
  final EdgeInsetsGeometry? contentPadding;

  const ThemedSliderListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    required this.title,
    this.subtitle,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.enabled = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: enabled
                            ? null
                            : Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .color!
                                .withOpacity(0.5),
                      ),
                  child: title,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                  child: subtitle!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ThemedSlider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            min: min,
            max: max,
            divisions: divisions,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}
