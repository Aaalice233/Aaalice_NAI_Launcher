import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

import '../../../../../data/models/prompt/post_process_rule.dart';
import '../../../../widgets/common/surface_ink_well.dart';
import '../diy_badges.dart';
import '../diy_category_field.dart';
import '../diy_editor_card.dart';
import '../diy_empty_state.dart';
import '../diy_panel_header.dart';
import '../diy_rule_list_card.dart';
import '../diy_section_card.dart';
import '../diy_switch_card.dart';

/// 后处理规则面板：按已选标签移除、替换或补充标签，或整类移除冲突的类别
class PostProcessRulePanel extends StatefulWidget {
  final List<PostProcessRule> rules;
  final ValueChanged<List<PostProcessRule>> onRulesChanged;

  /// 移除类别操作可选的目标类别
  final List<DiyCategoryOption> categoryOptions;

  final bool readOnly;

  const PostProcessRulePanel({
    super.key,
    required this.rules,
    required this.onRulesChanged,
    this.categoryOptions = const [],
    this.readOnly = false,
  });

  @override
  State<PostProcessRulePanel> createState() => _PostProcessRulePanelState();
}

class _PostProcessRulePanelState extends State<PostProcessRulePanel> {
  // 弹出的表单路由不随父级重建，面板自己持有正在编辑的规则
  late List<PostProcessRule> _rules;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _rules = widget.rules;
  }

  @override
  void didUpdateWidget(PostProcessRulePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.rules, _rules)) {
      _rules = widget.rules;
      if ((_selectedIndex ?? 0) >= _rules.length) _selectedIndex = null;
    }
  }

  void _setRules(List<PostProcessRule> rules, {int? selectedIndex}) {
    setState(() {
      _rules = rules;
      _selectedIndex = selectedIndex;
    });
    widget.onRulesChanged(rules);
  }

  void _removeRule(int index) {
    final selected = _selectedIndex;
    _setRules(
      List<PostProcessRule>.from(_rules)..removeAt(index),
      selectedIndex: selected == null || selected == index
          ? null
          : selected > index
          ? selected - 1
          : selected,
    );
  }

  void _updateRule(int index, PostProcessRule rule) {
    final newRules = List<PostProcessRule>.from(_rules);
    newRules[index] = rule;
    _setRules(newRules, selectedIndex: _selectedIndex);
  }

  void _addRule() {
    final newRule = PostProcessRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: context.l10n.diy_ruleDefaultName(_rules.length + 1),
    );
    _setRules([..._rules, newRule], selectedIndex: _rules.length);
  }

  void _addPresetRule(_PresetRule preset) {
    final targets = _categoryIdsForKeys(preset.targetCategoryKeys);
    // 目标没能全部定位到本预设的类别时直接展开编辑，让用户补选要移除的类别
    final needsTargets =
        targets.isEmpty || targets.length < preset.targetCategoryKeys.length;
    _setRules([
      ..._rules,
      preset.create(targets),
    ], selectedIndex: needsTargets ? _rules.length : _selectedIndex);
  }

  List<String> _categoryIdsForKeys(List<String> keys) {
    final ids = <String>[];
    for (final key in keys) {
      final matches = widget.categoryOptions
          .where((option) => option.key == key)
          .toList();
      // 键名重复时无法确定指向哪个类别，留给用户选择
      if (matches.length == 1) ids.add(matches.single.id);
    }
    return ids;
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
            child: _PostProcessRuleEditor(
              rule: _rules[index],
              categoryOptions: widget.categoryOptions,
              readOnly: widget.readOnly,
              onChanged: (rule) => _updateRule(index, rule),
              onClose: () => setState(() => _selectedIndex = null),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiyPanelHeader(
          icon: Icons.auto_fix_high_rounded,
          accent: colorScheme.tertiary,
          title: l10n.diy_postProcessTitle,
          subtitle: l10n.diy_postProcessSubtitle,
          trailing: _rules.isEmpty
              ? null
              : DiyCountBadge(
                  label: l10n.diy_ruleCount(_rules.length),
                  accent: colorScheme.tertiary,
                  container: colorScheme.tertiaryContainer,
                ),
        ),
        const SizedBox(height: 12),
        if (!widget.readOnly) ...[
          DiySectionCard(
            icon: Icons.auto_awesome_rounded,
            accent: colorScheme.secondary,
            accentContainer: colorScheme.secondaryContainer,
            title: l10n.diy_presetRules,
            child: _PresetRuleButtons(
              presets: _presets(context),
              onSelected: _addPresetRule,
            ),
          ),
          const SizedBox(height: 12),
        ],
        DiyRuleListCard(
          items: [for (final rule in _rules) _listItem(rule)],
          selectedIndex: _selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
          onDeleted: widget.readOnly ? null : _removeRule,
          deleteTooltip: l10n.diy_deleteRule,
          emptyState: DiyEmptyState(
            icon: Icons.auto_fix_high_rounded,
            title: l10n.diy_noPostProcessRules,
            hint: l10n.diy_noPostProcessRulesHint,
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

  List<_PresetRule> _presets(BuildContext context) {
    final l10n = context.l10n;
    return [
      _PresetRule(
        emoji: '😴',
        label: l10n.diy_sleepingRule,
        color: Colors.indigo,
        targetCategoryKeys: PostProcessRule.sleepingTargetCategoryKeys,
        create: (targets) =>
            PostProcessRule.sleepingRule(targetCategoryIds: targets).copyWith(
              name: l10n.diy_sleepingRule,
              description: l10n.diy_sleepingRuleDescription,
            ),
      ),
      _PresetRule(
        emoji: '🧜',
        label: l10n.diy_mermaidRule,
        color: Colors.teal,
        targetCategoryKeys: PostProcessRule.mermaidTargetCategoryKeys,
        create: (targets) =>
            PostProcessRule.mermaidRule(targetCategoryIds: targets).copyWith(
              name: l10n.diy_mermaidRule,
              description: l10n.diy_mermaidRuleDescription,
            ),
      ),
    ];
  }

  DiyRuleListItem _listItem(PostProcessRule rule) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final triggers = rule.triggerTags.isNotEmpty
        ? rule.triggerTags.join(', ')
        : l10n.diy_noTriggers;
    return DiyRuleListItem(
      leading: DiyRuleAvatar(
        accent: _actionColor(theme.colorScheme, rule.action),
        enabled: rule.enabled,
        builder: (foreground) =>
            Icon(_actionIcon(rule.action), size: 18, color: foreground),
      ),
      title: rule.name,
      enabled: rule.enabled,
      details: [
        Text(
          l10n.diy_actionSummary(triggers, _actionLabel(context, rule.action)),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

Color _actionColor(ColorScheme colorScheme, PostProcessAction action) =>
    switch (action) {
      PostProcessAction.remove => colorScheme.error,
      PostProcessAction.replace => colorScheme.tertiary,
      PostProcessAction.add => colorScheme.primary,
      PostProcessAction.removeCategory => Colors.orange,
    };

IconData _actionIcon(PostProcessAction action) => switch (action) {
  PostProcessAction.remove => Icons.remove_circle_outline_rounded,
  PostProcessAction.replace => Icons.swap_horiz_rounded,
  PostProcessAction.add => Icons.add_circle_outline_rounded,
  PostProcessAction.removeCategory => Icons.folder_delete_outlined,
};

String _actionLabel(BuildContext context, PostProcessAction action) {
  final l10n = context.l10n;
  return switch (action) {
    PostProcessAction.remove => l10n.diy_actionRemoveTags,
    PostProcessAction.replace => l10n.diy_actionReplaceTags,
    PostProcessAction.add => l10n.diy_actionAddTags,
    PostProcessAction.removeCategory => l10n.diy_actionRemoveCategories,
  };
}

List<String> _splitTags(String value) => value
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toList();

/// 预设规则按类别键名声明目标，添加时再定位到当前预设的类别 ID
class _PresetRule {
  const _PresetRule({
    required this.emoji,
    required this.label,
    required this.color,
    required this.targetCategoryKeys,
    required this.create,
  });

  final String emoji;
  final String label;
  final Color color;
  final List<String> targetCategoryKeys;
  final PostProcessRule Function(List<String> targetCategoryIds) create;
}

/// 预设规则按钮：放得下时并排，窄屏时上下排列
class _PresetRuleButtons extends StatelessWidget {
  const _PresetRuleButtons({required this.presets, required this.onSelected});

  final List<_PresetRule> presets;
  final ValueChanged<_PresetRule> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 480;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final preset in presets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _button(context, preset),
                ),
            ],
          );
        }
        return Row(
          children: [
            for (final preset in presets)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _button(context, preset),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _button(BuildContext context, _PresetRule preset) {
    final theme = Theme.of(context);
    final side = BorderSide(color: preset.color.withValues(alpha: 0.3));
    return SurfaceInkWell(
      borderRadius: BorderRadius.circular(10),
      color: theme.colorScheme.surfaceContainerHighest,
      side: side,
      onTap: () => onSelected(preset),
      child: Padding(
        padding: EdgeInsets.all(12 + side.width),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                preset.label,
                textAlign: TextAlign.center,
                softWrap: true,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostProcessRuleEditor extends StatelessWidget {
  const _PostProcessRuleEditor({
    required this.rule,
    required this.categoryOptions,
    required this.readOnly,
    required this.onChanged,
    required this.onClose,
  });

  final PostProcessRule rule;
  final List<DiyCategoryOption> categoryOptions;
  final bool readOnly;
  final ValueChanged<PostProcessRule> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final fieldIconColor = colorScheme.onSurfaceVariant;
    return DiyEditorCard(
      title: l10n.diy_editRule,
      accent: colorScheme.tertiary,
      accentContainer: colorScheme.tertiaryContainer,
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
        _actionField(context, fieldIconColor),
        const SizedBox(height: 16),
        ThemedFormInput(
          initialValue: rule.triggerTags.join(', '),
          decoration: InputDecoration(
            labelText: l10n.diy_triggerTags,
            hintText: l10n.diy_commaSeparatedTagsHint,
            prefixIcon: Icon(
              Icons.play_circle_outline_rounded,
              color: fieldIconColor,
            ),
          ),
          readOnly: readOnly,
          onChanged: (value) =>
              onChanged(rule.copyWith(triggerTags: _splitTags(value))),
        ),
        const SizedBox(height: 16),
        _targetField(context, fieldIconColor),
        const SizedBox(height: 12),
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

  Widget _actionField(BuildContext context, Color iconColor) {
    return DropdownButtonFormField<PostProcessAction>(
      initialValue: rule.action,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(
        labelText: context.l10n.diy_actionType,
        prefixIcon: Icon(_actionIcon(rule.action), color: iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        for (final action in PostProcessAction.values)
          DropdownMenuItem(
            value: action,
            child: Row(
              children: [
                Icon(_actionIcon(action), size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(_actionLabel(context, action))),
              ],
            ),
          ),
      ],
      onChanged: readOnly
          ? null
          : (value) {
              if (value != null) onChanged(rule.copyWith(action: value));
            },
    );
  }

  Widget _targetField(BuildContext context, Color iconColor) {
    final l10n = context.l10n;
    if (rule.action == PostProcessAction.removeCategory) {
      return DiyCategoryMultiSelect(
        values: rule.targetCategoryIds,
        options: categoryOptions,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: l10n.diy_targetCategories,
          prefixIcon: Icon(Icons.folder_outlined, color: iconColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (ids) => onChanged(rule.copyWith(targetCategoryIds: ids)),
      );
    }
    return ThemedFormInput(
      initialValue: rule.targetTags.join(', '),
      decoration: InputDecoration(
        labelText: l10n.diy_targetTags,
        hintText: l10n.diy_commaSeparatedTagsHint,
        prefixIcon: Icon(Icons.label_outline_rounded, color: iconColor),
      ),
      readOnly: readOnly,
      onChanged: (value) =>
          onChanged(rule.copyWith(targetTags: _splitTags(value))),
    );
  }
}
