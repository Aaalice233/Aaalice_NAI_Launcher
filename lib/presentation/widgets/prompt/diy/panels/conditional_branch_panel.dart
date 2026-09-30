import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../adaptive/interaction_policy.dart';
import '../../../../../data/models/prompt/conditional_branch.dart';
import '../../../common/labeled_slider_rows.dart';
import '../../../common/surface_ink_well.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';
import '../diy_badges.dart';
import '../diy_panel_header.dart';
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
  bool _usesDefaultConfig = false;

  @override
  void initState() {
    super.initState();
    _usesDefaultConfig = widget.config == null;
    _config = widget.config ?? const ConditionalBranchConfig(id: '', name: '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_usesDefaultConfig && _config.name.isEmpty) {
      _config = _config.copyWith(name: context.l10n.diy_conditionalDefaultName);
    }
  }

  @override
  void didUpdateWidget(ConditionalBranchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _usesDefaultConfig = widget.config == null;
      _config =
          widget.config ??
          ConditionalBranchConfig(
            id: '',
            name: context.l10n.diy_conditionalDefaultName,
          );
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
      name: context.l10n.diy_branchDefaultName(_config.branches.length + 1),
      probability: 10,
    );
    _updateConfig(_config.copyWith(branches: [..._config.branches, newBranch]));
  }

  void _removeBranch(int index) {
    final newBranches = List<ConditionalBranch>.from(_config.branches)
      ..removeAt(index);
    final selected = _selectedIndex;
    _selectedIndex = selected == null || selected == index
        ? null
        : selected > index
        ? selected - 1
        : selected;
    _updateConfig(_config.copyWith(branches: newBranches));
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
        if (_selectedIndex != null &&
            _selectedIndex! < _config.branches.length) ...[
          const SizedBox(height: 12),
          // 输入框只在创建时读取初始值，切换分支需要重建编辑区
          KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: _buildBranchEditor(_selectedIndex!),
          ),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;

    return DiyPanelHeader(
      icon: Icons.call_split_rounded,
      accent: colorScheme.secondary,
      title: context.l10n.diy_conditionalTitle,
      subtitle: context.l10n.diy_conditionalSubtitle,
      trailing: _config.branches.isEmpty
          ? null
          : DiyCountBadge(
              label: context.l10n.diy_branchCount(_config.branches.length),
              accent: colorScheme.secondary,
              container: colorScheme.secondaryContainer,
            ),
    );
  }

  Widget _buildProbabilityBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 渐变色组合
    final gradients = [
      [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.7)],
      [colorScheme.secondary, colorScheme.secondary.withValues(alpha: 0.7)],
      [colorScheme.tertiary, colorScheme.tertiary.withValues(alpha: 0.7)],
      [Colors.orange, Colors.orange.withValues(alpha: 0.7)],
      [Colors.purple, Colors.purple.withValues(alpha: 0.7)],
      [Colors.teal, Colors.teal.withValues(alpha: 0.7)],
    ];

    final total = _config.branches.fold<int>(
      0,
      (sum, b) => sum + b.probability,
    );
    if (total <= 0) return const SizedBox.shrink();

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // 放大文字后分段标签变高，条高度随内容增长而不是溢出
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: context.interactionPolicy.minimumControlExtent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, branch) in _config.branches.indexed)
                  Expanded(
                    flex: branch.probability,
                    child: _buildProbabilitySegment(
                      index: index,
                      branch: branch,
                      colors: gradients[index % gradients.length],
                      percent: (branch.probability / total * 100)
                          .toStringAsFixed(0),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProbabilitySegment({
    required int index,
    required ConditionalBranch branch,
    required List<Color> colors,
    required String percent,
  }) {
    final isSelected = _selectedIndex == index;
    return Tooltip(
      message: '${branch.name}: $percent%',
      child: SurfaceInkWell(
        borderRadius: BorderRadius.zero,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSelected
              ? colors
              : [
                  colors[0].withValues(alpha: 0.6),
                  colors[1].withValues(alpha: 0.4),
                ],
        ),
        duration: const Duration(milliseconds: 200),
        onTap: () => setState(() => _selectedIndex = index),
        child: Center(
          child: branch.probability >= 10
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      branch.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : null,
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
                context.l10n.diy_noConditionalBranches,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.diy_noConditionalBranchesHint,
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
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        itemBuilder: (context, index) {
          final branch = _config.branches[index];
          final accentColor = accentColors[index % accentColors.length];
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
                    // 概率圆形指示器；放大文字后撑成胶囊而不是让读数溢出
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: branch.enabled
                              ? [
                                  accentColor,
                                  accentColor.withValues(alpha: 0.7),
                                ]
                              : [
                                  colorScheme.surfaceContainerHighest,
                                  colorScheme.surfaceContainerHighest,
                                ],
                        ),
                        shadows: branch.enabled
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${branch.probability}%',
                          maxLines: 1,
                          softWrap: false,
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
                              context.l10n.diy_conditionCount(
                                branch.conditions.length,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (!branch.enabled) ...[
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
                        onPressed: () => _removeBranch(index),
                        tooltip: context.l10n.diy_deleteBranch,
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
        onPressed: _addBranch,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(context.l10n.diy_addBranch),
      ),
    );
  }

  static String _probabilityText(double probability) =>
      '${probability.round()}%';

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
          colorScheme.primary.withValues(alpha: 0.5),
          colorScheme.secondary.withValues(alpha: 0.3),
        ],
      ),
      gradientBorderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiySectionTitle(
            icon: Icons.edit_rounded,
            accent: colorScheme.primary,
            container: colorScheme.primaryContainer,
            title: context.l10n.diy_editBranch(branch.name),
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
          // 分支名称
          ThemedFormInput(
            initialValue: branch.name,
            decoration: InputDecoration(
              labelText: context.l10n.diy_branchName,
              prefixIcon: const Icon(Icons.label_outline_rounded),
            ),
            readOnly: widget.readOnly,
            onChanged: (value) {
              _updateBranch(index, branch.copyWith(name: value));
            },
          ),
          const SizedBox(height: 16),
          LabeledSliderRows(
            labelStyle: theme.textTheme.titleSmall,
            valueStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.tertiary,
            ),
            sliders: [
              LabeledSlider(
                label: context.l10n.diy_probability,
                valueText: _probabilityText,
                value: branch.probability.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: widget.readOnly
                    ? null
                    : (value) => _updateBranch(
                        index,
                        branch.copyWith(probability: value.round()),
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
                    context.l10n.diy_enableBranch,
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
