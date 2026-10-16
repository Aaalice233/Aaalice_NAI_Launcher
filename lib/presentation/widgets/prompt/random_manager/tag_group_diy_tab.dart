import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../common/labeled_slider_rows.dart';
import 'probability_text.dart';
import 'tag_group_diy_section.dart';

/// 词组可配置的 DIY 能力，各自在独立表单中编辑
enum TagGroupDiyAbility {
  conditionalBranch(Icons.call_split),
  dependency(Icons.link),
  visibility(Icons.visibility),
  time(Icons.calendar_today),
  postProcess(Icons.build);

  const TagGroupDiyAbility(this.icon);

  final IconData icon;

  String title(AppLocalizations l10n) => switch (this) {
    conditionalBranch => l10n.randomManager_conditionalBranch,
    dependency => l10n.randomManager_dependencyConfig,
    visibility => l10n.randomManager_visibilityRules,
    time => l10n.randomManager_timeCondition,
    postProcess => l10n.randomManager_postProcessRules,
  };

  String description(AppLocalizations l10n) => switch (this) {
    conditionalBranch => l10n.randomManager_conditionalBranchDesc,
    dependency => l10n.randomManager_dependencyConfigDesc,
    visibility => l10n.randomManager_visibilityRulesDesc,
    time => l10n.randomManager_timeConditionDesc,
    postProcess => l10n.randomManager_postProcessRulesDesc,
  };

  bool isConfiguredIn(RandomTagGroup group) => switch (this) {
    conditionalBranch => group.hasConditionalBranch,
    dependency => group.hasDependency,
    visibility => group.hasVisibilityRules,
    time => group.hasTimeCondition,
    postProcess => group.hasPostProcessRules,
  };
}

/// 词组编辑面板的 DIY 页：各项能力的入口与强调概率；默认预设只说明不可用
class TagGroupDiyTab extends StatelessWidget {
  const TagGroupDiyTab({
    super.key,
    required this.group,
    required this.readOnly,
    required this.onOpen,
    required this.onChanged,
  });

  final RandomTagGroup group;
  final bool readOnly;
  final ValueChanged<TagGroupDiyAbility> onOpen;
  final ValueChanged<RandomTagGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    if (readOnly) return const _DiyUnavailableNotice();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final ability in TagGroupDiyAbility.values) ...[
            TagGroupDiySection(
              icon: ability.icon,
              title: ability.title(l10n),
              description: ability.description(l10n),
              enabled: ability.isConfiguredIn(group),
              onOpen: () => onOpen(ability),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          _EmphasisProbability(
            value: group.emphasisProbability,
            onChanged: (value) =>
                onChanged(group.copyWith(emphasisProbability: value)),
          ),
        ],
      ),
    );
  }
}

class _DiyUnavailableNotice extends StatelessWidget {
  const _DiyUnavailableNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              l10n.diyNotAvailableForDefault,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.diyNotAvailableHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmphasisProbability extends StatelessWidget {
  const _EmphasisProbability({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: controlSurfaceColor(colorScheme),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, size: 18, color: colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: colorScheme.tertiary,
                inactiveTrackColor: colorScheme.tertiaryContainer.withValues(
                  alpha: 0.3,
                ),
                thumbColor: colorScheme.tertiary,
                overlayColor: colorScheme.tertiary.withValues(alpha: 0.1),
              ),
              child: LabeledSliderRows(
                labelStyle: theme.textTheme.bodyMedium,
                valueStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary,
                ),
                sliders: [
                  LabeledSlider(
                    label: l10n.randomManager_emphasisProbability,
                    valueText: formatProbabilityPercent,
                    value: value,
                    max: 0.1,
                    divisions: 10,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
