import 'package:flutter/material.dart';

/// 模型选择抽屉
///
/// 收起时在标题行回显当前模型名（藏起来的是控件，不是信息），
/// 点击展开完整的模型选择控件。
class CollapsibleModelSelector extends StatelessWidget {
  final String title;
  final String currentModelName;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget child;

  const CollapsibleModelSelector({
    super.key,
    required this.title,
    required this.currentModelName,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      title: Row(
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              currentModelName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
      children: [child],
    );
  }
}
