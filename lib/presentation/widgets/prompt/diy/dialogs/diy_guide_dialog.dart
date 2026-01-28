import 'package:flutter/material.dart';
import '../../../../widgets/common/themed_divider.dart';

/// DIY 功能指南弹窗
///
/// 展示 DIY 系统的各项功能说明和使用示例
class DiyGuideDialog extends StatelessWidget {
  const DiyGuideDialog({super.key});

  /// 显示弹窗
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const DiyGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.help_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('DIY 功能指南'),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本指南介绍了 DIY 系统的核心概念和高级功能，帮助您构建强大的动态提示词库。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const _GuideSection(
                title: '层级结构 (Hierarchy)',
                icon: Icons.account_tree_outlined,
                description: 'DIY 系统采用三级分类结构来组织提示词，便于管理和检索。',
                example:
                    'Category (分类): 角色特征\n  └─ Group (分组): 发型\n      └─ Tag (标签): 长发, 短发, 双马尾',
              ),
              const _GuideSection(
                title: '选择模式 (Selection Mode)',
                icon: Icons.select_all,
                description: '决定从一个分组(Group)中选取多少个标签。',
                example:
                    '• Random (随机): 每次随机选取一个 (如：随机发色)\n• All (全选): 选取组内所有标签 (如：固定特征组合)',
              ),
              const _GuideSection(
                title: '权重控制 (Weight)',
                icon: Icons.fitness_center,
                description: '调整特定提示词在生成过程中的影响力。',
                example:
                    '• 增强: {masterpiece} = 1.05倍权重\n• 强力增强: {{{masterpiece}}} = 1.16倍权重\n• 减弱: [bad hands] = 0.95倍权重',
              ),
              const _GuideSection(
                title: '性别限制 (Gender)',
                icon: Icons.wc,
                description: '限制标签仅对特定性别的角色生效，避免生成错误的特征。',
                example:
                    '• Female: 仅女性角色可用 (如：裙子)\n• Male: 仅男性角色可用 (如：胡须)\n• Any: 通用 (如：T恤)',
              ),
              const _GuideSection(
                title: '作用域 (Scope)',
                icon: Icons.api,
                description: '定义标签是作用于角色本身、背景环境还是全局画面。',
                example:
                    '• Character: 角色特征 (眼睛, 头发)\n• Background: 环境描述 (蓝天, 室内)\n• Global: 画风, 质量词 (best quality)',
              ),
              const _GuideSection(
                title: '条件分支 (Conditional)',
                icon: Icons.call_split,
                description: '基于已选标签或其他条件来动态决定后续标签。',
                example:
                    'IF (已选 "下雨")\n  THEN {添加 "雨伞", "湿衣服"}\n  ELSE {添加 "晴朗"}',
              ),
              const _GuideSection(
                title: '依赖引用 (Dependencies)',
                icon: Icons.link,
                description: '建立标签间的关联，选中一个标签时自动引入相关联的其他标签。',
                example: '选中 "JK制服" -> 自动引入 "学校背景", "书包"',
              ),
              const _GuideSection(
                title: '可见性规则 (Visibility)',
                icon: Icons.visibility_outlined,
                description: '控制标签在界面上的显示条件，或在生成时的生效条件。',
                example: '仅当选中 "魔法少女" 分类时，显示 "魔杖" 选项组',
              ),
              const _GuideSection(
                title: '时间条件 (Time)',
                icon: Icons.schedule,
                description: '根据现实时间或设定的模拟时间触发特定标签。',
                example:
                    '• 06:00-18:00 -> 添加 "daylight"\n• 18:00-06:00 -> 添加 "night"',
              ),
              const _GuideSection(
                title: '后处理规则 (Post-processing)',
                icon: Icons.cleaning_services_outlined,
                description: '在提示词生成最后阶段进行文本替换或清理。',
                example: '将所有 "blue eyes" 替换为 "azure eyes" 以获得更独特的描述',
              ),
              const _GuideSection(
                title: '强调概率 (Emphasis)',
                icon: Icons.casino_outlined,
                description: '为标签随机添加权重符号的概率，增加结果的多样性。',
                example: '设置 30% 概率: 约有 1/3 的机会输出 {tag}, 2/3 的机会输出 tag',
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('明白了'),
        ),
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final String example;

  const _GuideSection({
    required this.title,
    required this.icon,
    required this.description,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ThemedDivider(),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '示例:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  example,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
