import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/conditional_branch.dart';
import '../../../common/themed_slider.dart';
import '../../../../widgets/common/themed_divider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 条件分支配置面板
///
/// 用于配置和编辑条件分支规则
class ConditionalBranchPanel extends StatefulWidget {
  /// 当前配置
  final ConditionalBranchConfig? config;

  /// 配置变更回调
  final ValueChanged<ConditionalBranchConfig?> onConfigChanged;

  /// 是否只读
  final bool readOnly;

  const ConditionalBranchPanel({
    super.key,
    this.config,
    required this.onConfigChanged,
    this.readOnly = false,
  });

  @override
  State<ConditionalBranchPanel> createState() => _ConditionalBranchPanelState();
}

class _ConditionalBranchPanelState extends State<ConditionalBranchPanel> {
  late ConditionalBranchConfig _config;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _config =
        widget.config ?? const ConditionalBranchConfig(id: '', name: '条件分支配置');
  }

  @override
  void didUpdateWidget(ConditionalBranchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _config = widget.config ??
          const ConditionalBranchConfig(id: '', name: '条件分支配置');
      _selectedIndex = null;
    }
  }

  void _updateConfig(ConditionalBranchConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    widget.onConfigChanged(newConfig);
  }

  void _addBranch() {
    final newBranch = ConditionalBranch(
      name: '分支 ${_config.branches.length + 1}',
      probability: 10,
    );
    _updateConfig(
      _config.copyWith(
        branches: [..._config.branches, newBranch],
      ),
    );
  }

  void _removeBranch(int index) {
    final newBranches = List<ConditionalBranch>.from(_config.branches)
      ..removeAt(index);
    _updateConfig(_config.copyWith(branches: newBranches));
    if (_selectedIndex == index) {
      _selectedIndex = null;
    }
  }

  void _updateBranch(int index, ConditionalBranch branch) {
    final newBranches = List<ConditionalBranch>.from(_config.branches);
    newBranches[index] = branch;
    _updateConfig(_config.copyWith(branches: newBranches));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        if (_config.branches.isNotEmpty) ...[
          _buildProbabilityBar(),
          const SizedBox(height: 16),
        ],
        _buildBranchList(),
        if (!widget.readOnly) ...[
          const SizedBox(height: 16),
          _buildAddButton(),
        ],
        if (_selectedIndex != null) ...[
          const SizedBox(height: 16),
          _buildBranchEditor(_selectedIndex!),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.call_split),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '条件分支配置',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_config.branches.isNotEmpty)
          Text(
            '${_config.branches.length} 个分支',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildProbabilityBar() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    final total =
        _config.branches.fold<int>(0, (sum, b) => sum + b.probability);
    if (total <= 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 32,
        child: Row(
          children: _config.branches.asMap().entries.map((entry) {
            final index = entry.key;
            final branch = entry.value;
            final color = colors[index % colors.length];
            final percent =
                (branch.probability / total * 100).toStringAsFixed(0);

            return Expanded(
              flex: branch.probability,
              child: Tooltip(
                message: '${branch.name}: $percent%',
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    color: _selectedIndex == index
                        ? color
                        : color.withOpacity(0.6),
                    child: Center(
                      child: Text(
                        branch.probability >= 10 ? branch.name : '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBranchList() {
    if (_config.branches.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.call_split,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  '暂无条件分支',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '添加分支以实现条件选择逻辑',
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
        itemCount: _config.branches.length,
        separatorBuilder: (_, __) => const ThemedDivider(height: 1),
        itemBuilder: (context, index) {
          final branch = _config.branches[index];
          return ListTile(
            selected: _selectedIndex == index,
            leading: CircleAvatar(
              backgroundColor: branch.enabled
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                '${branch.probability}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: branch.enabled
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            title: Text(branch.name),
            subtitle: branch.conditions.isNotEmpty
                ? Text('${branch.conditions.length} 个条件')
                : null,
            trailing: widget.readOnly
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeBranch(index),
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
        onPressed: _addBranch,
        icon: const Icon(Icons.add),
        label: const Text('添加分支'),
      ),
    );
  }

  Widget _buildBranchEditor(int index) {
    final branch = _config.branches[index];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '编辑: ${branch.name}',
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
              initialValue: branch.name,
              decoration: const InputDecoration(labelText: '分支名称'),
              readOnly: widget.readOnly,
              onChanged: (value) {
                _updateBranch(index, branch.copyWith(name: value));
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('概率:'),
                Expanded(
                  child: ThemedSlider(
                    value: branch.probability.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: widget.readOnly
                        ? null
                        : (value) {
                            _updateBranch(
                              index,
                              branch.copyWith(probability: value.round()),
                            );
                          },
                  ),
                ),
                Text('${branch.probability}%'),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('启用'),
              value: branch.enabled,
              onChanged: widget.readOnly
                  ? null
                  : (value) {
                      _updateBranch(index, branch.copyWith(enabled: value));
                    },
            ),
          ],
        ),
      ),
    );
  }
}
