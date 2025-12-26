import 'tag_category.dart';
import 'tag_group_mapping.dart';
import 'tag_group_sync_config.dart';

/// 默认 Tag Group 映射配置
///
/// 预设了常用的 Danbooru tag_group 到 NAI TagSubCategory 的映射
class DefaultTagGroupMappings {
  /// 默认映射列表
  ///
  /// 基于 Danbooru 的 tag_groups wiki 页面结构
  /// 参考: https://danbooru.donmai.us/wiki_pages/tag_groups
  static List<TagGroupMapping> get mappings => [
        // 发色
        TagGroupMapping(
          id: 'default_hair_color',
          groupTitle: 'tag_group:hair_color',
          displayName: 'Hair Color',
          targetCategory: TagSubCategory.hairColor,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: false,
        ),

        // 发型
        TagGroupMapping(
          id: 'default_hair_styles',
          groupTitle: 'tag_group:hair_styles',
          displayName: 'Hair Styles',
          targetCategory: TagSubCategory.hairStyle,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: true,
        ),

        // 眼睛/瞳色
        TagGroupMapping(
          id: 'default_eyes',
          groupTitle: 'tag_group:eyes',
          displayName: 'Eyes',
          targetCategory: TagSubCategory.eyeColor,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: false,
        ),

        // 服装
        TagGroupMapping(
          id: 'default_attire',
          groupTitle: 'tag_group:attire',
          displayName: 'Attire',
          targetCategory: TagSubCategory.clothing,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: true,
        ),

        // 配饰
        TagGroupMapping(
          id: 'default_accessories',
          groupTitle: 'tag_group:accessories',
          displayName: 'Accessories',
          targetCategory: TagSubCategory.accessory,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: true,
        ),

        // 表情 (从 face 分组获取)
        TagGroupMapping(
          id: 'default_face',
          groupTitle: 'tag_group:face_tags',
          displayName: 'Face Tags',
          targetCategory: TagSubCategory.expression,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: false, // 只取直接标签，避免和眼睛分类重复
        ),

        // 姿势
        TagGroupMapping(
          id: 'default_posture',
          groupTitle: 'tag_group:posture',
          displayName: 'Posture',
          targetCategory: TagSubCategory.pose,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: true,
        ),

        // 背景
        TagGroupMapping(
          id: 'default_backgrounds',
          groupTitle: 'tag_group:backgrounds',
          displayName: 'Backgrounds',
          targetCategory: TagSubCategory.background,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: true,
        ),

        // 场景
        TagGroupMapping(
          id: 'default_image_composition',
          groupTitle: 'tag_group:image_composition',
          displayName: 'Image Composition',
          targetCategory: TagSubCategory.scene,
          createdAt: DateTime(2024, 1, 1),
          includeChildren: false,
        ),
      ];

  /// 创建默认映射列表的深拷贝
  ///
  /// 用于初始化预设时使用，确保每个预设有独立的映射副本
  /// 注意：默认禁用所有 Danbooru 映射，只启用内置词组
  static List<TagGroupMapping> createDefaultMappings() {
    return mappings.map((m) => m.copyWith(
      id: 'mapping_${DateTime.now().millisecondsSinceEpoch}_${m.targetCategory.name}',
      createdAt: DateTime.now(),
      enabled: false, // 默认禁用 Danbooru 映射，只启用内置词组
    ),).toList();
  }

  /// 获取默认配置
  static TagGroupSyncConfig getDefaultConfig() {
    return TagGroupSyncConfig(
      enabled: true,
      mappings: mappings,
      minPostCount: 1000,
      maxTagsPerGroup: 200,
      syncIntervalDays: 7,
      includeChildGroups: true,
    );
  }

  /// 根据目标分类查找默认映射
  static TagGroupMapping? findByTargetCategory(TagSubCategory category) {
    try {
      return mappings.firstWhere((m) => m.targetCategory == category);
    } catch (_) {
      return null;
    }
  }

  /// 获取所有可用的 tag_group 标题（用于浏览器）
  ///
  /// 这是 Danbooru tag_groups 的顶级分类结构
  static const List<String> topLevelGroups = [
    'tag_group:visual_characteristics',
    'tag_group:copyrights',
    'tag_group:metatags',
  ];

  /// Visual characteristics 下的子分组
  static const List<String> visualCharacteristicsChildren = [
    'tag_group:image_composition',
    'tag_group:body',
    'tag_group:attire',
    'tag_group:sex_tags',
    'tag_group:objects',
    'tag_group:creatures',
    'tag_group:plants',
    'tag_group:games',
    'tag_group:real_world',
  ];

  /// Body 下的子分组
  static const List<String> bodyChildren = [
    'tag_group:hair_color',
    'tag_group:hair_styles',
    'tag_group:eyes',
    'tag_group:face_tags',
    'tag_group:body_parts',
  ];

  /// Attire 下的子分组
  static const List<String> attireChildren = [
    'tag_group:clothing',
    'tag_group:accessories',
    'tag_group:footwear',
    'tag_group:headwear',
  ];
}
