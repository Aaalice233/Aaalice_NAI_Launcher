import 'package:flutter/material.dart';

import '../../../../widgets/common/editable_double_field.dart';
import '../../../../widgets/common/themed_slider.dart';
import 'precise_reference_strength_scale.dart';

class PreciseReferenceSliderRow extends StatelessWidget {
  const PreciseReferenceSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maximum = 1,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final position = preciseReferenceStrengthPosition(value, maximum);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(flex: 2, child: Text(label, style: style)),
            Flexible(
              child: EditableDoubleField(
                value: value,
                semanticLabel: label,
                width: 64,
                onChanged: onChanged,
                textStyle: style?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: NamedSlider(
            label: label,
            valueText: (position) => EditableDoubleField.format(
              preciseReferenceStrengthAtPosition(position, maximum),
            ),
            value: position,
            divisions: maximum == 1 ? 20 : null,
            onChanged: (position) => onChanged(
              preciseReferenceStrengthAtPosition(position, maximum),
            ),
          ),
        ),
      ],
    );
  }
}
