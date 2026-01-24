import 'prompt_config.dart';
import 'tag_category.dart';
import 'tag_library.dart';
import 'weighted_tag.dart';

/// 默认预设配置名称
class DefaultPresetNames {
  final String presetName;
  final String character;
  final String expression;
  final String clothing;
  final String action;
  final String background;
  final String shot;
  final String composition;
  final String specialStyle;

  const DefaultPresetNames({
    required this.presetName,
    required this.character,
    required this.expression,
    required this.clothing,
    required this.action,
    required this.background,
    required this.shot,
    required this.composition,
    required this.specialStyle,
  });

  /// 默认名称（中文）
  static const defaultNames = DefaultPresetNames(
    presetName: '默认预设',
    character: '角色',
    expression: '表情',
    clothing: '服装',
    action: '动作',
    background: '背景',
    shot: '镜头',
    composition: '构图',
    specialStyle: '特殊风格',
  );
}

/// 默认预设数据
class DefaultPresets {
  DefaultPresets._();

  /// 创建默认预设
  static RandomPromptPreset createDefaultPreset([DefaultPresetNames? names]) {
    final n = names ?? DefaultPresetNames.defaultNames;
    return RandomPromptPreset.create(
      name: n.presetName,
      isDefault: true,
      configs: [
        // 角色数量 - 单选
        PromptConfig.create(
          name: n.character,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: [
            '1girl',
            '1boy',
            '1girl, 1boy',
            '2girls',
            'solo',
            'multiple girls',
          ],
        ),

        // 表情 - 单选（精简版，只保留常用表情）
        PromptConfig.create(
          name: n.expression,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _expressionTags,
        ),

        // 服装 - 单选（精简版，只保留常用服装）
        PromptConfig.create(
          name: n.clothing,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _clothingTags,
        ),

        // 动作/姿势 - 单选（精简版，只保留常用动作）
        PromptConfig.create(
          name: n.action,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _actionTags,
        ),

        // 背景 - 单选（精简版，只保留常用背景）
        PromptConfig.create(
          name: n.background,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _backgroundTags,
        ),

        // 镜头 - 单选
        PromptConfig.create(
          name: n.shot,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _shotTags,
        ),

        // 构图 - 概率出现 (30%的几率出现一个构图词)
        PromptConfig.create(
          name: n.composition,
          selectionMode: SelectionMode.singleProbability,
          contentType: ContentType.string,
          selectProbability: 0.3,
          stringContents: _compositionTags,
        ),

        // 特殊风格 - 概率出现 (10%的几率出现一个风格词)
        PromptConfig.create(
          name: n.specialStyle,
          selectionMode: SelectionMode.singleProbability,
          contentType: ContentType.string,
          selectProbability: 0.1,
          stringContents: _styleTags,
        ),
      ],
    );
  }

  /// 从词库创建预设
  ///
  /// 使用词库中的标签替换静态标签列表
  /// [includeDanbooruSupplement] 是否包含 Danbooru 补充标签
  static RandomPromptPreset createFromLibrary(
    TagLibrary library, {
    DefaultPresetNames? names,
    bool includeDanbooruSupplement = true,
  }) {
    final n = names ?? DefaultPresetNames.defaultNames;

    // 从词库获取标签列表，如果没有则使用静态默认值
    List<String> getTagsFromCategory(
        TagSubCategory category, List<String> fallback,) {
      final tags = library.getFilteredCategory(category,
          includeDanbooruSupplement: includeDanbooruSupplement,);
      if (tags.isEmpty) return fallback;
      // 按权重排序后返回标签名称
      final sorted = List<WeightedTag>.from(tags)
        ..sort((a, b) => b.weight.compareTo(a.weight));
      return sorted.map((t) => t.tag).toList();
    }

    return RandomPromptPreset.create(
      name: n.presetName,
      isDefault: true,
      configs: [
        // 角色数量 - 从词库获取
        PromptConfig.create(
          name: n.character,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: getTagsFromCategory(
            TagSubCategory.characterCount,
            [
              '1girl',
              '1boy',
              '1girl, 1boy',
              '2girls',
              'solo',
              'multiple girls',
            ],
          ),
        ),

        // 表情 - 从词库获取
        PromptConfig.create(
          name: n.expression,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: getTagsFromCategory(
            TagSubCategory.expression,
            _expressionTags,
          ),
        ),

        // 服装 - 暂无对应词库类别，使用默认
        PromptConfig.create(
          name: n.clothing,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _clothingTags,
        ),

        // 动作/姿势 - 从词库获取
        PromptConfig.create(
          name: n.action,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: getTagsFromCategory(
            TagSubCategory.pose,
            _actionTags,
          ),
        ),

        // 背景 - 从词库获取
        PromptConfig.create(
          name: n.background,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: getTagsFromCategory(
            TagSubCategory.background,
            _backgroundTags,
          ),
        ),

        // 镜头 - 暂无对应词库类别，使用默认
        PromptConfig.create(
          name: n.shot,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _shotTags,
        ),

        // 构图 - 从词库场景类别获取
        PromptConfig.create(
          name: n.composition,
          selectionMode: SelectionMode.singleProbability,
          contentType: ContentType.string,
          selectProbability: 0.3,
          stringContents: getTagsFromCategory(
            TagSubCategory.scene,
            _compositionTags,
          ),
        ),

        // 特殊风格 - 从词库获取
        PromptConfig.create(
          name: n.specialStyle,
          selectionMode: SelectionMode.singleProbability,
          contentType: ContentType.string,
          selectProbability: 0.1,
          stringContents: getTagsFromCategory(
            TagSubCategory.style,
            _styleTags,
          ),
        ),
      ],
    );
  }

