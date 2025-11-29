// ignore_for_file: avoid_print
import 'dart:io';

/// 从 danbooru_tags.csv 提取各类别的标签
void main() async {
  final file = File(
    r'C:\Users\Administrator\AppData\Roaming\com.example\nai_launcher\tag_cache\danbooru_tags.csv',
  );

  if (!await file.exists()) {
    print('File not found');
    return;
  }

  final lines = await file.readAsLines();
  print('Total lines: ${lines.length}');

  // 解析所有标签
  final allTags = <Map<String, dynamic>>[];
  for (var i = 1; i < lines.length; i++) {
    final parts = _parseCsvLine(lines[i]);
    if (parts.length < 3) continue;

    final tag = parts[0];
    final category = int.tryParse(parts[1]) ?? 0;
    final count = int.tryParse(parts[2]) ?? 0;

    allTags.add({'tag': tag, 'category': category, 'count': count});
  }

  // 只取 General 类别 (category 0)，按使用量排序
  final generalTags = allTags
      .where((t) => t['category'] == 0)
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

  print('General tags: ${generalTags.length}');

  // 定义各类别的关键词模式
  final expressionPatterns = [
    // 眼神/视线
    'looking_at', 'looking_to', 'looking_up', 'looking_down', 'looking_back',
    'looking_away', 'looking_ahead', 'eye_contact', 'staring', 'glancing',
    // 表情
    'smile', 'grin', 'smirk', 'frown', 'pout', 'expressionless', 'serious',
    'blush', 'embarrassed', 'shy', 'nervous', 'worried', 'scared', 'afraid',
    'crying', 'tears', 'sobbing', 'sad', 'depressed', 'melancholy',
    'angry', 'annoyed', 'frustrated', 'furious', 'rage',
    'happy', 'excited', 'cheerful', 'joyful', 'delighted',
    'surprised', 'shocked', 'amazed', 'startled',
    'confused', 'puzzled', 'curious', 'thinking',
    'tired', 'sleepy', 'drowsy', 'exhausted', 'yawn',
    'drunk', 'intoxicated', 'dazed',
    'bored', 'unimpressed', 'disappointed',
    'disgusted', 'uncomfortable',
    'determined', 'confident', 'smug', 'proud',
    'evil', 'crazy', 'insane', 'yandere',
    // 嘴部
    'open_mouth', 'closed_mouth', 'parted_lips', 'puckered_lips',
    'tongue', 'tongue_out', 'licking', 'drooling', 'saliva',
    'teeth', 'fangs', 'vampire', 'biting',
    // 眼睛状态
    'closed_eyes', 'half-closed_eyes', 'one_eye_closed', 'wink',
    'wide-eyed', 'narrow_eyes', 'squinting',
    'heart_eyes', 'glowing_eyes', 'empty_eyes', 'sparkling_eyes',
    'heterochromia', 'multicolored_eyes', 'symbol_in_eye',
    // 脸部特征
    'blush_stickers', 'nose_blush', 'full-face_blush',
    'naughty_face', 'ahegao', 'fucked_silly',
  ];

  final clothingPatterns = [
    // 上衣
    'shirt', 'blouse', 'top', 'sweater', 'hoodie', 'cardigan', 'vest',
    'jacket', 'coat', 'blazer', 'suit', 'tuxedo',
    'tank_top', 'crop_top', 'tube_top', 't-shirt',
    // 下装
    'skirt', 'miniskirt', 'long_skirt', 'pleated_skirt',
    'pants', 'trousers', 'jeans', 'shorts', 'hotpants',
    // 连衣
    'dress', 'gown', 'sundress', 'wedding_dress', 'evening_dress',
    'jumpsuit', 'romper', 'overalls',
    // 制服
    'uniform', 'school_uniform', 'serafuku', 'sailor', 'military',
    'maid', 'nurse', 'police', 'waitress', 'bunny_girl',
    // 传统服装
    'kimono', 'yukata', 'hakama', 'furisode',
    'chinese_clothes', 'cheongsam', 'qipao', 'hanfu',
    'korean_clothes', 'hanbok',
    // 内衣
    'bra', 'panties', 'underwear', 'lingerie', 'negligee',
    'thong', 'g-string', 'boyshorts',
    // 泳装
    'swimsuit', 'bikini', 'one-piece', 'school_swimsuit', 'competition_swimsuit',
    // 紧身衣
    'bodysuit', 'leotard', 'unitard', 'catsuit', 'plugsuit',
    // 袜子/腿部
    'thighhighs', 'stockings', 'pantyhose', 'tights', 'socks', 'knee_highs',
    'garter', 'garter_belt', 'garter_straps',
    // 鞋子
    'shoes', 'boots', 'heels', 'high_heels', 'sneakers', 'sandals', 'slippers',
    'loafers', 'mary_janes', 'platform',
    // 手套
    'gloves', 'fingerless_gloves', 'elbow_gloves', 'mittens',
    // 帽子/头饰
    'hat', 'cap', 'beret', 'beanie', 'hood', 'helmet',
    'crown', 'tiara', 'headband', 'hairband', 'hair_ribbon',
    'headphones', 'headset', 'earmuffs',
    // 配饰
    'ribbon', 'bow', 'tie', 'necktie', 'bowtie', 'scarf', 'choker', 'collar',
    'necklace', 'earrings', 'bracelet', 'ring', 'anklet',
    'glasses', 'sunglasses', 'monocle', 'eyepatch',
    'mask', 'blindfold', 'gag',
    // 外套/披风
    'cape', 'cloak', 'mantle', 'poncho', 'shawl', 'stole',
    // 围裙
    'apron', 'waist_apron',
    // 其他
    'armor', 'gauntlets', 'pauldrons',
    'corset', 'bustier',
    'onesie', 'pajamas', 'nightgown', 'robe', 'bathrobe',
    'costume', 'cosplay', 'outfit', 'clothes', 'clothing', 'attire', 'wear',
  ];

  final actionPatterns = [
    // 基本姿势
    'standing', 'sitting', 'kneeling', 'squatting', 'crouching',
    'lying', 'lying_down', 'on_back', 'on_stomach', 'on_side',
    'leaning', 'bending', 'hunched',
    // 移动
    'walking', 'running', 'jogging', 'jumping', 'leaping', 'floating', 'flying',
    'falling', 'diving', 'swimming', 'climbing', 'crawling',
    // 手臂动作
    'arms_up', 'arms_down', 'arms_behind', 'arms_crossed', 'arms_at_sides',
    'hand_up', 'hand_on', 'hands_on', 'hand_in', 'hands_in',
    'pointing', 'waving', 'beckoning', 'reaching', 'grabbing', 'holding',
    'hugging', 'embracing', 'carrying',
    'clapping', 'praying', 'saluting', 'fist',
    // 腿部动作
    'legs_up', 'legs_apart', 'legs_together', 'legs_crossed',
    'kicking', 'stepping', 'tiptoeing',
    'spread_legs', 'crossed_legs', 'indian_style',
    // 头部动作
    'head_tilt', 'looking', 'turning',
    // 身体姿势
    'pose', 'stretch', 'arched_back', 'bent_over', 'all_fours',
    'fetal_position', 'spread_eagle',
    // 活动
    'fighting', 'attacking', 'defending', 'blocking',
    'dancing', 'singing', 'playing', 'gaming',
    'eating', 'drinking', 'cooking', 'baking',
    'reading', 'writing', 'drawing', 'painting', 'typing',
    'sleeping', 'resting', 'relaxing', 'bathing', 'showering',
    'dressing', 'undressing', 'changing',
    'exercising', 'training', 'working_out',
    'smoking', 'vaping',
    // 互动
    'kiss', 'kissing', 'licking', 'biting', 'sucking',
    'petting', 'stroking', 'caressing', 'touching',
    // 视角相关姿势
    'from_behind', 'from_below', 'from_above', 'from_side',
    'back_view', 'front_view', 'side_view',
    // 特殊姿势
    'v_sign', 'peace_sign', 'thumbs_up', 'finger_gun', 'ok_sign',
    'heart_hands', 'double_v', 'w_pose',
    'seiza', 'wariza', 'yokozuwari',
  ];

  final backgroundPatterns = [
    // 基础背景
    'background', 'simple_background', 'white_background', 'black_background',
    'grey_background', 'blue_background', 'pink_background', 'gradient_background',
    'transparent_background', 'two-tone_background', 'multicolored_background',
    // 室内
    'indoors', 'room', 'bedroom', 'bathroom', 'kitchen', 'living_room',
    'classroom', 'office', 'library', 'hospital', 'church', 'temple', 'shrine',
    'restaurant', 'cafe', 'bar', 'shop', 'store', 'mall',
    'gym', 'pool', 'bath', 'onsen', 'sauna',
    'hallway', 'corridor', 'stairs', 'elevator',
    // 室外
    'outdoors', 'outside', 'street', 'road', 'path', 'sidewalk',
    'park', 'garden', 'yard', 'field', 'meadow', 'grassland',
    'forest', 'woods', 'jungle', 'swamp',
    'mountain', 'hill', 'cliff', 'cave', 'canyon', 'valley',
    'beach', 'coast', 'shore', 'ocean', 'sea', 'lake', 'river', 'waterfall', 'pond',
    'desert', 'wasteland', 'ruins',
    'city', 'town', 'village', 'urban', 'downtown', 'alley',
    'rooftop', 'balcony', 'terrace', 'porch',
    // 天空/天气
    'sky', 'cloud', 'sun', 'moon', 'star', 'night_sky', 'starry_sky',
    'sunset', 'sunrise', 'twilight', 'dusk', 'dawn',
    'rain', 'snow', 'fog', 'mist', 'storm', 'lightning', 'rainbow',
    // 自然元素
    'tree', 'flower', 'grass', 'plant', 'leaf', 'petals', 'cherry_blossoms', 'sakura',
    'water', 'fire', 'ice', 'wind',
    // 建筑
    'building', 'house', 'castle', 'tower', 'bridge', 'wall', 'fence', 'gate',
    'window', 'door', 'pillar', 'arch',
    // 家具/物品
    'bed', 'chair', 'sofa', 'couch', 'table', 'desk', 'floor', 'carpet', 'rug',
    'curtain', 'mirror',
    // 交通
    'car', 'train', 'bus', 'airplane', 'ship', 'boat', 'vehicle',
    // 特殊场景
    'space', 'underwater', 'fantasy', 'magical', 'dreamlike',
    'battlefield', 'arena', 'stadium', 'stage', 'concert',
    'scenery', 'landscape', 'cityscape', 'skyline',
  ];

  final stylePatterns = [
    // 艺术风格
    'sketch', 'lineart', 'line_art', 'monochrome', 'greyscale', 'grayscale',
    'watercolor', 'oil_painting', 'acrylic', 'pastel',
    'pixel_art', 'pixel', 'retro', 'vintage', 'nostalgic',
    'realistic', 'photorealistic', 'semi-realistic',
    'chibi', 'super_deformed', 'sd',
    '3d', 'cg', 'render', 'cel_shading',
    'anime_style', 'manga_style', 'comic_style',
    'minimalist', 'abstract', 'surreal', 'psychedelic',
    'impressionist', 'expressionist',
    'art_nouveau', 'art_deco',
    // 色彩风格
    'colorful', 'vibrant', 'pastel_colors', 'muted_colors', 'neon',
    'sepia', 'desaturated', 'high_contrast', 'low_contrast',
    'warm_colors', 'cool_colors', 'monochromatic',
    // 光影
    'lighting', 'dramatic_lighting', 'rim_lighting', 'backlighting',
    'soft_lighting', 'harsh_lighting', 'spotlight',
    'shadow', 'silhouette', 'glow', 'bloom', 'lens_flare',
    // 特效
    'sparkle', 'glitter', 'particles', 'bubbles', 'feathers', 'petals',
    'motion_blur', 'depth_of_field', 'bokeh', 'chromatic_aberration',
    'film_grain', 'halftone', 'screentone',
    // 构图
    'portrait', 'bust', 'upper_body', 'lower_body', 'full_body',
    'close-up', 'medium_shot', 'wide_shot', 'cowboy_shot',
    'dutch_angle', 'bird\'s_eye_view', 'worm\'s_eye_view',
    'symmetry', 'asymmetry', 'centered', 'off-center',
    // 画质
    'highres', 'absurdres', 'incredibly_absurdres', 'masterpiece', 'best_quality',
    'high_quality', 'detailed', 'intricate', 'elaborate',
  ];

  // 分类函数
  bool matchesPatterns(String tag, List<String> patterns) {
    final lowerTag = tag.toLowerCase();
    for (final pattern in patterns) {
      if (lowerTag.contains(pattern.toLowerCase())) return true;
    }
    return false;
  }

  // 提取各类别（取高频标签，最多1000个）
  final expressions = <String>[];
  final clothing = <String>[];
  final actions = <String>[];
  final backgrounds = <String>[];
  final styles = <String>[];

  for (final item in generalTags) {
    final tag = item['tag'] as String;
    
    // 跳过太通用的标签
    if (tag == '1girl' || tag == '1boy' || tag == 'solo' || 
        tag == 'multiple_girls' || tag == 'multiple_boys' ||
        tag.contains('hair') && !tag.contains('style')) continue;

    if (expressions.length < 1000 && matchesPatterns(tag, expressionPatterns)) {
      expressions.add(tag);
    } else if (clothing.length < 1000 && matchesPatterns(tag, clothingPatterns)) {
      clothing.add(tag);
    } else if (actions.length < 1000 && matchesPatterns(tag, actionPatterns)) {
      actions.add(tag);
    } else if (backgrounds.length < 1000 && matchesPatterns(tag, backgroundPatterns)) {
      backgrounds.add(tag);
    } else if (styles.length < 1000 && matchesPatterns(tag, stylePatterns)) {
      styles.add(tag);
    }
  }

  // 输出统计
  print('\n=== Extracted Tags ===');
  print('Expressions: ${expressions.length}');
  print('Clothing: ${clothing.length}');
  print('Actions: ${actions.length}');
  print('Backgrounds: ${backgrounds.length}');
  print('Styles: ${styles.length}');

  // 转义单引号
  String escape(String tag) => tag.replaceAll("'", "\\'");

  // 写入文件
  final output = StringBuffer();
  output.writeln('// Auto-generated from danbooru_tags.csv');
  output.writeln('// ignore_for_file: constant_identifier_names');
  output.writeln('');
  output.writeln('/// 表情相关标签');
  output.writeln('const expressionTags = [');
  for (final tag in expressions) {
    output.writeln("  '${escape(tag)}',");
  }
  output.writeln('];');
  output.writeln('');
  output.writeln('/// 服装相关标签');
  output.writeln('const clothingTags = [');
  for (final tag in clothing) {
    output.writeln("  '${escape(tag)}',");
  }
  output.writeln('];');
  output.writeln('');
  output.writeln('/// 动作/姿势相关标签');
  output.writeln('const actionTags = [');
  for (final tag in actions) {
    output.writeln("  '${escape(tag)}',");
  }
  output.writeln('];');
  output.writeln('');
  output.writeln('/// 背景相关标签');
  output.writeln('const backgroundTags = [');
  for (final tag in backgrounds) {
    output.writeln("  '${escape(tag)}',");
  }
  output.writeln('];');
  output.writeln('');
  output.writeln('/// 特殊风格相关标签');
  output.writeln('const styleTags = [');
  for (final tag in styles) {
    output.writeln("  '${escape(tag)}',");
  }
  output.writeln('];');

  await File('lib/data/models/prompt/extracted_tags.dart').writeAsString(output.toString());
  print('\nWritten to lib/data/models/prompt/extracted_tags.dart');
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var inQuotes = false;
  var current = StringBuffer();

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }
  result.add(current.toString());

  return result;
}
