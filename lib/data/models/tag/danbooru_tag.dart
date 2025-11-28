import 'package:freezed_annotation/freezed_annotation.dart';
import 'tag_suggestion.dart';

part 'danbooru_tag.freezed.dart';
part 'danbooru_tag.g.dart';

/// Danbooru 标签分类
/// Danbooru API 返回的分类值：
/// - 0 = general (通用)
/// - 1 = artist (艺术家)
/// - 3 = copyright (版权)
/// - 4 = character (角色)
/// - 5 = meta (元数据)
enum DanbooruCategory {
  general(0),
  artist(1),
  copyright(3),
  character(4),
  meta(5);

  final int value;
  const DanbooruCategory(this.value);

  static DanbooruCategory fromValue(int value) {
    return DanbooruCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DanbooruCategory.general,
    );
  }

  /// 转换为应用内的 TagCategory 值
  /// 应用内分类映射：0=general, 1=character, 3=copyright, 4=artist
  int toAppCategoryValue() {
    switch (this) {
      case DanbooruCategory.general:
        return 0;
      case DanbooruCategory.artist:
        return 4; // 应用内 artist = 4
      case DanbooruCategory.copyright:
        return 3;
      case DanbooruCategory.character:
        return 1; // 应用内 character = 1
      case DanbooruCategory.meta:
        return 5;
    }
  }
}

/// Danbooru API 返回的标签数据模型
/// API 端点: GET https://danbooru.donmai.us/tags/autocomplete.json
@freezed
class DanbooruTag with _$DanbooruTag {
  const DanbooruTag._();

  const factory DanbooruTag({
    /// 标签 ID
    required int id,

    /// 标签名称 (如 "blue_eyes", "1girl")
    required String name,

    /// 使用该标签的帖子数量
    @JsonKey(name: 'post_count') @Default(0) int postCount,

    /// 标签分类 (0=general, 1=artist, 3=copyright, 4=character, 5=meta)
    @Default(0) int category,

    /// 标签别名 (某些标签有别名)
    @JsonKey(name: 'antecedent_name') String? antecedentName,
  }) = _DanbooruTag;

  factory DanbooruTag.fromJson(Map<String, dynamic> json) =>
      _$DanbooruTagFromJson(json);

  /// 转换为应用内的 TagSuggestion 模型
  TagSuggestion toTagSuggestion() {
    final danbooruCategory = DanbooruCategory.fromValue(category);
    return TagSuggestion(
      tag: name,
      count: postCount,
      category: danbooruCategory.toAppCategoryValue(),
      alias: antecedentName,
    );
  }
}

/// Danbooru 标签列表扩展
extension DanbooruTagListExtension on List<DanbooruTag> {
  /// 批量转换为 TagSuggestion 列表
  List<TagSuggestion> toTagSuggestions() {
    return map((tag) => tag.toTagSuggestion()).toList();
  }
}
