import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'vibe_reference.dart';

part 'vibe_library_entry.freezed.dart';
part 'vibe_library_entry.g.dart';

/// Vibe 库条目数据模型
///
/// 用于保存可复用的 Vibe 参考配置，支持分类、标签和使用统计
/// 使用 Hive 进行本地持久化存储
@HiveType(typeId: 23)
@freezed
class VibeLibraryEntry with _$VibeLibraryEntry {
  const VibeLibraryEntry._();

  const factory VibeLibraryEntry({
    /// 唯一标识 (UUID)
    @HiveField(0) required String id,

    /// 显示名称
    @HiveField(1) required String name,

    /// Vibe 显示名称 (来自 vibeData.displayName)
    @HiveField(2) required String vibeDisplayName,

    /// 预编码的 vibe 数据 (Base64 字符串)
    @HiveField(3) required String vibeEncoding,

    /// Vibe 缩略图数据 (可选，用于 UI 预览)
    @HiveField(4) Uint8List? vibeThumbnail,

    /// 原始图片数据 (仅 rawImage 模式使用)
    @HiveField(5) Uint8List? rawImageData,

    /// Reference Strength (0-1)
    @HiveField(6) @Default(0.6) double strength,

    /// Information Extracted (0-1)
    @HiveField(7) @Default(0.7) double infoExtracted,

    /// 数据来源类型索引 (VibeSourceType 的索引)
    @HiveField(8) @Default(3) int sourceTypeIndex, // default to rawImage (index 3)

    /// 所属分类 ID
    @HiveField(9) String? categoryId,

    /// 标签列表 (用于筛选)
    @HiveField(10) @Default([]) List<String> tags,

    /// 是否收藏
    @HiveField(11) @Default(false) bool isFavorite,

    /// 使用次数
    @HiveField(12) @Default(0) int usedCount,

    /// 最后使用时间
    @HiveField(13) DateTime? lastUsedAt,

    /// 创建时间
    @HiveField(14) required DateTime createdAt,

    /// 库条目缩略图数据 (与 vibeThumbnail 分开存储)
    @HiveField(15) Uint8List? thumbnail,

    /// 关联文件路径（.naiv4vibe / .naiv4vibebundle）
    @HiveField(16) String? filePath,

    /// 所属 bundle 的 ID（若当前条目来自 bundle）
    @HiveField(17) String? bundleId,

    /// bundle 内部 vibe 名称列表缓存
    @HiveField(18) List<String>? bundledVibeNames,

    /// bundle 内部 vibe 缩略图缓存（前几个用于 UI 预览）
    @HiveField(19) List<Uint8List>? bundledVibePreviews,
  }) = _VibeLibraryEntry;

  /// 从 VibeReference 创建库条目
  factory VibeLibraryEntry.fromVibeReference({
    required String name,
    required VibeReference vibeData,
    String? categoryId,
    List<String>? tags,
    Uint8List? thumbnail,
    String? filePath,
    bool isFavorite = false,
  }) {
    final now = DateTime.now();
    return VibeLibraryEntry(
      id: const Uuid().v4(),
      name: name.trim(),
      vibeDisplayName: vibeData.displayName,
      vibeEncoding: vibeData.vibeEncoding,
      vibeThumbnail: vibeData.thumbnail,
      rawImageData: vibeData.rawImageData,
      strength: vibeData.strength,
      infoExtracted: vibeData.infoExtracted,
      sourceTypeIndex: vibeData.sourceType.index,
      categoryId: categoryId,
      tags: tags ?? [],
      isFavorite: isFavorite,
      usedCount: 0,
      lastUsedAt: null,
      createdAt: now,
      thumbnail: thumbnail,
      filePath: filePath,
    );
  }

  /// 创建新 Vibe 库条目 (简化版)
  factory VibeLibraryEntry.create({
    required String name,
    required String vibeDisplayName,
    required String vibeEncoding,
    String? categoryId,
    List<String>? tags,
    Uint8List? thumbnail,
    String? filePath,
    bool isFavorite = false,
    VibeSourceType sourceType = VibeSourceType.rawImage,
  }) {
    final now = DateTime.now();
    return VibeLibraryEntry(
      id: const Uuid().v4(),
      name: name.trim(),
      vibeDisplayName: vibeDisplayName,
      vibeEncoding: vibeEncoding,
      categoryId: categoryId,
      tags: tags ?? [],
      isFavorite: isFavorite,
      usedCount: 0,
      lastUsedAt: null,
      createdAt: now,
      thumbnail: thumbnail,
      filePath: filePath,
      sourceTypeIndex: sourceType.index,
    );
  }

  /// 转换为 VibeReference
  VibeReference toVibeReference() {
    return VibeReference(
      displayName: vibeDisplayName,
      vibeEncoding: vibeEncoding,
      thumbnail: vibeThumbnail,
      rawImageData: rawImageData,
      strength: strength,
      infoExtracted: infoExtracted,
      sourceType: VibeSourceType.values[sourceTypeIndex],
    );
  }

  /// 数据来源类型
  VibeSourceType get sourceType => VibeSourceType.values[sourceTypeIndex];

  /// 是否为预编码数据 (不需要服务端编码)
  bool get isPreEncoded => sourceType.isPreEncoded;

  /// 显示名称 (如果名称为空则使用 vibeDisplayName)
  String get displayName {
    if (name.isNotEmpty) return name;
    return vibeDisplayName;
  }

  /// 是否有缩略图
  bool get hasThumbnail => thumbnail != null && thumbnail!.isNotEmpty;

  /// 是否有 vibe 缩略图
  bool get hasVibeThumbnail => vibeThumbnail != null && vibeThumbnail!.isNotEmpty;

