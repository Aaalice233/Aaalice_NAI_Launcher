import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

import '../../../../../data/models/prompt/visibility_rule.dart';
import '../diy_badges.dart';
import '../diy_category_field.dart';
import '../diy_editor_card.dart';
import '../diy_empty_state.dart';
import '../diy_panel_header.dart';
import '../diy_rule_list_card.dart';
import '../diy_switch_card.dart';

/// 可见性规则面板：按源类别的取值决定目标类别或本词组是否出现
class VisibilityRulePanel extends StatefulWidget {
  final List<VisibilityRule> rules;
  final ValueChanged<List<VisibilityRule>> onRulesChanged;
  final List<DiyCategoryOption> categoryOptions;

  /// 规则所属词组的 ID；目标选它时规则只控制该词组
  final String? ownerGroupId;

  final bool readOnly;

  const VisibilityRulePanel({
    super.key,
    required this.rules,
    required this.onRulesChanged,
    this.categoryOptions = const [],
    this.ownerGroupId,
    this.readOnly = false,
  });

  @override
  State<VisibilityRulePanel> createState() => _VisibilityRulePanelState();
}

class _VisibilityRulePanelState extends State<VisibilityRulePanel> {
  // 弹出的表单路由不随父级重建，面板自己持有正在编辑的规则
  late List<VisibilityRule> _rules;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _rules = widget.rules;
  }

  @override
  void didUpdateWidget(VisibilityRulePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.rules, _rules)) {
      _rules = widget.rules;
      if ((_selectedIndex ?? 0) >= _rules.length) _selectedIndex = null;
    }
  }

  void _setRules(List<VisibilityRule> rules, {int? selectedIndex}) {
    setState(() {
      _rules = rules;
      _selectedIndex = selectedIndex;
    });
    widget.onRulesChanged(rules);
  }

  void _removeRule(int index) {
    final selected = _selectedIndex;
    _setRules(
      List<VisibilityRule>.from(_rules)..removeAt(index),
      selectedIndex: selected == null || selected == index
          ? null
          : selected > index
          ? selected - 1
          : selected,
    );
  }

  void _updateRule(int index, VisibilityRule rule) {
    final newRules = List<VisibilityRule>.from(_rules);
    newRules[index] = rule;
    _setRules(newRules, selectedIndex: _selectedIndex);
  }

  void _addRule() {
    final newRule = VisibilityRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: context.l10n.diy_ruleDefaultName(_rules.length + 1),
      targetCategoryId: '',
      sourceCategoryId: '',
      conditionValue: '',
    );
    _setRules([..._rules, newRule], selectedIndex: _rules.length);
  }

  // 目标为类别时作用于该类别全部词组，目标为本词组时只控制规则所属的词组
  List<DiyCategoryOption> get _targetOptions {
    final ownerGroupId = widget.ownerGroupId;
    return [
      if (ownerGroupId != null && ownerGroupId.isNotEmpty)
        DiyCategoryOption(
          id: ownerGroupId,
          label: context.l10n.diy_targetCurrentGroup,
        ),
      ...widget.categoryOptions,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final index = _selectedIndex;
    final editor = index == null || index >= _rules.length
        ? null
        // 输入框只在创建时读取初始值，切换规则需要重建编辑区
        : KeyedSubtree(
            key: ValueKey(index),
            child: _VisibilityRuleEditor(
              rule: _rules[index],
              sourceOptions: widget.categoryOptions,
              targetOptions: _targetOptions,
              readOnly: widget.readOnly,
              onChanged: (rule) => _updateRule(index, rule),
              onClose: () => setState(() => _selectedIndex = null),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiyPanelHeader(
          icon: Icons.visibility_rounded,
          accent: colorScheme.secondary,
          title: l10n.diy_visibilityTitle,
          subtitle: l10n.diy_visibilitySubtitle,
          trailing: _rules.isEmpty
              ? null
              : DiyCountBadge(
                  label: l10n.diy_ruleCount(_rules.length),
                  accent: colorScheme.secondary,
                  container: colorScheme.secondaryContainer,
                ),
        ),
        const SizedBox(height: 12),
        DiyRuleListCard(
          items: [for (final rule in _rules) _listItem(rule)],
          selectedIndex: _selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
          onDeleted: widget.readOnly ? null : _removeRule,
          deleteTooltip: l10n.diy_deleteRule,
          emptyState: DiyEmptyState(
            icon: Icons.visibility_off_rounded,
            title: l10n.diy_noVisibilityRules,
            hint: l10n.diy_noVisibilityRulesHint,
          ),
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 12),
          DiyAddRuleButton(label: l10n.diy_addRule, onPressed: _addRule),
        ],
        if (editor != null) ...[const SizedBox(height: 12), editor],
      ],
    );
  }

  DiyRuleListItem _listItem(VisibilityRule rule) {
    final colorScheme = Theme.of(context).colorScheme;
    return DiyRuleListItem(
      leading: DiyRuleAvatar(
        accent: rule.visibleWhenMatched
            ? colorScheme.primary
            : colorScheme.tertiary,
        enabled: rule.enabled,
        builder: (foreground) => Icon(
          rule.visibleWhenMatched
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          size: 18,
          color: foreground,
        ),
      ),
      title: rule.name,
      enabled: rule.enabled,
      details: [
        _CategoryRoute(
          source: _categoryLabel(rule.sourceCategoryId, widget.categoryOptions),
          target: _categoryLabel(rule.targetCategoryId, _targetOptions),
        ),
      ],
    );
  }

  String _categoryLabel(String reference, List<DiyCategoryOption> options) {
    if (reference.isEmpty) return context.l10n.diy_notSet;
    for (final option in options) {
      if (option.id == reference) return option.label;
    }
    return context.l10n.diy_categoryUnavailable(reference);
  }
}

