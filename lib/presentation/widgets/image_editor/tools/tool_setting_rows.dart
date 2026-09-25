import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/common/themed_input.dart';

/// 工具设置行：标签、控件与可选的尾随数值
class ToolSettingRow {
  const ToolSettingRow({
    required this.label,
    required this.control,
    this.trailing,
  });

  /// 紧凑滑块行；传入 [controller] 时尾随为数值输入框，否则为只读数值
  ToolSettingRow.slider({
    required this.label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    TextEditingController? controller,
    String suffix = '',
  }) : control = _ToolSlider(
         value: value,
         min: min,
         max: max,
         onChanged: onChanged,
       ),
       trailing = controller == null
           ? _ToolValueText('${value.round()}$suffix')
           : _ToolNumberField(
               controller: controller,
               min: min,
               max: max,
               onChanged: onChanged,
             );

  final String label;
  final Widget control;
  final Widget? trailing;
}

/// 成组的工具设置行
///
/// 标签列按实测最宽标签对齐；控件放不下时整组改为标签独占一行。
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
    final labelStyle = Theme.of(context).textTheme.bodySmall;
    final trailingWidth = MediaQuery.textScalerOf(
      context,
    ).scale(_trailingWidth);
    final labelWidth = rows.fold(
      _minLabelWidth,
      (widest, row) =>
          math.max(widest, _singleLineWidth(context, row.label, labelStyle)),
    );
    final hasTrailing = rows.any((row) => row.trailing != null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final controlWidth =
            constraints.maxWidth -
            rowPadding.horizontal -
            labelWidth -
            (hasTrailing ? trailingWidth : 0);
        final inline = controlWidth >= _minControlWidth;
        return Column(
          children: [
            for (final row in rows)
              Padding(
                padding: rowPadding,
                child: inline
                    ? _InlineSettingRow(
                        row: row,
                        labelStyle: labelStyle,
                        labelWidth: labelWidth,
                        trailingWidth: trailingWidth,
                      )
                    : _StackedSettingRow(
                        row: row,
                        labelStyle: labelStyle,
                        trailingWidth: trailingWidth,
                      ),
              ),
          ],
        );
      },
    );
  }

  // 与 Text 的样式解析一致，测得的宽度即渲染宽度
  static double _singleLineWidth(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    var effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }
}

class _InlineSettingRow extends StatelessWidget {
  const _InlineSettingRow({
    required this.row,
    required this.labelStyle,
    required this.labelWidth,
    required this.trailingWidth,
  });

  final ToolSettingRow row;
  final TextStyle? labelStyle;
  final double labelWidth;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(row.label, style: labelStyle),
        ),
        Expanded(child: row.control),
        if (row.trailing case final trailing?)
          SizedBox(width: trailingWidth, child: trailing),
      ],
    );
  }
}

class _StackedSettingRow extends StatelessWidget {
  const _StackedSettingRow({
    required this.row,
    required this.labelStyle,
    required this.trailingWidth,
  });

  final ToolSettingRow row;
  final TextStyle? labelStyle;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.label, style: labelStyle),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: row.control),
            if (row.trailing case final trailing?)
              SizedBox(width: trailingWidth, child: trailing),
          ],
        ),
      ],
    );
  }
}

class _ToolSlider extends StatelessWidget {
  const _ToolSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    );
  }
}

class _ToolNumberField extends StatelessWidget {
  const _ToolNumberField({
    required this.controller,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ThemedInput(
      controller: controller,
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
        if (parsed != null) {
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
