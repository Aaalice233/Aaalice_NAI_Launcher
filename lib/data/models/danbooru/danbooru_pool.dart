import 'package:freezed_annotation/freezed_annotation.dart';

part 'danbooru_pool.freezed.dart';
part 'danbooru_pool.g.dart';

/// Pool 类型
enum PoolCategory {
  /// 系列（有序）
  @JsonValue('series')
  series,

  /// 收藏（无序）
  @JsonValue('collection')
  collection,
}

/// Danbooru Pool（图池）模型
///
/// Pool 是 Danbooru 上的帖子集合，可用于从中提取高频标签
@freezed
class DanbooruPool with _$DanbooruPool {
  const DanbooruPool._();

  const factory DanbooruPool({
    /// Pool ID
    required int id,

    /// Pool 名称（下划线格式）
    required String name,

    /// 描述
    @Default('') String description,

    /// 帖子数量
    @JsonKey(name: 'post_count') @Default(0) int postCount,

    /// 帖子 ID 列表（可能不完整，仅用于预览）
    @JsonKey(name: 'post_ids') @Default([]) List<int> postIds,

    /// 是否激活
    @JsonKey(name: 'is_active') @Default(true) bool isActive,

    /// Pool 类型
    @Default(PoolCategory.collection) PoolCategory category,

    /// 创建时间
    @JsonKey(name: 'created_at') DateTime? createdAt,

    /// 更新时间
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _DanbooruPool;

  factory DanbooruPool.fromJson(Map<String, dynamic> json) =>
      _$DanbooruPoolFromJson(json);

  /// 显示名称（空格格式）
  String get displayName => name.replaceAll('_', ' ');

  /// 是否有效（有帖子）
  bool get isValid => postCount > 0;

  /// 获取 Pool 类型的显示名称
  String get categoryDisplayName => switch (category) {
        PoolCategory.series => 'Series',
        PoolCategory.collection => 'Collection',
      };
}
