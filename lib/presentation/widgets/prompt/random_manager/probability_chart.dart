import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';

/// 概率分布预览图表组件
///
/// 紧凑的水平条形图展示角色数量的概率分布
/// 采用实心渐变背景，有层次感的设计
class ProbabilityChart extends ConsumerWidget {
  const ProbabilityChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    if (preset == null) {
      return const SizedBox.shrink();
    }

    final config = preset.algorithmConfig;
    final weights = config.characterCountWeights;

    // 找到最大权重用于缩放
    final maxWeight = weights.fold<int>(
      0,
      (max, w) => w[1] > max ? w[1] : max,
    );

    // 定义颜色
    final barColors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.orange.shade400,
      Colors.teal.shade400,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // 实心深色渐变背景
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerLowest,
            colorScheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 小标题
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
          // 紧凑的水平条形图
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
    );
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
          // 实心背景 - 悬停时变化
          color: _isHovered
              ? widget.color.withOpacity(0.12)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? widget.color.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            // 标签
            SizedBox(
              width: 50,
              child: Text(
                widget.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: _isHovered
                      ? widget.color
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 进度条容器
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    // 进度条
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
            // 百分比
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

/// 性别分布图表组件
///
/// 紧凑的横向布局展示性别权重分布
class GenderDistributionChart extends ConsumerWidget {
  const GenderDistributionChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    if (preset == null) {
      return const SizedBox.shrink();
    }

    final config = preset.algorithmConfig;
    final female = config.genderWeights['female'] ?? 60;
    final male = config.genderWeights['male'] ?? 30;
    final other = config.genderWeights['other'] ?? 10;
    final total = female + male + other;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // 实心渐变背景
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerLowest,
            colorScheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 小标题
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
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Row(
                children: [
                  // 女性
                  _GenderSegment(
                    flex: female,
                    color: Colors.pink.shade400,
                    label: 'F',
                    value: female,
                    total: total,
                  ),
                  // 男性
                  _GenderSegment(
                    flex: male,
                    color: Colors.blue.shade400,
                    label: 'M',
                    value: male,
                    total: total,
                  ),
                  // 其他
                  _GenderSegment(
                    flex: other,
                    color: Colors.purple.shade400,
                    label: 'O',
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
              _GenderLegend(
                icon: Icons.female,
                label: '女',
                value: female,
                color: Colors.pink.shade400,
              ),
              _GenderLegend(
                icon: Icons.male,
                label: '男',
                value: male,
                color: Colors.blue.shade400,
              ),
              _GenderLegend(
                icon: Icons.transgender,
                label: '其他',
                value: other,
                color: Colors.purple.shade400,
              ),
            ],
          ),
        ],
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

/// 性别图例
class _GenderLegend extends StatelessWidget {
  const _GenderLegend({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 12,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value%',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
