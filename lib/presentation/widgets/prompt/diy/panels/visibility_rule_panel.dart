import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/visibility_rule.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 可见性规则面板
///
/// 用于配置类别的可见性规则
/// 采用 Dimensional Layering 设计风格
class VisibilityRulePanel extends StatefulWidget {
  /// 当前规则列表
  final List<VisibilityRule> rules;

  /// 规则变更回调
  final ValueChanged<List<VisibilityRule>> onRulesChanged;

  /// 可选的类别列表
  final List<String> availableCategories;

  /// 是否只读
  final bool readOnly;

  const VisibilityRulePanel({
    super.key,
    required this.rules,
    required this.onRulesChanged,
    this.availableCategories = const [],
    this.readOnly = false,
  });

  @override
  State<VisibilityRulePanel> createState() => _VisibilityRulePanelState();
}

class _VisibilityRulePanelState extends State<VisibilityRulePanel> {
  int? _selectedIndex;

  void _addRule() {
    final newRule = VisibilityRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: context.l10n.diy_ruleDefaultName(widget.rules.length + 1),
      targetCategoryId: '',
      sourceCategoryId: '',
      conditionValue: '',
    );
    widget.onRulesChanged([...widget.rules, newRule]);
    setState(() {
      _selectedIndex = widget.rules.length;
    });
  }

  void _removeRule(int index) {
    final newRules = List<VisibilityRule>.from(widget.rules)..removeAt(index);
    widget.onRulesChanged(newRules);
    if (_selectedIndex == index) {
      setState(() {
        _selectedIndex = null;
      });
    }
  }

  void _updateRule(int index, VisibilityRule rule) {
    final newRules = List<VisibilityRule>.from(widget.rules);
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
                colorScheme.secondary.withValues(alpha: 0.2),
                colorScheme.secondary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colorScheme.secondary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.visibility_rounded,
            size: 20,
            color: colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.diy_visibilityTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                context.l10n.diy_visibilitySubtitle,
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
              color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.diy_ruleCount(widget.rules.length),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.secondary,
              ),
            ),
          ),
      ],
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
                  Icons.visibility_off_rounded,
                  size: 40,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.diy_noVisibilityRules,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.diy_noVisibilityRulesHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                    // 可见性图标
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: rule.enabled
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: rule.visibleWhenMatched
                                    ? [
                                        colorScheme.primary,
                                        colorScheme.primary.withValues(
                                          alpha: 0.7,
                                        ),
                                      ]
                                    : [
                                        colorScheme.tertiary,
                                        colorScheme.tertiary.withValues(
                                          alpha: 0.7,
                                        ),
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
                                  color:
                                      (rule.visibleWhenMatched
                                              ? colorScheme.primary
                                              : colorScheme.tertiary)
                                          .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        rule.visibleWhenMatched
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rule.sourceCategoryId.isNotEmpty
                                      ? rule.sourceCategoryId
                                      : context.l10n.diy_notSet,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rule.targetCategoryId.isNotEmpty
                                      ? rule.targetCategoryId
                                      : context.l10n.diy_notSet,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
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
          colorScheme.secondary.withValues(alpha: 0.5),
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
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: colorScheme.secondary,
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
          // 源类别
          _buildCategoryDropdown(
            label: context.l10n.diy_sourceCategory,
            icon: Icons.folder_outlined,
            value: rule.sourceCategoryId,
            color: colorScheme.primary,
            onChanged: (value) {
              _updateRule(index, rule.copyWith(sourceCategoryId: value));
            },
          ),
          const SizedBox(height: 16),
          // 目标类别
          _buildCategoryDropdown(
            label: context.l10n.diy_targetCategory,
            icon: Icons.folder_special_outlined,
            value: rule.targetCategoryId,
            color: colorScheme.secondary,
            onChanged: (value) {
              _updateRule(index, rule.copyWith(targetCategoryId: value));
            },
          ),
          const SizedBox(height: 16),
          // 条件类型
          DropdownButtonFormField<VisibilityConditionType>(
            initialValue: rule.conditionType,
            decoration: InputDecoration(
              labelText: context.l10n.diy_conditionType,
              prefixIcon: Icon(
                Icons.rule_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: VisibilityConditionType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getConditionTypeLabel(type)),
              );
            }).toList(),
            onChanged: widget.readOnly
                ? null
                : (value) {
                    if (value != null) {
                      _updateRule(index, rule.copyWith(conditionType: value));
                    }
                  },
          ),
          const SizedBox(height: 16),
          // 条件值
          ThemedFormInput(
            initialValue: rule.conditionValue,
            decoration: InputDecoration(
              labelText: context.l10n.diy_conditionValue,
              hintText: context.l10n.diy_conditionValueHint,
              prefixIcon: Icon(
                Icons.text_fields_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            readOnly: widget.readOnly,
            onChanged: (value) {
              _updateRule(index, rule.copyWith(conditionValue: value));
            },
          ),
          const SizedBox(height: 12),
          // 条件匹配时可见
          ElevatedCard(
            elevation: CardElevation.level1,
            borderRadius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  rule.visibleWhenMatched
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 20,
                  color: rule.visibleWhenMatched
                      ? colorScheme.primary
                      : colorScheme.tertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.diy_visibleWhenMatched,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: rule.visibleWhenMatched,
                  onChanged: widget.readOnly
                      ? null
                      : (value) {
                          _updateRule(
                            index,
                            rule.copyWith(visibleWhenMatched: value),
                          );
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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

  Widget _buildCategoryDropdown({
    required String label,
    required IconData icon,
    required String value,
    required Color color,
    required ValueChanged<String> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.availableCategories.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: value.isNotEmpty ? value : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: widget.availableCategories.map((category) {
          return DropdownMenuItem(value: category, child: Text(category));
        }).toList(),
        onChanged: widget.readOnly
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      );
    }

    return ThemedFormInput(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      readOnly: widget.readOnly,
      onChanged: onChanged,
    );
  }

  String _getConditionTypeLabel(VisibilityConditionType type) {
    switch (type) {
      case VisibilityConditionType.tagExists:
        return context.l10n.diy_conditionTagExists;
      case VisibilityConditionType.tagNotExists:
        return context.l10n.diy_conditionTagNotExists;
      case VisibilityConditionType.valueEquals:
        return context.l10n.diy_conditionValueEquals;
      case VisibilityConditionType.valueNotEquals:
        return context.l10n.diy_conditionValueNotEquals;
      case VisibilityConditionType.valueInList:
        return context.l10n.diy_conditionValueInList;
      case VisibilityConditionType.valueNotInList:
        return context.l10n.diy_conditionValueNotInList;
    }
  }
}
