import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../data/models/gallery/gallery_statistics.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/repositories/local_gallery_repository.dart';
import '../../data/services/statistics_service.dart';
import '../providers/local_gallery_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 动画数字显示组件
class _AnimatedNumber extends StatefulWidget {
  final int targetValue;
  final String suffix;
  final TextStyle style;
  final Duration duration;

  const _AnimatedNumber({
    required this.targetValue,
    this.suffix = '',
    required this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<_AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<_AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = (_animation.value * widget.targetValue).toInt();
        return Text(
          '$value${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// 动画柱状图组件
class _AnimatedBarChart extends StatefulWidget {
  final BarChartData data;
  final double height;

  const _AnimatedBarChart({
    required this.data,
    required this.height,
  });

  @override
  State<_AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<_AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Animate bar growth from zero
          final animatedData = BarChartData(
            alignment: widget.data.alignment,
            maxY: widget.data.maxY,
            minY: widget.data.minY,
            barTouchData: widget.data.barTouchData,
            titlesData: widget.data.titlesData,
            gridData: widget.data.gridData,
            borderData: widget.data.borderData,
            barGroups: widget.data.barGroups?.map((group) {
              return BarChartGroupData(
                x: group.x,
                barRods: group.barRods.map((rod) {
                  return BarChartRodData(
                    toY: rod.toY * _animation.value,
                    color: rod.color,
                    width: rod.width,
                    borderRadius: rod.borderRadius,
                  );
                }).toList(),
              );
            }).toList(),
          );

          return BarChart(animatedData);
        },
      ),
    );
  }
}

/// 动画饼图组件
class _AnimatedPieChart extends StatefulWidget {
  final PieChartData data;
  final double height;

  const _AnimatedPieChart({
    required this.data,
    required this.height,
  });

  @override
  State<_AnimatedPieChart> createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<_AnimatedPieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          // Animate pie growth from zero
          final animatedData = PieChartData(
            sectionsSpace: widget.data.sectionsSpace,
            centerSpaceRadius: widget.data.centerSpaceRadius,
            sections: widget.data.sections.map((section) {
              return PieChartSectionData(
                color: section.color,
                value: section.value * _animation.value,
                title: section.title,
                radius: section.radius,
                titleStyle: section.titleStyle,
                showTitle: section.showTitle,
              );
            }).toList(),
            pieTouchData: widget.data.pieTouchData,
          );

