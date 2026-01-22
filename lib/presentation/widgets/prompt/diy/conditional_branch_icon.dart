import 'package:flutter/material.dart';

import '../../../../data/models/prompt/conditional_branch.dart';

/// 条件分支图标组件
///
/// 显示条件分支的可视化图标和状态
class ConditionalBranchIcon extends StatelessWidget {
  /// 条件分支配置
  final ConditionalBranchConfig? config;

  /// 图标大小
  final double size;

  /// 点击回调
  final VoidCallback? onTap;

  const ConditionalBranchIcon({
    super.key,
    this.config,
    this.size = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasConfig = config != null && config!.branches.isNotEmpty;
    final theme = Theme.of(context);

    return Tooltip(
      message: hasConfig ? _buildTooltipMessage() : '无条件分支配置',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hasConfig
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.call_split,
            size: size * 0.6,
            color: hasConfig
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _buildTooltipMessage() {
    if (config == null || config!.branches.isEmpty) {
      return '无条件分支';
    }

    final lines = <String>['条件分支:'];
    for (final branch in config!.branches) {
      lines.add('  ${branch.name}: ${branch.probability}%');
    }
    return lines.join('\n');
  }
}

/// 条件分支列表项
class ConditionalBranchListTile extends StatelessWidget {
  /// 分支
  final ConditionalBranch branch;

  /// 是否选中
  final bool selected;

  /// 点击回调
  final VoidCallback? onTap;

  /// 删除回调
  final VoidCallback? onDelete;

  const ConditionalBranchListTile({
    super.key,
    required this.branch,
    this.selected = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      selected: selected,
      leading: CircleAvatar(
        backgroundColor: branch.enabled
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(
          '${branch.probability}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: branch.enabled
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(branch.name),
      subtitle: branch.description != null
          ? Text(
              branch.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (branch.conditions.isNotEmpty)
            Chip(
              label: Text('${branch.conditions.length} 条件'),
              visualDensity: VisualDensity.compact,
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: '删除',
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 条件分支概率条
class ConditionalBranchProbabilityBar extends StatelessWidget {
  /// 分支列表
  final List<ConditionalBranch> branches;

  /// 高度
  final double height;

  const ConditionalBranchProbabilityBar({
    super.key,
    required this.branches,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final enabledBranches = branches.where((b) => b.enabled).toList();
    if (enabledBranches.isEmpty) {
      return SizedBox(height: height);
    }

    final total = enabledBranches.fold<int>(0, (sum, b) => sum + b.probability);
    if (total <= 0) {
      return SizedBox(height: height);
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: enabledBranches.asMap().entries.map((entry) {
            final index = entry.key;
            final branch = entry.value;
            final flex = branch.probability;
            final color = colors[index % colors.length];

            return Expanded(
              flex: flex,
              child: Tooltip(
                message: '${branch.name}: ${branch.probability}%',
                child: Container(
                  color: color.withOpacity(0.7),
                  child: Center(
                    child: Text(
                      branch.probability >= 10 ? '${branch.probability}%' : '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
}
