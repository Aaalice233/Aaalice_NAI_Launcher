import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../data/models/gallery/gallery_statistics.dart';
import '../statistics_state.dart';
import '../widgets/widgets.dart';
import '../utils/utils.dart';

/// Overview page - displays key metrics and filters
class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final data = ref.watch(statisticsNotifierProvider);
    final notifier = ref.read(statisticsNotifierProvider.notifier);

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.error != null) {
      return _buildErrorState(context, l10n, data.error!, notifier);
    }

    final stats = data.statistics;
    if (stats == null || stats.totalImages == 0) {
      return _buildEmptyState(l10n);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildFilterBar(context, theme, l10n, data, notifier),
        const SizedBox(height: 24),
        _buildMetricCards(theme, stats, l10n),
        const SizedBox(height: 24),
        _buildQuickStats(theme, stats, l10n),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    String error,
    StatisticsNotifier notifier,
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
            onPressed: () => notifier.refresh(),
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

  Widget _buildFilterBar(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    StatisticsData data,
    StatisticsNotifier notifier,
  ) {
    final colorScheme = theme.colorScheme;
    final filter = notifier.filter;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                l10n.statistics_filterTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (filter.hasActiveFilters)
                TextButton.icon(
                  onPressed: () => notifier.clearFilters(),
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(l10n.statistics_filterClear),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildDateChip(context, theme, l10n, filter, notifier),
              _buildModelDropdown(theme, l10n, data, notifier),
              _buildResolutionDropdown(theme, l10n, data, notifier),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    StatisticsFilter filter,
    StatisticsNotifier notifier,
  ) {
    final colorScheme = theme.colorScheme;
    final isActive = filter.dateRange != null;

    return InkWell(
      onTap: () => _selectDateRange(context, filter, notifier),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary.withOpacity(0.1) : null,
          border: Border.all(
            color: isActive
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color:
                  isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              filter.dateRange != null
                  ? '${StatisticsFormatter.formatDateShort(filter.dateRange!.start)} - ${StatisticsFormatter.formatDateShort(filter.dateRange!.end)}'
                  : l10n.statistics_filterDateRange,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(
    BuildContext context,
    StatisticsFilter filter,
    StatisticsNotifier notifier,
  ) async {
    final now = DateTime.now();
    final initialRange = filter.dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: initialRange,
    );

    if (picked != null) {
      notifier.setDateRange(picked);
    }
  }

  Widget _buildModelDropdown(
    ThemeData theme,
    AppLocalizations l10n,
    StatisticsData data,
    StatisticsNotifier notifier,
  ) {
    final colorScheme = theme.colorScheme;
    final filter = notifier.filter;
    final isActive =
        filter.selectedModel != null && filter.selectedModel!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary.withOpacity(0.1) : null,
        border: Border.all(
          color: isActive
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: filter.selectedModel,
          hint: Text(
            l10n.statistics_filterModel,
            style: theme.textTheme.labelMedium,
          ),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(l10n.statistics_filterAllModels),
            ),
            ...data.availableModels.map(
              (m) => DropdownMenuItem(
                value: m,
                child: Text(m, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => notifier.setModel(value),
        ),
      ),
    );
  }

  Widget _buildResolutionDropdown(
    ThemeData theme,
    AppLocalizations l10n,
    StatisticsData data,
    StatisticsNotifier notifier,
  ) {
    final colorScheme = theme.colorScheme;
    final filter = notifier.filter;
    final isActive = filter.selectedResolution != null &&
        filter.selectedResolution!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary.withOpacity(0.1) : null,
        border: Border.all(
          color: isActive
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: filter.selectedResolution,
          hint: Text(
            l10n.statistics_filterResolution,
            style: theme.textTheme.labelMedium,
          ),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(l10n.statistics_filterAllResolutions),
            ),
            ...data.availableResolutions.map(
              (r) => DropdownMenuItem(value: r, child: Text(r)),
            ),
          ],
          onChanged: (value) => notifier.setResolution(value),
        ),
      ),
    );
  }

  Widget _buildMetricCards(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final screenWidth = WidgetsBinding
            .instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 2 : 1);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        MetricCard(
          icon: Icons.photo_library_outlined,
          label: l10n.statistics_totalImages,
          value: '${stats.totalImages}',
          iconColor: theme.colorScheme.primary,
        ),
        MetricCard(
          icon: Icons.storage_outlined,
          label: l10n.statistics_totalSize,
          value: StatisticsFormatter.formatBytes(stats.totalSizeBytes),
          iconColor: theme.colorScheme.secondary,
        ),
        MetricCard(
          icon: Icons.favorite_outline,
          label: l10n.statistics_favorites,
          value:
              '${stats.favoriteCount} (${stats.favoritePercentage.toStringAsFixed(1)}%)',
          iconColor: Colors.red,
        ),
        MetricCard(
          icon: Icons.label_outline,
          label: l10n.statistics_tagged,
          value:
              '${stats.taggedImageCount} (${stats.taggedImagePercentage.toStringAsFixed(1)}%)',
          iconColor: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildQuickStats(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    return ChartCard(
      title: l10n.statistics_additionalStats,
      titleIcon: Icons.insights_outlined,
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          _StatItem(
            label: l10n.statistics_averageFileSize,
            value: StatisticsFormatter.formatBytes(
              stats.totalImages > 0
                  ? stats.totalSizeBytes ~/ stats.totalImages
                  : 0,
            ),
          ),
          _StatItem(
            label: l10n.statistics_withMetadata,
            value: '${stats.imagesWithMetadata}',
          ),
          if (stats.modelDistribution.isNotEmpty)
            _StatItem(
              label: l10n.statistics_modelDistribution,
              value: stats.modelDistribution.first.modelName,
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
