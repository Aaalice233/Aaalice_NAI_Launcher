import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_options.dart';
import 'dlss_parameter_slider.dart';
import 'dlss_pass_count_field.dart';

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
        DlssPassCountField(
          value: value.passes,
          onChanged: onChanged == null
              ? null
              : (passes) => onChanged!(value.copyWith(passes: passes)),
        ),
        _slider(
          l10n.dlss_scale,
          l10n.dlss_scaleHint,
          value.scale,
          (v) => value.copyWith(scale: v),
          min: 1,
          max: 16384,
        ),
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
        Text(l10n.dlss_styleHint),
        const SizedBox(height: 8),
        Text(l10n.dlss_numericHint),
        _slider(
          l10n.dlss_intensity,
          l10n.dlss_intensityHint,
          value.intensity,
          (v) => value.copyWith(intensity: v),
        ),
        _slider(
          l10n.dlss_detail,
          l10n.dlss_detailHint,
          value.detail,
          (v) => value.copyWith(detail: v),
        ),
        _slider(
          l10n.dlss_color,
          l10n.dlss_colorHint,
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
            l10n.dlss_structureHint,
            value.localStructure,
            (v) => value.copyWith(localStructure: v),
          ),
          _slider(
            l10n.dlss_tone,
            l10n.dlss_toneHint,
            value.localTone,
            (v) => value.copyWith(localTone: v),
          ),
          _slider(
            l10n.dlss_skin,
            l10n.dlss_skinHint,
            value.skin,
            (v) => value.copyWith(skin: v),
            min: -1,
            valueLabel: value.skin < 0 ? l10n.dlss_modelDefault : null,
          ),
          _slider(
            l10n.dlss_globalTone,
            l10n.dlss_globalToneHint,
            value.globalTone,
            (v) => value.copyWith(globalTone: v),
            min: -1,
            valueLabel: value.globalTone < 0 ? l10n.dlss_modelDefault : null,
          ),
          SwitchListTile(
            key: const Key('dlss-auto-mask'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dlss_autoMask),
            subtitle: Text(l10n.dlss_autoMaskHint),
            value: value.autoMask,
            onChanged: onChanged == null
                ? null
                : (v) => onChanged!(value.copyWith(autoMask: v)),
          ),
          SwitchListTile(
            key: const Key('dlss-ui-correction'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dlss_uiCorrection),
            subtitle: Text(l10n.dlss_uiCorrectionHint),
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
    String description,
    double value,
    DlssOptions Function(double) update, {
    double? max,
    double min = 0,
    String? valueLabel,
  }) => DlssParameterSlider(
    label: label,
    description: description,
    value: value,
    minimum: min,
    maximum: max,
    valueLabel: valueLabel,
    onChanged: onChanged == null ? null : (v) => onChanged!(update(v)),
  );
}
