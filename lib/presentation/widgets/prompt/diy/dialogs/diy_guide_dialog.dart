import 'package:flutter/material.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/elevated_card.dart';

/// DIY 功能指南弹窗
///
/// 展示 DIY 系统的各项功能说明和使用示例
/// 采用 Dimensional Layering 设计风格
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
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(context),
            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 介绍文本
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.3),
                            colorScheme.primaryContainer.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '本指南介绍了 DIY 系统的核心概念和高级功能，帮助您构建强大的动态提示词库。',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 功能指南卡片
                    const _GuideSection(
                      title: '层级结构 (Hierarchy)',
                      icon: Icons.account_tree_rounded,
                      color: Colors.blue,
                      description: 'DIY 系统采用三级分类结构来组织提示词，便于管理和检索。',
                      example:
                          'Category (分类): 角色特征\n  └─ Group (分组): 发型\n      └─ Tag (标签): 长发, 短发, 双马尾',
                    ),
                    const _GuideSection(
                      title: '选择模式 (Selection Mode)',
                      icon: Icons.select_all_rounded,
                      color: Colors.green,
                      description: '决定从一个分组(Group)中选取多少个标签。',
                      example:
                          '• Random (随机): 每次随机选取一个 (如：随机发色)\n• All (全选): 选取组内所有标签 (如：固定特征组合)',
                    ),
                    const _GuideSection(
                      title: '权重控制 (Weight)',
                      icon: Icons.fitness_center_rounded,
                      color: Colors.orange,
                      description: '调整特定提示词在生成过程中的影响力。',
                      example:
                          '• 增强: {masterpiece} = 1.05倍权重\n• 强力增强: {{{masterpiece}}} = 1.16倍权重\n• 减弱: [bad hands] = 0.95倍权重',
                    ),
                    const _GuideSection(
                      title: '性别限制 (Gender)',
                      icon: Icons.wc_rounded,
                      color: Colors.pink,
                      description: '限制标签仅对特定性别的角色生效，避免生成错误的特征。',
                      example:
                          '• Female: 仅女性角色可用 (如：裙子)\n• Male: 仅男性角色可用 (如：胡须)\n• Any: 通用 (如：T恤)',
                    ),
                    const _GuideSection(
                      title: '作用域 (Scope)',
                      icon: Icons.layers_rounded,
                      color: Colors.purple,
                      description: '定义标签是作用于角色本身、背景环境还是全局画面。',
                      example:
                          '• Character: 角色特征 (眼睛, 头发)\n• Background: 环境描述 (蓝天, 室内)\n• Global: 画风, 质量词 (best quality)',
                    ),
                    const _GuideSection(
                      title: '条件分支 (Conditional)',
                      icon: Icons.call_split_rounded,
                      color: Colors.teal,
                      description: '基于已选标签或其他条件来动态决定后续标签。',
                      example:
                          'IF (已选 "下雨")\n  THEN {添加 "雨伞", "湿衣服"}\n  ELSE {添加 "晴朗"}',
                    ),
                    const _GuideSection(
                      title: '依赖引用 (Dependencies)',
                      icon: Icons.link_rounded,
                      color: Colors.indigo,
                      description: '建立标签间的关联，选中一个标签时自动引入相关联的其他标签。',
                      example: '选中 "JK制服" -> 自动引入 "学校背景", "书包"',
                    ),
                    const _GuideSection(
                      title: '可见性规则 (Visibility)',
                      icon: Icons.visibility_rounded,
                      color: Colors.cyan,
                      description: '控制标签在界面上的显示条件，或在生成时的生效条件。',
                      example: '仅当选中 "魔法少女" 分类时，显示 "魔杖" 选项组',
                    ),
                    const _GuideSection(
                      title: '时间条件 (Time)',
                      icon: Icons.schedule_rounded,
                      color: Colors.amber,
                      description: '根据现实时间或设定的模拟时间触发特定标签。',
                      example:
                          '• 06:00-18:00 -> 添加 "daylight"\n• 18:00-06:00 -> 添加 "night"',
                    ),
                    const _GuideSection(
                      title: '后处理规则 (Post-processing)',
                      icon: Icons.auto_fix_high_rounded,
                      color: Colors.deepOrange,
                      description: '在提示词生成最后阶段进行文本替换或清理。',
                      example: '将所有 "blue eyes" 替换为 "azure eyes" 以获得更独特的描述',
                    ),
                    const _GuideSection(
                      title: '强调概率 (Emphasis)',
                      icon: Icons.format_bold_rounded,
                      color: Colors.brown,
                      description: '为标签随机添加权重符号的概率，增加结果的多样性。',
                      example: '设置 30% 概率: 约有 1/3 的机会输出 {tag}, 2/3 的机会输出 tag',
                    ),
                  ],
                ),
              ),
            ),
            // 底部按钮
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // 图标容器
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withOpacity(0.2),
                  colorScheme.primary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 24,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DIY 功能指南',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '了解高级功能，创建专属词库',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('明白了'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String example;

  const _GuideSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedCard(
        elevation: CardElevation.level1,
        hoverElevation: CardElevation.level2,
        enableHoverEffect: true,
        borderRadius: 12,
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(
            dividerColor: Colors.transparent,
            splashColor: color.withOpacity(0.1),
            highlightColor: color.withOpacity(0.05),
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ThemedDivider(),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              // 示例代码框
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '示例',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      example,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurface.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
