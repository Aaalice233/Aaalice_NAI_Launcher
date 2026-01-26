import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../data/models/gallery/gallery_statistics.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/statistics_service.dart';
import '../providers/local_gallery_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 统计仪表盘屏幕
///
/// 显示本地画廊的各种统计信息，包括：
/// - 总图片数和总大小
/// - 模型分布图表
/// - 分辨率分布图表
/// - 采样器分布图表
/// - 文件大小分布图表
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
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

  /// 计算统计数据
  Future<GalleryStatistics> _calculateStatistics() async {
    final state = ref.read(localGalleryNotifierProvider);
    final service = ref.read(statisticsServiceProvider);

    // 从仓库加载所有记录
    final repository = LocalGalleryRepository.instance;
    final allRecords = await repository.loadRecords(state.allFiles);

    return service.calculateStatistics(allRecords);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statistics_title),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.statistics_tabOverview),
            Tab(text: l10n.statistics_tabTrends),
            Tab(text: l10n.statistics_tabDetails),
          ],
        ),
      ),
      body: FutureBuilder<GalleryStatistics>(
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final statistics = snapshot.data;

          if (statistics == null || statistics.totalImages == 0) {
            return _buildEmptyState(theme);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Overview Tab
              _buildOverviewTab(theme, statistics, l10n),
              // Trends Tab
              _buildTrendsTab(theme, statistics, l10n),
              // Details Tab
              _buildDetailsTab(theme, statistics, l10n),
            ],
          );
        },
      ),
    );
  }

  /// 构建 Overview Tab
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
          // 总览统计卡片
          _buildOverviewCards(theme, statistics, l10n),
        ],
      ),
    );
  }

  /// 构建 Trends Tab
  Widget _buildTrendsTab(
    ThemeData theme,
    GalleryStatistics statistics,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 模型分布图表
          if (statistics.modelDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_modelDistribution,
              Icons.category,
            ),
            const SizedBox(height: 12),
            _buildModelDistributionChart(theme, statistics, l10n),
            const SizedBox(height: 24),
          ],

          // 分辨率分布图表
          if (statistics.resolutionDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_resolutionDistribution,
              Icons.aspect_ratio,
            ),
            const SizedBox(height: 12),
            _buildResolutionDistributionChart(theme, statistics, l10n),
            const SizedBox(height: 24),
          ],

          // 采样器分布图表
          if (statistics.samplerDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_samplerDistribution,
              Icons.tune,
            ),
            const SizedBox(height: 12),
            _buildSamplerDistributionChart(theme, statistics, l10n),
            const SizedBox(height: 24),
          ],

          // 文件大小分布图表
          if (statistics.sizeDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_sizeDistribution,
              Icons.storage,
            ),
            const SizedBox(height: 12),
            _buildSizeDistributionChart(theme, statistics, l10n),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  /// 构建 Details Tab
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
          // 其他统计
          _buildAdditionalStats(theme, statistics, l10n),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    final l10n = context.l10n;

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

  /// 构建总览统计卡片
  Widget _buildOverviewCards(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statistics_overview,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    Icons.photo_library,
                    l10n.statistics_totalImages,
                    '${stats.totalImages}',
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    Icons.storage,
                    l10n.statistics_totalSize,
                    stats.totalSizeFormatted,
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
                    '${stats.favoriteCount} (${stats.favoritePercentage.toStringAsFixed(1)}%)',
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    Icons.tag,
                    l10n.statistics_tagged,
                    '${stats.taggedImageCount} (${stats.taggedImagePercentage.toStringAsFixed(1)}%)',
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个统计卡片
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

  /// 构建章节标题
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
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

  /// 构建模型分布图表（饼图）
  Widget _buildModelDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
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

  /// 构建分辨率分布图表（横向柱状图）
  Widget _buildResolutionDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
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

  /// 构建采样器分布图表（饼图）
  Widget _buildSamplerDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
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

  /// 构建文件大小分布图表（横向柱状图）
  Widget _buildSizeDistributionChart(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
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

  /// 构建饼图扇区（模型分布）
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

  /// 构建饼图扇区（采样器分布）
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

  /// 构建图例项
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

  /// 构建其他统计信息
  Widget _buildAdditionalStats(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statistics_additionalStats,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              theme,
              l10n.statistics_averageFileSize,
              stats.averageSizeFormatted,
            ),
            const Divider(height: 24),
            _buildStatRow(
              theme,
              l10n.statistics_withMetadata,
              '${stats.imagesWithMetadata} (${stats.metadataPercentage.toStringAsFixed(1)}%)',
            ),
            const Divider(height: 24),
            _buildStatRow(
              theme,
              l10n.statistics_calculatedAt,
              _formatDateTime(stats.calculatedAt, l10n),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计行
  Widget _buildStatRow(
    ThemeData theme,
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.statistics_justNow;
    } else if (difference.inMinutes < 60) {
      return l10n.statistics_minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.statistics_hoursAgo(difference.inHours);
    } else {
      return l10n.statistics_daysAgo(difference.inDays);
    }
  }

  /// 获取颜色（循环使用）
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
