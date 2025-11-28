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
    @JsonKey(name: 'tag_string_character') @Default('') String tagStringCharacter,
    @JsonKey(name: 'tag_string_copyright') @Default('') String tagStringCopyright,
    @JsonKey(name: 'tag_string_artist') @Default('') String tagStringArtist,
    @JsonKey(name: 'tag_string_meta') @Default('') String tagStringMeta,
    @JsonKey(name: 'fav_count') @Default(0) int favCount,
    @JsonKey(name: 'has_large') @Default(false) bool hasLarge,
  }) = _DanbooruPost;

  factory DanbooruPost.fromJson(Map<String, dynamic> json) =>
      _$DanbooruPostFromJson(json);

  /// 获取预览图 URL
  String get previewUrl {
    if (previewFileUrl != null && previewFileUrl!.isNotEmpty) {
      return previewFileUrl!;
    }
    // Danbooru 预览图 URL 格式
    return 'https://cdn.donmai.us/preview/$md5.jpg';
  }

  /// 获取示例图 URL（较大尺寸）
  String? get sampleUrl {
    if (largeFileUrl != null && largeFileUrl!.isNotEmpty) {
      return largeFileUrl;
    }
    if (hasLarge) {
      return 'https://cdn.donmai.us/sample/$md5.jpg';
    }
    return fileUrl;
  }

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

  /// 获取帖子页面 URL
  String get postUrl => 'https://danbooru.donmai.us/posts/$id';
}
