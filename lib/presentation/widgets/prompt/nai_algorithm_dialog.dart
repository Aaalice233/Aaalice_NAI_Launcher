import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';

/// NAI随机算法说明弹窗
///
/// 详细展示 NovelAI 官网的随机提示词生成算法
class NaiAlgorithmDialog extends StatelessWidget {
  const NaiAlgorithmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(context.l10n.naiAlgorithm_title),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 角色数量分布
              _buildSection(
                context,
                theme,
                icon: Icons.group,
                title: context.l10n.naiAlgorithm_characterCount,
                child: Column(
                  children: [
                    _buildProbabilityBar(context, theme, '1人 (solo)', 70, Colors.blue),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, '2人 (2girls等)', 20, Colors.green),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, '3人 (multiple)', 7, Colors.orange),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, '无人物', 5, Colors.grey),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. 类别选择概率（与主界面一致）
              _buildSection(
                context,
                theme,
                icon: Icons.category,
                title: context.l10n.naiAlgorithm_categoryProbability,
                child: Column(
                  children: [
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_background, 90, Colors.teal),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_hairColor, 50, Colors.purple),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_eyeColor, 50, Colors.blue),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_hairStyle, 50, Colors.pink),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_expression, 50, Colors.amber),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_pose, 50, Colors.indigo),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_clothing, 50, Colors.orange),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_accessory, 50, Colors.brown),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_scene, 50, Colors.green),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_style, 30, Colors.cyan),
                    const SizedBox(height: 6),
                    _buildProbabilityBar(context, theme, context.l10n.naiAlgorithm_bodyFeature, 30, Colors.grey),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. 加权随机算法
              _buildSection(
                context,
                theme,
                icon: Icons.functions,
                title: context.l10n.naiAlgorithm_weightedRandom,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.naiAlgorithm_weightedRandomDesc,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    // 公式展示
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormula(theme, 'weight = post_count / 100000'),
                          const SizedBox(height: 4),
                          _buildFormula(theme, 'P(tag) = weight / Σweights'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. V4 多角色联动
              _buildSection(
                context,
                theme,
                icon: Icons.people,
                title: context.l10n.naiAlgorithm_v4MultiCharacter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.naiAlgorithm_v4Desc,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    // 结构示意
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStructureItem(
                            theme,
                            context.l10n.naiAlgorithm_mainPrompt,
                            context.l10n.naiAlgorithm_mainPromptTags,
                            theme.colorScheme.primary,
                          ),
                          const Divider(height: 16),
                          _buildStructureItem(
                            theme,
                            context.l10n.naiAlgorithm_characterPrompt,
                            context.l10n.naiAlgorithm_characterPromptTags,
                            theme.colorScheme.tertiary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. 无人物场景
              _buildSection(
                context,
                theme,
                icon: Icons.landscape,
                title: context.l10n.naiAlgorithm_noHuman,
                child: Text(
                  context.l10n.naiAlgorithm_noHumanDesc,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_close),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: child,
        ),
      ],
    );
  }

  Widget _buildProbabilityBar(
    BuildContext context,
    ThemeData theme,
    String label,
    int percentage,
    Color color,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              // 背景
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // 进度条
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$percentage%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildFormula(ThemeData theme, String formula) {
    return Text(
      formula,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStructureItem(
    ThemeData theme,
    String label,
    String content,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
