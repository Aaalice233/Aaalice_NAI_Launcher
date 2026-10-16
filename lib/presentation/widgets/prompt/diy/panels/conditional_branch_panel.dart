import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

import '../../../../adaptive/interaction_policy.dart';
import '../../../../../data/models/prompt/conditional_branch.dart';
import '../../../common/elevated_card.dart';
import '../../../common/labeled_slider_rows.dart';
import '../../../common/surface_ink_well.dart';
import '../diy_badges.dart';
import '../diy_category_field.dart';
import '../diy_editor_card.dart';
import '../diy_empty_state.dart';
import '../diy_panel_header.dart';
import '../diy_rule_list_card.dart';
import '../diy_rule_list_editing.dart';
import '../diy_switch_card.dart';
import 'branch_conditions_editor.dart';

/// 条件分支面板：按概率与条件选择输出哪些词组
class ConditionalBranchPanel extends StatefulWidget {
  final ConditionalBranchConfig? config;
  final ValueChanged<ConditionalBranchConfig?> onConfigChanged;

  /// 分支可输出的词组：本词组的子词组与同类别的其他词组
  final List<DiyCategoryOption> targetOptions;

  /// 选中后会形成循环引用的词组
  final Set<String> cyclicTargetIds;

  /// 分支条件可引用的变量
  final List<BranchConditionSource> conditionSources;

  /// 打开时直接编辑的分支
  final int? initialSelectedIndex;

  final bool readOnly;

  const ConditionalBranchPanel({
    super.key,
    this.config,
    required this.onConfigChanged,
    this.targetOptions = const [],
    this.cyclicTargetIds = const {},
    this.conditionSources = const [],
    this.initialSelectedIndex,
    this.readOnly = false,
  });

  @override
  State<ConditionalBranchPanel> createState() => _ConditionalBranchPanelState();
}

class _ConditionalBranchPanelState extends State<ConditionalBranchPanel>
    with DiyRuleListEditing<ConditionalBranchPanel, ConditionalBranch> {
  late ConditionalBranchConfig _config;
  bool _usesDefaultConfig = false;

  @override
  List<ConditionalBranch> rulesOf(ConditionalBranchPanel widget) =>
      widget.config?.branches ?? const [];

  @override
  void onRulesEdited(List<ConditionalBranch> branches) {
    _config = _config.copyWith(branches: branches);
    widget.onConfigChanged(_config);
  }

  @override
  void initState() {
    super.initState();
    _usesDefaultConfig = widget.config == null;
    _config = widget.config ?? const ConditionalBranchConfig(id: '', name: '');
    final initial = widget.initialSelectedIndex;
    if (initial != null && initial >= 0 && initial < rules.length) {
      selectedIndex = initial;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_usesDefaultConfig && _config.name.isEmpty) {
      _config = _config.copyWith(name: context.l10n.diy_conditionalDefaultName);
    }
  }

  @override
  void didUpdateWidget(ConditionalBranchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _usesDefaultConfig = widget.config == null;
      _config =
          widget.config ??
          ConditionalBranchConfig(
            id: '',
            name: context.l10n.diy_conditionalDefaultName,
          );
    }
  }

  void _addBranch() {
    addRule(
      ConditionalBranch(
        name: context.l10n.diy_branchDefaultName(rules.length + 1),
        probability: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final accents = _branchAccents(colorScheme);
    final editor = buildSelectedEditor(
      (index, branch) => _BranchEditor(
        branch: branch,
        targetOptions: widget.targetOptions,
        cyclicTargetIds: widget.cyclicTargetIds,
        conditionSources: widget.conditionSources,
        readOnly: widget.readOnly,
        onChanged: (branch) => replaceRule(index, branch),
        onClose: () => selectRule(null),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiyPanelHeader(
          icon: Icons.call_split_rounded,
          accent: colorScheme.secondary,
          title: l10n.diy_conditionalTitle,
          subtitle: l10n.diy_conditionalSubtitle,
          trailing: rules.isEmpty
              ? null
              : DiyCountBadge(
                  label: l10n.diy_branchCount(rules.length),
                  accent: colorScheme.secondary,
                  container: colorScheme.secondaryContainer,
                ),
        ),
        const SizedBox(height: 12),
        if (rules.any((branch) => branch.probability > 0)) ...[
          _ProbabilityBar(
            branches: rules,
            accents: accents,
            selectedIndex: selectedIndex,
            onSelected: selectRule,
          ),
          const SizedBox(height: 12),
        ],
        DiyRuleListCard(
          items: [
            for (final (index, branch) in rules.indexed)
              _listItem(branch, accents[index % accents.length]),
          ],
          selectedIndex: selectedIndex,
          onSelected: selectRule,
          onDeleted: widget.readOnly ? null : removeRule,
          deleteTooltip: l10n.diy_deleteBranch,
          emptyState: DiyEmptyState(
            icon: Icons.call_split_rounded,
            title: l10n.diy_noConditionalBranches,
            hint: l10n.diy_noConditionalBranchesHint,
          ),
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 12),
          DiyAddRuleButton(label: l10n.diy_addBranch, onPressed: _addBranch),
        ],
        if (editor != null) ...[const SizedBox(height: 12), editor],
      ],
    );
  }

  DiyRuleListItem _listItem(ConditionalBranch branch, Color accent) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return DiyRuleListItem(
      // 放大文字后撑成胶囊而不是让读数溢出
      leading: DiyRuleAvatar(
        accent: accent,
        enabled: branch.enabled,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        builder: (foreground) => Center(
          child: Text(
            '${branch.probability}%',
            maxLines: 1,
            softWrap: false,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ),
      ),
      title: branch.name,
      enabled: branch.enabled,
      details: [
        if (branch.tagGroupIds.isNotEmpty)
          Text(
            l10n.diy_branchTargetCount(branch.tagGroupIds.length),
            style: detailStyle,
          ),
        if (branch.conditions.isNotEmpty)
          Text(
            l10n.diy_conditionCount(branch.conditions.length),
            style: detailStyle,
          ),
      ],
    );
  }
}