  /// 所有默认预设
  static List<RandomPromptPreset> get allDefaults => [
        createDefaultPreset(),
      ];
}

/// 表情标签（精简版 - 约30个常用表情）
const _expressionTags = [
  'looking_at_viewer',
  'blush',
  'smile',
  'open_mouth',
  'closed_eyes',
  'closed_mouth',
  'grin',
  'one_eye_closed',
  'tears',
  'expressionless',
  'embarrassed',
  'frown',
  'happy',
  'light_smile',
  'shy',
  'surprised',
  'pout',
  'smirk',
  'smug',
  'nervous',
  'confused',
  'excited',
  'sleepy',
  'wink',
  'tongue_out',
  'parted_lips',
  'half-closed_eyes',
  'serious',
  'sad',
  'angry',
];

/// 服装标签（精简版 - 约50个常用服装）
const _clothingTags = [
  'shirt',
  'skirt',
  'dress',
  'thighhighs',
  'jacket',
  'school_uniform',
  'swimsuit',
  'bikini',
  'pantyhose',
  'shorts',
  'boots',
  'shoes',
  'gloves',
  'kimono',
  'sweater',
  'hoodie',
  'armor',
  'maid',
  'uniform',
  'sundress',
  'coat',
  'cardigan',
  'tank_top',
  't-shirt',
  'jeans',
  'leotard',
  'bodysuit',
  'pajamas',
  'hat',
  'ribbon',
  'bow',
  'choker',
  'necklace',
  'earrings',
  'glasses',
  'scarf',
  'cape',
  'apron',
  'vest',
  'blouse',
  'miniskirt',
  'pleated_skirt',
  'chinese_clothes',
  'japanese_clothes',
  'gothic_lolita',
  'military_uniform',
  'nurse',
  'maid_headdress',
  'sailor_collar',
  'serafuku',
];

/// 动作标签（精简版 - 约40个常用动作）
const _actionTags = [
  'sitting',
  'standing',
  'lying',
  'walking',
  'running',
  'jumping',
  'kneeling',
  'squatting',
  'stretching',
  'sleeping',
  'eating',
  'drinking',
  'reading',
  'holding',
  'carrying',
  'hugging',
  'waving',
  'pointing',
  'dancing',
  'floating',
  'flying',
  'leaning_forward',
  'leaning_back',
  'arms_up',
  'arms_behind_back',
  'hand_up',
  'hands_on_hips',
  'hand_on_hip',
  'crossed_arms',
  'crossed_legs',
  'spread_legs',
  'wariza',
  'seiza',
  'on_back',
  'on_side',
  'on_stomach',
  'all_fours',
  'bent_over',
  'head_tilt',
  'peace_sign',
  'thumbs_up',
  'v',
];

/// 背景标签（精简版 - 约40个常用背景）
const _backgroundTags = [
  'simple_background',
  'white_background',
  'grey_background',
  'black_background',
  'gradient_background',
  'outdoors',
  'indoors',
  'sky',
  'blue_sky',
  'night_sky',
  'starry_sky',
  'sunset',
  'sunrise',
  'cloudy_sky',
  'beach',
  'ocean',
  'forest',
  'mountain',
  'city',
  'street',
  'park',
  'garden',
  'flower_field',
  'snow',
  'rain',
  'room',
  'bedroom',
  'classroom',
  'office',
  'library',
  'cafe',
  'kitchen',
  'bathroom',
  'balcony',
  'rooftop',
  'window',
  'bed',
  'couch',
  'chair',
  'tree',
];

/// 镜头标签（拍摄距离）
const _shotTags = [
  'full_body',
  'upper_body',
  'cowboy_shot',
  'portrait',
  'close-up',
  'wide_shot',
  'lower_body',
  'very_wide_shot',
];

/// 构图标签（拍摄角度和视角）
const _compositionTags = [
  'dutch_angle',
  'from_above',
  'from_below',
  'from_side',
  'from_behind',
  'pov',
  'looking_at_viewer',
  'looking_away',
  'looking_back',
  'head_tilt',
  'leaning_forward',
  'profile',
  'three-quarter_view',
];

/// 特殊风格标签（精简版 - 约25个常用风格）
const _styleTags = [
  'monochrome',
  'greyscale',
  'chibi',
  'sketch',
  'pixel_art',
  'realistic',
  'retro_artstyle',
  'silhouette',
  '3d',
  'bokeh',
  'lineart',
  'sepia',
  'colorful',
  'pastel_colors',
  'high_contrast',
  'neon_lights',
  'light_particles',
  'lens_flare',
  'backlighting',
  'motion_blur',
  'chromatic_aberration',
  'bloom',
  'glowing',
  'art_nouveau',
  'watercolor_(medium)',
];
