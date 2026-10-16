import 'package:flutter/material.dart';

/// DIY 配置面板的首行：说明面板作用；尾随内容并排放不下时移到说明下方
///
/// 面板名称由承载它的表单标题显示，这里不再重复。
class DiyPanelHeader extends StatelessWidget {
  const DiyPanelHeader({super.key, required this.description, this.trailing});

  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HeadingWithTrailing(
      heading: Text(
        description,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
    );
  }
}

/// DIY 面板内分组卡片的标题行
class DiySectionTitle extends StatelessWidget {
  const DiySectionTitle({
    super.key,
    required this.icon,
    required this.accent,
    required this.container,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final Color accent;
  final Color container;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: container.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: accent),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
    return _HeadingWithTrailing(heading: heading, trailing: trailing);
  }
}

class _HeadingWithTrailing extends StatelessWidget {
  const _HeadingWithTrailing({required this.heading, this.trailing});

  final Widget heading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    if (trailing == null) return heading;
    return OverflowBar(
      alignment: MainAxisAlignment.spaceBetween,
      overflowAlignment: OverflowBarAlignment.start,
      spacing: 12,
      overflowSpacing: 8,
      children: [heading, trailing],
    );
  }
}
