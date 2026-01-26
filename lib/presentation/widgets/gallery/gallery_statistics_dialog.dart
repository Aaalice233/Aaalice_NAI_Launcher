import 'package:fl_chart/fl_chart.dart';
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
          // Model distribution chart
          if (statistics.modelDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              l10n.statistics_modelDistribution,
              Icons.category,
              theme,
            ),
            const SizedBox(height: 12),
            _buildModelDistributionChart(theme, statistics),
            const SizedBox(height: 24),
          ],

          // Resolution distribution chart
          if (statistics.resolutionDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              l10n.statistics_resolutionDistribution,
              Icons.aspect_ratio,
              theme,
            ),
            const SizedBox(height: 12),
            _buildResolutionDistributionChart(theme, statistics),
            const SizedBox(height: 24),
          ],

          // Sampler distribution chart
          if (statistics.samplerDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              l10n.statistics_samplerDistribution,
              Icons.tune,
              theme,
            ),
            const SizedBox(height: 12),
            _buildSamplerDistributionChart(theme, statistics),
            const SizedBox(height: 24),
          ],

          // File size distribution chart
          if (statistics.sizeDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              l10n.statistics_sizeDistribution,
              Icons.storage,
              theme,
            ),
            const SizedBox(height: 12),
            _buildSizeDistributionChart(theme, statistics),
            const SizedBox(height: 24),
          ],
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

  /// Build section header
  Widget _buildSectionHeader(
    String title,
    IconData icon,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build model distribution chart (PieChart)
  Widget _buildModelDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
  ) {
    final distribution = stats.modelDistribution;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _buildPieSections(distribution, theme),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: distribution.map((model) {
                final color = _getColorForIndex(
                  distribution.indexOf(model),
                );
                return _buildLegendItem(
                  theme,
                  color,
                  '${model.modelName} (${model.count}, ${model.percentage.toStringAsFixed(1)}%)',
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build resolution distribution chart (BarChart)
  Widget _buildResolutionDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
  ) {
    final distribution = stats.resolutionDistribution;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: distribution.length * 40.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: distribution
                          .map((r) => r.count.toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= distribution.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              distribution[index].label,
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                        reservedSize: 80,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toInt().toString(),
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.dividerColor.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: distribution.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data.count.toDouble(),
                          color: _getColorForIndex(index),
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build sampler distribution chart (PieChart)
  Widget _buildSamplerDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
  ) {
    final distribution = stats.samplerDistribution;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: _buildPieSectionsFromSamplers(distribution, theme),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: distribution.map((sampler) {
                final color = _getColorForIndex(
                  distribution.indexOf(sampler),
                );
                return _buildLegendItem(
                  theme,
                  color,
                  '${sampler.samplerName} (${sampler.count}, ${sampler.percentage.toStringAsFixed(1)}%)',
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build file size distribution chart (BarChart)
  Widget _buildSizeDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
  ) {
    final distribution = stats.sizeDistribution;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: distribution.length * 40.0,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: distribution
                          .map((s) => s.count.toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= distribution.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              distribution[index].label,
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                        reservedSize: 80,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toInt().toString(),
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: theme.dividerColor.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: distribution.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: data.count.toDouble(),
                          color: _getColorForIndex(index),
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build pie chart sections (Model distribution)
  List<PieChartSectionData> _buildPieSections(
    List<ModelStatistics> distribution,
    ThemeData theme,
  ) {
    return distribution.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final color = _getColorForIndex(index);

      return PieChartSectionData(
        color: color,
        value: data.count.toDouble(),
        title: '${data.percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }

  /// Build pie chart sections (Sampler distribution)
  List<PieChartSectionData> _buildPieSectionsFromSamplers(
    List<SamplerStatistics> distribution,
    ThemeData theme,
  ) {
    return distribution.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final color = _getColorForIndex(index);

      return PieChartSectionData(
        color: color,
        value: data.count.toDouble(),
        title: '${data.percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();
  }

  /// Build legend item
  Widget _buildLegendItem(
    ThemeData theme,
    Color color,
    String label,
  ) {
    return Row(
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
    );
  }

  /// Get color for index (cycling through colors)
  Color _getColorForIndex(int index) {
    const colors = [
      Color(0xFF4CAF50), // Green
      Color(0xFF2196F3), // Blue
      Color(0xFFFF9800), // Orange
      Color(0xFF9C27B0), // Purple
      Color(0xFFF44336), // Red
      Color(0xFF00BCD4), // Cyan
      Color(0xFF795548), // Brown
      Color(0xFF607D8B), // Blue Grey
      Color(0xFFE91E63), // Pink
      Color(0xFFFFEB3B), // Yellow
    ];

    return colors[index % colors.length];
  }
}
