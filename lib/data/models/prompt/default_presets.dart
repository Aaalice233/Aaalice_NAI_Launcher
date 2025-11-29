import 'extracted_tags.dart';
import 'prompt_config.dart';

/// 默认预设配置名称
class DefaultPresetNames {
  final String presetName;
  final String character;
  final String artist;
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
    required this.artist,
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
    artist: '画师',
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

        // 画师风格 - 多选(指定数量)
        PromptConfig.create(
          name: n.artist,
          selectionMode: SelectionMode.multipleCount,
          contentType: ContentType.string,
          selectCount: 2,
          bracketMin: 0,
          bracketMax: 2,
          stringContents: _artistTags,
        ),

        // 表情 - 单选
        PromptConfig.create(
          name: n.expression,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: expressionTags,
        ),

        // 服装 - 单选
        PromptConfig.create(
          name: n.clothing,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: clothingTags,
        ),

        // 动作/姿势 - 单选
        PromptConfig.create(
          name: n.action,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: actionTags,
        ),

        // 背景 - 单选
        PromptConfig.create(
          name: n.background,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: backgroundTags,
        ),

        // 镜头 - 单选
        PromptConfig.create(
          name: n.shot,
          selectionMode: SelectionMode.singleRandom,
          contentType: ContentType.string,
          stringContents: _shotTags,
        ),

        // 构图 - 概率选取 (10%)
        PromptConfig.create(
          name: n.composition,
          selectionMode: SelectionMode.multipleProbability,
          contentType: ContentType.string,
          selectProbability: 0.1,
          stringContents: _compositionTags,
        ),

        // 特殊风格 - 概率选取 (5%)
        PromptConfig.create(
          name: n.specialStyle,
          selectionMode: SelectionMode.multipleProbability,
          contentType: ContentType.string,
          selectProbability: 0.05,
          stringContents: _styleTags,
        ),
      ],
    );
  }

  /// 所有默认预设
  static List<RandomPromptPreset> get allDefaults => [
        createDefaultPreset(),
      ];
}

/// 画师标签（手动维护的高质量画师列表）
const _artistTags = [
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
  'artist:fuzichoco',
  'artist:necomi',
  'artist:kakure_eria',
  'artist:anmi',
  'artist:kita_(kita_sendai)',
  'artist:nabeshima_tetsuhiro',
  'artist:mogumo',
  'artist:kantoku',
  'artist:tony_taka',
  'artist:kishida_mel',
  'artist:redjuice',
  'artist:ilya_kuvshinov',
  'artist:krenz_cushart',
  'artist:sakimichan',
  'artist:guweiz',
  'artist:dice_(dice_k_1616)',
  'artist:torino_(kty)',
  'artist:hoshimachi_suisei',
  'artist:yomu_(sgt_epper)',
  'artist:yuuki_hagure',
  'artist:nineo',
  'artist:yin-ting_tian',
  'artist:siragiku_hirano',
  'artist:shion_(mirudakemann)',
  'artist:neco',
  'artist:ogata_tomio',
  'artist:karasu_(naoshow357)',
  'artist:swd3e2',
  'artist:momoko_(momopoco)',
  'artist:sogawa66',
  'artist:nili',
  'artist:nardack',
  'artist:kyrie_meii',
  'artist:ume_(pickled_plum)',
  'artist:novelance',
  'artist:hanakage',
  'artist:ishikei',
  'artist:wasabi_(sekai)',
  'artist:koh_(minagi_ech)',
  'artist:suzuhito_yasuda',
  'artist:kagami_hirotaka',
  'artist:rella',
  'artist:haori',
  'artist:cha_goma',
  'artist:yoneyama_mai',
  'artist:rosuuri',
  'artist:banishment',
  'artist:po-ju',
  'artist:pochi_(pochi-goya)',
  'artist:ring_(kami_kagetsu)',
  'artist:asanagi',
  'artist:koruse',
  'artist:zheng',
  'artist:parang',
  'artist:ayami_kazaine',
  'artist:stu_dts',
  'artist:namori',
  'artist:kuromiya',
  'artist:tsubasa_tsubasa',
  'artist:saitom',
  'artist:naruwe',
  'artist:samsunglocked',
  'artist:ayaki',
  'artist:sheya',
  'artist:haruaki',
  'artist:sakiyamama',
  'artist:mibu_natsuki',
  'artist:nagisa_kurousagi',
  'artist:lunacle',
  'artist:nyum',
  'artist:amano_yoki',
  'artist:senryoko',
  'artist:suzu_(imori)',
  'artist:naga_u',
  'artist:oekakizuki',
  'artist:vania600',
  'artist:mery_(aporo_2699)',
  'artist:fkey',
  'artist:saru',
  'artist:fuyuyu',
  'artist:matsunaga_kouyou',
  'artist:nemu_(nebusokugimi)',
  'artist:ningen_plamo',
  'artist:mitsumine_toyomaru',
  'artist:jiu_ye_sang',
  'artist:imoko_(imo_co17)',
  'artist:ao_masami',
  'artist:jcm2',
  'artist:kase_daiki',
  'artist:kuro_kosyou',
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

/// 特殊风格标签（排除镜头和构图相关）
const _styleTags = [
  'monochrome',
  'greyscale',
  'chibi',
  'sketch',
  'shadow',
  'glowing',
  'feathers',
  'light_particles',
  'eyeshadow',
  'lens_flare',
  'backlighting',
  'motion_blur',
  'chromatic_aberration',
  'bloomers',
  'pixel_art',
  'realistic',
  'chibi_inset',
  'retro_artstyle',
  'chibi_only',
  'silhouette',
  'red_eyeshadow',
  '3d',
  'glowing_eye',
  'halftone',
  'fox_shadow_puppet',
  'white_bloomers',
  'bokeh',
  'drop_shadow',
  'lineart',
  'see-through_silhouette',
  'soap_bubbles',
  'sidelighting',
  'sepia',
  'white_feathers',
  'blowing_bubbles',
  'glowing_weapon',
  'spotlight',
  'black_feathers',
  'glowstick',
  'neon_trim',
  'colorful',
  'bloom',
  'surreal',
  'blue_eyeshadow',
  'pink_eyeshadow',
  'glowing_sword',
  'purple_eyeshadow',
  'abstract',
  'high_contrast',
  'no_lineart',
  'neon_lights',
  'sketchbook',
  'double_fox_shadow_puppet',
  'blue_feathers',
  'pastel_colors',
  'symmetry',
  'screentones',
  'portrait_(object)',
  'rotational_symmetry',
  'glowing_tattoo',
  'glowing_butterfly',
  'colored_shadow',
  'glowing_wings',
  'black_eyeshadow',
  'red_feathers',
  'pixelated',
  'art_nouveau',
  'glitter',
  'afterglow',
  'green_feathers',
  'photorealistic',
  'glowing_horns',
];
