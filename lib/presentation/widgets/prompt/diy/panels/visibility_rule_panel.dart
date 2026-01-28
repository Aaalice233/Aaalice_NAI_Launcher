import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/visibility_rule.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 可见性规则面板
///
/// 用于配置类别的可见性规则
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
      name: '规则 ${widget.rules.length + 1}',
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
        const SizedBox(height: 16),
        _buildRuleList(),
        if (!widget.readOnly) ...[
          const SizedBox(height: 16),
          _buildAddButton(),
        ],
        if (_selectedIndex != null &&
            _selectedIndex! < widget.rules.length) ...[
          const SizedBox(height: 16),
          _buildRuleEditor(_selectedIndex!),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.visibility),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '可见性规则',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (widget.rules.isNotEmpty)
          Text(
            '${widget.rules.length} 条规则',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildRuleList() {
    if (widget.rules.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.visibility_off,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  '暂无可见性规则',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '添加规则以根据构图控制类别可见性',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.rules.length,
        separatorBuilder: (_, __) => const ThemedDivider(height: 1),
        itemBuilder: (context, index) {
          final rule = widget.rules[index];
          return ListTile(
            selected: _selectedIndex == index,
            leading: Icon(
              rule.visibleWhenMatched ? Icons.visibility : Icons.visibility_off,
              color: rule.enabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            title: Text(rule.name),
            subtitle: Text(
              '${rule.sourceCategoryId} → ${rule.targetCategoryId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: widget.readOnly
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeRule(index),
                  ),
            onTap: () => setState(() => _selectedIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return Center(
      child: OutlinedButton.icon(
        onPressed: _addRule,
        icon: const Icon(Icons.add),
        label: const Text('添加规则'),
      ),
    );
  }

  Widget _buildRuleEditor(int index) {
    final rule = widget.rules[index];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '编辑规则',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedIndex = null),
                ),
              ],
            ),
            const ThemedDivider(),
            ThemedFormInput(
              initialValue: rule.name,
              decoration: const InputDecoration(labelText: '规则名称'),
              readOnly: widget.readOnly,
              onChanged: (value) {
                _updateRule(index, rule.copyWith(name: value));
              },
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(
              label: '源类别',
              value: rule.sourceCategoryId,
              onChanged: (value) {
                _updateRule(index, rule.copyWith(sourceCategoryId: value));
              },
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(
              label: '目标类别',
              value: rule.targetCategoryId,
              onChanged: (value) {
                _updateRule(index, rule.copyWith(targetCategoryId: value));
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VisibilityConditionType>(
              value: rule.conditionType,
              decoration: const InputDecoration(
                labelText: '条件类型',
                border: OutlineInputBorder(),
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
            ThemedFormInput(
              initialValue: rule.conditionValue,
              decoration: const InputDecoration(
                labelText: '条件值',
                hintText: '标签名或值',
                border: OutlineInputBorder(),
              ),
              readOnly: widget.readOnly,
              onChanged: (value) {
                _updateRule(index, rule.copyWith(conditionValue: value));
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('条件匹配时可见'),
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
            SwitchListTile(
              title: const Text('启用'),
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
    );
  }

  Widget _buildCategoryDropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    if (widget.availableCategories.isNotEmpty) {
      return DropdownButtonFormField<String>(
        value: value.isNotEmpty ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: widget.availableCategories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(category),
          );
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
        border: const OutlineInputBorder(),
      ),
      readOnly: widget.readOnly,
      onChanged: onChanged,
    );
  }

  String _getConditionTypeLabel(VisibilityConditionType type) {
    switch (type) {
      case VisibilityConditionType.tagExists:
        return '标签存在';
      case VisibilityConditionType.tagNotExists:
        return '标签不存在';
      case VisibilityConditionType.valueEquals:
        return '值等于';
      case VisibilityConditionType.valueNotEquals:
        return '值不等于';
      case VisibilityConditionType.valueInList:
        return '值在列表中';
      case VisibilityConditionType.valueNotInList:
        return '值不在列表中';
    }
  }
}
