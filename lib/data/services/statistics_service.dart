import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/gallery/daily_trend_statistics.dart';
import '../models/gallery/gallery_statistics.dart';
import '../models/gallery/local_image_record.dart';
import '../models/gallery/nai_image_metadata.dart';

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
  /// 计算画廊统计数据
  ///
  /// [records] - 图片记录列表
  /// 返回完整的画廊统计信息
  GalleryStatistics calculateStatistics(List<LocalImageRecord> records) {
    AppLogger.d(
      'Calculating statistics for ${records.length} images',
      'Statistics',
    );

    // 基础统计
    final totalImages = records.length;
    final totalSizeBytes = records.fold<int>(
      0,
      (sum, record) => sum + record.size,
    );
    final averageFileSizeBytes =
        totalImages > 0 ? totalSizeBytes / totalImages : 0.0;

    // 收藏和标签统计
    final favoriteCount = records.where((r) => r.isFavorite).length;
    final taggedImageCount = records.where((r) => r.tags.isNotEmpty).length;
    final imagesWithMetadata = records.where((r) => r.hasMetadata).length;

    // 分辨率分布统计
    final resolutionDistribution =
        _calculateResolutionDistribution(records, totalImages);

    // 模型分布统计
    final modelDistribution = _calculateModelDistribution(records, totalImages);

    // 采样器分布统计
    final samplerDistribution =
        _calculateSamplerDistribution(records, totalImages);

    // 文件大小分布统计
    final sizeDistribution = _calculateSizeDistribution(records, totalImages);

    return GalleryStatistics(
      totalImages: totalImages,
      totalSizeBytes: totalSizeBytes,
      averageFileSizeBytes: averageFileSizeBytes,
      favoriteCount: favoriteCount,
      taggedImageCount: taggedImageCount,
      imagesWithMetadata: imagesWithMetadata,
      resolutionDistribution: resolutionDistribution,
      modelDistribution: modelDistribution,
      samplerDistribution: samplerDistribution,
      sizeDistribution: sizeDistribution,
      calculatedAt: DateTime.now(),
    );
  }

  /// 计算分辨率分布统计
  List<ResolutionStatistics> _calculateResolutionDistribution(
    List<LocalImageRecord> records,
    int totalImages,
  ) {
    final counts = <String, int>{};

    for (final record in records) {
      final width = record.metadata?.width;
      final height = record.metadata?.height;
      if (width != null && height != null) {
        final resolution = '${width}x$height';
        counts[resolution] = (counts[resolution] ?? 0) + 1;
      }
    }

    return _sortedStatistics<ResolutionStatistics>(
      counts,
      totalImages,
      (label, count, percentage) =>
          ResolutionStatistics(label: label, count: count, percentage: percentage),
    );
  }

  /// 计算模型分布统计
  List<ModelStatistics> _calculateModelDistribution(
    List<LocalImageRecord> records,
    int totalImages,
  ) {
    final counts = _countByKey(records, (r) => r.metadata?.model);

    return _sortedStatistics<ModelStatistics>(
      counts,
      totalImages,
      (label, count, percentage) =>
          ModelStatistics(modelName: label, count: count, percentage: percentage),
    );
  }

  /// 计算采样器分布统计
  List<SamplerStatistics> _calculateSamplerDistribution(
    List<LocalImageRecord> records,
    int totalImages,
  ) {
    final counts = <String, int>{};

    for (final record in records) {
      final sampler = record.metadata?.sampler;
      if (sampler != null && sampler.isNotEmpty) {
        final formatted = _formatSamplerName(sampler);
        counts[formatted] = (counts[formatted] ?? 0) + 1;
      }
    }

    return _sortedStatistics<SamplerStatistics>(
      counts,
      totalImages,
      (label, count, percentage) =>
          SamplerStatistics(samplerName: label, count: count, percentage: percentage),
    );
  }

  /// 通用计数方法
  Map<String, int> _countByKey(
    List<LocalImageRecord> records,
    String? Function(LocalImageRecord) keyExtractor,
  ) {
    final counts = <String, int>{};

    for (final record in records) {
      final key = keyExtractor(record);
      if (key != null && key.isNotEmpty) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return counts;
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
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  /// 计算文件大小分布统计
  List<SizeDistributionStatistics> _calculateSizeDistribution(
    List<LocalImageRecord> records,
    int totalImages,
  ) {
    const mb = 1024 * 1024;

    final counts = <String, int>{};

    for (final record in records) {
      final sizeMB = record.size / mb;
      final label = switch (sizeMB) {
        < 1 => '< 1 MB',
        < 2 => '1-2 MB',
        < 5 => '2-5 MB',
        < 10 => '5-10 MB',
        _ => '> 10 MB',
      };
      counts[label] = (counts[label] ?? 0) + 1;
    }

    return counts.entries.where((e) => e.value > 0).map((e) {
      final percentage = totalImages > 0 ? (e.value / totalImages) * 100 : 0.0;
      return SizeDistributionStatistics(
        label: e.key,
        count: e.value,
        percentage: percentage,
      );
    }).toList();
  }

  /// 增量更新统计数据 (当前实现返回原统计，建议调用者重新计算)
  GalleryStatistics updateStatistics(
    GalleryStatistics currentStats,
    List<LocalImageRecord> newRecords,
    List<LocalImageRecord> removedRecords,
  ) {
    AppLogger.d(
      'Updating statistics: +${newRecords.length} -${removedRecords.length}',
      'Statistics',
    );
    return currentStats;
  }

  /// 异步计算完整的画廊统计数据
  Future<GalleryStatistics> computeAllStatistics(
    List<LocalImageRecord> records,
  ) async {
    AppLogger.d(
      'Computing all statistics for ${records.length} images',
      'Statistics',
    );

    final results = await Future.wait([
      compute(_computeAllStatisticsIsolate, records),
      computeTimeTrends(records, groupBy: 'daily'),
      computeTagStatistics(records, limit: 20),
      computeParameterDistribution(records),
      computeFavoritesStatistics(records),
      computeRecentActivity(records, days: 30),
    ]);

    return (results[0] as GalleryStatistics).copyWith(
      dailyTrends: results[1] as List<DailyTrendStatistics>,
      tagDistribution: results[2] as List<TagStatistics>,
      parameterDistribution: results[3] as List<ParameterStatistics>,
      favoritesStatistics: results[4] as Map<String, dynamic>,
      recentActivity: results[5] as List<Map<String, dynamic>>,
    );
  }

  /// 异步计算时间趋势统计
  Future<List<DailyTrendStatistics>> computeTimeTrends(
    List<LocalImageRecord> records, {
    String groupBy = 'daily',
  }) async {
    AppLogger.d(
      'Computing time trends ($groupBy) for ${records.length} images',
      'Statistics',
    );

    return compute(_computeTimeTrendsIsolate, _TimeTrendParams(records, groupBy));
  }

  /// 异步计算标签使用统计
  Future<List<TagStatistics>> computeTagStatistics(
    List<LocalImageRecord> records, {
    int limit = 20,
  }) async {
    AppLogger.d(
      'Computing tag statistics for ${records.length} images',
      'Statistics',
    );

    return compute(_computeTagStatisticsIsolate, _TagStatisticsParams(records, limit));
  }

  /// 异步计算参数分布统计
  Future<List<ParameterStatistics>> computeParameterDistribution(
    List<LocalImageRecord> records, {
    List<String>? parameters,
  }) async {
    AppLogger.d(
      'Computing parameter distribution for ${records.length} images',
      'Statistics',
    );

    const defaultParams = [
      'steps',
      'scale',
      'sampler',
      'noise_schedule',
      'smear',
      'sm_dyn',
      'cfg_rescale',
    ];

    return compute(
      _computeParameterDistributionIsolate,
      _ParameterDistributionParams(records, parameters ?? defaultParams),
    );
  }

  /// 异步计算收藏相关统计
  Future<Map<String, dynamic>> computeFavoritesStatistics(
    List<LocalImageRecord> records,
  ) async {
    AppLogger.d(
      'Computing favorites statistics for ${records.length} images',
      'Statistics',
    );

    return compute(_computeFavoritesStatisticsIsolate, records);
  }

  /// 异步计算最近活动时间线
  Future<List<Map<String, dynamic>>> computeRecentActivity(
    List<LocalImageRecord> records, {
    int days = 30,
  }) async {
    AppLogger.d(
      'Computing recent activity (last $days days) for ${records.length} images',
      'Statistics',
    );

    return compute(_computeRecentActivityIsolate, _RecentActivityParams(records, days));
  }
}

// ============================================================================
// Isolate 静态计算函数
// ============================================================================

/// 在 isolate 中计算完整统计数据
GalleryStatistics _computeAllStatisticsIsolate(
  List<LocalImageRecord> records,
) {
  final service = StatisticsService();
  return service.calculateStatistics(records);
}

class _TimeTrendParams {
  final List<LocalImageRecord> records;
  final String groupBy;

  _TimeTrendParams(this.records, this.groupBy);
}

List<DailyTrendStatistics> _computeTimeTrendsIsolate(_TimeTrendParams params) {
  final records = params.records;
  final groupBy = params.groupBy;

  if (records.isEmpty) return [];

  final groupedData = _groupRecordsByTime(records, groupBy);
  final sortedKeys = groupedData.keys.toList()..sort();

  final trends = sortedKeys.map((key) {
    final groupRecords = groupedData[key]!;
    final date = _parseTimeKey(key, groupBy);

    return DailyTrendStatistics(
      date: date,
      count: groupRecords.length,
      totalSizeBytes: groupRecords.fold(0, (sum, r) => sum + r.size),
      favoriteCount: groupRecords.where((r) => r.isFavorite).length,
      taggedImageCount: groupRecords.where((r) => r.tags.isNotEmpty).length,
      percentage: 0.0,
    );
  }).toList();

  final totalImages = records.length;
  if (totalImages == 0) return trends;

  return trends.map((t) {
    final percentage = (t.count / totalImages * 100).clamp(0.0, 100.0);
    return t.copyWith(percentage: percentage);
  }).toList();
}

Map<String, List<LocalImageRecord>> _groupRecordsByTime(
  List<LocalImageRecord> records,
  String groupBy,
) {
  final groupedData = <String, List<LocalImageRecord>>{};

  for (final record in records) {
    final date = record.modifiedAt;
    final key = switch (groupBy) {
      'monthly' => '${date.year}-${date.month.toString().padLeft(2, '0')}',
      'weekly' => _formatWeekKey(date),
      _ =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    };
    groupedData.putIfAbsent(key, () => []).add(record);
  }

  return groupedData;
}

String _formatWeekKey(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
  return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
}

DateTime _parseTimeKey(String key, String groupBy) {
  final parts = key.split('-');

  return switch (groupBy) {
    'monthly' => DateTime(int.parse(parts[0]), int.parse(parts[1])),
    'weekly' => DateTime(
        int.parse(parts[0]),
        1,
        1 + (int.parse(parts[1].substring(1)) - 1) * 7,
      ),
    _ => DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
  };
}

class _TagStatisticsParams {
  final List<LocalImageRecord> records;
  final int limit;

  _TagStatisticsParams(this.records, this.limit);
}

List<TagStatistics> _computeTagStatisticsIsolate(_TagStatisticsParams params) {
  final records = params.records;
  final limit = params.limit;

  final tagCounts = <String, int>{};

  for (final record in records) {
    for (final tag in record.tags) {
      if (tag.isNotEmpty) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
  }

  final sortedEntries = tagCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final topEntries = sortedEntries.take(limit).toList();
  final totalImages = records.length;

  return topEntries.map((entry) {
    return TagStatistics(
      tagName: entry.key,
      count: entry.value,
      percentage: totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
    );
  }).toList();
}

class _ParameterDistributionParams {
  final List<LocalImageRecord> records;
  final List<String> parameters;

  _ParameterDistributionParams(this.records, this.parameters);
}

List<ParameterStatistics> _computeParameterDistributionIsolate(
  _ParameterDistributionParams params,
) {
  final records = params.records;
  final parameters = params.parameters;

  final paramCounts = <String, Map<String, int>>{};

  for (final record in records) {
    final metadata = record.metadata;
    if (metadata == null) continue;

    for (final paramName in parameters) {
      final value = _getParamValue(metadata, paramName);
      if (value != null && value.isNotEmpty) {
        paramCounts.putIfAbsent(paramName, () => {});
        paramCounts[paramName]![value] = (paramCounts[paramName]![value] ?? 0) + 1;
      }
    }
  }

  final results = <ParameterStatistics>[];
  final totalImages = records.length;

  for (final paramName in parameters) {
    final counts = paramCounts[paramName];
    if (counts == null || counts.isEmpty) continue;

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      results.add(
        ParameterStatistics(
          parameterName: paramName,
          value: entry.key,
          count: entry.value,
          percentage: totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
        ),
      );
    }
  }

  return results;
}

String? _getParamValue(NaiImageMetadata metadata, String paramName) {
  return switch (paramName) {
    'steps' => metadata.steps?.toString(),
    'scale' => metadata.scale?.toString(),
    'sampler' => metadata.sampler,
    'noise_schedule' => metadata.noiseSchedule,
    'smear' => metadata.smea?.toString(),
    'sm_dyn' => metadata.smeaDyn?.toString(),
    'cfg_rescale' => metadata.cfgRescale?.toString(),
    _ => null,
  };
}

Map<String, dynamic> _computeFavoritesStatisticsIsolate(
  List<LocalImageRecord> records,
) {
  final favoriteRecords = records.where((r) => r.isFavorite).toList();

  final favoriteCount = favoriteRecords.length;
  final totalSize = favoriteRecords.fold<int>(0, (sum, r) => sum + r.size);
  final averageSize = favoriteCount > 0 ? totalSize / favoriteCount : 0.0;

  final favoriteByDate = <String, int>{};
  for (final record in favoriteRecords) {
    final dateKey =
        '${record.modifiedAt.year}-${record.modifiedAt.month.toString().padLeft(2, '0')}-${record.modifiedAt.day.toString().padLeft(2, '0')}';
    favoriteByDate[dateKey] = (favoriteByDate[dateKey] ?? 0) + 1;
  }

  return {
    'favoriteCount': favoriteCount,
    'totalSizeBytes': totalSize,
    'averageSizeBytes': averageSize,
    'favoriteByDate': favoriteByDate,
    'percentage': records.isNotEmpty ? (favoriteCount / records.length) * 100 : 0.0,
  };
}

class _RecentActivityParams {
  final List<LocalImageRecord> records;
  final int days;

  _RecentActivityParams(this.records, this.days);
}

List<Map<String, dynamic>> _computeRecentActivityIsolate(
  _RecentActivityParams params,
) {
  final records = params.records;
  final days = params.days;

  final cutoffDate = DateTime.now().subtract(Duration(days: days));

  final recentRecords = records
      .where((r) => r.modifiedAt.isAfter(cutoffDate))
      .toList()
    ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

  return recentRecords.map((record) {
    final meta = record.metadata;
    return {
      'path': record.path,
      'size': record.size,
      'modifiedAt': record.modifiedAt.toIso8601String(),
      'isFavorite': record.isFavorite,
      'tags': record.tags,
      'hasMetadata': record.hasMetadata,
      'width': meta?.width,
      'height': meta?.height,
      'model': meta?.model,
      'sampler': meta?.sampler,
      'steps': meta?.steps,
      'scale': meta?.scale,
    };
  }).toList();
}

/// Provider
@Riverpod(keepAlive: true)
StatisticsService statisticsService(Ref ref) {
  return StatisticsService();
}
