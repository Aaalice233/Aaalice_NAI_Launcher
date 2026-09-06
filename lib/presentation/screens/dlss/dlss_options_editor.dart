import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_options.dart';
import 'dlss_parameter_slider.dart';
import 'dlss_pass_count_field.dart';
import 'dlss_parameter_row.dart';

class DlssOptionsEditor extends StatelessWidget {
  const DlssOptionsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onReset,
  });
  final DlssOptions value;
  final ValueChanged<DlssOptions>? onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(context, l10n.dlss_processing),
            _slider(
              l10n.dlss_scale,
              l10n.dlss_scaleHint,
              value.scale,
              (v) => value.copyWith(scale: v),
              min: 1,
              max: 16384,
            ),
            DlssPassCountField(
              value: value.passes,
              onChanged: onChanged == null
                  ? null
                  : (passes) => onChanged!(value.copyWith(passes: passes)),
            ),
            const SizedBox(height: 28),
            _heading(context, l10n.dlss_appearance),
            DlssParameterRow(
              label: l10n.dlss_style,
              description: l10n.dlss_styleHint,
            ),
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
            const SizedBox(height: 8),
            _slider(
              l10n.dlss_intensity,
              '${l10n.dlss_intensityHint}\n${l10n.dlss_numericHint}',
              value.intensity,
              (v) => value.copyWith(intensity: v),
            ),
            const SizedBox(height: 16),
            _advanced(context),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onChanged == null
                    ? null
                    : onReset ?? () => onChanged!(const DlssOptions()),
                child: Text(
                  onReset == null ? l10n.common_reset : l10n.dlss_restorePreset,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _advanced(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(l10n.dlss_advanced),
        children: [
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
          const SizedBox(height: 16),
          DlssParameterRow(
            label: l10n.dlss_preset,
            description: l10n.dlss_presetHint,
          ),
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
          DlssParameterRow(
            key: const Key('dlss-auto-mask'),
            label: l10n.dlss_autoMask,
            description: l10n.dlss_autoMaskHint,
            trailing: Switch(
              value: value.autoMask,
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(value.copyWith(autoMask: v)),
            ),
          ),
          DlssParameterRow(
            key: const Key('dlss-ui-correction'),
            label: l10n.dlss_uiCorrection,
            description: l10n.dlss_uiCorrectionHint,
            trailing: Switch(
              value: value.uiCorrection,
              onChanged: onChanged == null
                  ? null
                  : (v) => onChanged!(value.copyWith(uiCorrection: v)),
            ),
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
