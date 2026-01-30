import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'tag_library_entry.freezed.dart';
part 'tag_library_entry.g.dart';

/// 词库条目数据模型
///
/// 用于保存可复用的提示词片段，支持分类、标签和使用统计
@freezed
class TagLibraryEntry with _$TagLibraryEntry {
  const TagLibraryEntry._();

  const factory TagLibraryEntry({
    /// 唯一标识
    required String id,

    /// 显示名称
    required String name,

    /// 提示词内容
    required String content,

    /// 预览图路径 (可选)
    String? thumbnail,

    /// 标签列表 (用于筛选)
    @Default([]) List<String> tags,

    /// 所属分类ID
    String? categoryId,

    /// 排序顺序
    @Default(0) int sortOrder,

    /// 使用次数
    @Default(0) int useCount,

    /// 最后使用时间
    DateTime? lastUsedAt,

    /// 是否收藏
    @Default(false) bool isFavorite,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    required DateTime updatedAt,
  }) = _TagLibraryEntry;

  factory TagLibraryEntry.fromJson(Map<String, dynamic> json) =>
      _$TagLibraryEntryFromJson(json);

  /// 创建新词库条目
  factory TagLibraryEntry.create({
    required String name,
    required String content,
    String? thumbnail,
    List<String>? tags,
    String? categoryId,
    int sortOrder = 0,
    bool isFavorite = false,
  }) {
    final now = DateTime.now();
    return TagLibraryEntry(
      id: const Uuid().v4(),
      name: name.trim(),
      content: content.trim(),
      thumbnail: thumbnail,
      tags: tags ?? [],
      categoryId: categoryId,
      sortOrder: sortOrder,
      useCount: 0,
      lastUsedAt: null,
      isFavorite: isFavorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 显示名称 (如果名称为空则显示内容的前20个字符)
  String get displayName {
    if (name.isNotEmpty) return name;
    if (content.length > 20) return '${content.substring(0, 20)}...';
    return content.isEmpty ? '未命名' : content;
  }

  /// 内容预览 (截取前100个字符)
  String get contentPreview {
    if (content.length > 100) {
      return '${content.substring(0, 100)}...';
    }
    return content;
  }

  /// 是否有预览图
  bool get hasThumbnail => thumbnail != null && thumbnail!.isNotEmpty;

  /// 计算内容中的实际标签数量（按逗号分隔，正确处理嵌套语法）
  int get promptTagCount {
    if (content.isEmpty) return 0;

    int count = 0;
    int braceDepth = 0; // {}
    int bracketDepth = 0; // []
    int parenDepth = 0; // ()
    bool hasContent = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == '{') {
        braceDepth++;
      } else if (char == '}') {
        braceDepth--;
      } else if (char == '[') {
        bracketDepth++;
      } else if (char == ']') {
        bracketDepth--;
      } else if (char == '(') {
        parenDepth++;
      } else if (char == ')') {
        parenDepth--;
      }

      // 在顶层遇到逗号时计数
      if (char == ',' &&
          braceDepth == 0 &&
          bracketDepth == 0 &&
          parenDepth == 0) {
        if (hasContent) {
          count++;
          hasContent = false;
        }
      } else if (char != ' ' && char != '\t' && char != '\n') {
        hasContent = true;
      }
    }

    // 最后一个片段
    if (hasContent) {
      count++;
    }

    return count;
  }

  /// 计算权重所需的嵌套层数
  static int calculateWeightLayers(double weight) {
    if (weight == 1.0) return 0;
    final clampedWeight = weight.clamp(0.5, 2.0);
    final layers = (log(clampedWeight) / log(1.05)).round();
    return layers;
  }

  /// 将权重应用到内容
  static String applyWeight(String content, double weight) {
    if (content.isEmpty) return content;
    if (weight == 1.0) return content;

    final layers = calculateWeightLayers(weight);
    if (layers == 0) return content;

    if (layers > 0) {
      final braces = '{' * layers;
      final closeBraces = '}' * layers;
      return '$braces$content$closeBraces';
    } else {
      final brackets = '[' * (-layers);
      final closeBrackets = ']' * (-layers);
      return '$brackets$content$closeBrackets';
    }
  }

  /// 更新条目
  TagLibraryEntry update({
    String? name,
    String? content,
    String? thumbnail,
    List<String>? tags,
    String? categoryId,
    int? sortOrder,
    bool? isFavorite,
  }) {
    return copyWith(
      name: name?.trim() ?? this.name,
      content: content?.trim() ?? this.content,
      thumbnail: thumbnail ?? this.thumbnail,
      tags: tags ?? this.tags,
      categoryId: categoryId ?? this.categoryId,
      sortOrder: sortOrder ?? this.sortOrder,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: DateTime.now(),
    );
  }

  /// 记录使用
  TagLibraryEntry recordUsage() {
    return copyWith(
      useCount: useCount + 1,
      lastUsedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 切换收藏状态
  TagLibraryEntry toggleFavorite() {
    return copyWith(
      isFavorite: !isFavorite,
      updatedAt: DateTime.now(),
    );
  }

  /// 添加标签
  TagLibraryEntry addTag(String tag) {
    if (tags.contains(tag)) return this;
    return copyWith(
      tags: [...tags, tag],
      updatedAt: DateTime.now(),
    );
  }

  /// 移除标签
  TagLibraryEntry removeTag(String tag) {
    return copyWith(
      tags: tags.where((t) => t != tag).toList(),
      updatedAt: DateTime.now(),
    );
  }
}

/// 词库条目列表扩展
extension TagLibraryEntryListExtension on List<TagLibraryEntry> {
  /// 获取收藏的条目
  List<TagLibraryEntry> get favorites => where((e) => e.isFavorite).toList();

  /// 获取指定分类的条目
  List<TagLibraryEntry> getByCategory(String? categoryId) =>
      where((e) => e.categoryId == categoryId).toList();

  /// 按排序顺序排列
  List<TagLibraryEntry> sortedByOrder() {
    final sorted = [...this];
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// 按更新时间排序（最新的在前）
  List<TagLibraryEntry> sortedByUpdatedAt() {
    final sorted = [...this];
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// 按使用次数排序（最多的在前）
  List<TagLibraryEntry> sortedByUseCount() {
    final sorted = [...this];
    sorted.sort((a, b) => b.useCount.compareTo(a.useCount));
    return sorted;
  }

  /// 按名称排序
  List<TagLibraryEntry> sortedByName() {
    final sorted = [...this];
    sorted.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return sorted;
  }

  /// 更新排序顺序
  List<TagLibraryEntry> reindex() {
    return asMap()
        .entries
        .map(
          (e) => e.value.copyWith(
            sortOrder: e.key,
            updatedAt: DateTime.now(),
          ),
        )
        .toList();
  }

  /// 搜索
  List<TagLibraryEntry> search(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where(
      (e) =>
          e.name.toLowerCase().contains(lowerQuery) ||
          e.content.toLowerCase().contains(lowerQuery) ||
          e.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
    ).toList();
  }

  /// 按标签筛选
  List<TagLibraryEntry> filterByTag(String tag) {
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
}
