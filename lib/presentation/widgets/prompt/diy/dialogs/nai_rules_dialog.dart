import 'package:flutter/material.dart';

/// NAI 随机规则说明弹窗
///
/// 展示 Prompt 生成器的内置规则逻辑
class NaiRulesDialog extends StatelessWidget {
  const NaiRulesDialog({super.key});

  /// 显示弹窗
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const NaiRulesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 8),
          Text('NAI 随机规则说明'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSection(
                context,
                title: '角色数量概率',
                icon: Icons.people_outline,
                children: [
                  _buildProbabilityItem(context, '1人 (Solo)', '50%'),
                  _buildProbabilityItem(context, '2人 (Duo)', '30%'),
                  _buildProbabilityItem(context, '3人 (Trio)', '15%'),
                  _buildProbabilityItem(context, '4人 (Group)', '5%'),
                ],
              ),
              _buildSection(
                context,
                title: '性别规则',
                icon: Icons.wc,
                children: [
                  _buildProbabilityItem(context, '女性 (Female)', '30%'),
                  _buildProbabilityItem(context, '男性 (Male)', '10%'),
                  _buildProbabilityItem(context, '混合/其他 (Mixed)', '60%'),
                ],
              ),
              _buildSection(
                context,
                title: '类别概率',
                icon: Icons.category_outlined,
                children: [
                  const ListTile(
                    dense: true,
                    title: Text('标签权重动态调整'),
                    subtitle:
                        Text('包含动作、服饰、表情、背景等多个维度的随机组合，根据画面主题动态调整各类别的抽取权重'),
                  ),
                ],
              ),
              _buildSection(
                context,
                title: '特殊机制',
                icon: Icons.auto_awesome,
                children: [
                  _buildProbabilityItem(
                    context,
                    '强调机制 (Tag Strengthening)',
                    '2%',
                  ),
                  const ListTile(
                    dense: true,
                    title: Text('季节词库'),
                    subtitle: Text('自动匹配季节特征，包含季节性服饰、天气、光照效果和环境氛围'),
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'V4 多角色位置',
                icon: Icons.grid_view,
                children: [
                  const ListTile(
                    dense: true,
                    title: Text('智能位置分配'),
                    subtitle:
                        Text('在 V4 模型下，使用 character positioning 语法精确控制多角色站位'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('了解了'),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: children,
      ),
    );
  }

  Widget _buildProbabilityItem(
    BuildContext context,
    String label,
    String probability,
  ) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(label),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          probability,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
