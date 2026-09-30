import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

/// 面板标题尾随的数量徽标
class DiyCountBadge extends StatelessWidget {
  const DiyCountBadge({
    super.key,
    required this.label,
    required this.accent,
    required this.container,
  });

  final String label;
  final Color accent;
  final Color container;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: container.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: accent,
        ),
      ),
    );
  }
}

/// 规则或分支列表条目上的已禁用标记
class DiyDisabledBadge extends StatelessWidget {
  const DiyDisabledBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        context.l10n.common_disabled,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colorScheme.error),
      ),
    );
  }
}
