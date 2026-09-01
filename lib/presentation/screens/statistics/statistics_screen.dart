import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../themes/theme_extension.dart';
import '../../widgets/statistics/export_dialog.dart';
import 'statistics_state.dart';
import 'widgets/widgets.dart';

/// 统计屏幕 - 单页瀑布流仪表盘布局
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(statisticsNotifierProvider.notifier).whenLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final data = ref.watch(statisticsNotifierProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, theme, l10n, data),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _buildContent(context, l10n, data, ref, constraints.maxWidth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    StatisticsData data,
  ) {
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final borderColor = extension?.borderColor ?? colorScheme.outlineVariant;
    final exportAction = data.statistics == null
        ? null
        : () => StatisticsExportDialog.show(
            context,
            statistics: data.statistics!,
          );

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bar_chart_rounded, size: 24, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.statistics_title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (PlatformCapabilities.current.hasTouchInput)
            TextButton.icon(
              onPressed: exportAction,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(l10n.common_export),
            )
          else
            IconButton(
              onPressed: exportAction,
              tooltip: l10n.common_export,
              icon: const Icon(Icons.download_outlined),
            ),
          const AnimatedRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    StatisticsData data,
    WidgetRef ref,
    double availableWidth,
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

    final crossAxisCount = availableWidth < 600
        ? 1
        : (availableWidth < 900 ? 2 : 3);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: StaggeredGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          StaggeredGridTile.fit(
            crossAxisCellCount: crossAxisCount,
            child: OverviewStatsRow(stats: stats),
          ),
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: OtherStatsCard(stats: stats),
          ),
          const StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: AnlasCostCard(),
          ),
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: SamplerDistributionCard(stats: stats),
          ),
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: AspectRatioCard(stats: stats),
          ),
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: ActivityHeatmapCard(dailyTrends: stats.dailyTrends),
          ),
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: HourlyDistributionCard(hourlyData: stats.hourlyDistribution),
          ),
          StaggeredGridTile.fit(
            crossAxisCellCount: 1,
            child: WeekdayDistributionCard(
              weekdayData: stats.weekdayDistribution,
            ),
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
