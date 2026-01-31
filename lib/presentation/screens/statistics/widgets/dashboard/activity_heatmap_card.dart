import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../../data/models/gallery/local_image_record.dart';
import '../cards/chart_card.dart';
import '../charts/heatmap_chart.dart';

/// 活动热力图卡片 - GitHub风格热力图展示26周活动
/// Activity heatmap card - displays 26-week activity heatmap in GitHub style
class ActivityHeatmapCard extends StatelessWidget {
  final List<LocalImageRecord> records;

  const ActivityHeatmapCard({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (records.isEmpty) {
      return ChartCard(
        title: l10n.statistics_chartActivityHeatmap,
        titleIcon: Icons.grid_on_outlined,
        child: ChartEmptyState(title: l10n.statistics_noData),
      );
    }

    // 统计每日图片数量
    final dateCounts = <DateTime, int>{};
    for (final record in records) {
      final date = DateTime(
        record.modifiedAt.year,
        record.modifiedAt.month,
        record.modifiedAt.day,
      );
      dateCounts[date] = (dateCounts[date] ?? 0) + 1;
    }

    final heatmapResult = generateHeatmapData(dateCounts, weeks: 14);

    return ChartCard(
      title: l10n.statistics_chartActivityHeatmap,
      titleIcon: Icons.grid_on_outlined,
      child: HeatmapChart(
        data: heatmapResult.data,
        cellSize: 20,
        cellSpacing: 4,
        todayPosition: heatmapResult.todayPosition,
        onCellTap: (week, day, value) {},
      ),
    );
  }
}
