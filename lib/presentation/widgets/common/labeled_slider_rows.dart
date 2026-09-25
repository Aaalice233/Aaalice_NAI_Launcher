import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/single_line_text_width.dart';
import 'editable_double_field.dart';
import 'labeled_control_rows.dart';
import 'themed_slider.dart';

/// 一条带行内读数的滑块；读数与读屏共用 [valueText]，[onChanged] 为空时整行禁用
class LabeledSlider {
  const LabeledSlider({
    required this.label,
    required this.value,
    required this.valueText,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
  }) : input = null;

  /// 读数为可输入的数值框；[inputMin]、[inputMax] 为空时输入不受滑块范围限制
  LabeledSlider.editable({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    int decimals = EditableDoubleField.defaultDecimals,
    Key? inputKey,
    double? inputMin,
    double? inputMax,
    double inputWidth = 64,
  }) : valueText = ((value) =>
           EditableDoubleField.format(value, decimals: decimals)),
       input = LabeledSliderInput._(
         key: inputKey,
         decimals: decimals,
         min: inputMin,
         max: inputMax,
         width: inputWidth,
       );

  final String label;
  final double value;
  final String Function(double value) valueText;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChangeStart;
  final LabeledSliderInput? input;
}

/// [LabeledSlider.editable] 的数值框配置
class LabeledSliderInput {
  const LabeledSliderInput._({
    required this.key,
    required this.decimals,
    required this.min,
    required this.max,
    required this.width,
  });

  final Key? key;
  final int decimals;
  final double? min;
  final double? max;
  final double width;
}

/// 成组的标签滑块：标签列与读数列各自对齐
///
/// 读数列按各行取值范围两端与当前值中最宽的读数定宽，拖动时滑块轨道长度不变。
class LabeledSliderRows extends StatelessWidget {
  const LabeledSliderRows({
    super.key,
    required this.sliders,
    this.labelStyle,
    this.valueStyle,
    this.rowPadding = EdgeInsets.zero,
  });

  static const _tabularFigures = [FontFeature.tabularFigures()];

  final List<LabeledSlider> sliders;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final EdgeInsets rowPadding;

  @override
  Widget build(BuildContext context) {
    final readoutStyle = (valueStyle ?? const TextStyle()).copyWith(
      fontFeatures: _tabularFigures,
    );
    // 未指定样式时数值框保持自身默认字号
    final inputStyle = valueStyle == null ? null : readoutStyle;
    return LabeledControlRows(
      labelStyle: labelStyle,
      trailingWidth: sliders.fold(
        0.0,
        (widest, slider) => math.max(
          widest,
          _readoutWidth(context, slider, readoutStyle, inputStyle),
        ),
      ),
      rowPadding: rowPadding,
      rows: [
        for (final slider in sliders)
          LabeledControlRow(
            label: slider.label,
            control: NamedSlider(
              label: slider.label,
              valueText: slider.valueText,
              value: slider.value,
              min: slider.min,
              max: slider.max,
              divisions: slider.divisions,
              onChangeStart: slider.onChangeStart,
              onChanged: slider.onChanged,
            ),
            trailing: _readout(slider, readoutStyle, inputStyle),
          ),
      ],
    );
  }

  double _readoutWidth(
    BuildContext context,
    LabeledSlider slider,
    TextStyle readoutStyle,
    TextStyle? inputStyle,
  ) {
    final input = slider.input;
    return [slider.min, slider.max, slider.value].fold(0.0, (widest, sample) {
      final text = slider.valueText(sample);
      return math.max(
        widest,
        input == null
            ? singleLineTextWidth(context, text, readoutStyle)
            : EditableDoubleField.widthFor(
                context,
                text,
                textStyle: inputStyle,
                minWidth: input.width,
              ),
      );
    });
  }

  Widget _readout(
    LabeledSlider slider,
    TextStyle readoutStyle,
    TextStyle? inputStyle,
  ) {
    final input = slider.input;
    if (input == null) {
      return Text(
        slider.valueText(slider.value),
        style: readoutStyle,
        textAlign: TextAlign.end,
        maxLines: 1,
        softWrap: false,
      );
    }
    final onChanged = slider.onChanged;
    return EditableDoubleField(
      key: input.key,
      value: slider.value,
      semanticLabel: slider.label,
      min: input.min,
      max: input.max,
      decimals: input.decimals,
      width: input.width,
      enabled: onChanged != null,
      textStyle: inputStyle,
      onChanged: onChanged ?? _ignoreValue,
    );
  }

  static void _ignoreValue(double _) {}
}
