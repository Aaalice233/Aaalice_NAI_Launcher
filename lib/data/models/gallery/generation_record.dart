import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../vibe/vibe_reference.dart';

part 'generation_record.freezed.dart';
part 'generation_record.g.dart';

/// 生成参数快照（简化版，用于存储）
@freezed
class GenerationParamsSnapshot with _$GenerationParamsSnapshot {
  const factory GenerationParamsSnapshot({
    /// 正向提示词
    required String prompt,

    /// 负向提示词
    @Default('') String negativePrompt,

    /// 模型名称
    @Default('nai-diffusion-4-full') String model,

    /// 图像宽度
    @Default(832) int width,

    /// 图像高度
    @Default(1216) int height,

    /// 采样步数
    @Default(28) int steps,

    /// 采样器
    @Default('k_euler_ancestral') String sampler,

    /// CFG Scale
    @Default(5.0) double scale,

    /// 种子
    @Default(0) int seed,

    /// SMEA
    @Default(true) bool smea,

    /// SMEA DYN
    @Default(false) bool smeaDyn,

    /// CFG Rescale
    @Default(0.0) double cfgRescale,

    /// 噪声计划
    @Default('native') String noiseSchedule,
  }) = _GenerationParamsSnapshot;

  factory GenerationParamsSnapshot.fromJson(Map<String, dynamic> json) =>
      _$GenerationParamsSnapshotFromJson(json);
}

/// 生成记录模型
///
/// 用于存储图像生成历史，支持持久化
@HiveType(typeId: 0)
@freezed
class GenerationRecord with _$GenerationRecord {
  const GenerationRecord._();

  const factory GenerationRecord({
    /// 唯一标识符 (UUID) - 作为 Hive Key 使用
    @HiveField(0) required String id,

    /// 生成时间
    @HiveField(1) required DateTime createdAt,

    /// 生成参数快照
    @HiveField(2) required GenerationParamsSnapshot params,

    /// 本地保存的图像文件路径
    @HiveField(3) String? filePath,

    /// 图像 base64 数据（用于未保存到文件的情况）
    @HiveField(4) String? imageBase64,

    /// 用户自定义标签
    @HiveField(5) @Default([]) List<String> userTags,

    /// 是否收藏
    @HiveField(6) @Default(false) bool isFavorite,

    /// 图像宽度（冗余存储，便于展示）
    @HiveField(7) @Default(0) int imageWidth,

    /// 图像高度（冗余存储，便于展示）
    @HiveField(8) @Default(0) int imageHeight,

    /// 图像文件大小（字节）
    @HiveField(9) @Default(0) int fileSize,

    /// Vibe 参考数据 (Hive 专用，不序列化为 JSON)
    @HiveField(10)
    @JsonKey(includeFromJson: false, includeToJson: false)
    VibeReference? vibeData,

    /// 是否有 Vibe 元数据
    @HiveField(11) @Default(false) bool hasVibeMetadata,

    /// 缩略图文件路径
    @HiveField(12) String? thumbnailPath,
  }) = _GenerationRecord;

  factory GenerationRecord.fromJson(Map<String, dynamic> json) =>
      _$GenerationRecordFromJson(json);

  /// 从图像数据和参数创建新记录
  factory GenerationRecord.create({
    required Uint8List imageData,
    required GenerationParamsSnapshot params,
    String? filePath,
    List<String>? userTags,
  }) {
    final id = const Uuid().v4();
    final now = DateTime.now();

    return GenerationRecord(
      id: id,
      createdAt: now,
      params: params,
      filePath: filePath,
      imageBase64: filePath == null ? base64Encode(imageData) : null,
      userTags: userTags ?? [],
      isFavorite: false,
      imageWidth: params.width,
      imageHeight: params.height,
      fileSize: imageData.length,
    );
  }

  /// 获取图像数据
  Uint8List? get imageData {
    if (imageBase64 != null) {
      return base64Decode(imageBase64!);
    }
    return null;
  }

  /// 是否有图像数据
  bool get hasImage => filePath != null || imageBase64 != null;

  /// 获取简短的提示词预览
  String get promptPreview {
    final prompt = params.prompt;
    if (prompt.length <= 50) return prompt;
    return '${prompt.substring(0, 50)}...';
  }

  /// 获取分辨率字符串
  String get resolution => '${params.width}x${params.height}';

  /// 格式化的创建时间
  String get formattedCreatedAt {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return '${createdAt.month}/${createdAt.day}';
  }

  /// 格式化的文件大小
  String get formattedFileSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// 画廊排序方式
enum GallerySortOrder {
  /// 最新优先
  newestFirst,

  /// 最旧优先
  oldestFirst,

  /// 收藏优先
  favoritesFirst,
}

/// 画廊筛选条件
@freezed
class GalleryFilter with _$GalleryFilter {
  const factory GalleryFilter({
    /// 搜索关键词（匹配提示词）
    String? searchQuery,

    /// 只显示收藏
    @Default(false) bool favoritesOnly,

    /// 只显示 Vibe 图片
    @Default(false) bool vibeOnly,

    /// 模型筛选
    String? modelFilter,

    /// 日期范围开始
    DateTime? dateFrom,

    /// 日期范围结束
    DateTime? dateTo,

    /// 用户标签筛选
    @Default([]) List<String> tagFilter,

    /// 排序方式
    @Default(GallerySortOrder.newestFirst) GallerySortOrder sortOrder,
  }) = _GalleryFilter;

  factory GalleryFilter.fromJson(Map<String, dynamic> json) =>
      _$GalleryFilterFromJson(json);
}
