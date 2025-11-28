import 'prompt_config.dart';

/// 默认预设数据
class DefaultPresets {
  DefaultPresets._();

  /// 创建默认预设
  static RandomPromptPreset createDefaultPreset() {
    return RandomPromptPreset.create(
      name: '默认预设',
      isDefault: true,
      configs: [
        // 质量标签 - 全选
        PromptConfig.create(
          name: '质量',
          selectionMode: SelectionMode.all,
          contentType: ContentType.string,
          stringContents: [
            'masterpiece',
            'best quality',
            'amazing quality',
            'very aesthetic',
            'absurdres',
          ],
        ),

        // 角色数量 - 单选
        PromptConfig.create(
          name: '角色',
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

        // 画师风格 - 多选(指定数量)
        PromptConfig.create(
          name: '画师',
          selectionMode: SelectionMode.multipleCount,
          contentType: ContentType.string,
          selectCount: 3,
          bracketMin: 0,
          bracketMax: 2,
          stringContents: [
            'artist:ciloranko',
            'artist:sho_(sho_lwlw)',
            'artist:kedama_milk',
            'artist:mika_pikazo',
            'artist:hiten',
            'artist:rurudo',
            'artist:ask_(askzy)',
            'artist:wlop',
            'artist:lack',
            'artist:ningen_mame',
          ],
        ),

        // 表情 - 单选
        PromptConfig.create(
          name: '表情',
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: [
            'smile',
            'grin',
            'blush',
            'shy',
            'closed eyes',
            'open mouth',
            'surprised',
            'wink',
            ':d',
            'looking at viewer',
          ],
        ),

        // 服装 - 单选
        PromptConfig.create(
          name: '服装',
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: [
            'school uniform',
            'dress',
            'casual clothes',
            'maid',
            'kimono',
            'bikini',
            'wedding dress',
            'suit',
            'hoodie',
            'sweater',
          ],
        ),

        // 动作/姿势 - 单选
        PromptConfig.create(
          name: '动作',
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: [
            'standing',
            'sitting',
            'walking',
            'running',
            'lying',
            'kneeling',
            'hands on hips',
            'arms up',
            'peace sign',
            'hand on own chest',
          ],
        ),

        // 背景 - 单选
        PromptConfig.create(
          name: '背景',
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: [
            'simple background',
            'white background',
            'outdoors',
            'indoors',
            'cityscape',
            'nature',
            'sky',
            'beach',
            'classroom',
            'bedroom',
          ],
        ),

        // 特殊风格 - 概率选取 (3%)
        PromptConfig.create(
          name: '特殊风格',
          selectionMode: SelectionMode.multipleProbability,
          contentType: ContentType.string,
          selectProbability: 0.03,
          stringContents: [
            'lineart',
            'sketch',
            'watercolor',
            'oil painting',
            '3d',
            'pixel art',
          ],
        ),
      ],
    );
  }

  /// 创建简单预设
  static RandomPromptPreset createSimplePreset() {
    return RandomPromptPreset.create(
      name: '简单预设',
      configs: [
        PromptConfig.create(
          name: '质量',
          selectionMode: SelectionMode.all,
          contentType: ContentType.string,
          stringContents: [
            'masterpiece',
            'best quality',
          ],
        ),
        PromptConfig.create(
          name: '角色',
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: [
            '1girl',
            '1boy',
          ],
        ),
      ],
    );
  }

  /// 所有默认预设
  static List<RandomPromptPreset> get allDefaults => [
    createDefaultPreset(),
    createSimplePreset(),
  ];
}
