import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../../data/models/prompt/algorithm_config.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../common/elevated_card.dart';
import 'random_manager_widgets.dart';

/// 算法配置卡片组件
///
/// 显示和编辑角色数量权重、性别权重等核心算法配置
class AlgorithmConfigCard extends ConsumerStatefulWidget {
  const AlgorithmConfigCard({super.key});

  @override
  ConsumerState<AlgorithmConfigCard> createState() =>
      _AlgorithmConfigCardState();
}

class _AlgorithmConfigCardState extends ConsumerState<AlgorithmConfigCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    if (preset == null) {
      return const SizedBox.shrink();
    }

    final config = preset.algorithmConfig;

    return ElevatedCard(
      elevation: CardElevation.level2,
      hoverElevation: CardElevation.level3,
      enableHoverEffect: false,
      borderRadius: 8,
      gradientBorder: _isExpanded ? CardGradients.primary(colorScheme) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(context, colorScheme),
            // 主体内容 - 紧凑视图
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildCompactView(context, config),
            ),
            // 展开的详细配置
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildExpandedView(context, preset, config),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _isExpanded
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.2),
                    colorScheme.secondaryContainer.withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isExpanded
                    ? colorScheme.primary.withOpacity(0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.tune,
                size: 18,
                color: _isExpanded
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '算法配置',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isExpanded ? colorScheme.primary : null,
                  ),
            ),
            const Spacer(),
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isExpanded ? 0.5 : 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView(BuildContext context, AlgorithmConfig config) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // 角色数量权重
        Expanded(
          child: _CompactWeightGroup(
            title: '角色数量',
            items: config.characterCountWeights.map((w) {
              final count = w[0];
              final weight = w[1];
              final label = count == 0 ? '无' : '$count人';
              return _WeightItem(label: label, weight: weight);
            }).toList(),
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        // 性别权重
        Expanded(
          child: _CompactWeightGroup(
            title: '性别',
            items: [
              _WeightItem(
                label: 'F',
                weight: config.genderWeights['female'] ?? 60,
              ),
              _WeightItem(
                label: 'M',
                weight: config.genderWeights['male'] ?? 30,
              ),
              _WeightItem(
                label: 'O',
                weight: config.genderWeights['other'] ?? 10,
              ),
            ],
            color: colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    RandomPreset preset,
    AlgorithmConfig config,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 渐变分隔线
        Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.3),
                colorScheme.secondary.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // 角色数量权重滑块
        SectionHeader(
          icon: Icons.people_outline,
          title: '角色数量权重',
          color: colorScheme.primary,
        ),
        const SizedBox(height: 12),
        ...config.characterCountWeights.map((w) {
          final count = w[0];
          final weight = w[1];
          final label = count == 0 ? '无人物' : '$count 人';
          return _WeightSlider(
            label: label,
            value: weight,
            color: colorScheme.primary,
            onChanged: (newWeight) {
              _updateCharacterCountWeight(preset, count, newWeight);
            },
          );
        }),
        const SizedBox(height: 20),
        // 性别权重滑块
        SectionHeader(
          icon: Icons.wc_outlined,
          title: '性别权重',
          color: colorScheme.secondary,
        ),
        const SizedBox(height: 12),
        _WeightSlider(
          label: '女性 (Female)',
          value: config.genderWeights['female'] ?? 60,
          color: Colors.pink.shade400,
          onChanged: (newWeight) {
            _updateGenderWeight(preset, 'female', newWeight);
          },
        ),
        _WeightSlider(
          label: '男性 (Male)',
          value: config.genderWeights['male'] ?? 30,
          color: Colors.blue.shade400,
          onChanged: (newWeight) {
            _updateGenderWeight(preset, 'male', newWeight);
          },
        ),
        _WeightSlider(
          label: '其他 (Other)',
          value: config.genderWeights['other'] ?? 10,
          color: Colors.purple.shade400,
          onChanged: (newWeight) {
            _updateGenderWeight(preset, 'other', newWeight);
          },
        ),
        const SizedBox(height: 20),
        // 全局设置
        SectionHeader(
          icon: Icons.settings_applications_outlined,
          title: '全局设置',
          color: colorScheme.tertiary,
        ),
        const SizedBox(height: 12),
        _buildGlobalSettings(context, preset, config),
      ],
    );
  }

  Widget _buildGlobalSettings(
    BuildContext context,
    RandomPreset preset,
    AlgorithmConfig config,
  ) {
    return Column(
      children: [
        // 季节性词库开关
        _SettingRow(
          icon: Icons.celebration_outlined,
          label: '启用季节性词库',
          subtitle: '圣诞节、万圣节等特殊日期词库',
          trailing: Switch(
            value: config.enableSeasonalWordlists,
            onChanged: (value) {
              final newConfig = config.copyWith(enableSeasonalWordlists: value);
              _updateConfig(preset, newConfig);
            },
          ),
        ),
        const SizedBox(height: 8),
        // 全局强调概率
        _SettingRow(
          icon: Icons.highlight_outlined,
          label: '全局强调概率',
          subtitle: '${(config.globalEmphasisProbability * 100).toInt()}%',
          trailing: SizedBox(
            width: 120,
            child: Slider(
              value: config.globalEmphasisProbability,
              min: 0,
              max: 0.1,
              divisions: 10,
              onChanged: (value) {
                final newConfig =
                    config.copyWith(globalEmphasisProbability: value);
                _updateConfig(preset, newConfig);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _updateCharacterCountWeight(
    RandomPreset preset,
    int count,
    int newWeight,
  ) {
    final config = preset.algorithmConfig;
    final newWeights = config.characterCountWeights.map((w) {
      if (w[0] == count) {
        return [count, newWeight];
      }
      return w;
    }).toList();

    final newConfig = config.copyWith(characterCountWeights: newWeights);
    _updateConfig(preset, newConfig);
  }

  void _updateGenderWeight(RandomPreset preset, String gender, int newWeight) {
    final config = preset.algorithmConfig;
    final newWeights = Map<String, int>.from(config.genderWeights);
    newWeights[gender] = newWeight;

    final newConfig = config.copyWith(genderWeights: newWeights);
    _updateConfig(preset, newConfig);
  }

  void _updateConfig(RandomPreset preset, AlgorithmConfig newConfig) {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    notifier.updatePreset(preset.updateAlgorithmConfig(newConfig));
  }
}

class _CompactWeightGroup extends StatelessWidget {
  const _CompactWeightGroup({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<_WeightItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: items.map((item) {
            return Expanded(
              child: _CompactWeightCell(
                label: item.label,
                weight: item.weight,
                color: color,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _WeightItem {
  final String label;
  final int weight;

  const _WeightItem({required this.label, required this.weight});
}

class _CompactWeightCell extends StatefulWidget {
  const _CompactWeightCell({
    required this.label,
    required this.weight,
    required this.color,
  });

  final String label;
  final int weight;
  final Color color;

  @override
  State<_CompactWeightCell> createState() => _CompactWeightCellState();
}

class _CompactWeightCellState extends State<_CompactWeightCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: _isHovered
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color.withOpacity(0.08),
                    widget.color.withOpacity(0.04),
                  ],
                )
              : null,
          color: _isHovered ? null : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.color.withOpacity(0.15)
                  : colorScheme.shadow.withOpacity(0.05),
              blurRadius: _isHovered ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              widget.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _isHovered ? widget.color : colorScheme.onSurfaceVariant,
                fontWeight: _isHovered ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.weight}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightSlider extends StatefulWidget {
  const _WeightSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  State<_WeightSlider> createState() => _WeightSliderState();
}

class _WeightSliderState extends State<_WeightSlider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _isHovered
              ? colorScheme.surfaceContainerHigh
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                widget.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isHovered
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                  fontWeight: _isHovered ? FontWeight.w500 : null,
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: widget.color,
                  thumbColor: widget.color,
                  inactiveTrackColor: widget.color.withOpacity(0.15),
                  overlayColor: widget.color.withOpacity(0.1),
                  trackHeight: 5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                    elevation: 2,
                    pressedElevation: 4,
                  ),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: widget.value.toDouble(),
                  min: 0,
                  max: 100,
                  onChanged: (v) => widget.onChanged(v.round()),
                ),
              ),
            ),
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${widget.value}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatefulWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget trailing;

  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? colorScheme.shadow.withOpacity(0.1)
                  : colorScheme.shadow.withOpacity(0.05),
              blurRadius: _isHovered ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            widget.trailing,
          ],
        ),
      ),
    );
  }
}
