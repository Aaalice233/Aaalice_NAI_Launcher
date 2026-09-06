import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/services/dlss/dlss_options.dart';
import '../settings/widgets/settings_card.dart';
import 'dlss_parameter_row.dart';
import 'dlss_parameter_slider.dart';

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
            _ParameterColumns(
              children: [_processing(context), _appearance(context)],
            ),
            const SizedBox(height: 16),
            _advanced(context),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onChanged == null
                    ? null
                    : onReset ?? () => onChanged!(const DlssOptions()),
                icon: const Icon(Icons.restore, size: 18),
                label: Text(
                  onReset == null ? l10n.common_reset : l10n.dlss_restorePreset,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _processing(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCard(
      key: const Key('dlss-processing-group'),
      title: l10n.dlss_processing,
      icon: Icons.crop_free,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _slider(
          l10n.dlss_scale,
          l10n.dlss_scaleHint,
          value.scale,
          (v) => value.copyWith(scale: v),
          min: 1,
          max: 16384,
        ),
      ),
    );
  }

  Widget _appearance(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCard(
      key: const Key('dlss-appearance-group'),
      title: l10n.dlss_appearance,
      icon: Icons.tune,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              l10n.dlss_intensityHint,
              value.intensity,
              (v) => value.copyWith(intensity: v),
              max: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _advanced(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsCard(
      key: const Key('dlss-advanced-group'),
      child: ExpansionTile(
        key: const ValueKey('dlss-advanced'),
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.settings_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          context.l10n.dlss_advanced,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          _ParameterColumns(
            children: [
              _detailAndColor(context),
              _nrPreset(context),
              _localAdjustments(context),
              _modelStrengths(context),
            ],
          ),
          const SizedBox(height: 20),
          _modelSwitches(context),
        ],
      ),
    );
  }

  Widget _detailAndColor(BuildContext context) {
    final l10n = context.l10n;
    return _subsection(context, l10n.dlss_detailAndColor, [
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
    ]);
  }

  Widget _nrPreset(BuildContext context) {
    final l10n = context.l10n;
    return _subsection(context, l10n.dlss_nrModel, [
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
    ]);
  }

  Widget _localAdjustments(BuildContext context) {
    final l10n = context.l10n;
    return _subsection(context, l10n.dlss_localAdjustments, [
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
    ]);
  }

  Widget _modelStrengths(BuildContext context) {
    final l10n = context.l10n;
    return _subsection(context, l10n.dlss_modelStrengths, [
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
    ]);
  }

  Widget _modelSwitches(BuildContext context) {
    final l10n = context.l10n;
    return _subsection(context, l10n.dlss_modelSwitches, [
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
    ]);
  }

  Widget _subsection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 4),
      ...children,
    ],
  );

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

class _ParameterColumns extends StatelessWidget {
  const _ParameterColumns({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 16.0;
      final minimumWidth =
          280 * MediaQuery.textScalerOf(context).scale(14) / 14;
      final twoColumns = constraints.maxWidth >= minimumWidth * 2 + gap;
      final width = twoColumns
          ? (constraints.maxWidth - gap) / 2
          : constraints.maxWidth;
      // Keep the same children under one Wrap so width changes do not recreate
      // numeric editors, pending input, focus nodes or their inline help.
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
