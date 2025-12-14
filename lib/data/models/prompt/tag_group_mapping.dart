import 'package:freezed_annotation/freezed_annotation.dart';

import 'tag_category.dart';

part 'tag_group_mapping.freezed.dart';
part 'tag_group_mapping.g.dart';

/// Tag Group 到 TagSubCategory 的映射
///
/// 定义如何将 Danbooru 的 tag_group 映射到应用内部的语义子分类
@freezed
class TagGroupMapping with _$TagGroupMapping {
  const TagGroupMapping._();

  const factory TagGroupMapping({
    /// 唯一标识符
    required String id,

    /// tag_group 标题 (如 "tag_group:hair_color")
    required String groupTitle,

    /// 显示名称 (如 "Hair Color")
    required String displayName,

    /// 目标 NAI 分类
    required TagSubCategory targetCategory,

    /// 是否启用
    @Default(true) bool enabled,

    /// 创建时间
    required DateTime createdAt,

    /// 上次同步时间
    DateTime? lastSyncedAt,

    /// 上次同步的标签数量（筛选后）
    @Default(0) int lastSyncedTagCount,

    /// Danbooru 原始标签数量（筛选前）
    @Default(0) int danbooruOriginalTagCount,

    /// 是否包含子分组的标签
    @Default(true) bool includeChildren,

    /// 自定义最小热度阈值（null 使用全局配置）
    int? customMinPostCount,

    /// wiki_page ID（用于快速访问）
    int? wikiPageId,
  }) = _TagGroupMapping;

  factory TagGroupMapping.fromJson(Map<String, dynamic> json) =>
      _$TagGroupMappingFromJson(json);

  /// 获取有效的最小热度阈值
  /// 如果有自定义值则使用自定义值，否则返回 null 表示使用全局配置
  int? get effectiveMinPostCount => customMinPostCount;

  /// 目标分类的显示名称
  String get targetCategoryDisplayName =>
      TagSubCategoryHelper.getDisplayName(targetCategory);

  /// 是否有自定义热度阈值
  bool get hasCustomMinPostCount => customMinPostCount != null;

  /// 格式化的同步信息
  String get syncInfo {
    if (lastSyncedAt == null) {
      return '从未同步';
    }
    if (danbooruOriginalTagCount > 0) {
      return '$lastSyncedTagCount / $danbooruOriginalTagCount 标签';
    }
    return '$lastSyncedTagCount 个标签';
  }

  /// 创建简单映射（用于快速创建）
  static TagGroupMapping simple({
    required String groupTitle,
    required TagSubCategory targetCategory,
    bool includeChildren = true,
  }) {
    return TagGroupMapping(
      id: 'mapping_${DateTime.now().millisecondsSinceEpoch}',
      groupTitle: groupTitle,
      displayName: _extractDisplayName(groupTitle),
      targetCategory: targetCategory,
      createdAt: DateTime.now(),
      includeChildren: includeChildren,
    );
  }

  /// 从 groupTitle 提取显示名称
  static String _extractDisplayName(String groupTitle) {
    // 移除 "tag_group:" 前缀
    var name = groupTitle;
    if (name.startsWith('tag_group:')) {
      name = name.substring('tag_group:'.length);
    }

    // 将下划线替换为空格，并将首字母大写
    return name
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }
}
