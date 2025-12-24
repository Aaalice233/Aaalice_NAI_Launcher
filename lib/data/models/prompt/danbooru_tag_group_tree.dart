// Danbooru Tag Group 预定义树状结构
//
// 按 NAI 提示词类别（TagSubCategory）对 Danbooru tag_group 进行分类
// 这些 tag_group 都是经过 API 验证的有效 wiki 页面

import 'tag_category.dart';

/// 预定义的 tag_group 树节点
class TagGroupTreeNode {
  /// 节点标题（tag_group 标题或类别名）
  final String title;

  /// 显示名称（中文）
  final String displayNameZh;

  /// 显示名称（英文）
  final String displayNameEn;

  /// 对应的 TagSubCategory（仅顶级节点有）
  final TagSubCategory? category;

  /// 子节点（tag_group 标题列表）
  final List<TagGroupTreeNode> children;

  /// 是否为 tag_group（叶子节点）
  final bool isTagGroup;

  const TagGroupTreeNode({
    required this.title,
    required this.displayNameZh,
    required this.displayNameEn,
    this.category,
    this.children = const [],
    this.isTagGroup = false,
  });

  /// 是否有子节点
  bool get hasChildren => children.isNotEmpty;
}

/// 预定义的 tag_group 树
///
/// 按 NAI 提示词类别分组，便于用户快速选择
class DanbooruTagGroupTree {
  DanbooruTagGroupTree._();

  /// 获取完整的树结构
  static List<TagGroupTreeNode> get tree => _tree;

  /// 根据类别获取对应的 tag_group 列表
  static List<String> getGroupsForCategory(TagSubCategory category) {
    final node = _tree.firstWhere(
      (n) => n.category == category,
      orElse: () => const TagGroupTreeNode(
        title: '',
        displayNameZh: '',
        displayNameEn: '',
      ),
    );
    return _collectTagGroups(node);
  }

  /// 递归收集节点下的所有 tag_group
  static List<String> _collectTagGroups(TagGroupTreeNode node) {
    final groups = <String>[];
    if (node.isTagGroup) {
      groups.add(node.title);
    }
    for (final child in node.children) {
      groups.addAll(_collectTagGroups(child));
    }
    return groups;
  }

