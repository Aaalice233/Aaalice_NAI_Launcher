import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../data/models/gallery/gallery_statistics.dart';
import '../statistics_state.dart';
import '../widgets/widgets.dart';

/// Parameter preferences page - radar chart and distributions
class ParameterPage extends ConsumerStatefulWidget {
  const ParameterPage({super.key});

  @override
  ConsumerState<ParameterPage> createState() => _ParameterPageState();
}

class _ParameterPageState extends ConsumerState<ParameterPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final data = ref.watch(statisticsNotifierProvider);

    if (data.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = data.statistics;
    if (stats == null) {
      return Center(
        child: ChartEmptyState(
          icon: Icons.tune_outlined,
          title: l10n.statistics_noData,
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRadar(theme, data, stats, l10n)),
              const SizedBox(width: 20),
              Expanded(child: _buildSamplerDistribution(theme, stats, l10n)),
            ],
          )
        else ...[
          _buildRadar(theme, data, stats, l10n),
          const SizedBox(height: 20),
          _buildSamplerDistribution(theme, stats, l10n),
        ],
        const SizedBox(height: 20),
        _buildAspectRatioSection(theme, stats, l10n),
      ],
    );
  }

  Widget _buildRadar(
    ThemeData theme,
    StatisticsData data,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    int totalSteps = 0, totalWidth = 0, totalHeight = 0;
    double totalScale = 0;
    int count = 0;

    for (final record in data.filteredRecords) {
      if (record.metadata != null && record.metadata!.hasData) {
        totalSteps += record.metadata!.steps ?? 0;
        totalScale += record.metadata!.scale ?? 0;
        totalWidth += record.metadata!.width ?? 0;
        totalHeight += record.metadata!.height ?? 0;
        count++;
      }
    }

    if (count == 0) {
      return ChartCard(
        child: ChartEmptyState(title: l10n.statistics_noMetadata),
      );
    }

    final radarData = [
      RadarDataPoint(
        label: l10n.statistics_labelSteps,
        value: ((totalSteps / count) / 50).clamp(0, 1),
      ),
      RadarDataPoint(
        label: l10n.statistics_labelCfg,
        value: ((totalScale / count) / 15).clamp(0, 1),
      ),
      RadarDataPoint(
        label: l10n.statistics_labelWidth,
        value: ((totalWidth / count) / 1536).clamp(0, 1),
      ),
      RadarDataPoint(
        label: l10n.statistics_labelHeight,
        value: ((totalHeight / count) / 1536).clamp(0, 1),
      ),
      RadarDataPoint(
        label: l10n.statistics_labelFavPercent,
        value: (stats.favoritePercentage / 100).clamp(0, 1),
      ),
      RadarDataPoint(
        label: l10n.statistics_labelTagPercent,
        value: (stats.taggedImagePercentage / 100).clamp(0, 1),
      ),
    ];

    return ChartCard(
      title: l10n.statistics_chartParameterOverview,
      titleIcon: Icons.radar_outlined,
      child: SizedBox(
        height: 300,
        child: CustomRadarChart(data: radarData),
      ),
    );
  }

  Widget _buildSamplerDistribution(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final samplerItems = stats.samplerDistribution.map((s) {
      return ParameterBarItem(
        label: s.samplerName,
        count: s.count,
        percentage: s.percentage,
      );
    }).toList();

    return ChartCard(
      title: l10n.statistics_samplerDistribution,
      titleIcon: Icons.settings_outlined,
      child: ParameterDistributionBar(
        title: '',
        items: samplerItems,
        height: 250,
        horizontal: true,
      ),
    );
  }

  Widget _buildAspectRatioSection(
    ThemeData theme,
    GalleryStatistics stats,
    AppLocalizations l10n,
  ) {
    final aspectRatios = <String, int>{};
    for (final res in stats.resolutionDistribution) {
      final parts = res.label.split('x');
      if (parts.length == 2) {
        final w = int.tryParse(parts[0]) ?? 1;
        final h = int.tryParse(parts[1]) ?? 1;
        final ratio = _simplifyRatio(w, h);
        aspectRatios[ratio] = (aspectRatios[ratio] ?? 0) + res.count;
      }
    }

    if (aspectRatios.isEmpty) return const SizedBox.shrink();

    final total = aspectRatios.values.fold<int>(0, (a, b) => a + b);
    final items = aspectRatios.entries.map((e) {
      return AspectRatioItem(
        ratio: e.key,
        label: _getRatioLabel(e.key, l10n),
        count: e.value,
        percentage: total > 0 ? e.value / total * 100 : 0,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return ChartCard(
      title: l10n.statistics_chartAspectRatio,
      titleIcon: Icons.aspect_ratio_outlined,
      child: AspectRatioChart(items: items.take(8).toList(), height: 250),
    );
  }

  String _simplifyRatio(int w, int h) {
    final gcd = _gcd(w, h);
    return '${w ~/ gcd}:${h ~/ gcd}';
  }

  int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  String _getRatioLabel(String ratio, AppLocalizations l10n) {
    final parts = ratio.split(':');
    if (parts.length != 2) return l10n.statistics_aspectOther;
    final w = int.tryParse(parts[0]) ?? 1;
    final h = int.tryParse(parts[1]) ?? 1;
    if (w == h) return l10n.statistics_aspectSquare;
    if (w > h) return l10n.statistics_aspectLandscape;
    return l10n.statistics_aspectPortrait;
  }
}
