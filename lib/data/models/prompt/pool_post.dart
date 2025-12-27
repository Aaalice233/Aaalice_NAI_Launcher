import 'package:freezed_annotation/freezed_annotation.dart';

import 'pool_output_config.dart';

part 'pool_post.freezed.dart';
part 'pool_post.g.dart';

/// Pool 帖子
///
/// 表示 Danbooru Pool 中的单个帖子，包含分类标签
@freezed
class PoolPost with _$PoolPost {
  const PoolPost._();

  const factory PoolPost({
    /// 帖子 ID
    required int postId,

    /// 通用标签（场景、姿势、表情等）
    @Default([]) List<String> generalTags,

    /// 角色标签
    @Default([]) List<String> characterTags,

    /// 版权标签（作品/系列）
    @Default([]) List<String> copyrightTags,

    /// 艺术家标签
    @Default([]) List<String> artistTags,

    /// 元标签（图片格式等，一般不使用）
    @Default([]) List<String> metaTags,
  }) = _PoolPost;

  factory PoolPost.fromJson(Map<String, dynamic> json) =>
      _$PoolPostFromJson(json);

  /// 从 Danbooru API 响应创建
  factory PoolPost.fromDanbooruPost(Map<String, dynamic> postData) {
    return PoolPost(
      postId: postData['id'] as int,
      generalTags: _parseTags(postData['tag_string_general']),
      characterTags: _parseTags(postData['tag_string_character']),
      copyrightTags: _parseTags(postData['tag_string_copyright']),
      artistTags: _parseTags(postData['tag_string_artist']),
      metaTags: _parseTags(postData['tag_string_meta']),
    );
  }

  /// 解析空格分隔的标签字符串
  static List<String> _parseTags(dynamic tagString) {
    if (tagString == null || tagString is! String || tagString.isEmpty) {
      return [];
    }
    return tagString.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// 根据配置获取要输出的标签
  List<String> getTagsForOutput(PoolOutputConfig config) {
    final result = <String>[];

    if (config.includeGeneral) {
      result.addAll(generalTags);
    }
    if (config.includeCharacter) {
      result.addAll(characterTags);
    }
    if (config.includeCopyright) {
      result.addAll(copyrightTags);
    }
    if (config.includeArtist) {
      result.addAll(artistTags);
    }

    // 应用最大数量限制（使用 effectiveMaxTagCount 确保有效性）
    final maxCount = config.effectiveMaxTagCount;
    if (maxCount > 0 && result.length > maxCount) {
      return result.take(maxCount).toList();
    }

    return result;
  }

  /// 获取所有标签数量
  int get totalTagCount =>
      generalTags.length +
      characterTags.length +
      copyrightTags.length +
      artistTags.length +
      metaTags.length;
}
