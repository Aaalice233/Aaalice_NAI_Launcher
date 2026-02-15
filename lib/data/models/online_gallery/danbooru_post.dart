import 'package:freezed_annotation/freezed_annotation.dart';

part 'danbooru_post.freezed.dart';
part 'danbooru_post.g.dart';

/// Danbooru 帖子模型
@freezed
class DanbooruPost with _$DanbooruPost {
  const DanbooruPost._();

  const factory DanbooruPost({
    required int id,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'uploader_id') int? uploaderId,
    @Default(0) int score,
    @Default('') String source,
    @Default('') String md5,
    @Default('g') String rating,
    @JsonKey(name: 'image_width') @Default(0) int width,
    @JsonKey(name: 'image_height') @Default(0) int height,
    @JsonKey(name: 'tag_string') @Default('') String tagString,
    @JsonKey(name: 'file_ext') @Default('jpg') String fileExt,
    @JsonKey(name: 'file_size') @Default(0) int fileSize,
    @JsonKey(name: 'file_url') String? fileUrl,
    @JsonKey(name: 'large_file_url') String? largeFileUrl,
    @JsonKey(name: 'preview_file_url') String? previewFileUrl,
    @JsonKey(name: 'tag_string_general') @Default('') String tagStringGeneral,
    @JsonKey(name: 'tag_string_character')
    @Default('')
    String tagStringCharacter,
    @JsonKey(name: 'tag_string_copyright')
    @Default('')
    String tagStringCopyright,
    @JsonKey(name: 'tag_string_artist') @Default('') String tagStringArtist,
    @JsonKey(name: 'tag_string_meta') @Default('') String tagStringMeta,
    @JsonKey(name: 'fav_count') @Default(0) int favCount,
    @JsonKey(name: 'has_large') @Default(false) bool hasLarge,
  }) = _DanbooruPost;

  factory DanbooruPost.fromJson(Map<String, dynamic> json) =>
      _$DanbooruPostFromJson(json);

  /// 获取预览图 URL
  String get previewUrl {
    // 优先使用 API 返回的预览图 URL
    if (previewFileUrl != null && previewFileUrl!.isNotEmpty) {
      return previewFileUrl!;
    }
    // 如果有 md5，构建 CDN URL
    if (md5.isNotEmpty) {
      return 'https://cdn.donmai.us/preview/$md5.jpg';
    }
    // 最后尝试使用原始文件 URL
    return fileUrl ?? '';
  }

  /// 获取示例图 URL（较大尺寸）
  String? get sampleUrl {
    // 优先使用 API 返回的大图 URL
    if (largeFileUrl != null && largeFileUrl!.isNotEmpty) {
      return largeFileUrl;
    }
    // 如果有大图且有 md5，构建 CDN URL
    if (hasLarge && md5.isNotEmpty) {
      return 'https://cdn.donmai.us/sample/$md5.jpg';
    }
    // 最后返回原始文件 URL
    return fileUrl;
  }

  /// 是否有有效的预览图
  bool get hasValidPreview => previewUrl.isNotEmpty;

  /// 获取所有标签列表
  List<String> get tags {
    if (tagString.isEmpty) return [];
    return tagString.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// 获取角色标签
  List<String> get characterTags {
    if (tagStringCharacter.isEmpty) return [];
    return tagStringCharacter.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// 获取作品标签
  List<String> get copyrightTags {
    if (tagStringCopyright.isEmpty) return [];
    return tagStringCopyright.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// 获取艺术家标签
  List<String> get artistTags {
    if (tagStringArtist.isEmpty) return [];
    return tagStringArtist.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// 获取通用标签
  List<String> get generalTags {
    if (tagStringGeneral.isEmpty) return [];
    return tagStringGeneral.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// 获取元标签
  List<String> get metaTags {
    if (tagStringMeta.isEmpty) return [];
    return tagStringMeta.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// 获取帖子页面 URL
  String get postUrl => 'https://danbooru.donmai.us/posts/$id';

  /// 是否为视频
  bool get isVideo =>
      const ['mp4', 'webm', 'zip'].contains(fileExt.toLowerCase());

  /// 是否为动图
  bool get isAnimated =>
      fileExt.toLowerCase() == 'gif' ||
      tagStringMeta.contains('animated') ||
      tagStringMeta.contains('video');

  /// 是否为静态图片
  bool get isImage => !isVideo && !isAnimated;

  /// 媒体类型标识
  String? get mediaTypeLabel {
    if (isVideo) return 'VIDEO';
    if (isAnimated) return 'GIF';
    return null;
  }
}
