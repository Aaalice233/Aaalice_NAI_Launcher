import 'package:flutter/material.dart';

import '../../common/elevated_card.dart';

/// DIY 面板里的开关行：状态图标、标题与可选说明，开关在行尾
///
/// 未指定 [icon] 时按开关状态显示启用或停用图标。
class DiySwitchRow extends StatelessWidget {
  const DiySwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// 为空时开关禁用
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = this.subtitle;
    return Row(
      children: [
        Icon(
          icon ?? (value ? Icons.check_circle_rounded : Icons.cancel_rounded),
          size: 20,
          color:
              iconColor ?? (value ? colorScheme.primary : colorScheme.outline),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// 独占一张卡片的 [DiySwitchRow]
class DiySwitchCard extends StatelessWidget {
  const DiySwitchCard({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      elevation: CardElevation.level1,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DiySwitchRow(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        icon: icon,
        iconColor: iconColor,
      ),
    );
  }
}
