import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag_suggestion.freezed.dart';
part 'tag_suggestion.g.dart';

/// 标签分类枚举
enum TagCategory {
  /// 通用标签
  general(0),
  /// 角色标签
  character(1),
  /// 版权标签
  copyright(3),
  /// 艺术家标签
  artist(4),
  /// 元数据标签
  meta(5);

  final int value;
  const TagCategory(this.value);

  static TagCategory fromValue(int value) {
    return TagCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TagCategory.general,
    );
  }

  String get displayName {
    switch (this) {
      case TagCategory.general:
        return '通用';
      case TagCategory.character:
        return '角色';
      case TagCategory.copyright:
        return '版权';
      case TagCategory.artist:
        return '艺术家';
      case TagCategory.meta:
        return '元数据';
    }
  }
}

/// 标签建议模型
@freezed
class TagSuggestion with _$TagSuggestion {
  const factory TagSuggestion({
    /// 标签名称
    required String tag,

    /// 使用频率/计数
    @Default(0) int count,

    /// 标签分类 (0=通用, 1=角色, 3=版权, 4=艺术家)
    @Default(0) int category,

    /// 标签别名（如果有）
    String? alias,
  }) = _TagSuggestion;

  factory TagSuggestion.fromJson(Map<String, dynamic> json) =>
      _$TagSuggestionFromJson(json);
}

/// TagSuggestion 扩展方法
extension TagSuggestionExtension on TagSuggestion {
  /// 获取分类枚举
  TagCategory get categoryEnum => TagCategory.fromValue(category);

  /// 格式化显示的计数
  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  /// 获取显示名称（优先使用别名）
  String get displayTag => alias ?? tag;
}

/// 标签建议响应模型
@freezed
class TagSuggestionResponse with _$TagSuggestionResponse {
  const factory TagSuggestionResponse({
    @Default([]) List<TagSuggestion> tags,
  }) = _TagSuggestionResponse;

  factory TagSuggestionResponse.fromJson(Map<String, dynamic> json) =>
      _$TagSuggestionResponseFromJson(json);
}
