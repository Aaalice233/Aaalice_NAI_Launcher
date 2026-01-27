import 'package:flutter/material.dart';

/// Model ranking item data
class ModelRankItem {
  final String name;
  final int count;
  final double percentage;
  final double? trend; // percentage change

  const ModelRankItem({
    required this.name,
    required this.count,
    required this.percentage,
    this.trend,
  });
}

/// Model ranking list widget with progress bars
class ModelRankingList extends StatelessWidget {
  final List<ModelRankItem> items;
  final int maxItems;
  final ValueChanged<ModelRankItem>? onItemTap;

  const ModelRankingList({
    super.key,
    required this.items,
    this.maxItems = 10,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayItems = items.take(maxItems).toList();
    if (displayItems.isEmpty) {
      return const Center(
        child: Text('No model data available'),
      );
    }

    return Column(
      children: displayItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _ModelRankRow(
          rank: index + 1,
          item: item,
          onTap: onItemTap != null ? () => onItemTap!(item) : null,
        );
      }).toList(),
    );
  }
}

class _ModelRankRow extends StatelessWidget {
  final int rank;
  final ModelRankItem item;
  final VoidCallback? onTap;

  const _ModelRankRow({
    required this.rank,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Rank badge colors
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD700), // Gold
      2 => const Color(0xFFC0C0C0), // Silver
      3 => const Color(0xFFCD7F32), // Bronze
      _ => colorScheme.surfaceContainerHighest,
    };

    final rankTextColor = rank <= 3 ? Colors.black : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: rankTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Model name and count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.percentage / 100,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary.withOpacity(0.8),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Stats column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.count}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.percentage.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (item.trend != null) ...[
                        const SizedBox(width: 4),
                        _TrendBadge(trend: item.trend!),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double trend;

  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isPositive = trend > 0;
    final isNegative = trend < 0;
    final color = isPositive
        ? Colors.green
        : isNegative
            ? Colors.red
            : Colors.grey;

    final icon = isPositive
        ? Icons.arrow_upward
        : isNegative
            ? Icons.arrow_downward
            : Icons.remove;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        Text(
          '${trend.abs().toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
