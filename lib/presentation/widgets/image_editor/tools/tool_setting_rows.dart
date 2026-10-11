import 'package:flutter/material.dart';

import '../../../adaptive/interaction_policy.dart';
import '../../../widgets/common/labeled_control_rows.dart';
import '../../../widgets/common/themed_input.dart';
import '../../../widgets/common/themed_slider.dart';

/// 工具设置行：标签、控件与可选的尾随数值
class ToolSettingRow extends LabeledControlRow {
  const ToolSettingRow({
    required super.label,
    required super.control,
    super.trailing,
  });

  /// 紧凑滑块行；传入 [controller] 时尾随为数值输入框，否则为只读数值
  ToolSettingRow.slider({
    required super.label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
    int? divisions,
    TextEditingController? controller,
    String suffix = '',
  }) : super(
         control: _ToolSlider(
           label: label,
           value: value,
           min: min,
           max: max,
           divisions: divisions,
           suffix: suffix,
           onChanged: onChanged,
         ),
         trailing: controller == null
             ? _ToolValueText(_sliderValueText(value, suffix))
             : _ToolNumberField(
                 label: label,
                 controller: controller,
                 min: min,
                 max: max,
                 onChanged: onChanged,
               ),
       );
}

// 尾随数值与滑块读屏数值共用，读出的即显示的
String _sliderValueText(double value, String suffix) =>
    '${value.round()}$suffix';

/// 成组的工具设置行：工具面板的小号标签、行距与随文字缩放的数值列
class ToolSettingRows extends StatelessWidget {
  const ToolSettingRows({
    super.key,
    required this.rows,
    this.rowPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  });

  final List<ToolSettingRow> rows;
  final EdgeInsets rowPadding;

  static const double _minLabelWidth = 60;
  static const double _trailingWidth = 50;
  static const double _minControlWidth = 120;

  @override
  Widget build(BuildContext context) {
    return LabeledControlRows(
      rows: rows,
      labelStyle: Theme.of(context).textTheme.bodySmall,
      trailingWidth: MediaQuery.textScalerOf(context).scale(_trailingWidth),
      rowPadding: rowPadding,
      minLabelWidth: _minLabelWidth,
      minControlWidth: _minControlWidth,
    );
  }
}

class _ToolSlider extends StatelessWidget {
  const _ToolSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String suffix;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final policy = context.interactionPolicy;
    return SizedBox(
      // 触屏撑足命中高度，轨道与滑块仍居中保持紧凑外观
      height: policy.shouldExposeTouchAlternatives
          ? policy.minimumControlExtent
          : null,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: NamedSlider(
          label: label,
          valueText: (value) => _sliderValueText(value, suffix),
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ToolNumberField extends StatelessWidget {
  const _ToolNumberField({
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return ThemedInput(
      controller: controller,
      semanticLabel: label,
      enabled: onChanged != null,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      onSubmitted: (text) {
        final parsed = double.tryParse(text);
        if (parsed != null && onChanged != null) {
          onChanged(parsed.clamp(min, max));
        }
      },
    );
  }
}

class _ToolValueText extends StatelessWidget {
  const _ToolValueText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