List<Color> _branchAccents(ColorScheme colorScheme) => [
  colorScheme.primary,
  colorScheme.secondary,
  colorScheme.tertiary,
  Colors.orange,
  Colors.purple,
  Colors.teal,
];

/// 各分支概率占比的横条，点按分段选中对应分支
class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({
    required this.branches,
    required this.accents,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ConditionalBranch> branches;
  final List<Color> accents;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final total = branches.fold<int>(0, (sum, b) => sum + b.probability);
    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // 放大文字后分段标签变高，条高度随内容增长而不是溢出
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: context.interactionPolicy.minimumControlExtent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, branch) in branches.indexed)
                  Expanded(
                    flex: branch.probability,
                    child: _segment(
                      context,
                      index: index,
                      branch: branch,
                      accent: accents[index % accents.length],
                      percent: (branch.probability / total * 100)
                          .toStringAsFixed(0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required int index,
    required ConditionalBranch branch,
    required Color accent,
    required String percent,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: '${branch.name}: $percent%',
      child: SurfaceInkWell(
        borderRadius: BorderRadius.zero,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: selectedIndex == index
              ? [accent, accent.withValues(alpha: 0.7)]
              : [accent.withValues(alpha: 0.6), accent.withValues(alpha: 0.4)],
        ),
        duration: const Duration(milliseconds: 200),
        onTap: () => onSelected(index),
        child: Center(
          child: branch.probability >= 10
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      branch.name,
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$percent%',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

class _BranchEditor extends StatelessWidget {
  const _BranchEditor({
    required this.branch,
    required this.targetOptions,
    required this.cyclicTargetIds,
    required this.conditionSources,
    required this.readOnly,
    required this.onChanged,
    required this.onClose,
  });

  final ConditionalBranch branch;
  final List<DiyCategoryOption> targetOptions;
  final Set<String> cyclicTargetIds;
  final List<BranchConditionSource> conditionSources;
  final bool readOnly;
  final ValueChanged<ConditionalBranch> onChanged;
  final VoidCallback onClose;

  static String _probabilityText(double probability) =>
      '${probability.round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    return DiyEditorCard(
      title: l10n.diy_editBranch(branch.name),
      accent: colorScheme.primary,
      accentContainer: colorScheme.primaryContainer,
      borderEnd: colorScheme.secondary,
      onClose: onClose,
      children: [
        ThemedFormInput(
          initialValue: branch.name,
          decoration: InputDecoration(
            labelText: l10n.diy_branchName,
            prefixIcon: const Icon(Icons.label_outline_rounded),
          ),
          readOnly: readOnly,
          onChanged: (value) => onChanged(branch.copyWith(name: value)),
        ),
        const SizedBox(height: 16),
        LabeledSliderRows(
          labelStyle: theme.textTheme.titleSmall,
          valueStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.tertiary,
          ),
          sliders: [
            LabeledSlider(
              label: l10n.diy_probability,
              valueText: _probabilityText,
              value: branch.probability.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: readOnly
                  ? null
                  : (value) =>
                        onChanged(branch.copyWith(probability: value.round())),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BranchTargetsEditor(
          branch: branch,
          options: targetOptions,
          cyclicTargetIds: cyclicTargetIds,
          readOnly: readOnly,
          onChanged: (ids) => onChanged(branch.copyWith(tagGroupIds: ids)),
        ),
        const SizedBox(height: 16),
        BranchConditionsEditor(
          conditions: branch.conditions,
          logicType: branch.logicType,
          sources: conditionSources,
          readOnly: readOnly,
          onChanged: (conditions, logicType) => onChanged(
            branch.copyWith(conditions: conditions, logicType: logicType),
          ),
        ),
        const SizedBox(height: 12),
        DiySwitchCard(
          title: l10n.diy_enableBranch,
          value: branch.enabled,
          onChanged: readOnly
              ? null
              : (value) => onChanged(branch.copyWith(enabled: value)),
        ),
      ],
    );
  }
}

class _BranchTargetsEditor extends StatelessWidget {
  const _BranchTargetsEditor({
    required this.branch,
    required this.options,
    required this.cyclicTargetIds,
    required this.readOnly,
    required this.onChanged,
  });

  final ConditionalBranch branch;
  final List<DiyCategoryOption> options;
  final Set<String> cyclicTargetIds;
  final bool readOnly;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final blocksCycle = options.any(
      (option) =>
          cyclicTargetIds.contains(option.id) &&
          !branch.tagGroupIds.contains(option.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiySectionTitle(
          icon: Icons.alt_route_rounded,
          accent: colorScheme.secondary,
          container: colorScheme.secondaryContainer,
          title: l10n.diy_branchTargets,
        ),
        const SizedBox(height: 12),
        DiyCategoryMultiSelect(
          values: branch.tagGroupIds,
          options: options,
          disabledIds: cyclicTargetIds,
          disabledReason: l10n.diy_branchTargetCycle,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: options.isEmpty ? l10n.diy_branchTargetsEmpty : null,
            helperText: l10n.diy_branchTargetsHint,
            helperMaxLines: 4,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: onChanged,
        ),
        if (blocksCycle) ...[
          const SizedBox(height: 8),
          Text(
            l10n.diy_branchTargetCycleHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
