import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'prompt_tag.dart';

part 'tag_favorite.freezed.dart';
part 'tag_favorite.g.dart';

/// 标签收藏数据模型
/// 用于保存用户常用的标签
@freezed
class TagFavorite with _$TagFavorite {
  const TagFavorite._();

  const factory TagFavorite({
    /// 唯一标识
    required String id,

    /// 收藏的标签
    required PromptTag tag,

    /// 创建时间
    required DateTime createdAt,

    /// 备注（可选）
    String? notes,
  }) = _TagFavorite;

  factory TagFavorite.fromJson(Map<String, dynamic> json) =>
      _$TagFavoriteFromJson(json);

  /// 创建新收藏
  factory TagFavorite.create({
    required PromptTag tag,
    String? notes,
  }) {
    return TagFavorite(
      id: const Uuid().v4(),
      tag: tag,
      createdAt: DateTime.now(),
      notes: notes,
    );
  }

  /// 显示名称（使用标签的显示名称）
  String get displayName => tag.displayName;

  /// 是否有备注
  bool get hasNotes => notes != null && notes!.isNotEmpty;
}
