import 'package:flutter/material.dart';

import '../../common/elevated_card.dart';
import 'diy_badges.dart';

/// [DiyRuleListCard] 中的一行
class DiyRuleListItem {
  const DiyRuleListItem({
    required this.leading,
    required this.title,
    required this.enabled,
    this.details = const [],
  });

  final Widget leading;
  final String title;
  final bool enabled;
  final List<Widget> details;
}

/// 规则或分支列表：点按条目选中编辑，[onDeleted] 为空时不提供删除；
/// 没有条目时显示 [emptyState]
class DiyRuleListCard extends StatelessWidget {
  const DiyRuleListCard({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onDeleted,
    required this.deleteTooltip,
    required this.emptyState,
  });

  final List<DiyRuleListItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int>? onDeleted;
  final String deleteTooltip;
  final Widget emptyState;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return emptyState;
    final divider = Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    );
    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) divider,
            _DiyRuleListRow(
              item: item,
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
              onDeleted: onDeleted == null ? null : () => onDeleted!(index),
              deleteTooltip: deleteTooltip,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiyRuleListRow extends StatelessWidget {
  const _DiyRuleListRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onDeleted,
    required this.deleteTooltip,
  });

  final DiyRuleListItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDeleted;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onDeleted = this.onDeleted;
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              item.leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      ...item.details,
                    ],
                    if (!item.enabled) ...[
                      const SizedBox(height: 4),
                      const DiyDisabledBadge(),
                    ],
                  ],
                ),
              ),
              if (onDeleted != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error.withValues(alpha: 0.7),
                  ),
                  onPressed: onDeleted,
                  tooltip: deleteTooltip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 列表条目前的强调色标记；停用时退为中性底色
class DiyRuleAvatar extends StatelessWidget {
  const DiyRuleAvatar({
    super.key,
    required this.accent,
    required this.enabled,
    required this.builder,
    this.shape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    this.padding = const EdgeInsets.all(10),
    this.constraints,
  });

  final Color accent;
  final bool enabled;

  /// 按当前底色给出前景色
  final Widget Function(Color foreground) builder;
  final ShapeBorder shape;
  final EdgeInsetsGeometry padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: constraints,
      padding: padding,
      decoration: ShapeDecoration(
        shape: shape,
        gradient: enabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, accent.withValues(alpha: 0.7)],
              )
            : null,
        color: enabled ? null : colorScheme.surfaceContainerHighest,
        shadows: enabled
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: builder(enabled ? Colors.white : colorScheme.onSurfaceVariant),
    );
  }
}

/// 列表下方的添加按钮
class DiyAddRuleButton extends StatelessWidget {
  const DiyAddRuleButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
