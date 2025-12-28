import 'random_category.dart';
import 'random_tag_group.dart';
import 'tag_category.dart';

/// 默认类别 Emoji 映射
///
/// 提供内置类别和词组的默认 emoji 图标
class DefaultCategoryEmojis {
  DefaultCategoryEmojis._();

  /// 内置类别的默认 emoji（按 key 映射）
  static const Map<String, String> categoryEmojis = {
    'hairColor': '🎨', // 发色
    'eyeColor': '👁️', // 瞳色
    'hairStyle': '✂️', // 发型
    'expression': '😊', // 表情
    'pose': '🧘', // 姿势
    'clothing': '👗', // 服装
    'clothingFemale': '👗', // 女性服装
    'clothingMale': '👔', // 男性服装
    'clothingGeneral': '🎽', // 通用服装
    'accessory': '💍', // 配饰
    'bodyFeature': '💃', // 身体特征
    'bodyFeatureFemale': '👙', // 女性体型
    'bodyFeatureMale': '💪', // 男性体型
    'bodyFeatureGeneral': '🧍', // 通用体型
    'background': '🌄', // 背景
    'scene': '🏞️', // 场景
    'style': '🎭', // 风格
    'characterCount': '👥', // 人数
    'other': '🏷️', // 其他
  };

  /// 词组来源类型的默认 emoji
  static const Map<TagGroupSourceType, String> sourceTypeEmojis = {
    TagGroupSourceType.custom: '✨', // 自定义
    TagGroupSourceType.tagGroup: '☁️', // Tag Group
    TagGroupSourceType.pool: '🖼️', // Pool
  };

  /// 默认回退 emoji
  static const String fallbackEmoji = '🏷️';

  /// 获取 RandomCategory 的 emoji
  ///
  /// 优先使用用户设置的 emoji，否则根据 key 返回默认值
  static String getCategoryEmoji(RandomCategory category) {
    if (category.emoji.isNotEmpty) {
      return category.emoji;
    }
    return categoryEmojis[category.key] ?? fallbackEmoji;
  }

  /// 获取 TagSubCategory 的 emoji
  ///
  /// 用于内置类别显示
  static String getTagSubCategoryEmoji(TagSubCategory category) {
    return categoryEmojis[category.name] ?? fallbackEmoji;
  }

  /// 获取 RandomTagGroup 的 emoji
  ///
  /// 优先使用用户设置的 emoji，否则根据来源类型返回默认值
  static String getGroupEmoji(RandomTagGroup group) {
    if (group.emoji.isNotEmpty) {
      return group.emoji;
    }
    return sourceTypeEmojis[group.sourceType] ?? '✨';
  }

  /// 获取词组来源类型的默认 emoji
  static String getSourceTypeEmoji(TagGroupSourceType sourceType) {
    return sourceTypeEmojis[sourceType] ?? '✨';
  }
}
