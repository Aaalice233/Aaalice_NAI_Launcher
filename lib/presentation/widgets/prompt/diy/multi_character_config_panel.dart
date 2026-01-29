import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/algorithm_config.dart';
import '../../common/themed_slider.dart';
import '../../common/elevated_card.dart';

/// 多角色配置面板
///
/// 用于配置角色数量权重和性别概率
/// 采用 Dimensional Layering 设计风格
class MultiCharacterConfigPanel extends ConsumerStatefulWidget {
  /// 当前算法配置
  final AlgorithmConfig config;

  /// 配置变更回调
  final ValueChanged<AlgorithmConfig> onConfigChanged;

  /// 是否只读
  final bool readOnly;

  const MultiCharacterConfigPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
    this.readOnly = false,
  });

  @override
  ConsumerState<MultiCharacterConfigPanel> createState() =>
      _MultiCharacterConfigPanelState();
}

class _MultiCharacterConfigPanelState
    extends ConsumerState<MultiCharacterConfigPanel> {
  late List<List<int>> _characterCountWeights;
  late Map<String, int> _genderWeights;

  @override
  void initState() {
    super.initState();
    _characterCountWeights = List.from(
      widget.config.characterCountWeights.map((w) => List<int>.from(w)),
    );
    _genderWeights = Map.from(widget.config.genderWeights);
  }

  @override
  void didUpdateWidget(MultiCharacterConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _characterCountWeights = List.from(
        widget.config.characterCountWeights.map((w) => List<int>.from(w)),
      );
      _genderWeights = Map.from(widget.config.genderWeights);
    }
  }

  void _updateConfig() {
    widget.onConfigChanged(
      widget.config.copyWith(
        characterCountWeights: _characterCountWeights,
        genderWeights: _genderWeights,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCharacterCountSection(),
        const SizedBox(height: 12),
        _buildGenderWeightSection(),
      ],
    );
  }

  Widget _buildCharacterCountSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labels = ['无人物', '单人', '双人', '三人', '多人'];

    // 渐变色组合
    final gradients = [
      [Colors.grey, Colors.grey.withOpacity(0.7)],
      [colorScheme.primary, colorScheme.primary.withOpacity(0.7)],
      [colorScheme.secondary, colorScheme.secondary.withOpacity(0.7)],
      [colorScheme.tertiary, colorScheme.tertiary.withOpacity(0.7)],
      [Colors.purple, Colors.purple.withOpacity(0.7)],
    ];

    return ElevatedCard(
      elevation: CardElevation.level1,
      hoverElevation: CardElevation.level2,
      enableHoverEffect: !widget.readOnly,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.2),
                      colorScheme.primary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.people_alt_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '角色数量权重',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 权重条
          _buildWeightBar(_characterCountWeights, gradients),
          const SizedBox(height: 16),
          // 滑块列表
          ...List.generate(_characterCountWeights.length, (index) {
            final count = _characterCountWeights[index][0];
            final weight = _characterCountWeights[index][1];
            final label = count < labels.length ? labels[count] : '$count人';
            final colors = gradients[index % gradients.length];

            return _buildWeightSlider(
              label: label,
              value: weight,
              color: colors[0],
              onChanged: widget.readOnly
                  ? null
                  : (value) {
                      setState(() {
                        _characterCountWeights[index][1] = value.round();
                      });
                      _updateConfig();
                    },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGenderWeightSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final genderData = [
      ('male', '男性', Colors.blue, Icons.male_rounded),
      ('female', '女性', Colors.pink, Icons.female_rounded),
      ('other', '其他', Colors.purple, Icons.transgender_rounded),
    ];

    return ElevatedCard(
      elevation: CardElevation.level1,
      hoverElevation: CardElevation.level2,
      enableHoverEffect: !widget.readOnly,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.secondary.withOpacity(0.2),
                      colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.wc_rounded,
                  size: 18,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '性别概率',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 权重条
          _buildGenderWeightBar(),
          const SizedBox(height: 16),
          // 滑块列表
          ...genderData.map((data) {
            final (key, label, color, icon) = data;
            final weight = _genderWeights[key] ?? 0;

            return _buildWeightSlider(
              label: label,
              value: weight,
              color: color,
              icon: icon,
              onChanged: widget.readOnly
                  ? null
                  : (value) {
                      setState(() {
                        _genderWeights[key] = value.round();
                      });
                      _updateConfig();
                    },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeightBar(
    List<List<int>> weights,
    List<List<Color>> gradients,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = weights.fold<int>(0, (sum, w) => sum + w[1]);

    if (total <= 0) {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '未设置权重',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 10,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 32,
          child: Row(
            children: weights.asMap().entries.map((entry) {
              final index = entry.key;
              final weight = entry.value[1];
              if (weight <= 0) return const SizedBox.shrink();

              final colors = gradients[index % gradients.length];
              final percent = (weight / total * 100).toStringAsFixed(0);

              return Expanded(
                flex: weight,
                child: Tooltip(
                  message: '$percent%',
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        weight >= 10 ? '$percent%' : '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 2),
                          ],
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

  Widget _buildGenderWeightBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = _genderWeights.values.fold<int>(0, (sum, w) => sum + w);

    if (total <= 0) {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '未设置权重',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final colors = {
      'male': [Colors.blue, Colors.blue.withOpacity(0.7)],
      'female': [Colors.pink, Colors.pink.withOpacity(0.7)],
      'other': [Colors.purple, Colors.purple.withOpacity(0.7)],
    };

    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 10,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 32,
          child: Row(
            children: _genderWeights.entries.map((entry) {
              final weight = entry.value;
              if (weight <= 0) return const SizedBox.shrink();

              final colorPair = colors[entry.key] ?? [Colors.grey, Colors.grey];
              final percent = (weight / total * 100).toStringAsFixed(0);

              return Expanded(
                flex: weight,
                child: Tooltip(
                  message: '${entry.key}: $percent%',
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colorPair,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        weight >= 10 ? '$percent%' : '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black26, blurRadius: 2),
                          ],
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

  Widget _buildWeightSlider({
    required String label,
    required int value,
    required Color color,
    IconData? icon,
    required ValueChanged<double>? onChanged,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 标签区域
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (icon != null) ...[
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 滑块
          Expanded(
            child: ThemedSlider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
          // 数值显示
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