          return PieChart(animatedData);
        },
      ),
    );
  }
}

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
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  List<LocalImageRecord> _allRecords = [];

  // Filter state
  DateTimeRange? _dateRange;
  String? _selectedModel;
  String? _selectedResolution;
  int _filterVersion = 0; // Increment to force FutureBuilder rebuild

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// 计算统计数据
  Future<GalleryStatistics> _calculateStatistics() async {
    final state = ref.read(localGalleryNotifierProvider);
    final service = ref.read(statisticsServiceProvider);

    // 从仓库加载所有记录
    final repository = LocalGalleryRepository.instance;
    final allRecords = await repository.loadRecords(state.allFiles);

    // 保存记录用于筛选
    _allRecords = allRecords;

    // 应用筛选器
    final filteredRecords = _applyFilters(allRecords);

    return service.calculateStatistics(filteredRecords);
  }

  /// 应用筛选器到记录列表
  List<LocalImageRecord> _applyFilters(List<LocalImageRecord> records) {
    var filtered = records;

    // 应用日期范围筛选
    if (_dateRange != null) {
      filtered = filtered.where((record) {
        final fileDate = record.modifiedAt;
        return !fileDate.isBefore(_dateRange!.start) &&
               !fileDate.isAfter(_dateRange!.end);
      }).toList();
    }

    // 应用模型筛选
    if (_selectedModel != null && _selectedModel!.isNotEmpty) {
      filtered = filtered.where((record) {
        return record.metadata?.model == _selectedModel;
      }).toList();
    }

    // 应用分辨率筛选
    if (_selectedResolution != null && _selectedResolution!.isNotEmpty) {
      filtered = filtered.where((record) {
        if (record.metadata == null) return false;
        final resolution = '${record.metadata!.width}x${record.metadata!.height}';
        return resolution == _selectedResolution;
      }).toList();
    }

    return filtered;
  }

  /// 获取所有可用的模型列表
  List<String> _getAvailableModels() {
    final models = _allRecords
        .map((r) => r.metadata?.model)
        .whereType<String>()
        .toSet()
        .toList();
    models.sort();
    return models;
  }

  /// 获取所有可用的分辨率列表
  List<String> _getAvailableResolutions() {
    final resolutions = _allRecords
        .where((r) => r.metadata != null && r.metadata!.hasData)
        .map((r) => '${r.metadata!.width}x${r.metadata!.height}')
        .toSet()
        .toList();
    resolutions.sort();
    return resolutions;
  }

  /// 清除所有筛选器
  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _selectedModel = null;
      _selectedResolution = null;
      _filterVersion++;
    });
  }

  /// 检查是否有活动的筛选器
  bool get _hasActiveFilters =>
      _dateRange != null ||
      (_selectedModel != null && _selectedModel!.isNotEmpty) ||
      (_selectedResolution != null && _selectedResolution!.isNotEmpty);

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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: FutureBuilder<GalleryStatistics>(
        key: ValueKey(_filterVersion),
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
      ),
    );
  }

  /// 构建筛选栏
  Widget _buildFilterBar(ThemeData theme, AppLocalizations l10n) {
    final availableModels = _getAvailableModels();
    final availableResolutions = _getAvailableResolutions();

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter controls
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Date range filter
                InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _dateRange != null
                            ? theme.colorScheme.primary
                            : theme.dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: _dateRange != null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _dateRange != null
                              ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                              : 'Date Range',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _dateRange != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Model filter
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedModel != null
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedModel,
                      hint: const Text('Model'),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All Models'),
                      ),
                      ...availableModels.map((model) {
                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            model,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedModel = value?.isEmpty == true ? null : value;
                        _filterVersion++;
                      });
                    },
                  ),
                  ),
                ),

                // Resolution filter
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedResolution != null
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedResolution,
                      hint: const Text('Resolution'),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All Resolutions'),
                      ),
                      ...availableResolutions.map((resolution) {
                        return DropdownMenuItem<String>(
                          value: resolution,
                          child: Text(resolution),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedResolution = value?.isEmpty == true ? null : value;
                        _filterVersion++;
                      });
                    },
                  ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 选择日期范围
  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialRange = _dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 30)),
      initialDateRange: initialRange,
    );

    if (picked != null) {
      // Set end date to end of day
      final endOfDay = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      );
      setState(() {
        _dateRange = DateTimeRange(start: picked.start, end: endOfDay);
        _filterVersion++;
      });
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 构建 Overview Tab
  Widget _buildOverviewTab(
    ThemeData theme,
    GalleryStatistics statistics,
    AppLocalizations l10n,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 筛选栏
          _buildFilterBar(theme, l10n),
          // 总览统计卡片
          _buildOverviewCards(theme, statistics, l10n, isMobile, isTablet, isDesktop),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 筛选栏
          _buildFilterBar(theme, l10n),
          // 模型分布图表
          if (statistics.modelDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_modelDistribution,
              Icons.category,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            _buildModelDistributionChart(theme, statistics, l10n, isMobile, isTablet, isDesktop),
            SizedBox(height: isDesktop ? 32 : 24),
          ],

          // 分辨率分布图表
          if (statistics.resolutionDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_resolutionDistribution,
              Icons.aspect_ratio,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            _buildResolutionDistributionChart(theme, statistics, l10n, isMobile, isTablet, isDesktop),
            SizedBox(height: isDesktop ? 32 : 24),
          ],

          // 采样器分布图表
          if (statistics.samplerDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_samplerDistribution,
              Icons.tune,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            _buildSamplerDistributionChart(theme, statistics, l10n, isMobile, isTablet, isDesktop),
            SizedBox(height: isDesktop ? 32 : 24),
          ],

          // 文件大小分布图表
          if (statistics.sizeDistribution.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.statistics_sizeDistribution,
              Icons.storage,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            _buildSizeDistributionChart(theme, statistics, l10n, isMobile, isTablet, isDesktop),
            SizedBox(height: isDesktop ? 32 : 24),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 筛选栏
          _buildFilterBar(theme, l10n),
          // 其他统计
          _buildAdditionalStats(theme, statistics, l10n, isDesktop),
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
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final cardPadding = EdgeInsets.all(isDesktop ? 20 : 16);
    final spacing = isMobile ? 8.0 : 12.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statistics_overview,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isDesktop ? 20 : 16),
            // Mobile: single column, Tablet/Desktop: 2 columns
            if (isMobile) ...[
              // Single column layout for mobile
              _buildStatCard(
                theme,
                Icons.photo_library,
                l10n.statistics_totalImages,
                '${stats.totalImages}',
                theme.colorScheme.primary,
              ),
              SizedBox(height: spacing),
              _buildStatCard(
                theme,
                Icons.storage,
                l10n.statistics_totalSize,
                stats.totalSizeFormatted,
                theme.colorScheme.secondary,
              ),
              SizedBox(height: spacing),
              _buildStatCard(
                theme,
                Icons.favorite,
                l10n.statistics_favorites,
                '${stats.favoriteCount} (${stats.favoritePercentage.toStringAsFixed(1)}%)',
                Colors.red,
              ),
              SizedBox(height: spacing),
              _buildStatCard(
                theme,
                Icons.tag,
                l10n.statistics_tagged,
                '${stats.taggedImageCount} (${stats.taggedImagePercentage.toStringAsFixed(1)}%)',
                Colors.green,
              ),
            ] else ...[
              // Two column layout for tablet and desktop
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
                  SizedBox(width: spacing),
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
              SizedBox(height: spacing),
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
                  SizedBox(width: spacing),
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
    // Try to parse number from value for animation
    final numberMatch = RegExp(r'^[\d,]+\.?\d*').firstMatch(value);
    final suffix = numberMatch != null ? value.substring(numberMatch.end) : '';
    final numberStr = numberMatch?.group(0) ?? value;
    final number = int.tryParse(numberStr.replaceAll(',', '')) ?? 0;

    // Only animate if it's a pure number or number with percentage
    final shouldAnimate = RegExp(r'^[\d,]+\.?\d*(?:\s*\(?\d+\.?\d*%?\)?)?$').hasMatch(value) ||
                          RegExp(r'^[\d,]+\s*\(?\d+\.?\d*%?\)?$').hasMatch(value);

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
          shouldAnimate
              ? _AnimatedNumber(
                  targetValue: number,
                  suffix: suffix,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ) ?? const TextStyle(),
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
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final distribution = stats.modelDistribution;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          children: [
            SizedBox(
              height: isDesktop ? 250 : (isTablet ? 220 : 180),
              child: _AnimatedPieChart(
                height: isDesktop ? 250 : (isTablet ? 220 : 180),
                data: PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: isMobile ? 30 : 40,
                  sections: _buildPieSections(distribution, theme),
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent &&
                          pieTouchResponse != null &&
                          pieTouchResponse.touchedSection != null) {
                        final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        final modelData = distribution[index];
                        _showModelDetailDialog(context, modelData, theme, l10n);
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 20 : 16),
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
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final distribution = stats.resolutionDistribution;
    final barHeight = isMobile ? 35.0 : 40.0;
    final barWidth = isMobile ? 16.0 : 20.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: distribution.length * barHeight,
              child: _AnimatedBarChart(
                height: distribution.length * barHeight,
                data: BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: distribution
                          .map((r) => r.count.toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is FlTapUpEvent &&
                          barTouchResponse != null &&
                          barTouchResponse.spot != null) {
                        final index = barTouchResponse.spot!.touchedBarGroupIndex;
                        final resolutionData = distribution[index];
                        _showResolutionDetailDialog(context, resolutionData, theme, l10n);
                      }
                    },
                  ),
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
                        reservedSize: isMobile ? 70 : 80,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: isMobile ? 35 : 40,
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
                          width: barWidth,
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
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final distribution = stats.samplerDistribution;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          children: [
            SizedBox(
              height: isDesktop ? 250 : (isTablet ? 220 : 180),
              child: _AnimatedPieChart(
                height: isDesktop ? 250 : (isTablet ? 220 : 180),
                data: PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: isMobile ? 30 : 40,
                  sections: _buildPieSectionsFromSamplers(distribution, theme),
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapUpEvent &&
                          pieTouchResponse != null &&
                          pieTouchResponse.touchedSection != null) {
                        final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        final samplerData = distribution[index];
                        _showSamplerDetailDialog(context, samplerData, theme, l10n);
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 20 : 16),
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
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final distribution = stats.sizeDistribution;
    final barHeight = isMobile ? 35.0 : 40.0;
    final barWidth = isMobile ? 16.0 : 20.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: distribution.length * barHeight,
              child: _AnimatedBarChart(
                height: distribution.length * barHeight,
                data: BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: distribution
                          .map((s) => s.count.toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                      if (event is FlTapUpEvent &&
                          barTouchResponse != null &&
                          barTouchResponse.spot != null) {
                        final index = barTouchResponse.spot!.touchedBarGroupIndex;
                        final sizeData = distribution[index];
                        _showSizeDetailDialog(context, sizeData, theme, l10n);
                      }
                    },
                  ),
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
                        reservedSize: isMobile ? 70 : 80,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: isMobile ? 35 : 40,
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
                          width: barWidth,
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
    bool isDesktop,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statistics_additionalStats,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isDesktop ? 20 : 16),
            _buildStatRow(
              theme,
              l10n.statistics_averageFileSize,
              stats.averageSizeFormatted,
            ),
            Divider(height: isDesktop ? 28 : 24),
            _buildStatRow(
              theme,
              l10n.statistics_withMetadata,
              '${stats.imagesWithMetadata} (${stats.metadataPercentage.toStringAsFixed(1)}%)',
            ),
            Divider(height: isDesktop ? 28 : 24),
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

  /// 显示模型详情对话框
  void _showModelDetailDialog(
    BuildContext context,
    ModelStatistics modelData,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final filteredRecords = _allRecords.where((record) {
      return record.metadata?.model == modelData.modelName;
    }).toList();

    _showDetailDialog(
      context,
      l10n.statistics_modelDistribution,
      modelData.modelName,
      filteredRecords,
      theme,
      l10n,
    );
  }

  /// 显示采样器详情对话框
  void _showSamplerDetailDialog(
    BuildContext context,
    SamplerStatistics samplerData,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final filteredRecords = _allRecords.where((record) {
      return record.metadata?.sampler == samplerData.samplerName;
    }).toList();

    _showDetailDialog(
      context,
      l10n.statistics_samplerDistribution,
      samplerData.samplerName,
      filteredRecords,
      theme,
      l10n,
    );
  }

  /// 显示分辨率详情对话框
  void _showResolutionDetailDialog(
    BuildContext context,
    ResolutionStatistics resolutionData,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final filteredRecords = _allRecords.where((record) {
      if (record.metadata == null) return false;
      final resolution = '${record.metadata!.width}x${record.metadata!.height}';
      return resolution == resolutionData.label;
    }).toList();

    _showDetailDialog(
      context,
      l10n.statistics_resolutionDistribution,
      resolutionData.label,
      filteredRecords,
      theme,
      l10n,
    );
  }

  /// 显示文件大小详情对话框
  void _showSizeDetailDialog(
    BuildContext context,
    SizeDistributionStatistics sizeData,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final filteredRecords = _allRecords.where((record) {
      // 根据标签范围筛选
      if (sizeData.label == '< 1MB') {
        return record.size < 1024 * 1024;
      } else if (sizeData.label == '1-5MB') {
        return record.size >= 1024 * 1024 && record.size < 5 * 1024 * 1024;
      } else if (sizeData.label == '5-10MB') {
        return record.size >= 5 * 1024 * 1024 && record.size < 10 * 1024 * 1024;
      } else if (sizeData.label == '> 10MB') {
        return record.size >= 10 * 1024 * 1024;
      }
      return false;
    }).toList();

    _showDetailDialog(
      context,
      l10n.statistics_sizeDistribution,
      sizeData.label,
      filteredRecords,
      theme,
      l10n,
    );
  }

  /// 显示详情对话框
  void _showDetailDialog(
    BuildContext context,
    String category,
    String filterValue,
    List<LocalImageRecord> records,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            filterValue,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.statistics_noData,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          return _buildDetailListItem(record, theme, l10n);
                        },
                      ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.statistics_totalImages}: ${records.length}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建详情列表项
  Widget _buildDetailListItem(
    LocalImageRecord record,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final fileName = record.path.split(Platform.pathSeparator).last;
    final meta = record.metadata;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.image,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          fileName,
          style: theme.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meta != null && meta.hasData) ...[
              Text(
                'Model: ${meta.model ?? "N/A"}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Sampler: ${meta.sampler ?? "N/A"}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Resolution: ${meta.width}x${meta.height}',
                style: theme.textTheme.bodySmall,
              ),
            ] else
              Text(
                'No metadata',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: Text(
          _formatBytes(record.size),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    } else {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return '$mb MB';
    }
  }
}
