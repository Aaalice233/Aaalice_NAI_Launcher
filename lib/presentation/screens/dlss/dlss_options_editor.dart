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
        _slider(
          l10n.dlss_color,
          value.color,
          (v) => value.copyWith(color: v),
          max: 1,
        ),
        _advanced(context),
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

  Widget _advanced(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        title: Text(l10n.dlss_advanced),
        children: [
          Text(l10n.dlss_preset),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var preset = 0; preset <= 3; preset++)
                ChoiceChip(
                  label: Text(preset == 0 ? l10n.dlss_styleDefault : '$preset'),
                  selected: value.preset == preset,
                  onSelected: onChanged == null
                      ? null
                      : (_) => onChanged!(value.copyWith(preset: preset)),
                ),
            ],
          ),
          Text(l10n.dlss_presetHint),
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
          _slider(
            l10n.dlss_skin,
            value.skin,
            (v) => value.copyWith(skin: v),
            min: -1,
            valueLabel: value.skin < 0 ? l10n.dlss_modelDefault : null,
          ),
          _slider(
            l10n.dlss_globalTone,
            value.globalTone,
            (v) => value.copyWith(globalTone: v),
            min: -1,
            valueLabel: value.globalTone < 0 ? l10n.dlss_modelDefault : null,
          ),
          Text(l10n.dlss_modelDefaultHint),
          SwitchListTile(
            key: const Key('dlss-auto-mask'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dlss_autoMask),
            value: value.autoMask,
            onChanged: onChanged == null
                ? null
                : (v) => onChanged!(value.copyWith(autoMask: v)),
          ),
          SwitchListTile(
            key: const Key('dlss-ui-correction'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dlss_uiCorrection),
            subtitle: Text(l10n.dlss_modelSwitchesHint),
            value: value.uiCorrection,
            onChanged: onChanged == null
                ? null
                : (v) => onChanged!(value.copyWith(uiCorrection: v)),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    DlssOptions Function(double) update, {
    double max = 2,
    double min = 0,
    String? valueLabel,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      Text('$label  ${valueLabel ?? value.toStringAsFixed(2)}'),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: ((max - min) / 0.05).round(),
        label: valueLabel ?? value.toStringAsFixed(2),
        onChanged: onChanged == null ? null : (v) => onChanged!(update(v)),
      ),
    ],
  );
}