  /// 预定义树结构
  static const List<TagGroupTreeNode> _tree = [
    // ========== 发色 ==========
    TagGroupTreeNode(
      title: 'hairColor',
      displayNameZh: '发色',
      displayNameEn: 'Hair Color',
      category: TagSubCategory.hairColor,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:hair_color',
          displayNameZh: '发色',
          displayNameEn: 'Hair Color',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 瞳色 ==========
    TagGroupTreeNode(
      title: 'eyeColor',
      displayNameZh: '瞳色',
      displayNameEn: 'Eye Color',
      category: TagSubCategory.eyeColor,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:eyes_tags',
          displayNameZh: '眼睛',
          displayNameEn: 'Eyes',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 发型 ==========
    TagGroupTreeNode(
      title: 'hairStyle',
      displayNameZh: '发型',
      displayNameEn: 'Hair Style',
      category: TagSubCategory.hairStyle,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:hair',
          displayNameZh: '头发',
          displayNameEn: 'Hair',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:hair_styles',
          displayNameZh: '发型',
          displayNameEn: 'Hair Styles',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 服装 ==========
    TagGroupTreeNode(
      title: 'clothing',
      displayNameZh: '服装',
      displayNameEn: 'Clothing',
      category: TagSubCategory.clothing,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:attire',
          displayNameZh: '着装',
          displayNameEn: 'Attire',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:dress',
          displayNameZh: '裙装',
          displayNameEn: 'Dress',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:fashion_style',
          displayNameZh: '穿搭风格',
          displayNameEn: 'Fashion Style',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:sleeves',
          displayNameZh: '袖型',
          displayNameEn: 'Sleeves',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:legwear',
          displayNameZh: '袜饰',
          displayNameEn: 'Legwear',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:sexual_attire',
          displayNameZh: '情趣服饰',
          displayNameEn: 'Sexual Attire',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:bra',
          displayNameZh: '文胸',
          displayNameEn: 'Bra',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:panties',
          displayNameZh: '底裤',
          displayNameEn: 'Panties',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:nudity',
          displayNameZh: '裸身',
          displayNameEn: 'Nudity',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:covering',
          displayNameZh: '遮体',
          displayNameEn: 'Covering',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 表情 ==========
    TagGroupTreeNode(
      title: 'expression',
      displayNameZh: '表情',
      displayNameEn: 'Expression',
      category: TagSubCategory.expression,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:face_tags',
          displayNameZh: '神态表情',
          displayNameEn: 'Face Tags',
          isTagGroup: true,
        ),
        // tag_group:smileys 已被合并到 face_tags，不再单独列出
      ],
    ),

    // ========== 姿势 ==========
    TagGroupTreeNode(
      title: 'pose',
      displayNameZh: '姿势',
      displayNameEn: 'Pose',
      category: TagSubCategory.pose,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:posture',
          displayNameZh: '体态',
          displayNameEn: 'Posture',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:gestures',
          displayNameZh: '手势',
          displayNameEn: 'Gestures',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:hands',
          displayNameZh: '手部动作',
          displayNameEn: 'Hands',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:dances',
          displayNameZh: '舞姿',
          displayNameEn: 'Dances',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:sexual_positions',
          displayNameZh: '体位',
          displayNameEn: 'Sexual Positions',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 背景 ==========
    TagGroupTreeNode(
      title: 'background',
      displayNameZh: '背景',
      displayNameEn: 'Background',
      category: TagSubCategory.background,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:backgrounds',
          displayNameZh: '背景',
          displayNameEn: 'Backgrounds',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:colors',
          displayNameZh: '色彩',
          displayNameEn: 'Colors',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:patterns',
          displayNameZh: '纹样',
          displayNameEn: 'Patterns',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 场景 ==========
    TagGroupTreeNode(
      title: 'scene',
      displayNameZh: '场景',
      displayNameEn: 'Scene',
      category: TagSubCategory.scene,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:locations',
          displayNameZh: '场所',
          displayNameEn: 'Locations',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:real_world_locations',
          displayNameZh: '现实地标',
          displayNameEn: 'Real World Locations',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:doors_and_gates',
          displayNameZh: '门窗',
          displayNameEn: 'Doors and Gates',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:water',
          displayNameZh: '水景',
          displayNameEn: 'Water',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:fire',
          displayNameZh: '火焰',
          displayNameEn: 'Fire',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:flowers',
          displayNameZh: '花卉',
          displayNameEn: 'Flowers',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 风格 ==========
    TagGroupTreeNode(
      title: 'style',
      displayNameZh: '风格',
      displayNameEn: 'Style',
      category: TagSubCategory.style,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:image_composition',
          displayNameZh: '构图',
          displayNameEn: 'Image Composition',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:visual_aesthetic',
          displayNameZh: '画风',
          displayNameEn: 'Visual Aesthetic',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:lighting',
          displayNameZh: '光影',
          displayNameEn: 'Lighting',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:focus_tags',
          displayNameZh: '景深',
          displayNameEn: 'Focus Tags',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:artistic_license',
          displayNameZh: '艺术演绎',
          displayNameEn: 'Artistic License',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:fine_art_parody',
          displayNameZh: '名画致敬',
          displayNameEn: 'Fine Art Parody',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 身体特征 ==========
    TagGroupTreeNode(
      title: 'bodyFeature',
      displayNameZh: '身体特征',
      displayNameEn: 'Body Feature',
      category: TagSubCategory.bodyFeature,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:body_parts',
          displayNameZh: '身体部位',
          displayNameEn: 'Body Parts',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:skin_color',
          displayNameZh: '肤色',
          displayNameEn: 'Skin Color',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:breasts_tags',
          displayNameZh: '胸部',
          displayNameEn: 'Breasts',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:ass',
          displayNameZh: '臀部',
          displayNameEn: 'Ass',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:ears_tags',
          displayNameZh: '耳朵',
          displayNameEn: 'Ears',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:tail',
          displayNameZh: '尾巴',
          displayNameEn: 'Tail',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:wings',
          displayNameZh: '翅膀',
          displayNameEn: 'Wings',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:shoulders',
          displayNameZh: '肩部',
          displayNameEn: 'Shoulders',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:skin_folds',
          displayNameZh: '肌肤纹理',
          displayNameEn: 'Skin Folds',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 配饰 ==========
    TagGroupTreeNode(
      title: 'accessory',
      displayNameZh: '配饰',
      displayNameEn: 'Accessory',
      category: TagSubCategory.accessory,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:accessories',
          displayNameZh: '饰品',
          displayNameEn: 'Accessories',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:headwear',
          displayNameZh: '头饰',
          displayNameEn: 'Headwear',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:eyewear',
          displayNameZh: '眼饰',
          displayNameEn: 'Eyewear',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:glasses',
          displayNameZh: '眼镜',
          displayNameEn: 'Glasses',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:handwear',
          displayNameZh: '手饰',
          displayNameEn: 'Handwear',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:neck_and_neckwear',
          displayNameZh: '颈饰',
          displayNameEn: 'Neck and Neckwear',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:piercings',
          displayNameZh: '穿环',
          displayNameEn: 'Piercings',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:embellishment',
          displayNameZh: '点缀',
          displayNameEn: 'Embellishment',
          isTagGroup: true,
        ),
        // tag_group:mask 已在 Danbooru 上删除 (HTTP 410 Gone)，故移除
        TagGroupTreeNode(
          title: 'tag_group:makeup',
          displayNameZh: '妆容',
          displayNameEn: 'Makeup',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 人数 ==========
    TagGroupTreeNode(
      title: 'characterCount',
      displayNameZh: '人数',
      displayNameEn: 'Character Count',
      category: TagSubCategory.characterCount,
      children: [
        TagGroupTreeNode(
          title: 'tag_group:character_count',
          displayNameZh: '人数',
          displayNameEn: 'Character Count',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:groups',
          displayNameZh: '群像',
          displayNameEn: 'Groups',
          isTagGroup: true,
        ),
        TagGroupTreeNode(
          title: 'tag_group:family_relationships',
          displayNameZh: '亲缘关系',
          displayNameEn: 'Family Relationships',
          isTagGroup: true,
        ),
      ],
    ),

    // ========== 其他 ==========
    TagGroupTreeNode(
      title: 'other',
      displayNameZh: '其他',
      displayNameEn: 'Other',
      category: TagSubCategory.other,
      children: [
        // 动物
        TagGroupTreeNode(
          title: 'animals',
          displayNameZh: '动物',
          displayNameEn: 'Animals',
          children: [
            TagGroupTreeNode(
              title: 'tag_group:cats',
              displayNameZh: '猫',
              displayNameEn: 'Cats',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:dogs',
              displayNameZh: '狗',
              displayNameEn: 'Dogs',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:birds',
              displayNameZh: '鸟类',
              displayNameEn: 'Birds',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:legendary_creatures',
              displayNameZh: '传说生物',
              displayNameEn: 'Legendary Creatures',
              isTagGroup: true,
            ),
          ],
        ),
        // 物品
        TagGroupTreeNode(
          title: 'objects',
          displayNameZh: '物品',
          displayNameEn: 'Objects',
          children: [
            TagGroupTreeNode(
              title: 'tag_group:food_tags',
              displayNameZh: '食物',
              displayNameEn: 'Food',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:technology',
              displayNameZh: '科技',
              displayNameEn: 'Technology',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:cards',
              displayNameZh: '卡片',
              displayNameEn: 'Cards',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:symbols',
              displayNameZh: '符号',
              displayNameEn: 'Symbols',
              isTagGroup: true,
            ),
          ],
        ),
        // 活动
        TagGroupTreeNode(
          title: 'activities',
          displayNameZh: '活动',
          displayNameEn: 'Activities',
          children: [
            TagGroupTreeNode(
              title: 'tag_group:sports',
              displayNameZh: '运动',
              displayNameEn: 'Sports',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:holidays_and_celebrations',
              displayNameZh: '节日庆典',
              displayNameEn: 'Holidays and Celebrations',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:jobs',
              displayNameZh: '职业',
              displayNameEn: 'Jobs',
              isTagGroup: true,
            ),
          ],
        ),
        // 游戏类型
        TagGroupTreeNode(
          title: 'games',
          displayNameZh: '游戏类型',
          displayNameEn: 'Game Types',
          children: [
            TagGroupTreeNode(
              title: 'tag_group:video_game',
              displayNameZh: '电子游戏',
              displayNameEn: 'Video Game',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:fighting_games',
              displayNameZh: '格斗游戏',
              displayNameEn: 'Fighting Games',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:shooter_games',
              displayNameZh: '射击游戏',
              displayNameEn: 'Shooter Games',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:visual_novel_games',
              displayNameZh: '视觉小说',
              displayNameEn: 'Visual Novel Games',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:role-playing_games',
              displayNameZh: '角色扮演',
              displayNameEn: 'Role-playing Games',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:platform_games',
              displayNameZh: '平台游戏',
              displayNameEn: 'Platform Games',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:board_games',
              displayNameZh: '桌游',
              displayNameEn: 'Board Games',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:card_games',
              displayNameZh: '卡牌游戏',
              displayNameEn: 'Card Games',
              isTagGroup: true,
            ),
          ],
        ),
        // 元数据
        TagGroupTreeNode(
          title: 'meta',
          displayNameZh: '元数据',
          displayNameEn: 'Meta',
          children: [
            TagGroupTreeNode(
              title: 'tag_group:metatags',
              displayNameZh: '元标签',
              displayNameEn: 'Metatags',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:text',
              displayNameZh: '文字',
              displayNameEn: 'Text',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:language',
              displayNameZh: '语言',
              displayNameEn: 'Language',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:scan',
              displayNameZh: '扫描',
              displayNameEn: 'Scan',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:censorship',
              displayNameZh: '审查',
              displayNameEn: 'Censorship',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:audio_tags',
              displayNameZh: '音频标签',
              displayNameEn: 'Audio Tags',
              isTagGroup: true,
            ),
          ],
        ),
        // 其他杂项
        TagGroupTreeNode(
          title: 'misc',
          displayNameZh: '杂项',
          displayNameEn: 'Miscellaneous',
          children: [
            TagGroupTreeNode(
              title: 'tag_group:people',
              displayNameZh: '人物类型',
              displayNameEn: 'People',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:meme',
              displayNameZh: '梗图',
              displayNameEn: 'Meme',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:history',
              displayNameZh: '历史',
              displayNameEn: 'History',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:prints',
              displayNameZh: '印刷图案',
              displayNameEn: 'Prints',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:verbs_and_gerunds',
              displayNameZh: '动词',
              displayNameEn: 'Verbs and Gerunds',
              isTagGroup: true,
            ),
            TagGroupTreeNode(
              title: 'tag_group:phrases',
              displayNameZh: '短语',
              displayNameEn: 'Phrases',
              isTagGroup: true,
            ),
          ],
        ),
      ],
    ),
  ];
}
