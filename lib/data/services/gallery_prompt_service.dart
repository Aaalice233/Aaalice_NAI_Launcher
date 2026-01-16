import '../../data/models/online_gallery/danbooru_post.dart';

/// 元标签列表（用于过滤）
/// 这些标签通常是图片质量描述或来源信息，不应作为实际生成提示词
const _metaTags = {
  'highres',
  'high_resolution',
  'masterpiece',
  'best_quality',
  'official_art',
  'official_cg',
  'anime_screenshot',
  'beautiful_detailed_background',
  'detailed_background',
};

/// 画廊提示词转换服务
///
/// 提供 Danbooru 标签与 NAI 提示词格式之间的转换功能
class GalleryPromptService {
  /// 转换为 NAI 格式（逗号分隔）
  ///
  /// 会自动移除元标签，只保留实际描述标签
  String toNaiFormat(List<String> tags) {
    final filtered = stripMetaTags(tags);
    return filtered.join(', ');
  }

  /// 移除元标签
  ///
  /// 保留通用标签、角色标签、作品标签等实际描述性标签
  List<String> stripMetaTags(List<String> tags) {
    return tags
        .where((tag) => !_metaTags.contains(tag.toLowerCase()))
        .toList();
  }

  /// 获取原始标签字符串（逗号分隔）
  ///
  /// 从 DanbooruPost 获取标签并转换为 NAI 格式
  String toRawTags(DanbooruPost post) {
    return toNaiFormat(post.tags);
  }

  /// 获取所有标签列表
  List<String> getAllTags(DanbooruPost post) {
    return post.tags;
  }
}
