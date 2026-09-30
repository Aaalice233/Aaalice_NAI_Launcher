import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/post_process_rule.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';
import '../../../../widgets/common/surface_ink_well.dart';
import '../diy_badges.dart';
import '../diy_category_field.dart';
import '../diy_panel_header.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 后处理规则面板
///
/// 用于配置根据已选标签移除冲突的规则
/// 采用 Dimensional Layering 设计风格
class PostProcessRulePanel extends StatefulWidget {
  /// 当前规则列表
  final List<PostProcessRule> rules;

  /// 规则变更回调
  final ValueChanged<List<PostProcessRule>> onRulesChanged;

  /// 移除类别操作可选的目标类别
  final List<DiyCategoryOption> categoryOptions;

  /// 是否只读
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

  void _addRule() {
    final newRule = PostProcessRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: context.l10n.diy_ruleDefaultName(_rules.length + 1),
    );
    _setRules([..._rules, newRule], selectedIndex: _rules.length);
  }

  void _addPresetRule(_PresetRule preset) {
    final targets = _categoryIdsForKeys(preset.targetCategoryKeys);
    final rule = preset.create(targets);
    // 目标没能全部定位到本预设的类别时直接展开编辑，让用户补选要移除的类别
    final needsTargets =
        targets.isEmpty || targets.length < preset.targetCategoryKeys.length;
    _setRules([
      ..._rules,
      rule,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        if (!widget.readOnly) _buildPresetSection(),
        if (!widget.readOnly) const SizedBox(height: 12),
        _buildRuleList(),
        if (!widget.readOnly) ...[
          const SizedBox(height: 12),
          _buildAddButton(),
        ],
        if (_selectedIndex != null && _selectedIndex! < _rules.length) ...[
          const SizedBox(height: 12),
          // 输入框只在创建时读取初始值，切换规则需要重建编辑区
          KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: _buildRuleEditor(_selectedIndex!),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    return DiyPanelHeader(
      icon: Icons.auto_fix_high_rounded,
      accent: colorScheme.tertiary,
      title: context.l10n.diy_postProcessTitle,
      subtitle: context.l10n.diy_postProcessSubtitle,
      trailing: _rules.isEmpty
          ? null
          : DiyCountBadge(
              label: context.l10n.diy_ruleCount(_rules.length),
              accent: colorScheme.tertiary,
              container: colorScheme.tertiaryContainer,
            ),
    );
  }

  Widget _buildPresetSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final presets = [
      _PresetRule(
        emoji: '😴',
        label: context.l10n.diy_sleepingRule,
        color: Colors.indigo,
        targetCategoryKeys: PostProcessRule.sleepingTargetCategoryKeys,
        create: (targets) =>
            PostProcessRule.sleepingRule(targetCategoryIds: targets).copyWith(
              name: context.l10n.diy_sleepingRule,
              description: context.l10n.diy_sleepingRuleDescription,
            ),
      ),
      _PresetRule(
        emoji: '🧜',
        label: context.l10n.diy_mermaidRule,
        color: Colors.teal,
        targetCategoryKeys: PostProcessRule.mermaidTargetCategoryKeys,
        create: (targets) =>
            PostProcessRule.mermaidRule(targetCategoryIds: targets).copyWith(
              name: context.l10n.diy_mermaidRule,
              description: context.l10n.diy_mermaidRuleDescription,
            ),
      ),
    ];

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiySectionTitle(
            icon: Icons.auto_awesome_rounded,
            accent: colorScheme.secondary,
            container: colorScheme.secondaryContainer,
            title: context.l10n.diy_presetRules,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackPresets = constraints.maxWidth < 480;

              Widget buildPresetButton(_PresetRule preset) {
                final side = BorderSide(
                  color: preset.color.withValues(alpha: 0.3),
                );
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: stackPresets ? 0 : 4,
                    vertical: stackPresets ? 4 : 0,
                  ),
                  child: SurfaceInkWell(
                    borderRadius: BorderRadius.circular(10),
                    color: colorScheme.surfaceContainerHighest,
                    side: side,
                    onTap: () => _addPresetRule(preset),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12 + side.width),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            preset.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
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
                  ),
                );
              }

              if (stackPresets) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: presets.map(buildPresetButton).toList(),
                );
              }

              return Row(
                children: presets
                    .map((preset) => Expanded(child: buildPresetButton(preset)))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRuleList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_rules.isEmpty) {
      return ElevatedCard(
        elevation: CardElevation.level1,
        borderRadius: 12,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 40,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.diy_noPostProcessRules,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.diy_noPostProcessRulesHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 操作类型颜色
    final actionColors = {
      PostProcessAction.remove: colorScheme.error,
      PostProcessAction.replace: colorScheme.tertiary,
      PostProcessAction.add: colorScheme.primary,
      PostProcessAction.removeCategory: Colors.orange,
    };

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _rules.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final rule = _rules[index];
          final isSelected = _selectedIndex == index;
          final actionColor = actionColors[rule.action] ?? colorScheme.primary;

          return Material(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // 操作图标
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: rule.enabled
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  actionColor,
                                  actionColor.withValues(alpha: 0.7),
                                ],
                              )
                            : null,
                        color: rule.enabled
                            ? null
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: rule.enabled
                            ? [
                                BoxShadow(
                                  color: actionColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _getActionIcon(rule.action),
                        size: 18,
                        color: rule.enabled
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 规则信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getActionDescription(rule),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!rule.enabled) ...[
                            const SizedBox(height: 4),
                            const DiyDisabledBadge(),
                          ],
                        ],
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _removeRule(index),
                        tooltip: context.l10n.diy_deleteRule,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return Center(
      child: FilledButton.tonalIcon(
        onPressed: _addRule,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(context.l10n.diy_addRule, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildRuleEditor(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rule = _rules[index];

    return ElevatedCard(
      elevation: CardElevation.level2,
      borderRadius: 12,
      gradientBorder: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.tertiary.withValues(alpha: 0.5),
          colorScheme.primary.withValues(alpha: 0.3),
        ],
      ),
      gradientBorderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiySectionTitle(
            icon: Icons.edit_rounded,
            accent: colorScheme.tertiary,
            container: colorScheme.tertiaryContainer,
            title: context.l10n.diy_editRule,
            trailing: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => setState(() => _selectedIndex = null),
              tooltip: context.l10n.common_close,
            ),
          ),
          const SizedBox(height: 12),
          const ThemedDivider(),
          const SizedBox(height: 12),
          // 规则名称
          ThemedFormInput(
            initialValue: rule.name,
            decoration: InputDecoration(
              labelText: context.l10n.diy_ruleName,
              prefixIcon: Icon(
                Icons.label_outline_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            readOnly: widget.readOnly,
            onChanged: (value) {
              _updateRule(index, rule.copyWith(name: value));
            },
          ),
          const SizedBox(height: 16),
          // 操作类型
          DropdownButtonFormField<PostProcessAction>(
            initialValue: rule.action,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              labelText: context.l10n.diy_actionType,
              prefixIcon: Icon(
                _getActionIcon(rule.action),
                color: colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: PostProcessAction.values.map((action) {
              return DropdownMenuItem(
                value: action,
                child: Row(
                  children: [
                    Icon(_getActionIcon(action), size: 18),
                    const SizedBox(width: 8),
                    Flexible(child: Text(_getActionLabel(action))),
                  ],
                ),
              );
            }).toList(),
            onChanged: widget.readOnly
                ? null
                : (value) {
                    if (value != null) {
                      _updateRule(index, rule.copyWith(action: value));
                    }
                  },
          ),
          const SizedBox(height: 16),
          // 触发标签
          ThemedFormInput(
            initialValue: rule.triggerTags.join(', '),
            decoration: InputDecoration(
              labelText: context.l10n.diy_triggerTags,
              hintText: context.l10n.diy_commaSeparatedTagsHint,
              prefixIcon: Icon(
                Icons.play_circle_outline_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            readOnly: widget.readOnly,
            onChanged: (value) {
              final tags = value
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              _updateRule(index, rule.copyWith(triggerTags: tags));
            },
          ),
          const SizedBox(height: 16),
          // 目标
          if (rule.action == PostProcessAction.removeCategory)
            DiyCategoryMultiSelect(
              values: rule.targetCategoryIds,
              options: widget.categoryOptions,
              readOnly: widget.readOnly,
              decoration: InputDecoration(
                labelText: context.l10n.diy_targetCategories,
                prefixIcon: Icon(
                  Icons.folder_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (ids) {
                _updateRule(index, rule.copyWith(targetCategoryIds: ids));
              },
            )
          else
            ThemedFormInput(
              initialValue: rule.targetTags.join(', '),
              decoration: InputDecoration(
                labelText: context.l10n.diy_targetTags,
                hintText: context.l10n.diy_commaSeparatedTagsHint,
                prefixIcon: Icon(
                  Icons.label_outline_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              readOnly: widget.readOnly,
              onChanged: (value) {
                final tags = value
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                _updateRule(index, rule.copyWith(targetTags: tags));
              },
            ),
          const SizedBox(height: 12),
          // 启用开关
          ElevatedCard(
            elevation: CardElevation.level1,
            borderRadius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  rule.enabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 20,
                  color: rule.enabled
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.diy_enableRule,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          _updateRule(index, rule.copyWith(enabled: value));
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(PostProcessAction action) {
    switch (action) {
      case PostProcessAction.remove:
        return Icons.remove_circle_outline_rounded;
      case PostProcessAction.replace:
        return Icons.swap_horiz_rounded;
      case PostProcessAction.add:
        return Icons.add_circle_outline_rounded;
      case PostProcessAction.removeCategory:
        return Icons.folder_delete_outlined;
    }
  }

  String _getActionLabel(PostProcessAction action) {
    switch (action) {
      case PostProcessAction.remove:
        return context.l10n.diy_actionRemoveTags;
      case PostProcessAction.replace:
        return context.l10n.diy_actionReplaceTags;
      case PostProcessAction.add:
        return context.l10n.diy_actionAddTags;
      case PostProcessAction.removeCategory:
        return context.l10n.diy_actionRemoveCategories;
    }
  }

  String _getActionDescription(PostProcessRule rule) {
    final triggers = rule.triggerTags.isNotEmpty
        ? rule.triggerTags.join(', ')
        : context.l10n.diy_noTriggers;
    return context.l10n.diy_actionSummary(
      triggers,
      _getActionLabel(rule.action),
    );
  }
}

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
