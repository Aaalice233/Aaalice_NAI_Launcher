import 'package:freezed_annotation/freezed_annotation.dart';

part 'gallery_statistics.freezed.dart';

/// 图片尺寸分布统计
///
/// 用于统计不同分辨率图片的数量
@freezed
class ResolutionStatistics with _$ResolutionStatistics {
  const factory ResolutionStatistics({
    required String label, // 分辨率标签（如 "1024x1024", "512x768"）
    required int count, // 图片数量
    @Default(0) double percentage, // 百分比 (0-100)
  }) = _ResolutionStatistics;

  const ResolutionStatistics._();
}

/// 模型分布统计
///
/// 用于统计不同生成模型的图片数量
@freezed
class ModelStatistics with _$ModelStatistics {
  const factory ModelStatistics({
    required String modelName, // 模型名称（如 "NAI Diffusion V4"）
    required int count, // 图片数量
    @Default(0) double percentage, // 百分比 (0-100)
  }) = _ModelStatistics;

  const ModelStatistics._();
}

/// 采样器分布统计
///
/// 用于统计不同采样器的图片数量
@freezed
class SamplerStatistics with _$SamplerStatistics {
  const factory SamplerStatistics({
    required String samplerName, // 采样器名称（如 "Euler Ancestral"）
    required int count, // 图片数量
    @Default(0) double percentage, // 百分比 (0-100)
  }) = _SamplerStatistics;

  const SamplerStatistics._();
}

/// 文件大小分布统计
///
/// 用于统计不同大小范围的图片数量
@freezed
class SizeDistributionStatistics with _$SizeDistributionStatistics {
  const factory SizeDistributionStatistics({
    required String label, // 大小范围标签（如 "< 1MB", "1-5MB", "> 5MB"）
    required int count, // 图片数量
    @Default(0) double percentage, // 百分比 (0-100)
  }) = _SizeDistributionStatistics;

  const SizeDistributionStatistics._();
}

/// 画廊统计数据模型
///
/// 包含画廊的完整统计信息，用于统计仪表盘显示
/// 支持总览统计和各种维度分布统计
@freezed
class GalleryStatistics with _$GalleryStatistics {
  const factory GalleryStatistics({
    /// 图片总数
    required int totalImages,

    /// 总磁盘大小（字节）
    required int totalSizeBytes,

    /// 平均文件大小（字节）
    required double averageFileSizeBytes,

    /// 收藏图片数量
    @Default(0) int favoriteCount,

    /// 有标签的图片数量
    @Default(0) int taggedImageCount,

    /// 有元数据的图片数量
    @Default(0) int imagesWithMetadata,

    /// 分辨率分布统计
    @Default([]) List<ResolutionStatistics> resolutionDistribution,

    /// 模型分布统计
    @Default([]) List<ModelStatistics> modelDistribution,

    /// 采样器分布统计
    @Default([]) List<SamplerStatistics> samplerDistribution,

    /// 文件大小分布统计
    @Default([]) List<SizeDistributionStatistics> sizeDistribution,

    /// 统计生成时间
    required DateTime calculatedAt,
  }) = _GalleryStatistics;

  const GalleryStatistics._();

  /// 获取格式化的总大小字符串
  ///
  /// 自动选择合适的单位（B/KB/MB/GB）
  String get totalSizeFormatted {
    return _formatBytes(totalSizeBytes);
  }

  /// 获取格式化的平均大小字符串
  ///
  /// 自动选择合适的单位（B/KB/MB/GB）
  String get averageSizeFormatted {
    return _formatBytes(averageFileSizeBytes.toInt());
  }

  /// 格式化字节数为可读字符串
  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).toStringAsFixed(2);
      return '$kb KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
      return '$mb MB';
    } else {
      final gb = (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
      return '$gb GB';
    }
  }

  /// 获取收藏图片占比
  double get favoritePercentage {
    if (totalImages == 0) return 0.0;
    return (favoriteCount / totalImages) * 100;
  }

  /// 获取有标签图片占比
  double get taggedImagePercentage {
    if (totalImages == 0) return 0.0;
    return (taggedImageCount / totalImages) * 100;
  }

  /// 获取有元数据图片占比
  double get metadataPercentage {
    if (totalImages == 0) return 0.0;
    return (imagesWithMetadata / totalImages) * 100;
  }
}