/// 列表条目上的“源类别 → 目标”摘要
class _CategoryRoute extends StatelessWidget {
  const _CategoryRoute({required this.source, required this.target});

  final String source;
  final String target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    Widget chip(String label, Color container, Color foreground) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: container.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(source, colorScheme.primaryContainer, colorScheme.primary),
        Icon(
          Icons.arrow_forward_rounded,
          size: 12,
          color: colorScheme.onSurfaceVariant,
        ),
        chip(target, colorScheme.secondaryContainer, colorScheme.secondary),
      ],
    );
  }
}

class _VisibilityRuleEditor extends StatelessWidget {
  const _VisibilityRuleEditor({
    required this.rule,
    required this.sourceOptions,
    required this.targetOptions,
    required this.readOnly,
    required this.onChanged,
    required this.onClose,
  });

  final VisibilityRule rule;
  final List<DiyCategoryOption> sourceOptions;
  final List<DiyCategoryOption> targetOptions;
  final bool readOnly;
  final ValueChanged<VisibilityRule> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final fieldIconColor = colorScheme.onSurfaceVariant;
    return DiyEditorCard(
      title: l10n.diy_editRule,
      accent: colorScheme.secondary,
      accentContainer: colorScheme.secondaryContainer,
      borderEnd: colorScheme.primary,
      onClose: onClose,
      children: [
        ThemedFormInput(
          initialValue: rule.name,
          decoration: InputDecoration(
            labelText: l10n.diy_ruleName,
            prefixIcon: Icon(
              Icons.label_outline_rounded,
              color: fieldIconColor,
            ),
          ),
          readOnly: readOnly,
          onChanged: (value) => onChanged(rule.copyWith(name: value)),
        ),
        const SizedBox(height: 16),
        _categoryDropdown(
          label: l10n.diy_sourceCategory,
          icon: Icons.folder_outlined,
          iconColor: fieldIconColor,
          value: rule.sourceCategoryId,
          options: sourceOptions,
          onChanged: (value) =>
              onChanged(rule.copyWith(sourceCategoryId: value)),
        ),
        const SizedBox(height: 16),
        _categoryDropdown(
          label: l10n.diy_targetCategory,
          icon: Icons.folder_special_outlined,
          iconColor: fieldIconColor,
          value: rule.targetCategoryId,
          options: targetOptions,
          onChanged: (value) =>
              onChanged(rule.copyWith(targetCategoryId: value)),
        ),
        const SizedBox(height: 16),
        _conditionTypeField(context, fieldIconColor),
        const SizedBox(height: 16),
        ThemedFormInput(
          initialValue: rule.conditionValue,
          decoration: InputDecoration(
            labelText: l10n.diy_conditionValue,
            hintText: l10n.diy_conditionValueHint,
            prefixIcon: Icon(Icons.text_fields_rounded, color: fieldIconColor),
          ),
          readOnly: readOnly,
          onChanged: (value) => onChanged(rule.copyWith(conditionValue: value)),
        ),
        const SizedBox(height: 12),
        DiySwitchCard(
          title: l10n.diy_visibleWhenMatched,
          value: rule.visibleWhenMatched,
          icon: rule.visibleWhenMatched
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          iconColor: rule.visibleWhenMatched
              ? colorScheme.primary
              : colorScheme.tertiary,
          onChanged: readOnly
              ? null
              : (value) => onChanged(rule.copyWith(visibleWhenMatched: value)),
        ),
        const SizedBox(height: 8),
        DiySwitchCard(
          title: l10n.diy_enableRule,
          value: rule.enabled,
          onChanged: readOnly
              ? null
              : (value) => onChanged(rule.copyWith(enabled: value)),
        ),
      ],
    );
  }

  Widget _conditionTypeField(BuildContext context, Color iconColor) {
    return DropdownButtonFormField<VisibilityConditionType>(
      initialValue: rule.conditionType,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(
        labelText: context.l10n.diy_conditionType,
        prefixIcon: Icon(Icons.rule_rounded, color: iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        for (final type in VisibilityConditionType.values)
          DropdownMenuItem(
            value: type,
            child: Text(_conditionTypeLabel(context, type)),
          ),
      ],
      onChanged: readOnly
          ? null
          : (value) {
              if (value != null) onChanged(rule.copyWith(conditionType: value));
            },
    );
  }

  Widget _categoryDropdown({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
    required List<DiyCategoryOption> options,
    required ValueChanged<String> onChanged,
  }) {
    return DiyCategoryDropdown(
      value: value,
      options: options,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: onChanged,
    );
  }

  static String _conditionTypeLabel(
    BuildContext context,
    VisibilityConditionType type,
  ) {
    final l10n = context.l10n;
    return switch (type) {
      VisibilityConditionType.tagExists => l10n.diy_conditionTagExists,
      VisibilityConditionType.tagNotExists => l10n.diy_conditionTagNotExists,
      VisibilityConditionType.valueEquals => l10n.diy_conditionValueEquals,
      VisibilityConditionType.valueNotEquals =>
        l10n.diy_conditionValueNotEquals,
      VisibilityConditionType.valueInList => l10n.diy_conditionValueInList,
      VisibilityConditionType.valueNotInList =>
        l10n.diy_conditionValueNotInList,
    };
  }
}
