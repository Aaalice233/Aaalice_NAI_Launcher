import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../../data/models/gallery/gallery_statistics.dart';
import '../cards/chart_card.dart';
import '../charts/parameter_distribution_bar.dart';

/// 采样器分布卡片 - 显示采样器使用分布的水平条形图
/// Sampler distribution card - displays sampler usage distribution as horizontal bar chart
class SamplerDistributionCard extends StatelessWidget {
  final GalleryStatistics stats;

  const SamplerDistributionCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final samplerItems = stats.samplerDistribution.map((s) {
      return ParameterBarItem(
        label: s.samplerName,
        count: s.count,
        percentage: s.percentage,
      );
    }).toList();

    if (samplerItems.isEmpty) {
      return ChartCard(
        title: l10n.statistics_samplerDistribution,
        titleIcon: Icons.settings_outlined,
        accentColor: Colors.orange,
        child: ChartEmptyState(title: l10n.statistics_noData),
      );
    }

    return ChartCard(
      title: l10n.statistics_samplerDistribution,
      titleIcon: Icons.settings_outlined,
      accentColor: Colors.orange,
      child: ParameterDistributionBar(
        title: '',
        items: samplerItems,
        height: 180,
        horizontal: true,
      ),
    );
  }
}
