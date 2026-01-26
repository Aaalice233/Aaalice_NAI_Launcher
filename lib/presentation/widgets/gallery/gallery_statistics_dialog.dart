import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/gallery/gallery_statistics.dart';
import '../../providers/gallery_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Gallery Statistics Dialog
///
/// Shows comprehensive statistics about the gallery including:
/// - Total images, favorites, tagged images
/// - Model distribution
/// - Resolution distribution
/// - Sampler distribution
/// - File size distribution
class GalleryStatisticsDialog extends ConsumerStatefulWidget {
  const GalleryStatisticsDialog({super.key});

  /// Show the statistics dialog
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const GalleryStatisticsDialog(),
    );
  }

  @override
  ConsumerState<GalleryStatisticsDialog> createState() =>
      _GalleryStatisticsDialogState();
}

class _GalleryStatisticsDialogState
    extends ConsumerState<GalleryStatisticsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Calculate statistics asynchronously
  Future<GalleryStatistics> _calculateStatistics() async {
    // The statistics are already calculated in the provider
    // We just need to return them
    final statistics = ref.read(galleryStatisticsProvider);
    return statistics;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bar_chart_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(l10n.statistics_title),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 550,
        child: Column(
          children: [
            // Tab bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              tabs: [
                Tab(
                  icon: const Icon(Icons.dashboard_outlined),
                  text: l10n.statistics_overview,
                ),
                Tab(
                  icon: const Icon(Icons.show_chart),
                  text: l10n.statistics_modelDistribution,
                ),
                Tab(
                  icon: const Icon(Icons.info_outline),
                  text: l10n.statistics_additionalStats,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tab content
            Expanded(
              child: FutureBuilder<GalleryStatistics>(
                future: _calculateStatistics(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  final statistics = snapshot.data;

                  if (statistics == null || statistics.totalImages == 0) {
                    return _buildEmptyState(theme, l10n);
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(theme, statistics, l10n),
                      _buildDistributionsTab(theme, statistics, l10n),
                      _buildDetailsTab(theme, statistics, l10n),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_close),
        ),
      ],
    );
  }

  /// Build empty state when no records exist
  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.statistics_noData,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.statistics_generateFirst,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Overview tab
  Widget _buildOverviewTab(
    ThemeData theme,
    GalleryStatistics statistics,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  Icons.photo_library,
                  l10n.statistics_totalImages,
                  '${statistics.totalImages}',
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  Icons.storage,
                  l10n.statistics_totalSize,
                  statistics.totalSizeFormatted,
                  theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  Icons.favorite,
                  l10n.statistics_favorites,
                  '${statistics.favoriteCount} (${statistics.favoritePercentage.toStringAsFixed(1)}%)',
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  Icons.tag,
                  l10n.statistics_tagged,
                  '${statistics.taggedImageCount} (${statistics.taggedImagePercentage.toStringAsFixed(1)}%)',
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Distributions tab
  Widget _buildDistributionsTab(
    ThemeData theme,
    GalleryStatistics statistics,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Charts will be added in subtask-2-3
          Text(
            'Distributions tab - Coming soon',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Details tab
  Widget _buildDetailsTab(
    ThemeData theme,
    GalleryStatistics statistics,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Additional stats will be added in subtask-2-4
          Text(
            'Details tab - Coming soon',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single stat card
  Widget _buildStatCard(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
