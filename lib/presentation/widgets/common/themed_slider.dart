import 'package:flutter/material.dart';

/// 项目统一滑块。
///
/// 复用 Material 原生拖动、键盘、焦点和语义行为，页面仅配置数值与语义颜色。
class ThemedSlider extends StatelessWidget {
  const ThemedSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.enabled = true,
    this.hideTickMarks = false,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.trackHeight = 6,
    this.thumbSize = 18,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final bool enabled;
  final bool hideTickMarks;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double trackHeight;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveOnChanged = enabled ? onChanged : null;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: trackHeight,
        activeTrackColor: activeColor ?? colors.primary,
        inactiveTrackColor: inactiveColor ?? colors.surfaceContainerHighest,
        thumbColor: thumbColor ?? activeColor ?? colors.primary,
        overlayColor: (activeColor ?? colors.primary).withValues(alpha: 0.12),
        tickMarkShape: hideTickMarks ? SliderTickMarkShape.noTickMark : null,
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: thumbSize / 2,
          disabledThumbRadius: thumbSize / 2,
        ),
        showValueIndicator: label == null
            ? ShowValueIndicator.never
            : ShowValueIndicator.onDrag,
      ),
      child: Slider(
        value: value.clamp(min, max),
        onChanged: effectiveOnChanged,
        onChangeStart: effectiveOnChanged == null ? null : onChangeStart,
        onChangeEnd: effectiveOnChanged == null ? null : onChangeEnd,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
      ),
    );
  }
}

/// 带标题和值说明的统一滑块。
class ThemedSliderListTile extends StatelessWidget {
  const ThemedSliderListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    required this.title,
    this.subtitle,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
    this.contentPadding,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Widget title;
  final Widget? subtitle;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: enabled
                        ? null
                        : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                  child: title,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.38),
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
