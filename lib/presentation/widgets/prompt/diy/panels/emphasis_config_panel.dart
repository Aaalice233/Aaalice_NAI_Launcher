import 'package:flutter/material.dart';

import '../../../common/themed_slider.dart';

/// 全局强调配置面板
///
/// 用于配置全局强调概率和括号层数
class EmphasisConfigPanel extends StatelessWidget {
  /// 强调概率 (0.0-1.0)
  final double emphasisProbability;

  /// 括号层数
  final int bracketCount;

  /// 概率变更回调
  final ValueChanged<double> onProbabilityChanged;

  /// 括号层数变更回调
  final ValueChanged<int> onBracketCountChanged;

  /// 是否只读
  final bool readOnly;

  const EmphasisConfigPanel({
    super.key,
    required this.emphasisProbability,
    required this.bracketCount,
    required this.onProbabilityChanged,
    required this.onBracketCountChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildProbabilityCard(context),
        const SizedBox(height: 16),
        _buildBracketCountCard(context),
        const SizedBox(height: 16),
        _buildPreviewCard(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.format_bold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '全局强调配置',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildProbabilityCard(BuildContext context) {
    final percent = (emphasisProbability * 100).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '强调概率',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ThemedSlider(
              value: emphasisProbability,
              min: 0,
              max: 0.2, // 最大 20%
              divisions: 40,
              onChanged: readOnly ? null : onProbabilityChanged,
            ),
            Text(
              '每个选中的标签有 $percent% 的概率被添加强调括号',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketCountCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '括号层数',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '$bracketCount 层',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final count = index + 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('$count'),
                      selected: bracketCount == count,
                      onSelected: readOnly
                          ? null
                          : (selected) {
                              if (selected) {
                                onBracketCountChanged(count);
                              }
                            },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final openBrackets = '{' * bracketCount;
    final closeBrackets = '}' * bracketCount;
    final example = '${openBrackets}example tag$closeBrackets';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '效果预览',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Text(
                example,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '强调括号会增加标签的权重，层数越多权重越高',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
