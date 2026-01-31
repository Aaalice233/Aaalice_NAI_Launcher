import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../../data/models/gallery/gallery_statistics.dart';
import '../../utils/utils.dart';
import '../cards/chart_card.dart';

/// 其他统计卡片 - 显示平均文件大小和有元数据的图片数
/// Other stats card - displays average file size and images with metadata
class OtherStatsCard extends StatelessWidget {
  final GalleryStatistics stats;

  const OtherStatsCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return ChartCard(
      title: l10n.statistics_additionalStats,
      titleIcon: Icons.insights_outlined,
      accentColor: Colors.orange,
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: l10n.statistics_averageFileSize,
              value: StatisticsFormatter.formatBytes(
                stats.totalImages > 0
                    ? stats.totalSizeBytes ~/ stats.totalImages
                    : 0,
              ),
              isDark: isDark,
              colorScheme: colorScheme,
              textTheme: theme.textTheme,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatItem(
              label: l10n.statistics_withMetadata,
              value: '${stats.imagesWithMetadata}',
              isDark: isDark,
              colorScheme: colorScheme,
              textTheme: theme.textTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StatItem({
    required this.label,
    required this.value,
    required this.isDark,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(isDark ? 0.08 : 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
