import 'pool_mapping.dart';
import 'pool_sync_config.dart';
import 'tag_category.dart';

/// 默认 Pool 映射配置
///
/// 提供预配置的高帖子数量 Danbooru Pools，用于丰富词库
class DefaultPoolMappings {
  /// 默认 Pool 映射列表
  ///
  /// 基于 Danbooru 高帖子数量的 Pools 选择
  /// 数据来源: https://danbooru.donmai.us/pools
  /// 已验证的 Pool IDs (2024-12)
  static final List<PoolMapping> mappings = [
    // ============ 角色特征类 ============

    // 表情 - Beautiful Smile (ID: 3032) - 7083 posts
    // https://danbooru.donmai.us/pools/3032
    PoolMapping(
      id: 'default_expression',
      poolId: 3032,
      poolName: 'Beautiful_Smile',
      postCount: 7083,
      targetCategory: TagSubCategory.expression,
      createdAt: DateTime(2024, 1, 1),
    ),

    // 发型 - Beautiful Hair (ID: 782) - 6281 posts
    // https://danbooru.donmai.us/pools/782
    PoolMapping(
      id: 'default_hair_style',
      poolId: 782,
      poolName: 'Beautiful_Hair',
      postCount: 6281,
      targetCategory: TagSubCategory.hairStyle,
      createdAt: DateTime(2024, 1, 1),
    ),

    // 瞳色 - Beautiful Eyes (ID: 2032) - 3395 posts
    // https://danbooru.donmai.us/pools/2032
    PoolMapping(
      id: 'default_eye_color',
      poolId: 2032,
      poolName: 'Beautiful_Eyes',
      postCount: 3395,
      targetCategory: TagSubCategory.eyeColor,
      createdAt: DateTime(2024, 1, 1),
    ),

    // ============ 服装配饰类 ============

    // 服装 - Exquisite Clothes (ID: 4983) - 2559 posts
    // https://danbooru.donmai.us/pools/4983
    PoolMapping(
      id: 'default_clothing',
      poolId: 4983,
      poolName: 'Exquisite_Clothes',
      postCount: 2559,
      targetCategory: TagSubCategory.clothing,
      createdAt: DateTime(2024, 1, 1),
    ),

    // 配饰 - Uncommonly-Styled Legwear (ID: 1445) - 1233 posts
    // https://danbooru.donmai.us/pools/1445
    PoolMapping(
      id: 'default_accessory',
      poolId: 1445,
      poolName: 'Uncommonly-Styled_Legwear',
      postCount: 1233,
      targetCategory: TagSubCategory.accessory,
      createdAt: DateTime(2024, 1, 1),
    ),

    // ============ 姿势动作类 ============

    // 姿势 - Defeating the Purpose (ID: 4116) - 390 posts
    // https://danbooru.donmai.us/pools/4116
    PoolMapping(
      id: 'default_pose',
      poolId: 4116,
      poolName: 'Defeating_the_Purpose',
      postCount: 390,
      targetCategory: TagSubCategory.pose,
      createdAt: DateTime(2024, 1, 1),
    ),

    // ============ 场景背景类 ============

    // 场景 - Dressed for the Wrong Occasion (ID: 4449) - 124 posts
    // https://danbooru.donmai.us/pools/4449
    PoolMapping(
      id: 'default_scene',
      poolId: 4449,
      poolName: 'Dressed_for_the_(Wrong)_Occasion',
      postCount: 124,
      targetCategory: TagSubCategory.scene,
      createdAt: DateTime(2024, 1, 1),
    ),

    // 背景 - Princess Connect Background Cards (ID: 18653) - 102 posts
    // https://danbooru.donmai.us/pools/18653
    PoolMapping(
      id: 'default_background',
      poolId: 18653,
      poolName: 'Princess_Connect_Background_Cards',
      postCount: 102,
      targetCategory: TagSubCategory.background,
      createdAt: DateTime(2024, 1, 1),
    ),

    // ============ 风格类 ============

    // 风格 - Disgustingly Adorable (ID: 903) - 1876 posts
    // https://danbooru.donmai.us/pools/903
    PoolMapping(
      id: 'default_style',
      poolId: 903,
      poolName: 'Disgustingly_Adorable',
      postCount: 1876,
      targetCategory: TagSubCategory.style,
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  /// 获取默认的 Pool 同步配置
  ///
  /// 返回预配置的 PoolSyncConfig，包含默认映射
  /// 默认启用 Pool 同步
  static PoolSyncConfig getDefaultConfig() {
    return PoolSyncConfig(
      enabled: true,
      mappings: mappings,
      maxPostsPerPool: 100,
      minTagOccurrence: 3,
    );
  }

  /// 检查是否为默认 Pool 映射
  static bool isDefaultMapping(String mappingId) {
    return mappingId.startsWith('default_');
  }
}
