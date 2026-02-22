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
  const AlgorithmConfigCard({
    super.key,
    this.isPresetDefault = false,
  });

  /// 是否为默认预设（只读模式）
  final bool isPresetDefault;

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
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 标题容器 - 统一样式
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.15),
                    colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '算法配置',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 展开/收起按钮
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

    final weights = config.characterCountWeights;
    final maxWeight = weights.fold<int>(0, (max, w) => w[1] > max ? w[1] : max);

    final barColors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.orange.shade400,
    ];

    final female = config.genderWeights['female'] ?? 60;
    final male = config.genderWeights['male'] ?? 30;
    final other = config.genderWeights['other'] ?? 10;
    final total = female + male + other;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 角色数量分布
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '角色数量分布',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...weights.asMap().entries.map((entry) {
                final index = entry.key;
                final count = entry.value[0];
                final weight = entry.value[1];
                final label = count == 0 ? '无人物' : '$count人';
                final widthRatio = maxWeight > 0 ? weight / maxWeight : 0.0;
                final color = barColors[index % barColors.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _HorizontalBar(
                    label: label,
                    weight: weight,
                    widthRatio: widthRatio,
                    color: color,
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 性别分布
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wc_rounded,
                    size: 14,
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '性别分布',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 堆叠进度条
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Row(
                    children: [
                      _GenderSegment(
                        flex: female,
                        color: Colors.pink.shade400,
                        label: '女',
                        value: female,
                        total: total,
                      ),
                      _GenderSegment(
                        flex: male,
                        color: Colors.blue.shade400,
                        label: '男',
                        value: male,
                        total: total,
                      ),
                      _GenderSegment(
                        flex: other,
                        color: Colors.purple.shade400,
                        label: '其他',
                        value: other,
                        total: total,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 图例
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChartLegendItem(
                    icon: Icons.female,
                    label: '女',
                    value: female,
                    color: Colors.pink.shade400,
                  ),
                  ChartLegendItem(
                    icon: Icons.male,
                    label: '男',
                    value: male,
                    color: Colors.blue.shade400,
                  ),
                  ChartLegendItem(
                    icon: Icons.transgender,
                    label: '其他',
                    value: other,
                    color: Colors.purple.shade400,
                  ),
                ],
              ),
            ],
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
    final isReadOnly = widget.isPresetDefault || preset.isDefault;

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
            enabled: !isReadOnly,
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
          label: '女性',
          value: config.genderWeights['female'] ?? 60,
          color: Colors.pink.shade400,
          enabled: !isReadOnly,
          onChanged: (newWeight) {
            _updateGenderWeight(preset, 'female', newWeight);
          },
        ),
        _WeightSlider(
          label: '男性',
          value: config.genderWeights['male'] ?? 30,
          color: Colors.blue.shade400,
          enabled: !isReadOnly,
          onChanged: (newWeight) {
            _updateGenderWeight(preset, 'male', newWeight);
          },
        ),
        _WeightSlider(
          label: '其他',
          value: config.genderWeights['other'] ?? 10,
          color: Colors.purple.shade400,
          enabled: !isReadOnly,
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
        _buildGlobalSettings(context, preset, config, isReadOnly),
      ],
    );
  }

  Widget _buildGlobalSettings(
    BuildContext context,
    RandomPreset preset,
    AlgorithmConfig config,
    bool isReadOnly,
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
            onChanged: isReadOnly
                ? null
                : (value) {
                    final newConfig =
                        config.copyWith(enableSeasonalWordlists: value);
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
            child: Opacity(
              opacity: isReadOnly ? 0.6 : 1.0,
              child: Slider(
                value: config.globalEmphasisProbability,
                min: 0,
                max: 0.1,
                divisions: 10,
                onChanged: isReadOnly
                    ? null
                    : (value) {
                        final newConfig =
                            config.copyWith(globalEmphasisProbability: value);
                        _updateConfig(preset, newConfig);
                      },
              ),
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

/// 水平条形图项
class _HorizontalBar extends StatefulWidget {
  const _HorizontalBar({
    required this.label,
    required this.weight,
    required this.widthRatio,
    required this.color,
  });

  final String label;
  final int weight;
  final double widthRatio;
  final Color color;

  @override
  State<_HorizontalBar> createState() => _HorizontalBarState();
}

class _HorizontalBarState extends State<_HorizontalBar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withOpacity(0.15)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(6),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                widget.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color:
                      _isHovered ? widget.color : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      widthFactor: widget.widthRatio.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.color,
                              widget.color.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: _isHovered
                              ? [
                                  BoxShadow(
                                    color: widget.color.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${widget.weight}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
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

/// 性别分布段
class _GenderSegment extends StatefulWidget {
  const _GenderSegment({
    required this.flex,
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  final int flex;
  final Color color;
  final String label;
  final int value;
  final int total;

  @override
  State<_GenderSegment> createState() => _GenderSegmentState();
}

class _GenderSegmentState extends State<_GenderSegment> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.flex <= 0) return const SizedBox.shrink();

    return Expanded(
      flex: widget.flex,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Tooltip(
          message: '${widget.label}: ${widget.value}%',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.color,
                  _isHovered ? widget.color : widget.color.withOpacity(0.8),
                ],
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: widget.flex > 15
                  ? Text(
                      '${widget.value}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    )
                  : null,
            ),
          ),
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
    this.enabled = true,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  State<_WeightSlider> createState() => _WeightSliderState();
}

class _WeightSliderState extends State<_WeightSlider> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = widget.enabled;
    final effectiveColor = isEnabled ? widget.color : colorScheme.outline;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: (_isHovered && isEnabled)
                ? colorScheme.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Row(
                  children: [
                    if (!isEnabled) ...[
                      Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        widget.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: (_isHovered && isEnabled)
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontWeight: (_isHovered && isEnabled)
                              ? FontWeight.w500
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: effectiveColor,
                    thumbColor: effectiveColor,
                    inactiveTrackColor: effectiveColor.withOpacity(0.15),
                    overlayColor: effectiveColor.withOpacity(0.1),
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
                    onChanged:
                        isEnabled ? (v) => widget.onChanged(v.round()) : null,
                  ),
                ),
              ),
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: effectiveColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.value}%',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                ),
              ),
            ],
          ),
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
