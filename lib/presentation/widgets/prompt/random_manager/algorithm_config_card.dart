import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/algorithm_config.dart';
import '../../../../data/models/prompt/character_count_config.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../themes/core/layered_surface_style.dart';
import 'random_config_l10n.dart';

class AlgorithmConfigCard extends ConsumerStatefulWidget {
  const AlgorithmConfigCard({
    super.key,
    this.isPresetDefault = false,
    this.onGlobalSettings,
  });

  final bool isPresetDefault;
  final VoidCallback? onGlobalSettings;

  @override
  ConsumerState<AlgorithmConfigCard> createState() =>
      _AlgorithmConfigCardState();
}

class _AlgorithmConfigCardState extends ConsumerState<AlgorithmConfigCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final preset = ref.watch(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) return const SizedBox.shrink();

    final config = preset.algorithmConfig;
    final characterConfig = config.effectiveCharacterCountConfig;
    final countCategories = characterConfig.categories
        .where((category) => !category.isMultiPersonContainer)
        .toList(growable: false);
    final soloOptions =
        characterConfig.findCategoryById('solo')?.tagOptions ?? const [];
    final readOnly = widget.isPresetDefault || preset.isDefault;
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      key: const ValueKey('random-manager-algorithm-card'),
      decoration: BoxDecoration(
        color: sectionSurfaceColor(colors),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 19, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.randomManager_algorithmConfig,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (readOnly)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    AnimatedRotation(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      turns: _expanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _DistributionSummary(
              countCategories: countCategories,
              soloOptions: soloOptions,
            ),
          ),
          if (widget.onGlobalSettings != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: readOnly ? null : widget.onGlobalSettings,
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  label: Text(context.l10n.randomManager_globalPeopleSettings),
                ),
              ),
            ),
          AnimatedSize(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _ExpandedConfig(
                    preset: preset,
                    config: config,
                    countCategories: countCategories,
                    soloOptions: soloOptions,
                    readOnly: readOnly,
                    onCountWeightChanged: (id, value) =>
                        _updateCharacterCountCategoryWeight(preset, id, value),
                    onGenderWeightChanged: (categoryId, optionId, value) =>
                        _updateCharacterTagOptionWeight(
                          preset,
                          categoryId,
                          optionId,
                          value,
                        ),
                    onConfigChanged: (value) => _updateConfig(preset, value),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  void _updateCharacterCountCategoryWeight(
    RandomPreset preset,
    String categoryId,
    int newWeight,
  ) {
    final config = preset.algorithmConfig;
    final characterConfig = config.effectiveCharacterCountConfig;
    final categories = characterConfig.categories.map((category) {
      return category.id == categoryId
          ? category.copyWith(weight: newWeight)
          : category;
    }).toList();
    _updateConfig(
      preset,
      config.copyWith(
        characterCountConfig: characterConfig.copyWith(categories: categories),
      ),
    );
  }

  void _updateCharacterTagOptionWeight(
    RandomPreset preset,
    String categoryId,
    String optionId,
    int newWeight,
  ) {
    final config = preset.algorithmConfig;
    final characterConfig = config.effectiveCharacterCountConfig;
    final categories = characterConfig.categories.map((category) {
      if (category.id != categoryId) return category;
      return category.copyWith(
        tagOptions: category.tagOptions.map((option) {
          return option.id == optionId
              ? option.copyWith(weight: newWeight.clamp(1, 100))
              : option;
        }).toList(),
      );
    }).toList();
    _updateConfig(
      preset,
      config.copyWith(
        characterCountConfig: characterConfig.copyWith(categories: categories),
      ),
    );
  }

  void _updateConfig(RandomPreset preset, AlgorithmConfig config) {
    ref
        .read(randomPresetNotifierProvider.notifier)
        .updatePreset(preset.updateAlgorithmConfig(config));
  }
}

class _DistributionSummary extends StatelessWidget {
  const _DistributionSummary({
    required this.countCategories,
    required this.soloOptions,
  });

  final List<CharacterCountCategory> countCategories;
  final List<CharacterTagOption> soloOptions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final countTotal = countCategories.fold<int>(
      0,
      (total, category) => total + category.weight,
    );
    final genderTotal = soloOptions.fold<int>(
      0,
      (total, option) => total + option.weight,
    );

    return Column(
      children: [
        _SegmentBar(
          values: countCategories.map((item) => item.weight).toList(),
          total: countTotal,
          colors: [
            colors.primary,
            colors.secondary,
            colors.tertiary,
            colors.onSurfaceVariant,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                countCategories
                    .take(4)
                    .map(
                      (category) =>
                          '${context.l10n.characterCountLabel(category)} ${category.weight}',
                    )
                    .join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (genderTotal > 0) ...[
              const SizedBox(width: 8),
              Icon(Icons.wc_rounded, size: 14, color: colors.onSurfaceVariant),
              const SizedBox(width: 3),
              Text(
                genderTotal.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.values,
    required this.total,
    required this.colors,
  });

  final List<int> values;
  final int total;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        child: total <= 0
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              )
            : Row(
                children: [
                  for (var index = 0; index < values.length; index++)
                    if (values[index] > 0)
                      Expanded(
                        flex: values[index],
                        child: ColoredBox(color: colors[index % colors.length]),
                      ),
                ],
              ),
      ),
    );
  }
}

class _ExpandedConfig extends StatelessWidget {
  const _ExpandedConfig({
    required this.preset,
    required this.config,
    required this.countCategories,
    required this.soloOptions,
    required this.readOnly,
    required this.onCountWeightChanged,
    required this.onGenderWeightChanged,
    required this.onConfigChanged,
  });

  final RandomPreset preset;
  final AlgorithmConfig config;
  final List<CharacterCountCategory> countCategories;
  final List<CharacterTagOption> soloOptions;
  final bool readOnly;
  final void Function(String id, int value) onCountWeightChanged;
  final void Function(String categoryId, String optionId, int value)
  onGenderWeightChanged;
  final ValueChanged<AlgorithmConfig> onConfigChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final soloCategoryId = config.effectiveCharacterCountConfig
        .findCategoryById('solo')
        ?.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            color: colors.outlineVariant.withValues(alpha: 0.18),
            height: 1,
          ),
          const SizedBox(height: 14),
          _SectionLabel(
            icon: Icons.people_outline_rounded,
            label: context.l10n.randomManager_characterCountWeight,
          ),
          const SizedBox(height: 8),
          ...countCategories.map(
            (category) => _WeightSlider(
              label: context.l10n.characterCountLabel(category),
              value: category.weight,
              enabled: !readOnly,
              onChanged: (value) => onCountWeightChanged(category.id, value),
            ),
          ),
          if (soloCategoryId != null && soloOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel(
              icon: Icons.wc_rounded,
              label: context.l10n.randomManager_genderWeight,
            ),
            const SizedBox(height: 8),
            ...soloOptions.map(
              (option) => _WeightSlider(
                label: context.l10n.characterTagOptionLabel(option),
                value: option.weight,
                enabled: !readOnly,
                onChanged: (value) =>
                    onGenderWeightChanged(soloCategoryId, option.id, value),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(context.l10n.randomManager_enableSeasonalWordlists),
            subtitle: Text(
              context.l10n.randomManager_enableSeasonalWordlistsDesc,
            ),
            value: config.enableSeasonalWordlists,
            onChanged: readOnly
                ? null
                : (value) => onConfigChanged(
                    config.copyWith(enableSeasonalWordlists: value),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.randomManager_globalEmphasisProbability,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              SizedBox(
                width: 140,
                child: Slider(
                  value: config.globalEmphasisProbability.clamp(0, 0.1),
                  min: 0,
                  max: 0.1,
                  divisions: 10,
                  onChanged: readOnly
                      ? null
                      : (value) => onConfigChanged(
                          config.copyWith(globalEmphasisProbability: value),
                        ),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${(config.globalEmphasisProbability * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _WeightSlider extends StatelessWidget {
  const _WeightSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(1, 100).toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: enabled ? (next) => onChanged(next.round()) : null,
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            value.toString(),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
