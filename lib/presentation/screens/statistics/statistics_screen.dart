import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../themes/theme_extension.dart';
import 'statistics_state.dart';
import 'widgets/widgets.dart';

/// Statistics Screen - Single page waterfall dashboard layout
/// 统计屏幕 - 单页瀑布流仪表盘布局
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final data = ref.watch(statisticsNotifierProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    // 响应式列数
    final crossAxisCount = _getCrossAxisCount(screenWidth);

    return Scaffold(
      body: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context, theme, l10n, colorScheme, extension),
          // 内容区域
          Expanded(
            child: _buildContent(
              context,
              theme,
              l10n,
              colorScheme,
              data,
              ref,
              crossAxisCount,
            ),
          ),
        ],
      ),
    );
  }

  /// 根据屏幕宽度获取列数
  int _getCrossAxisCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 3;
  }

  /// 顶部标题栏
  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    AppThemeExtension? extension,
  ) {
    final borderColor = extension?.borderColor ?? colorScheme.outlineVariant;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: borderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 标题
          Icon(
            Icons.bar_chart_rounded,
            size: 24,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            l10n.statistics_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // 刷新按钮 (自带加载动画)
          const AnimatedRefreshButton(),
        ],
      ),
    );
  }

  /// 内容区域
  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    StatisticsData data,
    WidgetRef ref,
    int crossAxisCount,
  ) {
    if (data.isLoading && data.statistics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.error != null && data.statistics == null) {
      return _buildErrorState(context, l10n, data.error!, ref);
    }

    final stats = data.statistics;
    if (stats == null || stats.totalImages == 0) {
      return _buildEmptyState(l10n);
    }

    final records = data.filteredRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: StaggeredGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          // 概览统计行 - 全宽
          StaggeredGridTile.fit(
            crossAxisCellCount: crossAxisCount,
            child: OverviewStatsRow(stats: stats),
          ),

          // 其他统计卡片 - 1列
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: OtherStatsCard(stats: stats),
          ),

          // 点数花费统计卡片 - 1列
          const StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: AnlasCostCard(),
          ),

          // 采样器分布卡片 - 1列
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: SamplerDistributionCard(stats: stats),
          ),

          // 宽高比分布卡片 - 1列
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: AspectRatioCard(stats: stats),
          ),

          // 活动热力图卡片 - 1列
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: ActivityHeatmapCard(records: records),
          ),

          // 小时分布卡片 - 1列
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: HourlyDistributionCard(records: records),
          ),

          // 星期分布卡片 - 1列
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: WeekdayDistributionCard(records: records),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    String error,
    WidgetRef ref,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(l10n.statistics_error(error)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(statisticsNotifierProvider.notifier).refresh(),
            child: Text(l10n.statistics_retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: ChartEmptyState(
        icon: Icons.bar_chart_outlined,
        title: l10n.statistics_noData,
        subtitle: l10n.statistics_generateFirst,
      ),
    );
  }
}
