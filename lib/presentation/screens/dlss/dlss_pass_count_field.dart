import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_options.dart';
import 'dlss_parameter_slider.dart';

class DlssPassCountField extends StatelessWidget {
  const DlssPassCountField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => DlssParameterSlider(
    label: context.l10n.dlss_passes,
    description: context.l10n.dlss_passesHint,
    value: value.toDouble(),
    minimum: 1,
    maximum: DlssOptions.maximumPasses.toDouble(),
    integerOnly: true,
    sliderKey: const Key('dlss-passes'),
    onChanged: onChanged == null ? null : (value) => onChanged!(value.toInt()),
  );
}
