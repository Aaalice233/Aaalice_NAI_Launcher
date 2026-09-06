import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_options.dart';
import 'dlss_parameter_row.dart';

class DlssPassCountField extends StatelessWidget {
  const DlssPassCountField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DlssParameterRow(
        label: context.l10n.dlss_passes,
        description: context.l10n.dlss_passesHint,
        trailing: Text('$value', textAlign: TextAlign.end),
      ),
      Slider(
        key: const Key('dlss-passes'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        value: value.toDouble(),
        min: 1,
        max: DlssOptions.maximumPasses.toDouble(),
        divisions: DlssOptions.maximumPasses - 1,
        label: '$value',
        semanticFormatterCallback: (value) =>
            '${context.l10n.dlss_passes}: ${value.round()}',
        onChanged: onChanged == null
            ? null
            : (value) => onChanged!(value.round()),
      ),
    ],
  );
}
