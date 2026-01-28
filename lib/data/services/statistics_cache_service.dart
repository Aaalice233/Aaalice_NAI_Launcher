import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../models/gallery/daily_trend_statistics.dart';
import '../models/gallery/gallery_statistics.dart';

part 'statistics_cache_service.g.dart';

/// 统计数据缓存元信息
class StatisticsCacheMetadata {
  /// 缓存的图片数量
  final int imageCount;

  /// 缓存创建时间
  final DateTime cachedAt;

  /// 画廊路径（用于验证）
  final String? galleryPath;

  const StatisticsCacheMetadata({
    required this.imageCount,
    required this.cachedAt,
    this.galleryPath,
  });

  Map<String, dynamic> toJson() => {
        'imageCount': imageCount,
        'cachedAt': cachedAt.toIso8601String(),
        'galleryPath': galleryPath,
      };

  factory StatisticsCacheMetadata.fromJson(Map<String, dynamic> json) {
    return StatisticsCacheMetadata(
      imageCount: json['imageCount'] as int,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      galleryPath: json['galleryPath'] as String?,
    );
  }
}

/// 统计数据持久化缓存服务
///
/// 将统计计算结果保存到 Hive，避免每次启动都重新计算
class StatisticsCacheService {
  Box get _cacheBox => Hive.box(StorageKeys.statisticsCacheBox);

  /// 保存统计数据到缓存
  ///
  /// [statistics] 统计数据
  /// [imageCount] 当前图片数量（用于缓存验证）
  /// [galleryPath] 画廊路径（可选，用于验证）
  Future<void> saveCache(
    GalleryStatistics statistics,
    int imageCount, {
    String? galleryPath,
  }) async {
    try {
      // 保存统计数据
      final statsJson = _serializeStatistics(statistics);
      await _cacheBox.put(StorageKeys.statisticsCacheData, statsJson);

      // 保存元信息
      final metadata = StatisticsCacheMetadata(
        imageCount: imageCount,
        cachedAt: DateTime.now(),
        galleryPath: galleryPath,
      );
      await _cacheBox.put(
        StorageKeys.statisticsCacheMetadata,
        jsonEncode(metadata.toJson()),
      );

      AppLogger.i(
        'Statistics cache saved: $imageCount images',
        'StatisticsCacheService',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save statistics cache',
        e,
        stack,
        'StatisticsCacheService',
      );
    }
  }

