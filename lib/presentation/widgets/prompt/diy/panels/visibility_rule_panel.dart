import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../../data/models/prompt/visibility_rule.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';
import '../diy_badges.dart';
import '../diy_category_field.dart';
import '../diy_panel_header.dart';
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

  /// 可选的类别
  final List<DiyCategoryOption> categoryOptions;

  /// 规则所属词组的 ID；目标选它时规则只控制该词组
  final String? ownerGroupId;

  /// 是否只读
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
      icon: Icons.visibility_rounded,
      accent: colorScheme.secondary,
      title: context.l10n.diy_visibilityTitle,
      subtitle: context.l10n.diy_visibilitySubtitle,
      trailing: _rules.isEmpty
          ? null
          : DiyCountBadge(
              label: context.l10n.diy_ruleCount(_rules.length),
              accent: colorScheme.secondary,
              container: colorScheme.secondaryContainer,
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
        itemCount: _rules.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final rule = _rules[index];
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
                                  _categoryLabel(
                                    rule.sourceCategoryId,
                                    widget.categoryOptions,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: colorScheme.onSurfaceVariant,
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
                                  _categoryLabel(
                                    rule.targetCategoryId,
                                    _targetOptions,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              ),
                              if (!rule.enabled) const DiyDisabledBadge(),
                            ],
                          ),
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
        label: Text(context.l10n.diy_addRule),
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
          colorScheme.secondary.withValues(alpha: 0.5),
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
            accent: colorScheme.secondary,
            container: colorScheme.secondaryContainer,
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
            options: widget.categoryOptions,
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
            options: _targetOptions,
            onChanged: (value) {
              _updateRule(index, rule.copyWith(targetCategoryId: value));
            },
          ),
          const SizedBox(height: 16),
          // 条件类型
          DropdownButtonFormField<VisibilityConditionType>(
            initialValue: rule.conditionType,
            isExpanded: true,
            itemHeight: null,
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

  Widget _buildCategoryDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<DiyCategoryOption> options,
    required ValueChanged<String> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return DiyCategoryDropdown(
      value: value,
      options: options,
      readOnly: widget.readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: onChanged,
    );
  }

  String _categoryLabel(String reference, List<DiyCategoryOption> options) {
    if (reference.isEmpty) return context.l10n.diy_notSet;
    for (final option in options) {
      if (option.id == reference) return option.label;
    }
    return context.l10n.diy_categoryUnavailable(reference);
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
