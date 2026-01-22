import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/algorithm_config.dart';

/// 多角色配置面板
///
/// 用于配置角色数量权重和性别概率
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
    _characterCountWeights =
        List.from(widget.config.characterCountWeights.map((w) => List<int>.from(w)));
    _genderWeights = Map.from(widget.config.genderWeights);
  }

  @override
  void didUpdateWidget(MultiCharacterConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _characterCountWeights =
          List.from(widget.config.characterCountWeights.map((w) => List<int>.from(w)));
      _genderWeights = Map.from(widget.config.genderWeights);
    }
  }

  void _updateConfig() {
    widget.onConfigChanged(widget.config.copyWith(
      characterCountWeights: _characterCountWeights,
      genderWeights: _genderWeights,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('角色数量权重'),
        const SizedBox(height: 8),
        _buildCharacterCountSection(),
        const SizedBox(height: 16),
        _buildSectionHeader('性别概率'),
        const SizedBox(height: 8),
        _buildGenderWeightSection(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildCharacterCountSection() {
    final labels = ['无人物', '单人', '双人', '三人', '多人'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 权重条
            _buildWeightBar(_characterCountWeights),
            const SizedBox(height: 16),
            // 滑块列表
            ...List.generate(_characterCountWeights.length, (index) {
              final count = _characterCountWeights[index][0];
              final weight = _characterCountWeights[index][1];
              final label = count < labels.length ? labels[count] : '$count人';

              return _buildWeightSlider(
                label: label,
                value: weight,
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
      ),
    );
  }

  Widget _buildGenderWeightSection() {
    final genderLabels = {
      'male': '男性',
      'female': '女性',
      'other': '其他',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 权重条
            _buildGenderWeightBar(),
            const SizedBox(height: 16),
            // 滑块列表
            ...genderLabels.entries.map((entry) {
              final weight = _genderWeights[entry.key] ?? 0;

              return _buildWeightSlider(
                label: entry.value,
                value: weight,
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        setState(() {
                          _genderWeights[entry.key] = value.round();
                        });
                        _updateConfig();
                      },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightBar(List<List<int>> weights) {
    final total = weights.fold<int>(0, (sum, w) => sum + w[1]);
    if (total <= 0) return const SizedBox(height: 24);

    final colors = [
      Colors.grey,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 24,
        child: Row(
          children: weights.asMap().entries.map((entry) {
            final index = entry.key;
            final weight = entry.value[1];
            if (weight <= 0) return const SizedBox.shrink();

            final color = colors[index % colors.length];
            final percent = (weight / total * 100).toStringAsFixed(0);

            return Expanded(
              flex: weight,
              child: Tooltip(
                message: '$percent%',
                child: Container(
                  color: color.withOpacity(0.7),
                  child: Center(
                    child: Text(
                      weight >= 10 ? '$percent%' : '',
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

  Widget _buildGenderWeightBar() {
    final total = _genderWeights.values.fold<int>(0, (sum, w) => sum + w);
    if (total <= 0) return const SizedBox(height: 24);

    final colors = {
      'male': Colors.blue,
      'female': Colors.pink,
      'other': Colors.purple,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 24,
        child: Row(
          children: _genderWeights.entries.map((entry) {
            final weight = entry.value;
            if (weight <= 0) return const SizedBox.shrink();

            final color = colors[entry.key] ?? Colors.grey;
            final percent = (weight / total * 100).toStringAsFixed(0);

            return Expanded(
              flex: weight,
              child: Tooltip(
                message: '${entry.key}: $percent%',
                child: Container(
                  color: color.withOpacity(0.7),
                  child: Center(
                    child: Text(
                      weight >= 10 ? '$percent%' : '',
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

  Widget _buildWeightSlider({
    required String label,
    required int value,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$value',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
