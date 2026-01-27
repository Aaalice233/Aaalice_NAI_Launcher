import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/gallery/daily_trend_statistics.dart';
import '../models/gallery/gallery_statistics.dart';
import '../models/gallery/local_image_record.dart';

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
    final resolutionCounts = <String, int>{};

    for (final record in records) {
      if (record.metadata?.width != null && record.metadata?.height != null) {
        final width = record.metadata!.width!;
        final height = record.metadata!.height!;
        final resolution = '${width}x$height';
        resolutionCounts[resolution] = (resolutionCounts[resolution] ?? 0) + 1;
      }
    }

    // 按数量降序排序
    final sortedEntries = resolutionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.map((entry) {
      return ResolutionStatistics(
        label: entry.key,
        count: entry.value,
        percentage: totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
      );
    }).toList();
  }

  /// 计算模型分布统计
  List<ModelStatistics> _calculateModelDistribution(
    List<LocalImageRecord> records,
    int totalImages,
  ) {
    final modelCounts = <String, int>{};

    for (final record in records) {
      final model = record.metadata?.model;
      if (model != null && model.isNotEmpty) {
        modelCounts[model] = (modelCounts[model] ?? 0) + 1;
      }
    }

    // 按数量降序排序
    final sortedEntries = modelCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.map((entry) {
      return ModelStatistics(
        modelName: entry.key,
        count: entry.value,
        percentage: totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
      );
    }).toList();
  }

  /// 计算采样器分布统计
  List<SamplerStatistics> _calculateSamplerDistribution(
    List<LocalImageRecord> records,
    int totalImages,
  ) {
    final samplerCounts = <String, int>{};

    for (final record in records) {
      final sampler = record.metadata?.sampler;
      if (sampler != null && sampler.isNotEmpty) {
        // 格式化采样器名称（如 k_euler_ancestral -> Euler Ancestral）
        final formattedSampler = _formatSamplerName(sampler);
        samplerCounts[formattedSampler] =
            (samplerCounts[formattedSampler] ?? 0) + 1;
      }
    }

    // 按数量降序排序
    final sortedEntries = samplerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.map((entry) {
      return SamplerStatistics(
        samplerName: entry.key,
        count: entry.value,
        percentage: totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
      );
    }).toList();
  }

  /// 格式化采样器名称
  ///
  /// 将 k_euler_ancestral 转换为 Euler Ancestral
  String _formatSamplerName(String sampler) {
    return sampler
        .replaceAll('k_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  /// 计算文件大小分布统计
  List<SizeDistributionStatistics> _calculateSizeDistribution(
    List<LocalImageRecord> records,
    int totalImages,
  ) {
    const mb = 1024 * 1024;

    final sizeRanges = <String, int>{
      '< 1 MB': 0,
      '1-2 MB': 0,
      '2-5 MB': 0,
      '5-10 MB': 0,
      '> 10 MB': 0,
    };

    for (final record in records) {
      final sizeMB = record.size / mb;

      if (sizeMB < 1) {
        sizeRanges['< 1 MB'] = sizeRanges['< 1 MB']! + 1;
      } else if (sizeMB < 2) {
        sizeRanges['1-2 MB'] = sizeRanges['1-2 MB']! + 1;
      } else if (sizeMB < 5) {
        sizeRanges['2-5 MB'] = sizeRanges['2-5 MB']! + 1;
      } else if (sizeMB < 10) {
        sizeRanges['5-10 MB'] = sizeRanges['5-10 MB']! + 1;
      } else {
        sizeRanges['> 10 MB'] = sizeRanges['> 10 MB']! + 1;
      }
    }

    // Filter out ranges with zero count, then map to statistics
    return sizeRanges.entries.where((entry) => entry.value > 0).map((entry) {
      return SizeDistributionStatistics(
        label: entry.key,
        count: entry.value,
        percentage: totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
      );
    }).toList();
  }

  /// 增量更新统计数据
  ///
  /// [currentStats] - 当前统计数据
  /// [newRecords] - 新增的图片记录
  /// [removedRecords] - 移除的图片记录
  /// 返回更新后的统计数据
  GalleryStatistics updateStatistics(
    GalleryStatistics currentStats,
    List<LocalImageRecord> newRecords,
    List<LocalImageRecord> removedRecords,
  ) {
    // 注意：这里简化处理，实际应该基于所有记录重新计算
    // 由于分布统计可能涉及所有数据，重新计算更准确
    AppLogger.d(
      'Updating statistics: +${newRecords.length} -${removedRecords.length}',
      'Statistics',
    );

    // 对于生产环境，建议保留完整的记录列表并重新计算
    // 这里仅返回当前统计数据，实际调用者应重新计算
    return currentStats;
  }

  /// 异步计算完整的画廊统计数据（主协调方法）
  ///
  /// [records] - 图片记录列表
  /// 返回包含所有统计数据的完整对象
  /// 此方法会调用所有统计计算方法，包括时间趋势、标签统计、参数分布等
  Future<GalleryStatistics> computeAllStatistics(
    List<LocalImageRecord> records,
  ) async {
    AppLogger.d(
      'Computing all statistics for ${records.length} images',
      'Statistics',
    );

    // 并行计算所有统计数据
    final results = await Future.wait([
      // 基础统计（在 isolate 中执行）
      compute(_computeAllStatisticsIsolate, records),
      // 时间趋势统计
      computeTimeTrends(records, groupBy: 'daily'),
      // 标签统计
      computeTagStatistics(records, limit: 20),
      // 参数分布统计
      computeParameterDistribution(records),
      // 收藏统计
      computeFavoritesStatistics(records),
      // 最近活动
      computeRecentActivity(records, days: 30),
    ]);

    final baseStats = results[0] as GalleryStatistics;
    final dailyTrends = results[1] as List<DailyTrendStatistics>;
    final tagStats = results[2] as List<TagStatistics>;
    final paramStats = results[3] as List<ParameterStatistics>;
    final favStats = results[4] as Map<String, dynamic>;
    final recentActivity = results[5] as List<Map<String, dynamic>>;

    // 合并所有统计数据
    return baseStats.copyWith(
      dailyTrends: dailyTrends,
      weeklyTrends: [], // 可选：如果有需要可以计算周趋势
      monthlyTrends: [], // 可选：如果有需要可以计算月趋势
      tagDistribution: tagStats,
      parameterDistribution: paramStats,
      favoritesStatistics: favStats,
      recentActivity: recentActivity,
    );
  }

  /// 异步计算时间趋势统计
  ///
  /// [records] - 图片记录列表
  /// [groupBy] - 分组方式 ('daily', 'weekly', 'monthly')
  /// 返回时间趋势数据列表
  Future<List<DailyTrendStatistics>> computeTimeTrends(
    List<LocalImageRecord> records, {
    String groupBy = 'daily',
  }) async {
    AppLogger.d(
      'Computing time trends ($groupBy) for ${records.length} images',
      'Statistics',
    );

    return compute(
      _computeTimeTrendsIsolate,
      _TimeTrendParams(records, groupBy),
    );
  }

  /// 异步计算标签使用统计
  ///
  /// [records] - 图片记录列表
  /// [limit] - 返回的最大标签数量（默认 20）
  /// 返回标签使用频率统计，按使用次数降序排序
  Future<List<TagStatistics>> computeTagStatistics(
    List<LocalImageRecord> records, {
    int limit = 20,
  }) async {
    AppLogger.d(
      'Computing tag statistics for ${records.length} images',
      'Statistics',
    );

    return compute(
      _computeTagStatisticsIsolate,
      _TagStatisticsParams(records, limit),
    );
  }

  /// 异步计算参数分布统计
  ///
  /// [records] - 图片记录列表
  /// [parameters] - 要统计的参数列表（默认统计所有常用参数）
  /// 返回参数使用频率统计
  Future<List<ParameterStatistics>> computeParameterDistribution(
    List<LocalImageRecord> records, {
    List<String>? parameters,
  }) async {
    AppLogger.d(
      'Computing parameter distribution for ${records.length} images',
      'Statistics',
    );

    // 默认统计的参数列表
    final defaultParams = [
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
      _ParameterDistributionParams(
        records,
        parameters ?? defaultParams,
      ),
    );
  }

  /// 异步计算收藏相关统计
  ///
  /// [records] - 图片记录列表
  /// 返回收藏统计信息（总数、大小、分布等）
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
  ///
  /// [records] - 图片记录列表
  /// [days] - 返回最近多少天的数据（默认 30 天）
  /// 返回按时间排序的最近活动列表
  Future<List<Map<String, dynamic>>> computeRecentActivity(
    List<LocalImageRecord> records, {
    int days = 30,
  }) async {
    AppLogger.d(
      'Computing recent activity (last $days days) for ${records.length} images',
      'Statistics',
    );

    return compute(
      _computeRecentActivityIsolate,
      _RecentActivityParams(records, days),
    );
  }
}

/// ============================================================================
/// Isolate 静态计算函数
///
/// 这些函数在独立的 isolate 中执行，必须都是顶层函数或静态函数
/// ============================================================================

/// 在 isolate 中计算完整统计数据
GalleryStatistics _computeAllStatisticsIsolate(
  List<LocalImageRecord> records,
) {
  final service = StatisticsService();
  return service.calculateStatistics(records);
}

/// 时间趋势计算参数
class _TimeTrendParams {
  final List<LocalImageRecord> records;
  final String groupBy;

  _TimeTrendParams(this.records, this.groupBy);
}

/// 在 isolate 中计算时间趋势
List<DailyTrendStatistics> _computeTimeTrendsIsolate(_TimeTrendParams params) {
  final records = params.records;
  final groupBy = params.groupBy;

  if (records.isEmpty) {
    return [];
  }

  // 按修改时间分组统计
  final groupedData = <String, List<LocalImageRecord>>{};

  for (final record in records) {
    final date = record.modifiedAt;
    String key;

    if (groupBy == 'monthly') {
      // 按月分组: YYYY-MM
      key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    } else if (groupBy == 'weekly') {
      // 按周分组: YYYY-Www
      // 计算 ISO 周数
      final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
      final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
      key = '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
    } else {
      // 按日分组: YYYY-MM-DD (默认)
      key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }

    groupedData.putIfAbsent(key, () => []).add(record);
  }

  // 转换为统计对象
  final trends = <DailyTrendStatistics>[];
  final sortedKeys = groupedData.keys.toList()..sort();

  for (final key in sortedKeys) {
    final groupRecords = groupedData[key]!;
    final parts = key.split('-');

    DateTime date;
    if (groupBy == 'monthly') {
      date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } else if (groupBy == 'weekly') {
      // 使用周的开始日期
      final year = int.parse(parts[0]);
      final week = int.parse(parts[1].substring(1));
      // 简化：使用年份和周数创建日期
      date = DateTime(year, 1, 1 + (week - 1) * 7);
    } else {
      date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }

    final totalSize = groupRecords.fold<int>(
      0,
      (sum, r) => sum + r.size,
    );
    final favoriteCount = groupRecords.where((r) => r.isFavorite).length;
    final taggedCount = groupRecords.where((r) => r.tags.isNotEmpty).length;

    trends.add(DailyTrendStatistics(
      date: date,
      count: groupRecords.length,
      totalSizeBytes: totalSize,
      favoriteCount: favoriteCount,
      taggedImageCount: taggedCount,
      percentage: 0.0, // 稍后计算
    ));
  }

  // 计算百分比
  final totalImages = records.length;
  if (totalImages > 0) {
    return trends.map((trend) {
      final percentage = (trend.count / totalImages * 100).clamp(0.0, 100.0);
      return trend.copyWith(percentage: percentage);
    }).toList();
  }

  return trends;
}

/// 标签统计参数
class _TagStatisticsParams {
  final List<LocalImageRecord> records;
  final int limit;

  _TagStatisticsParams(this.records, this.limit);
}

/// 在 isolate 中计算标签统计
List<TagStatistics> _computeTagStatisticsIsolate(_TagStatisticsParams params) {
  final records = params.records;
  final limit = params.limit;

  final tagCounts = <String, int>{};

  // 统计每个标签的使用频率
  for (final record in records) {
    for (final tag in record.tags) {
      if (tag.isNotEmpty) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
  }

  // 按使用次数降序排序
  final sortedEntries = tagCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // 取前 N 个标签
  final topEntries = sortedEntries.take(limit).toList();
  final totalImages = records.length;

  return topEntries.map((entry) {
    return TagStatistics(
      tagName: entry.key,
      count: entry.value,
      percentage:
          totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
    );
  }).toList();
}

/// 参数分布统计参数
class _ParameterDistributionParams {
  final List<LocalImageRecord> records;
  final List<String> parameters;

  _ParameterDistributionParams(this.records, this.parameters);
}

/// 在 isolate 中计算参数分布统计
List<ParameterStatistics> _computeParameterDistributionIsolate(
  _ParameterDistributionParams params,
) {
  final records = params.records;
  final parameters = params.parameters;

  final paramCounts = <String, Map<String, int>>{};

  // 统计每个参数值的使用频率
  for (final record in records) {
    final metadata = record.metadata;
    if (metadata == null) continue;

    for (final paramName in parameters) {
      paramCounts.putIfAbsent(paramName, () => {});

      String? value;
      switch (paramName) {
        case 'steps':
          value = metadata.steps?.toString();
          break;
        case 'scale':
          value = metadata.scale?.toString();
          break;
        case 'sampler':
          value = metadata.sampler;
          break;
        case 'noise_schedule':
          value = metadata.noiseSchedule;
          break;
        case 'smear':
          value = metadata.smea?.toString();
          break;
        case 'sm_dyn':
          value = metadata.smeaDyn?.toString();
          break;
        case 'cfg_rescale':
          value = metadata.cfgRescale?.toString();
          break;
      }

      if (value != null && value.isNotEmpty) {
        paramCounts[paramName]![value] =
            (paramCounts[paramName]![value] ?? 0) + 1;
      }
    }
  }

  // 转换为统计对象列表
  final results = <ParameterStatistics>[];
  final totalImages = records.length;

  for (final paramName in parameters) {
    final counts = paramCounts[paramName];
    if (counts == null || counts.isEmpty) continue;

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      results.add(ParameterStatistics(
        parameterName: paramName,
        value: entry.key,
        count: entry.value,
        percentage: totalImages > 0 ? (entry.value / totalImages) * 100 : 0.0,
      ));
    }
  }

  return results;
}

/// 在 isolate 中计算收藏统计
Map<String, dynamic> _computeFavoritesStatisticsIsolate(
  List<LocalImageRecord> records,
) {
  final favoriteRecords = records.where((r) => r.isFavorite).toList();

  final favoriteCount = favoriteRecords.length;
  final totalSize = favoriteRecords.fold<int>(
    0,
    (sum, r) => sum + r.size,
  );
  final averageSize =
      favoriteCount > 0 ? totalSize / favoriteCount : 0.0;

  // 按修改时间分组
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
    'percentage': records.isNotEmpty
        ? (favoriteCount / records.length) * 100
        : 0.0,
  };
}

