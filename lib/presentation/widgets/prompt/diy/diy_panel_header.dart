import 'package:flutter/material.dart';

/// DIY 配置面板的标题；尾随内容与标题并排放不下时移到标题下方
///
/// 标题完整换行显示，不为给尾随内容让位而被挤成窄列。
class DiyPanelHeader extends StatelessWidget {
  const DiyPanelHeader({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.2),
                accent.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return _HeadingWithTrailing(heading: heading, trailing: trailing);
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
