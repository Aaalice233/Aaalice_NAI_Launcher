import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/post_process_rule.dart';
import '../../../../widgets/common/themed_divider.dart';

/// 后处理规则面板
///
/// 用于配置根据已选标签移除冲突的规则
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
      name: '规则 ${widget.rules.length + 1}',
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
        const SizedBox(height: 16),
        if (!widget.readOnly) _buildPresetSection(),
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
        const Icon(Icons.auto_fix_high),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '后处理规则',
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

  Widget _buildPresetSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '预设规则',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Text('😴'),
                  label: const Text('睡眠规则'),
                  onPressed: () =>
                      _addPresetRule(PostProcessRule.sleepingRule()),
                ),
                ActionChip(
                  avatar: const Text('🧜'),
                  label: const Text('美人鱼规则'),
                  onPressed: () =>
                      _addPresetRule(PostProcessRule.mermaidRule()),
                ),
              ],
            ),
          ],
        ),
      ),
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
                  Icons.auto_fix_high,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  '暂无后处理规则',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '添加规则以自动处理标签冲突',
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
              _getActionIcon(rule.action),
              color: rule.enabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            title: Text(rule.name),
            subtitle: Text(
              _getActionDescription(rule),
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
            TextFormField(
              initialValue: rule.name,
              decoration: const InputDecoration(labelText: '规则名称'),
              readOnly: widget.readOnly,
              onChanged: (value) {
                _updateRule(index, rule.copyWith(name: value));
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PostProcessAction>(
              value: rule.action,
              decoration: const InputDecoration(
                labelText: '操作类型',
                border: OutlineInputBorder(),
              ),
              items: PostProcessAction.values.map((action) {
                return DropdownMenuItem(
                  value: action,
                  child: Text(_getActionLabel(action)),
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
            TextFormField(
              initialValue: rule.triggerTags.join(', '),
              decoration: const InputDecoration(
                labelText: '触发标签',
                hintText: '逗号分隔的标签列表',
                border: OutlineInputBorder(),
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
            if (rule.action == PostProcessAction.removeCategory)
              TextFormField(
                initialValue: rule.targetCategoryIds.join(', '),
                decoration: const InputDecoration(
                  labelText: '目标类别',
                  hintText: '逗号分隔的类别 ID 列表',
                  border: OutlineInputBorder(),
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
              TextFormField(
                initialValue: rule.targetTags.join(', '),
                decoration: const InputDecoration(
                  labelText: '目标标签',
                  hintText: '逗号分隔的标签列表',
                  border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
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

  IconData _getActionIcon(PostProcessAction action) {
    switch (action) {
      case PostProcessAction.remove:
        return Icons.remove_circle_outline;
      case PostProcessAction.replace:
        return Icons.swap_horiz;
      case PostProcessAction.add:
        return Icons.add_circle_outline;
      case PostProcessAction.removeCategory:
        return Icons.folder_delete_outlined;
    }
  }

  String _getActionLabel(PostProcessAction action) {
    switch (action) {
      case PostProcessAction.remove:
        return '移除标签';
      case PostProcessAction.replace:
        return '替换标签';
      case PostProcessAction.add:
        return '添加标签';
      case PostProcessAction.removeCategory:
        return '移除类别';
    }
  }

  String _getActionDescription(PostProcessRule rule) {
    final triggers =
        rule.triggerTags.isNotEmpty ? rule.triggerTags.join(', ') : '无触发条件';
    return '当 [$triggers] 时 ${_getActionLabel(rule.action)}';
  }
}