  /// 从缓存获取统计数据
  ///
  /// 返回 null 如果缓存不存在或解析失败
  GalleryStatistics? getCache() {
    try {
      final statsJson =
          _cacheBox.get(StorageKeys.statisticsCacheData) as String?;
      if (statsJson == null) return null;

      return _deserializeStatistics(statsJson);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get statistics cache',
        e,
        stack,
        'StatisticsCacheService',
      );
      return null;
    }
  }

  /// 获取缓存元信息
  StatisticsCacheMetadata? getCacheMetadata() {
    try {
      final metaJson =
          _cacheBox.get(StorageKeys.statisticsCacheMetadata) as String?;
      if (metaJson == null) return null;

      return StatisticsCacheMetadata.fromJson(
        jsonDecode(metaJson) as Map<String, dynamic>,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to get cache metadata',
        e,
        stack,
        'StatisticsCacheService',
      );
      return null;
    }
  }

  /// 验证缓存是否有效
  ///
  /// [currentImageCount] 当前图片数量
  /// 返回 true 如果缓存有效
  bool isCacheValid(int currentImageCount) {
    final metadata = getCacheMetadata();
    if (metadata == null) return false;

    // 图片数量一致则认为缓存有效
    return metadata.imageCount == currentImageCount;
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      await _cacheBox.delete(StorageKeys.statisticsCacheData);
      await _cacheBox.delete(StorageKeys.statisticsCacheMetadata);
      AppLogger.i('Statistics cache cleared', 'StatisticsCacheService');
    } catch (e, stack) {
      AppLogger.e(
        'Failed to clear statistics cache',
        e,
        stack,
        'StatisticsCacheService',
      );
    }
  }

  /// 序列化 GalleryStatistics 为 JSON 字符串
  String _serializeStatistics(GalleryStatistics stats) {
    final json = {
      'totalImages': stats.totalImages,
      'totalSizeBytes': stats.totalSizeBytes,
      'averageFileSizeBytes': stats.averageFileSizeBytes,
      'favoriteCount': stats.favoriteCount,
      'taggedImageCount': stats.taggedImageCount,
      'imagesWithMetadata': stats.imagesWithMetadata,
      'resolutionDistribution': stats.resolutionDistribution
          .map((r) => {
                'label': r.label,
                'count': r.count,
                'percentage': r.percentage,
              },)
          .toList(),
      'modelDistribution': stats.modelDistribution
          .map((m) => {
                'modelName': m.modelName,
                'count': m.count,
                'percentage': m.percentage,
              },)
          .toList(),
      'samplerDistribution': stats.samplerDistribution
          .map((s) => {
                'samplerName': s.samplerName,
                'count': s.count,
                'percentage': s.percentage,
              },)
          .toList(),
      'sizeDistribution': stats.sizeDistribution
          .map((s) => {
                'label': s.label,
                'count': s.count,
                'percentage': s.percentage,
              },)
          .toList(),
      'tagDistribution': stats.tagDistribution
          .map((t) => {
                'tagName': t.tagName,
                'count': t.count,
                'percentage': t.percentage,
              },)
          .toList(),
      'parameterDistribution': stats.parameterDistribution
          .map((p) => {
                'parameterName': p.parameterName,
                'value': p.value,
                'count': p.count,
                'percentage': p.percentage,
              },)
          .toList(),
      'dailyTrends': stats.dailyTrends
          .map((d) => {
                'date': d.date.toIso8601String(),
                'count': d.count,
                'totalSizeBytes': d.totalSizeBytes,
                'favoriteCount': d.favoriteCount,
                'taggedImageCount': d.taggedImageCount,
                'percentage': d.percentage,
              },)
          .toList(),
      'weeklyTrends': stats.weeklyTrends
          .map((w) => {
                'weekStart': w.weekStart.toIso8601String(),
                'weekEnd': w.weekEnd.toIso8601String(),
                'count': w.count,
                'totalSizeBytes': w.totalSizeBytes,
                'favoriteCount': w.favoriteCount,
                'taggedImageCount': w.taggedImageCount,
                'percentage': w.percentage,
              },)
          .toList(),
      'monthlyTrends': stats.monthlyTrends
          .map((m) => {
                'year': m.year,
                'month': m.month,
                'count': m.count,
                'totalSizeBytes': m.totalSizeBytes,
                'favoriteCount': m.favoriteCount,
                'taggedImageCount': m.taggedImageCount,
                'percentage': m.percentage,
              },)
          .toList(),
      'favoritesStatistics': stats.favoritesStatistics,
      'recentActivity': stats.recentActivity,
      'calculatedAt': stats.calculatedAt.toIso8601String(),
    };
    return jsonEncode(json);
  }

  /// 从 JSON 字符串反序列化 GalleryStatistics
  GalleryStatistics _deserializeStatistics(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    return GalleryStatistics(
      totalImages: json['totalImages'] as int,
      totalSizeBytes: json['totalSizeBytes'] as int,
      averageFileSizeBytes: (json['averageFileSizeBytes'] as num).toDouble(),
      favoriteCount: json['favoriteCount'] as int? ?? 0,
      taggedImageCount: json['taggedImageCount'] as int? ?? 0,
      imagesWithMetadata: json['imagesWithMetadata'] as int? ?? 0,
      resolutionDistribution: (json['resolutionDistribution'] as List?)
              ?.map((r) => ResolutionStatistics(
                    label: r['label'] as String,
                    count: r['count'] as int,
                    percentage: (r['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      modelDistribution: (json['modelDistribution'] as List?)
              ?.map((m) => ModelStatistics(
                    modelName: m['modelName'] as String,
                    count: m['count'] as int,
                    percentage: (m['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      samplerDistribution: (json['samplerDistribution'] as List?)
              ?.map((s) => SamplerStatistics(
                    samplerName: s['samplerName'] as String,
                    count: s['count'] as int,
                    percentage: (s['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      sizeDistribution: (json['sizeDistribution'] as List?)
              ?.map((s) => SizeDistributionStatistics(
                    label: s['label'] as String,
                    count: s['count'] as int,
                    percentage: (s['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      tagDistribution: (json['tagDistribution'] as List?)
              ?.map((t) => TagStatistics(
                    tagName: t['tagName'] as String,
                    count: t['count'] as int,
                    percentage: (t['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      parameterDistribution: (json['parameterDistribution'] as List?)
              ?.map((p) => ParameterStatistics(
                    parameterName: p['parameterName'] as String,
                    value: p['value'] as String,
                    count: p['count'] as int,
                    percentage: (p['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      dailyTrends: (json['dailyTrends'] as List?)
              ?.map((d) => DailyTrendStatistics(
                    date: DateTime.parse(d['date'] as String),
                    count: d['count'] as int,
                    totalSizeBytes: d['totalSizeBytes'] as int? ?? 0,
                    favoriteCount: d['favoriteCount'] as int? ?? 0,
                    taggedImageCount: d['taggedImageCount'] as int? ?? 0,
                    percentage: (d['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      weeklyTrends: (json['weeklyTrends'] as List?)
              ?.map((w) => WeeklyTrendStatistics(
                    weekStart: DateTime.parse(w['weekStart'] as String),
                    weekEnd: DateTime.parse(w['weekEnd'] as String),
                    count: w['count'] as int,
                    totalSizeBytes: w['totalSizeBytes'] as int? ?? 0,
                    favoriteCount: w['favoriteCount'] as int? ?? 0,
                    taggedImageCount: w['taggedImageCount'] as int? ?? 0,
                    percentage: (w['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      monthlyTrends: (json['monthlyTrends'] as List?)
              ?.map((m) => MonthlyTrendStatistics(
                    year: m['year'] as int,
                    month: m['month'] as int,
                    count: m['count'] as int,
                    totalSizeBytes: m['totalSizeBytes'] as int? ?? 0,
                    favoriteCount: m['favoriteCount'] as int? ?? 0,
                    taggedImageCount: m['taggedImageCount'] as int? ?? 0,
                    percentage: (m['percentage'] as num?)?.toDouble() ?? 0,
                  ),)
              .toList() ??
          [],
      favoritesStatistics:
          (json['favoritesStatistics'] as Map<String, dynamic>?) ?? {},
      recentActivity: (json['recentActivity'] as List?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
    );
  }
}

/// StatisticsCacheService Provider
@Riverpod(keepAlive: true)
StatisticsCacheService statisticsCacheService(Ref ref) {
  return StatisticsCacheService();
}
