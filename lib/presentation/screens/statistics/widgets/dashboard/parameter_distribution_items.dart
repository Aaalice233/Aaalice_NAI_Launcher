import 'package:flutter/painting.dart';

import '../../../../../data/models/gallery/gallery_parameter.dart';
import '../../../../../data/models/gallery/gallery_statistics.dart';
import '../../../../../data/services/statistics_service.dart';
import '../charts/parameter_distribution_bar.dart';

/// 参数分布卡片最多逐条列出的取值数；只影响展示，统计与导出保留全部取值
const int parameterDistributionVisibleValues = 5;

/// 某个参数在参数分布卡片里的条目，沿用统计里的降序；取值过多时其余并为一条
List<ParameterBarItem> parameterDistributionItems(
  List<ParameterStatistics> distribution,
  GalleryParameter parameter, {
  required String otherLabel,
  Color? otherColor,
}) {
  final entries = [
    for (final entry in distribution)
      if (entry.parameterName == parameter.key) entry,
  ];
  // 只多出一个取值时照常列出：并成"其他"占同样一行，却丢了取值
  final folds = entries.length > parameterDistributionVisibleValues + 1;
  final shown = folds
      ? entries.take(parameterDistributionVisibleValues)
      : entries;
  final folded = folds
      ? entries.skip(parameterDistributionVisibleValues)
      : const <ParameterStatistics>[];

  return [
    for (final entry in shown)
      ParameterBarItem(
        label: parameter == GalleryParameter.sampler
            ? StatisticsService.formatSamplerName(entry.value)
            : entry.value,
        count: entry.count,
        percentage: entry.percentage,
      ),
    if (folds)
      ParameterBarItem(
        label: otherLabel,
        count: folded.fold(0, (sum, entry) => sum + entry.count),
        percentage: folded.fold(0.0, (sum, entry) => sum + entry.percentage),
        color: otherColor,
      ),
  ];
}
