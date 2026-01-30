import 'package:flutter/material.dart';
import '../animated/animated_number.dart';

/// Statistics card widget
/// 统计卡片组件
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool animate;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.animate = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Try to parse number from value for animation
    final numberMatch = RegExp(r'^[\d,]+\.?\d*').firstMatch(value);
    final suffix = numberMatch != null ? value.substring(numberMatch.end) : '';
    final numberStr = numberMatch?.group(0) ?? value;
    final number = int.tryParse(numberStr.replaceAll(',', '')) ?? 0;

    // Only animate if it's a pure number or number with percentage
    final shouldAnimate = animate &&
        (RegExp(r'^[\d,]+\.?\d*(?:\s*\(?\d+\.?\d*%?\)?)?$').hasMatch(value) ||
            RegExp(r'^[\d,]+\s*\(?\d+\.?\d*%?\)?$').hasMatch(value));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // 深度层叠风格：使用更高对比度的彩色背景
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          // 添加轻微阴影增强层次感
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            shouldAnimate
                ? AnimatedNumber(
                    targetValue: number,
                    suffix: suffix,
                    style: theme.textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(),
                  )
                : Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Trend summary item
/// 趋势汇总项
class TrendSummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const TrendSummaryItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Legend item widget
/// 图例项组件
class LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