  /// 是否为 bundle 条目
  bool get isBundle =>
      bundledVibeNames != null && bundledVibeNames!.isNotEmpty;

  /// bundle 内部 vibe 数量
  int get bundledVibeCount => bundledVibeNames?.length ?? 0;

  /// 更新条目
  VibeLibraryEntry update({
    String? name,
    String? vibeDisplayName,
    String? vibeEncoding,
    Uint8List? vibeThumbnail,
    Uint8List? rawImageData,
    double? strength,
    double? infoExtracted,
    VibeSourceType? sourceType,
    String? categoryId,
    List<String>? tags,
    Uint8List? thumbnail,
    String? filePath,
    String? bundleId,
    List<String>? bundledVibeNames,
    List<Uint8List>? bundledVibePreviews,
    bool? isFavorite,
  }) {
    return copyWith(
      name: name?.trim() ?? this.name,
      vibeDisplayName: vibeDisplayName ?? this.vibeDisplayName,
      vibeEncoding: vibeEncoding ?? this.vibeEncoding,
      vibeThumbnail: vibeThumbnail ?? this.vibeThumbnail,
      rawImageData: rawImageData ?? this.rawImageData,
      strength: strength ?? this.strength,
      infoExtracted: infoExtracted ?? this.infoExtracted,
      sourceTypeIndex: sourceType != null ? sourceType.index : sourceTypeIndex,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      thumbnail: thumbnail ?? this.thumbnail,
      filePath: filePath ?? this.filePath,
      bundleId: bundleId ?? this.bundleId,
      bundledVibeNames: bundledVibeNames ?? this.bundledVibeNames,
      bundledVibePreviews: bundledVibePreviews ?? this.bundledVibePreviews,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// 从 VibeReference 更新 vibe 数据
  VibeLibraryEntry updateVibeData(VibeReference vibeData) {
    return copyWith(
      vibeDisplayName: vibeData.displayName,
      vibeEncoding: vibeData.vibeEncoding,
      vibeThumbnail: vibeData.thumbnail,
      rawImageData: vibeData.rawImageData,
      strength: vibeData.strength,
      infoExtracted: vibeData.infoExtracted,
      sourceTypeIndex: vibeData.sourceType.index,
    );
  }

  /// 记录使用
  VibeLibraryEntry recordUsage() {
    return copyWith(
      usedCount: usedCount + 1,
      lastUsedAt: DateTime.now(),
    );
  }

  /// 切换收藏状态
  VibeLibraryEntry toggleFavorite() {
    return copyWith(isFavorite: !isFavorite);
  }

  /// 添加标签
  VibeLibraryEntry addTag(String tag) {
    if (tags.contains(tag)) return this;
    return copyWith(tags: [...tags, tag]);
  }

  /// 移除标签
  VibeLibraryEntry removeTag(String tag) {
    return copyWith(tags: tags.where((t) => t != tag).toList());
  }

  /// 更新 Vibe 强度
  VibeLibraryEntry updateStrength(double newStrength) {
    return copyWith(strength: newStrength.clamp(0.0, 1.0));
  }

  /// 更新信息提取度
  VibeLibraryEntry updateInfoExtracted(double newInfoExtracted) {
    return copyWith(infoExtracted: newInfoExtracted.clamp(0.0, 1.0));
  }
}

/// Vibe 库条目列表扩展
extension VibeLibraryEntryListExtension on List<VibeLibraryEntry> {
  /// 获取收藏的条目
  List<VibeLibraryEntry> get favorites =>
      where((e) => e.isFavorite).toList();

  /// 获取指定分类的条目
  List<VibeLibraryEntry> getByCategory(String? categoryId) =>
      where((e) => e.categoryId == categoryId).toList();

  /// 按创建时间排序（最新的在前）
  List<VibeLibraryEntry> sortedByCreatedAt() {
    return [...this]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 按使用时间排序（最新的在前）
  List<VibeLibraryEntry> sortedByLastUsed() {
    return [...this]..sort((a, b) {
        if (a.lastUsedAt == null) return b.lastUsedAt == null ? 0 : 1;
        if (b.lastUsedAt == null) return -1;
        return b.lastUsedAt!.compareTo(a.lastUsedAt!);
      });
  }

  /// 按使用次数排序（最多的在前）
  List<VibeLibraryEntry> sortedByUsedCount() {
    return [...this]..sort((a, b) => b.usedCount.compareTo(a.usedCount));
  }

  /// 按名称排序
  List<VibeLibraryEntry> sortedByName() {
    return [...this]..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
  }

  /// 搜索
  List<VibeLibraryEntry> search(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where(
      (e) =>
          e.name.toLowerCase().contains(lowerQuery) ||
          e.vibeDisplayName.toLowerCase().contains(lowerQuery) ||
          e.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
    ).toList();
  }

  /// 按标签筛选
  List<VibeLibraryEntry> filterByTag(String tag) {
    return where((e) => e.tags.contains(tag)).toList();
  }

  /// 获取所有标签
  Set<String> get allTags {
    final tags = <String>{};
    for (final entry in this) {
      tags.addAll(entry.tags);
    }
    return tags;
  }

  /// 获取预编码的 vibe 条目 (无需额外消耗 Anlas)
  List<VibeLibraryEntry> get preEncoded =>
      where((e) => e.isPreEncoded).toList();

  /// 获取需要服务端编码的 vibe 条目 (消耗 2 Anlas/张)
  List<VibeLibraryEntry> get rawImageEntries =>
      where((e) => e.sourceType == VibeSourceType.rawImage).toList();
}
