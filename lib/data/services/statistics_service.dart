import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/gallery/daily_trend_statistics.dart';
import '../models/gallery/gallery_dashboard_snapshot.dart';
import '../models/gallery/gallery_statistics.dart';

part 'statistics_service.g.dart';

/// 画廊统计服务
///
/// 负责计算画廊的各种统计数据，包括：
/// - 总图片数和总大小
/// - 分辨率分布
/// - 模型分布
/// - 采样器分布
/// - 文件大小分布
/// - 收藏和标签统计
class StatisticsService {
  /// Builds dashboard statistics from database-side aggregate counts.
  GalleryStatistics fromDashboardSnapshot(
    GalleryDashboardSnapshot snapshot, {
    DateTime? calculatedAt,
  }) {
    final totalImages = snapshot.totalImages;
    final dailyTrends = <DailyTrendStatistics>[];
    final sortedDailyCounts = snapshot.dailyCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedDailyCounts) {
      final date = _dateFromYmd(entry.key);
      if (date == null) continue;
      dailyTrends.add(
        DailyTrendStatistics(
          date: date,
          count: entry.value,
          percentage: totalImages > 0 ? entry.value / totalImages * 100 : 0.0,
        ),
      );
    }

    return GalleryStatistics(
      totalImages: totalImages,
      totalSizeBytes: snapshot.totalSizeBytes,
      averageFileSizeBytes: totalImages > 0
          ? snapshot.totalSizeBytes / totalImages
          : 0.0,
      favoriteCount: snapshot.favoriteCount,
      taggedImageCount: snapshot.taggedImageCount,
      imagesWithMetadata: snapshot.imagesWithMetadata,
      resolutionDistribution: _sortedStatistics<ResolutionStatistics>(
        snapshot.resolutionCounts,
        totalImages,
        (label, count, percentage) => ResolutionStatistics(
          label: label,
          count: count,
          percentage: percentage,
        ),
      ),
      modelDistribution: _sortedStatistics<ModelStatistics>(
        snapshot.modelCounts,
        totalImages,
        (label, count, percentage) => ModelStatistics(
          modelName: label,
          count: count,
          percentage: percentage,
        ),
      ),
      samplerDistribution: _sortedStatistics<SamplerStatistics>(
        snapshot.samplerCounts,
        totalImages,
        (label, count, percentage) => SamplerStatistics(
          samplerName: _formatSamplerName(label),
          count: count,
          percentage: percentage,
        ),
      ),
      sizeDistribution: _sortedStatistics<SizeDistributionStatistics>(
        snapshot.sizeCounts,
        totalImages,
        (label, count, percentage) => SizeDistributionStatistics(
          label: label,
          count: count,
          percentage: percentage,
        ),
      ),
      tagDistribution: _sortedStatistics<TagStatistics>(
        snapshot.tagCounts,
        totalImages,
        (label, count, percentage) =>
            TagStatistics(tagName: label, count: count, percentage: percentage),
      ),
      dailyTrends: dailyTrends,
      hourlyDistribution: snapshot.hourlyCounts,
      weekdayDistribution: snapshot.weekdayCounts,
      favoritesStatistics: {
        'favoriteCount': snapshot.favoriteCount,
        'percentage': totalImages > 0
            ? snapshot.favoriteCount / totalImages * 100
            : 0.0,
      },
      calculatedAt: calculatedAt ?? DateTime.now(),
    );
  }

  /// 通用统计排序和转换
  List<T> _sortedStatistics<T>(
    Map<String, int> counts,
    int totalImages,
    T Function(String label, int count, double percentage) factory,
  ) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) {
      final percentage = totalImages > 0 ? (e.value / totalImages) * 100 : 0.0;
      return factory(e.key, e.value, percentage);
    }).toList();
  }

  /// 格式化采样器名称 (k_euler_ancestral -> Euler Ancestral)
  String _formatSamplerName(String sampler) {
    return sampler
        .replaceAll('k_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');
  }

  DateTime? _dateFromYmd(int value) {
    if (value <= 0) return null;
    final year = value ~/ 10000;
    final month = (value ~/ 100) % 100;
    final day = value % 100;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}

/// Provider
@Riverpod(keepAlive: true)
StatisticsService statisticsService(Ref ref) {
  return StatisticsService();
}
