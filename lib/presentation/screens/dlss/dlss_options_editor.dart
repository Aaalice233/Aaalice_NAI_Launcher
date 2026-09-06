import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_options.dart';

class DlssOptionsEditor extends StatelessWidget {
  const DlssOptionsEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final DlssOptions value;
  final ValueChanged<DlssOptions>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.dlss_style),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              'default': l10n.dlss_styleDefault,
              'natural': l10n.dlss_styleNatural,
              'cinematic': l10n.dlss_styleCinematic,
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: value.style == entry.key,
                onSelected: onChanged == null
                    ? null
                    : (_) => onChanged!(value.copyWith(style: entry.key)),
              ),
          ],
        ),
        _slider(
          l10n.dlss_intensity,
          value.intensity,
          (v) => value.copyWith(intensity: v),
        ),
        _slider(
          l10n.dlss_detail,
          value.detail,
          (v) => value.copyWith(detail: v),
        ),
        _slider(l10n.dlss_color, value.color, (v) => value.copyWith(color: v)),
        Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            title: Text(l10n.dlss_advanced),
            children: [
              _slider(
                l10n.dlss_structure,
                value.localStructure,
                (v) => value.copyWith(localStructure: v),
              ),
              _slider(
                l10n.dlss_tone,
                value.localTone,
                (v) => value.copyWith(localTone: v),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onChanged == null
                ? null
                : () => onChanged!(const DlssOptions()),
            child: Text(l10n.common_reset),
          ),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    DlssOptions Function(double) update,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      Text('$label  ${value.toStringAsFixed(2)}'),
      Slider(
        value: value,
        divisions: 20,
        label: value.toStringAsFixed(2),
        onChanged: onChanged == null ? null : (v) => onChanged!(update(v)),
      ),
    ],
  );
}
