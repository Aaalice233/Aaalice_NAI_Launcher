import 'package:freezed_annotation/freezed_annotation.dart';

/// Danbooru 官方标签类别
///
/// 对应 Danbooru API 的 category 字段
enum DanbooruTagCategory {
  /// 通用标签（描述画面内容）- category=0
  @JsonValue(0)
  general,

  /// 画师/创作者名称 - category=1
  @JsonValue(1)
  artist,

  /// 作品/版权/系列 - category=3
  @JsonValue(3)
  copyright,

  /// 角色名称 - category=4
  @JsonValue(4)
  character,

  /// 元数据（图片属性）- category=5
  @JsonValue(5)
  meta,
}

/// 语义子分类（用于 General 类别的细分）
///
/// NovelAI 对 Danbooru 的 General 类别进行了语义子分类
/// 参考: docs/NAI随机提示词功能分析.md
enum TagSubCategory {
  /// 发色 - *_hair 且颜色相关
  hairColor,

  /// 瞳色 - *_eyes
  eyeColor,

  /// 发型 - *_hair 且非颜色
  hairStyle,

  /// 服装 - *_dress, *_shirt, *_skirt 等（总类，向后兼容）
  clothing,

  /// 女性服装 - 女性专属服装标签
  clothingFemale,

  /// 男性服装 - 男性专属服装标签
  clothingMale,

  /// 通用服装 - 无性别区分的服装标签
  clothingGeneral,

  /// 表情 - smile, blush, open_mouth 等
  expression,

  /// 姿势 - sitting, standing, looking_at_viewer 等
  pose,

  /// 背景 - *_background
  background,

  /// 场景 - scenery, outdoors, indoors 等
  scene,

  /// 风格 - photorealistic, abstract 等
  style,

  /// 身体特征 - abs, breasts 等（总类，向后兼容）
  bodyFeature,

  /// 女性体型 - 女性专属身体特征标签
  bodyFeatureFemale,

  /// 男性体型 - 男性专属身体特征标签
  bodyFeatureMale,

  /// 通用体型 - 无性别区分的身体特征标签
  bodyFeatureGeneral,

  /// 配饰 - hat, glasses, jewelry 等
  accessory,

  /// 人数 - solo, 1girl, 1boy, 2girls, multiple girls 等
  /// 注意: duo 和 trio 是 Danbooru 已废弃的标签
  characterCount,

  /// 其他
  other,
}

/// 标签子分类工具类
///
/// 注意：预定义标签列表已迁移到 assets/data/nai_official_tags.json
/// 使用 NaiTagsDataSource 加载
class TagSubCategoryHelper {
  /// 发色关键词（用于 classifyTag 方法判断）
  ///
  /// 这些关键词用于判断 *_hair 标签是发色还是发型
  static const hairColorKeywords = [
    'blonde',
    'blue',
    'black',
    'brown',
    'red',
    'white',
    'pink',
    'green',
    'purple',
    'silver',
    'grey',
    'gray',
    'orange',
    'multicolored',
    'gradient',
    'two-tone',
    'streaked',
    'aqua',
    'platinum',
    'strawberry',
    'light',
    'dark',
  ];

  /// 人数标签模式（用于 classifyTag 方法判断）
  ///
  /// 注意: "duo" 和 "trio" 是 Danbooru 已废弃的标签，不应使用
  /// 参考: https://danbooru.donmai.us/wiki_pages/duo
  /// 使用具体的角色组合标签如 2girls, 1girl 1boy 等
  static const _characterCountPatterns = [
    'solo',
    'group',
    'couple',
    'crowd',
    'no_humans',
    'multiple_girls',
    'multiple_boys',
    '2girls',
    '2boys',
    '3girls',
    '3boys',
  ];