/// 最近活动计算参数
class _RecentActivityParams {
  final List<LocalImageRecord> records;
  final int days;

  _RecentActivityParams(this.records, this.days);
}

/// 在 isolate 中计算最近活动
List<Map<String, dynamic>> _computeRecentActivityIsolate(
  _RecentActivityParams params,
) {
  final records = params.records;
  final days = params.days;

  final cutoffDate = DateTime.now().subtract(Duration(days: days));

  // 筛选最近 N 天的图片，按修改时间降序排序
  final recentRecords = records
      .where((r) => r.modifiedAt.isAfter(cutoffDate))
      .toList()
    ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

  // 转换为活动时间线数据
  return recentRecords.map((record) {
    return {
      'path': record.path,
      'size': record.size,
      'modifiedAt': record.modifiedAt.toIso8601String(),
      'isFavorite': record.isFavorite,
      'tags': record.tags,
      'hasMetadata': record.hasMetadata,
      'width': record.metadata?.width,
      'height': record.metadata?.height,
      'model': record.metadata?.model,
      'sampler': record.metadata?.sampler,
      'steps': record.metadata?.steps,
      'scale': record.metadata?.scale,
    };
  }).toList();
}

/// Provider
@Riverpod(keepAlive: true)
StatisticsService statisticsService(Ref ref) {
  return StatisticsService();
}
