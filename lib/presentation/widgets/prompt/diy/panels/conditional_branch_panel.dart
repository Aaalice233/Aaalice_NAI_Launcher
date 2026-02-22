import 'package:flutter/material.dart';

import '../../../../../data/models/prompt/conditional_branch.dart';
import '../../../common/themed_slider.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

/// 条件分支配置面板
///
/// 用于配置和编辑条件分支规则
/// 采用 Dimensional Layering 设计风格
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
        const SizedBox(height: 12),
        if (_config.branches.isNotEmpty) ...[
          _buildProbabilityBar(),
          const SizedBox(height: 12),
        ],
        _buildBranchList(),
        if (!widget.readOnly) ...[
          const SizedBox(height: 12),
          _buildAddButton(),
        ],
        if (_selectedIndex != null) ...[
          const SizedBox(height: 12),
          _buildBranchEditor(_selectedIndex!),
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
                colorScheme.secondary.withOpacity(0.2),
                colorScheme.secondary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colorScheme.secondary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.call_split_rounded,
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
                '条件分支配置',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '根据概率选择不同分支',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (_config.branches.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_config.branches.length} 个分支',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.secondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProbabilityBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 渐变色组合
    final gradients = [
      [colorScheme.primary, colorScheme.primary.withOpacity(0.7)],
      [colorScheme.secondary, colorScheme.secondary.withOpacity(0.7)],
      [colorScheme.tertiary, colorScheme.tertiary.withOpacity(0.7)],
      [Colors.orange, Colors.orange.withOpacity(0.7)],
      [Colors.purple, Colors.purple.withOpacity(0.7)],
      [Colors.teal, Colors.teal.withOpacity(0.7)],
    ];

    final total =
        _config.branches.fold<int>(0, (sum, b) => sum + b.probability);
    if (total <= 0) return const SizedBox.shrink();

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: Row(
            children: _config.branches.asMap().entries.map((entry) {
              final index = entry.key;
              final branch = entry.value;
              final colors = gradients[index % gradients.length];
              final percent =
                  (branch.probability / total * 100).toStringAsFixed(0);
              final isSelected = _selectedIndex == index;

              return Expanded(
                flex: branch.probability,
                child: Tooltip(
                  message: '${branch.name}: $percent%',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isSelected
                                ? colors
                                : [
                                    colors[0].withOpacity(0.6),
                                    colors[1].withOpacity(0.4),
                                  ],
                          ),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: branch.probability >= 10
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      branch.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black26,
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$percent%',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_config.branches.isEmpty) {
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
                  Icons.call_split_rounded,
                  size: 40,
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '暂无条件分支',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '添加分支以实现条件选择逻辑',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 渐变色组合
    final accentColors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _config.branches.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: colorScheme.outline.withOpacity(0.1),
        ),
        itemBuilder: (context, index) {
          final branch = _config.branches[index];
          final accentColor = accentColors[index % accentColors.length];
          final isSelected = _selectedIndex == index;

          return Material(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // 概率圆形指示器
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: branch.enabled
                              ? [accentColor, accentColor.withOpacity(0.7)]
                              : [
                                  colorScheme.surfaceContainerHighest,
                                  colorScheme.surfaceContainerHighest,
                                ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: branch.enabled
                            ? [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${branch.probability}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: branch.enabled
                                ? Colors.white
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 分支信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (branch.conditions.isNotEmpty)
                            Text(
                              '${branch.conditions.length} 个条件',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 状态和操作
                    if (!branch.enabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '已禁用',
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
                          color: colorScheme.error.withOpacity(0.7),
                        ),
                        onPressed: () => _removeBranch(index),
                        tooltip: '删除分支',
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
          onTap: _addBranch,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '添加分支',
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

  Widget _buildBranchEditor(int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final branch = _config.branches[index];

    return ElevatedCard(
      elevation: CardElevation.level2,
      borderRadius: 12,
      gradientBorder: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primary.withOpacity(0.5),
          colorScheme.secondary.withOpacity(0.3),
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
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '编辑: ${branch.name}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _selectedIndex = null),
                tooltip: '关闭',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ThemedDivider(),
          const SizedBox(height: 12),
          // 分支名称
          ThemedFormInput(
            initialValue: branch.name,
            decoration: const InputDecoration(
              labelText: '分支名称',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
            readOnly: widget.readOnly,
            onChanged: (value) {
              _updateBranch(index, branch.copyWith(name: value));
            },
          ),
          const SizedBox(height: 16),
          // 概率滑块
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.percent_rounded,
                  size: 14,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '概率',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(width: 12),
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
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.tertiary.withOpacity(0.15),
                      colorScheme.tertiary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${branch.probability}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  ),
                ),
              ),
            ],
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
                  branch.enabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 20,
                  color: branch.enabled
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '启用此分支',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Switch(
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
        ],
      ),
    );
  }
}
