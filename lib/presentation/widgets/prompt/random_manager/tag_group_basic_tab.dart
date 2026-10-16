import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/prompt/random_tag_group.dart';
import '../../common/labeled_control_rows.dart';
import '../../common/labeled_slider_rows.dart';
import '../../common/themed_input.dart';
import 'probability_text.dart';

/// 词组编辑面板的基础页：名称、出现概率与选择模式
class TagGroupBasicTab extends StatelessWidget {
  const TagGroupBasicTab({
    super.key,
    required this.group,
    required this.nameController,
    required this.readOnly,
    required this.onChanged,
  });

  final RandomTagGroup group;
  final TextEditingController nameController;
  final bool readOnly;
  final ValueChanged<RandomTagGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThemedInput(
            controller: nameController,
            enabled: !readOnly,
            decoration: InputDecoration(
              labelText: l10n.randomManager_tagGroupName,
              suffixIcon: readOnly
                  ? Icon(
                      Icons.lock_outline,
                      color: theme.colorScheme.outline,
                      size: 18,
                    )
                  : null,
            ),
            onChanged: readOnly
                ? null
                : (value) => onChanged(group.copyWith(name: value)),
          ),
          const SizedBox(height: 16),
          LabeledSliderRows(
            labelStyle: labelStyle,
            valueStyle: labelStyle?.copyWith(fontWeight: FontWeight.bold),
            sliders: [
              LabeledSlider(
                label: l10n.randomManager_probability,
                valueText: formatProbabilityPercent,
                value: group.probability,
                divisions: 20,
                onChanged: readOnly
                    ? null
                    : (value) => onChanged(group.copyWith(probability: value)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LabeledControlRows(
            labelStyle: labelStyle,
            columnGap: 16,
            rows: [
              LabeledControlRow(
                label: l10n.randomManager_selectionMode,
                control: _SelectionModeDropdown(
                  value: group.selectionMode,
                  onChanged: readOnly
                      ? null
                      : (mode) =>
                            onChanged(group.copyWith(selectionMode: mode)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionModeDropdown extends StatelessWidget {
  const _SelectionModeDropdown({required this.value, required this.onChanged});

  final SelectionMode value;
  final ValueChanged<SelectionMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onChanged = this.onChanged;
    return DropdownButton<SelectionMode>(
      value: value,
      isExpanded: true,
      items: [
        for (final mode in SelectionMode.values)
          DropdownMenuItem(value: mode, child: Text(_label(l10n, mode))),
      ],
      onChanged: onChanged == null
          ? null
          : (mode) {
              if (mode != null) onChanged(mode);
            },
    );
  }

  static String _label(AppLocalizations l10n, SelectionMode mode) {
    final (label, description) = switch (mode) {
      SelectionMode.single => (
        l10n.randomManager_selectionSingle,
        l10n.randomManager_selectionSingleDesc,
      ),
      SelectionMode.all => (
        l10n.randomManager_selectionAll,
        l10n.randomManager_selectionAllDesc,
      ),
      SelectionMode.multipleNum => (
        l10n.randomManager_selectionMultipleCount,
        l10n.randomManager_selectionMultipleCountDesc,
      ),
      SelectionMode.multipleProb => (
        l10n.randomManager_selectionMultipleProbability,
        l10n.randomManager_selectionMultipleProbabilityDesc,
      ),
      SelectionMode.sequential => (
        l10n.randomManager_selectionSequential,
        l10n.randomManager_selectionSequentialDesc,
      ),
    };
    return '$label - $description';
  }
}
