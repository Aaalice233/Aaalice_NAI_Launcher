import 'package:flutter/material.dart';
import '../../../../themes/theme_extension.dart';

/// Section header widget
/// 章节标题组件
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Chart card wrapper with consistent styling and enhanced visual effects
/// 图表卡片包装器，提供一致的样式和增强的视觉效果
class ChartCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? titleIcon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool elevated;

  const ChartCard({
    super.key,
    required this.child,
    this.title,
    this.titleIcon,
    this.trailing,
    this.padding,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final shadowIntensity = extension?.shadowIntensity ?? 0.1;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(shadowIntensity),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -8,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? EdgeInsets.all(isDesktop ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    if (titleIcon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          titleIcon,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Stat row widget for key-value display
/// 统计行组件，用于键值对显示
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: labelStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value,
          style: valueStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

/// Empty state widget for charts
/// 图表空状态组件
class ChartEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const ChartEmptyState({
    super.key,
    this.icon = Icons.bar_chart_outlined,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
