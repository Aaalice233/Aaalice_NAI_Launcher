import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
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
}

/// Provider
@Riverpod(keepAlive: true)
StatisticsService statisticsService(Ref ref) {
  return StatisticsService();
}
