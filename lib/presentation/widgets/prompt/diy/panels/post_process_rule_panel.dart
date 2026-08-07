import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/post_process_rule.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';
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

  /// 可选的类别列表
  final List<String> availableCategories;

  /// 是否只读
  final bool readOnly;

  const PostProcessRulePanel({
    super.key,
    required this.rules,
    required this.onRulesChanged,
    this.availableCategories = const [],
    this.readOnly = false,
  });

  @override
  State<PostProcessRulePanel> createState() => _PostProcessRulePanelState();
}

class _PostProcessRulePanelState extends State<PostProcessRulePanel> {
  int? _selectedIndex;

  void _addRule() {
    final newRule = PostProcessRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: context.l10n.diy_ruleDefaultName(widget.rules.length + 1),
    );
    widget.onRulesChanged([...widget.rules, newRule]);
    setState(() {
      _selectedIndex = widget.rules.length;
    });
  }

  void _addPresetRule(PostProcessRule rule) {
    widget.onRulesChanged([...widget.rules, rule]);
  }

  void _removeRule(int index) {
    final newRules = List<PostProcessRule>.from(widget.rules)..removeAt(index);
    widget.onRulesChanged(newRules);
    if (_selectedIndex == index) {
      setState(() => _selectedIndex = null);
    }
  }

  void _updateRule(int index, PostProcessRule rule) {
    final newRules = List<PostProcessRule>.from(widget.rules);
    newRules[index] = rule;
    widget.onRulesChanged(newRules);
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
        if (_selectedIndex != null &&
            _selectedIndex! < widget.rules.length) ...[
          const SizedBox(height: 12),
          _buildRuleEditor(_selectedIndex!),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // 图标容器 - 渐变背景
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.tertiary.withValues(alpha: 0.2),
                colorScheme.tertiary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colorScheme.tertiary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_fix_high_rounded,
            size: 20,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.diy_postProcessTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                context.l10n.diy_postProcessSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (widget.rules.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.diy_ruleCount(widget.rules.length),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.tertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final presets = [
      (
        '😴',
        context.l10n.diy_sleepingRule,
        () => PostProcessRule.sleepingRule().copyWith(
          name: context.l10n.diy_sleepingRule,
          description: context.l10n.diy_sleepingRuleDescription,
        ),
        Colors.indigo,
      ),
      (
        '🧜',
        context.l10n.diy_mermaidRule,
        () => PostProcessRule.mermaidRule().copyWith(
          name: context.l10n.diy_mermaidRule,
          description: context.l10n.diy_mermaidRuleDescription,
        ),
        Colors.teal,
      ),
    ];

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.diy_presetRules,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: presets.map((preset) {
              final (emoji, label, ruleFactory, color) = preset;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _addPresetRule(ruleFactory()),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.rules.isEmpty) {
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
        itemCount: widget.rules.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final rule = widget.rules[index];
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
                        ],
                      ),
                    ),
                    // 状态标签
                    if (!rule.enabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.l10n.common_disabled,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.error,
                          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _addRule,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diy_addRule,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleEditor(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rule = widget.rules[index];

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
          // 标题栏
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.diy_editRule,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _selectedIndex = null),
                tooltip: context.l10n.common_close,
              ),
            ],
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
                    Text(_getActionLabel(action)),
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
            ThemedFormInput(
              initialValue: rule.targetCategoryIds.join(', '),
              decoration: InputDecoration(
                labelText: context.l10n.diy_targetCategories,
                hintText: context.l10n.diy_commaSeparatedCategoryIdsHint,
                prefixIcon: Icon(
                  Icons.folder_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              readOnly: widget.readOnly,
              onChanged: (value) {
                final ids = value
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
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
