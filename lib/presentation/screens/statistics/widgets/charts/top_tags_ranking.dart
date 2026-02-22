import 'package:flutter/material.dart';

/// Tag ranking item data
class TagRankItem {
  final String tag;
  final int count;
  final double percentage;
  final double? trend;

  const TagRankItem({
    required this.tag,
    required this.count,
    required this.percentage,
    this.trend,
  });
}

/// Top tags ranking list widget
class TopTagsRanking extends StatelessWidget {
  final List<TagRankItem> items;
  final int maxItems;
  final ValueChanged<TagRankItem>? onItemTap;
  final bool showTrend;

  const TopTagsRanking({
    super.key,
    required this.items,
    this.maxItems = 20,
    this.onItemTap,
    this.showTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayItems = items.take(maxItems).toList();
    if (displayItems.isEmpty) {
      return const Center(
        child: Text('No tag data available'),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    // Use grid for desktop, list for mobile
    if (isDesktop && displayItems.length > 5) {
      return _buildGrid(context, displayItems);
    }

    return Column(
      children: displayItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _TagRankRow(
          rank: index + 1,
          item: item,
          showTrend: showTrend,
          onTap: onItemTap != null ? () => onItemTap!(item) : null,
        );
      }).toList(),
    );
  }

  Widget _buildGrid(BuildContext context, List<TagRankItem> items) {
    final leftColumn = items.take((items.length / 2).ceil()).toList();
    final rightColumn = items.skip((items.length / 2).ceil()).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: leftColumn.asMap().entries.map((entry) {
              return _TagRankRow(
                rank: entry.key + 1,
                item: entry.value,
                showTrend: showTrend,
                onTap: onItemTap != null ? () => onItemTap!(entry.value) : null,
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: rightColumn.asMap().entries.map((entry) {
              final actualRank = entry.key + leftColumn.length + 1;
              return _TagRankRow(
                rank: actualRank,
                item: entry.value,
                showTrend: showTrend,
                onTap: onItemTap != null ? () => onItemTap!(entry.value) : null,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TagRankRow extends StatelessWidget {
  final int rank;
  final TagRankItem item;
  final bool showTrend;
  final VoidCallback? onTap;

  const _TagRankRow({
    required this.rank,
    required this.item,
    this.showTrend = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Color based on rank
    final rankColor = _getRankColor(rank, colorScheme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 28,
                child: Text(
                  '#$rank',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tag chip
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: rankColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    item.tag,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: rankColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Count
              Text(
                '${item.count}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showTrend && item.trend != null) ...[
                const SizedBox(width: 6),
                _MiniTrendIndicator(trend: item.trend!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank, ColorScheme colorScheme) {
    return switch (rank) {
      1 => const Color(0xFFFF6B6B),
      2 => const Color(0xFFFF8E53),
      3 => const Color(0xFFFFD93D),
      4 || 5 => colorScheme.primary,
      _ => colorScheme.onSurfaceVariant,
    };
  }
}

class _MiniTrendIndicator extends StatelessWidget {
  final double trend;

  const _MiniTrendIndicator({required this.trend});

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
        ? Icons.north
        : isNegative
            ? Icons.south
            : Icons.remove;

    return Icon(icon, size: 14, color: color);
  }
}