  /// 判断标签的子分类
  ///
  /// 使用模式匹配规则判断标签属于哪个子分类
  /// 对于无法通过模式判断的标签返回 [TagSubCategory.other]
  static TagSubCategory classifyTag(String tagName) {
    final normalized = tagName.toLowerCase().replaceAll(' ', '_');

    // 发色/发型（*_hair）
    if (normalized.endsWith('_hair')) {
      for (final keyword in hairColorKeywords) {
        if (normalized.contains(keyword)) {
          return TagSubCategory.hairColor;
        }
      }
      return TagSubCategory.hairStyle;
    }

    // 瞳色（*_eyes）
    if (normalized.endsWith('_eyes')) {
      return TagSubCategory.eyeColor;
    }

    // 背景（*_background）
    if (normalized.endsWith('_background')) {
      return TagSubCategory.background;
    }

    // 服装（各种服装后缀）
    if (normalized.endsWith('_dress') ||
        normalized.endsWith('_shirt') ||
        normalized.endsWith('_skirt') ||
        normalized.endsWith('_pants') ||
        normalized.endsWith('_shoes') ||
        normalized.endsWith('_boots') ||
        normalized.endsWith('_socks') ||
        normalized.endsWith('_stockings') ||
        normalized.endsWith('_gloves') ||
        normalized.endsWith('_coat') ||
        normalized.endsWith('_jacket') ||
        normalized.endsWith('_sweater') ||
        normalized.endsWith('_uniform') ||
        normalized.endsWith('_swimsuit') ||
        normalized.endsWith('_bikini') ||
        normalized.endsWith('_lingerie') ||
        normalized.endsWith('_underwear') ||
        normalized.endsWith('_bra') ||
        normalized.endsWith('_panties')) {
      return TagSubCategory.clothing;
    }

    // 配饰（各种配饰后缀）
    if (normalized.endsWith('_hat') ||
        normalized.endsWith('_glasses') ||
        normalized.endsWith('_earrings') ||
        normalized.endsWith('_necklace') ||
        normalized.endsWith('_bracelet') ||
        normalized.endsWith('_ring') ||
        normalized.endsWith('_ribbon') ||
        normalized.endsWith('_bow') ||
        normalized.endsWith('_hairpin') ||
        normalized.endsWith('_headband') ||
        normalized.endsWith('_crown') ||
        normalized.endsWith('_tiara') ||
        normalized.endsWith('_mask') ||
        normalized.endsWith('_wings') ||
        normalized.endsWith('_tail') ||
        normalized.endsWith('_horns') ||
        normalized.endsWith('_ears')) {
      return TagSubCategory.accessory;
    }

    // 人数标签
    // 匹配 Ngirl(s), Nboy(s), N+girl(s), N+boy(s) 等模式
    if (RegExp(r'^\d+\+?(girl|boy)s?$').hasMatch(normalized)) {
      return TagSubCategory.characterCount;
    }
    for (final pattern in _characterCountPatterns) {
      if (normalized == pattern) {
        return TagSubCategory.characterCount;
      }
    }

    // 无法通过模式匹配判断的标签
    return TagSubCategory.other;
  }

  /// 获取子分类的显示名称
  static String getDisplayName(TagSubCategory category, {String locale = 'zh'}) {
    if (locale == 'zh') {
      return switch (category) {
        TagSubCategory.hairColor => '发色',
        TagSubCategory.eyeColor => '瞳色',
        TagSubCategory.hairStyle => '发型',
        TagSubCategory.clothing => '服装',
        TagSubCategory.clothingFemale => '女性服装',
        TagSubCategory.clothingMale => '男性服装',
        TagSubCategory.clothingGeneral => '通用服装',
        TagSubCategory.expression => '表情',
        TagSubCategory.pose => '姿势',
        TagSubCategory.background => '背景',
        TagSubCategory.scene => '场景',
        TagSubCategory.style => '风格',
        TagSubCategory.bodyFeature => '身体特征',
        TagSubCategory.bodyFeatureFemale => '女性体型',
        TagSubCategory.bodyFeatureMale => '男性体型',
        TagSubCategory.bodyFeatureGeneral => '通用体型',
        TagSubCategory.accessory => '配饰',
        TagSubCategory.characterCount => '人数',
        TagSubCategory.other => '其他',
      };
    }
    return switch (category) {
      TagSubCategory.hairColor => 'Hair Color',
      TagSubCategory.eyeColor => 'Eye Color',
      TagSubCategory.hairStyle => 'Hair Style',
      TagSubCategory.clothing => 'Clothing',
      TagSubCategory.clothingFemale => 'Female Clothing',
      TagSubCategory.clothingMale => 'Male Clothing',
      TagSubCategory.clothingGeneral => 'General Clothing',
      TagSubCategory.expression => 'Expression',
      TagSubCategory.pose => 'Pose',
      TagSubCategory.background => 'Background',
      TagSubCategory.scene => 'Scene',
      TagSubCategory.style => 'Style',
      TagSubCategory.bodyFeature => 'Body Feature',
      TagSubCategory.bodyFeatureFemale => 'Female Body',
      TagSubCategory.bodyFeatureMale => 'Male Body',
      TagSubCategory.bodyFeatureGeneral => 'General Body',
      TagSubCategory.accessory => 'Accessory',
      TagSubCategory.characterCount => 'Character Count',
      TagSubCategory.other => 'Other',
    };
  }
}
