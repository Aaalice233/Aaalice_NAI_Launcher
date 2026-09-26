import 'package:flutter/material.dart';

/// 所有滑块的共享底座：读屏名称写进滑块自身语义节点，读数与界面数值一致。
///
/// [valueText] 应与页面上显示当前值的文本共用同一个格式化函数。
class NamedSlider extends StatelessWidget {
  const NamedSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.padding,
  });

  final String label;
  final String Function(double value) valueText;
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        tickMarkShape: SliderTickMarkShape.noTickMark,
        // label 已是读屏名称，画成气泡就成了把名称当数值显示
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        padding: padding,
        // 3.44 起滑块自成语义节点，外包 Semantics 只会标到外层容器
        label: label,
        // 默认按区间读百分比，与界面数值不一致
        semanticFormatterCallback: valueText,
        onChanged: onChanged,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// 项目统一滑块。
///
/// 在 [NamedSlider] 上叠加项目外观，页面仅配置数值与语义颜色。
class ThemedSlider extends StatelessWidget {
  const ThemedSlider({
    super.key,
    required this.label,
    required this.valueText,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.trackHeight = 6,
    this.thumbSize = 18,
  });

  final String label;
  final String Function(double value) valueText;
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
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
        thumbShape: RoundSliderThumbShape(
          enabledThumbRadius: thumbSize / 2,
          disabledThumbRadius: thumbSize / 2,
        ),
      ),
      child: NamedSlider(
        label: label,
        valueText: valueText,
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: effectiveOnChanged,
        onChangeStart: effectiveOnChanged == null ? null : onChangeStart,
        onChangeEnd: effectiveOnChanged == null ? null : onChangeEnd,
      ),
    );
  }
}
