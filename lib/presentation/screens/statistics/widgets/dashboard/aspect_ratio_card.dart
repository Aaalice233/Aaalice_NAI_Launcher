import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../../data/models/gallery/gallery_statistics.dart';
import '../cards/chart_card.dart';
import '../charts/aspect_ratio_chart.dart';

/// 宽高比分布卡片 - 显示环形图+图例
/// Aspect ratio distribution card - displays donut chart with legend
class AspectRatioCard extends StatelessWidget {
  final GalleryStatistics stats;

  const AspectRatioCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 计算宽高比分布
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

    if (aspectRatios.isEmpty) {
      return ChartCard(
        title: l10n.statistics_chartAspectRatio,
        titleIcon: Icons.aspect_ratio_outlined,
        child: ChartEmptyState(title: l10n.statistics_noData),
      );
    }

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
      child: AspectRatioChart(items: items.take(8).toList(), height: 180),
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
