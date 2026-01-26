import 'dart:math';

import '../models/character/character_prompt.dart';
import '../models/prompt/character_count_config.dart';

/// 角色数量与性别解析器
///
/// 提供角色数量标签生成和性别转换逻辑
/// 从 RandomPromptGenerator 中提取的专门处理角色组合的组件
///
/// 主要功能：
/// - 根据性别列表生成角色数量标签（如 "solo", "2girls", "1girl, 1boy"）
/// - 将性别字符串转换为 CharacterGender 枚举
/// - 支持从配置中确定角色数量
///
/// 标签生成规则：
/// - 0个角色: "no humans"
/// - 1个角色: "solo"
/// - 2个角色: "2girls", "2boys", "1girl, 1boy"
/// - 3个角色: "3girls", "3boys", "2girls, 1boy", "1girl, 2boys"
/// - 更多同性: "multiple girls" 或 "multiple boys"
/// - 混合多人: "group"
class CharacterCountResolver {
  /// 角色数量权重分布（来自 NAI 官网）
  /// [[1,70], [2,20], [3,7], [0,5]]
  static const List<List<int>> naiCharacterCountWeights = [
    [1, 70], // 1人 70%
    [2, 20], // 2人 20%
    [3, 7], // 3人 7%
    [0, 5], // 无人 5%
  ];

  /// Furry 性别权重分布（预留，当前未使用）
  /// [["m",45], ["f",45], ["o",10]]
  static const List<List<dynamic>> furryGenderWeights = [
    ['m', 45], // 男性 45%
    ['f', 45], // 女性 45%
    ['o', 10], // 其他 10%
  ];

  /// 根据性别列表生成角色数量标签
  ///
  /// 将一组角色的性别转换为 Danbooru 格式的人数标签。
  /// 这是生成随机提示词时的核心逻辑，决定了主提示词中的人数标签。
  ///
  /// [genders] 角色性别列表，可以为空
  ///
  /// 返回 Danbooru 格式的人数标签
  ///
  /// 示例：
  /// ```dart
  /// final resolver = CharacterCountResolver();
  ///
  /// // 无人
  /// resolver.getCountTag([]); // "no humans"
  ///
  /// // 单人
  /// resolver.getCountTag([CharacterGender.female]); // "solo"
  /// resolver.getCountTag([CharacterGender.male]); // "solo"
  ///
  /// // 双人
  /// resolver.getCountTag([CharacterGender.female, CharacterGender.female]); // "2girls"
  /// resolver.getCountTag([CharacterGender.male, CharacterGender.male]); // "2boys"
  /// resolver.getCountTag([CharacterGender.female, CharacterGender.male]); // "1girl, 1boy"
  ///
  /// // 三人
  /// resolver.getCountTag([CharacterGender.female, CharacterGender.female, CharacterGender.female]); // "3girls"
  /// resolver.getCountTag([CharacterGender.female, CharacterGender.female, CharacterGender.male]); // "2girls, 1boy"
  ///
  /// // 多人
  /// resolver.getCountTag(List.filled(4, CharacterGender.female)); // "multiple girls"
  /// resolver.getCountTag([CharacterGender.female, CharacterGender.male, CharacterGender.male, CharacterGender.female]); // "group"
  /// ```
  String getCountTag(List<CharacterGender> genders) {
    if (genders.isEmpty) return 'no humans';
    if (genders.length == 1) return 'solo';

    final femaleCount =
        genders.where((g) => g == CharacterGender.female).length;
    final maleCount = genders.where((g) => g == CharacterGender.male).length;

    // 2人组合
    if (genders.length == 2) {
      if (femaleCount == 2) return '2girls';
      if (maleCount == 2) return '2boys';
      if (femaleCount == 1 && maleCount == 1) return '1girl, 1boy';
    }

    // 3人组合
    if (genders.length == 3) {
      if (femaleCount == 3) return '3girls';
      if (maleCount == 3) return '3boys';
      if (femaleCount == 2 && maleCount == 1) return '2girls, 1boy';
      if (femaleCount == 1 && maleCount == 2) return '1girl, 2boys';
    }

    // 更多角色
    final otherCount = genders.length - femaleCount - maleCount;
    if (femaleCount > 0 && maleCount == 0 && otherCount == 0) {
      return 'multiple girls';
    }
    if (maleCount > 0 && femaleCount == 0 && otherCount == 0) {
      return 'multiple boys';
    }
    return 'group';
  }

  /// 使用 NAI 默认权重决定角色数量
  ///
  /// 使用 NAI 官网的角色数量分布概率来随机决定生成的角色数量。
  /// 这是 NAI 风格随机提示词生成的第一步。
  ///
  /// [random] 随机数生成器，可选（默认创建新实例）
  ///
  /// 返回角色数量（0-3，其中 0 表示无人场景）
  ///
  /// 抛出 [ArgumentError] 当权重列表为空时
  ///
  /// 示例：
  /// ```dart
  /// final resolver = CharacterCountResolver();
  /// final random = Random(42); // 可复现的随机数
  /// final count = resolver.determineCharacterCount(random: random);
  /// // 返回值大概率是 1（70%概率），其次是 2（20%），3（7%），0（5%）
  /// ```
  int determineCharacterCount({Random? random}) {
    return determineCharacterCountFromWeights(
      naiCharacterCountWeights,
      random: random,
    );
  }

  /// 从自定义权重决定角色数量
  ///
  /// 使用自定义的角色数量权重分布来决定角色数量。
  /// 支持预设配置中的自定义权重。
  ///
  /// [weights] 权重列表，格式为 [[数量, 权重], ...]
  /// [random] 随机数生成器，可选
  ///
  /// 返回选中的角色数量
  ///
  /// 抛出 [ArgumentError] 当权重列表为空时
  ///
  /// 示例：
  /// ```dart
  /// final resolver = CharacterCountResolver();
  /// final customWeights = [
  ///   [1, 50],  // 1人 50%
  ///   [2, 50],  // 2人 50%
  /// ];
  /// final count = resolver.determineCharacterCountFromWeights(customWeights);
  /// ```
  int determineCharacterCountFromWeights(
    List<List<int>> weights, {
    Random? random,
  }) {
    if (weights.isEmpty) {
      throw ArgumentError('Weights list cannot be empty');
    }

    random ??= Random();

    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w[1]);
    final target = random.nextInt(totalWeight) + 1;

    var cumulative = 0;
    for (final w in weights) {
      cumulative += w[1];
      if (target <= cumulative) {
        return w[0];
      }
    }

    return weights.last[0];
  }

  /// 从字符标签列表生成性别枚举列表
  ///
  /// 解析角色槽位标签（如 "girl", "boy", "other"）为性别枚举列表。
  /// 用于从 CharacterTagOption 的 slotTags 中提取性别信息。
  ///
  /// [characterTags] 角色标签列表（如 ["girl", "boy", "girl"]）
  ///
  /// 返回对应的性别枚举列表
  ///
  /// 示例：
  /// ```dart
  /// final resolver = CharacterCountResolver();
  ///
  /// resolver.getGendersFromTags(['girl']); // [CharacterGender.female]
  /// resolver.getGendersFromTags(['boy']); // [CharacterGender.male]
  /// resolver.getGendersFromTags(['girl', 'boy']); // [CharacterGender.female, CharacterGender.male]
  /// resolver.getGendersFromTags(['other']); // [CharacterGender.other]
  /// resolver.getGendersFromTags(['girl', 'boy', 'girl']); // [CharacterGender.female, CharacterGender.male, CharacterGender.female]
  /// ```
  List<CharacterGender> getGendersFromTags(List<String> characterTags) {
    return characterTags.map((tag) => genderFromString(tag)).toList();
  }

  /// 从字符串标签转换为性别枚举
  ///
  /// 解析单个角色标签为性别枚举。支持多种常见标签格式。
  /// 识别规则：
  /// - 包含 "girl" 或 "female" → female
  /// - 包含 "boy" 或 "male" → male
  /// - 其他 → female（默认值，与原实现一致）
  ///
  /// [gender] 性别标签字符串
  ///
  /// 返回对应的性别枚举
  ///
  /// 示例：
  /// ```dart
  /// final resolver = CharacterCountResolver();
  ///
  /// resolver.genderFromString('girl'); // CharacterGender.female
  /// resolver.genderFromString('1girl'); // CharacterGender.female
  /// resolver.genderFromString('boy'); // CharacterGender.male
  /// resolver.genderFromString('male'); // CharacterGender.male
  /// resolver.genderFromString('unknown'); // CharacterGender.female (default)
  /// ```
  CharacterGender genderFromString(String gender) {
    final lowerGender = gender.toLowerCase();

    if (lowerGender.contains('girl') || lowerGender.contains('female')) {
      return CharacterGender.female;
    }
    if (lowerGender.contains('boy') || lowerGender.contains('male')) {
      return CharacterGender.male;
    }

    // Default to female for unknown tags (matches original implementation)
    return CharacterGender.female;
  }

  /// 从 CharacterTagOption 提取性别列表并生成人数标签
  ///
  /// 这是一个便捷方法，结合了 getGendersFromTags 和 getCountTag 的功能。
  /// 常用于从预设配置的 CharacterTagOption 直接生成人数标签。
  ///
  /// [tagOption] 角色标签选项
  ///
  /// 返回 Danbooru 格式的人数标签
  ///
  /// 示例：
  /// ```dart
  /// final resolver = CharacterCountResolver();
  ///
  /// final option = CharacterTagOption(
  ///   id: 'duo_mixed',
  ///   label: '一女一男',
  ///   mainPromptTags: '1girl, 1boy',
  ///   slotTags: [
  ///     CharacterSlotTag(slotIndex: 0, characterTag: 'girl'),
  ///     CharacterSlotTag(slotIndex: 1, characterTag: 'boy'),
  ///   ],
  /// );
  ///
  /// resolver.getCountTagFromOption(option); // "1girl, 1boy"
  /// ```
  String getCountTagFromOption(CharacterTagOption tagOption) {
    final characterTags =
        tagOption.slotTags.map((slot) => slot.characterTag).toList();
    final genders = getGendersFromTags(characterTags);
    return getCountTag(genders);
  }

  /// 验证性别列表与预期数量是否匹配
  ///
  /// 用于验证生成的角色配置是否一致。
  ///
  /// [genders] 性别列表
  /// [expectedCount] 预期的角色数量
  ///
  /// 返回是否匹配
  ///
  /// 示例：
  /// ```dart
  /// final resolver = CharacterCountResolver();
  ///
  /// final genders = [CharacterGender.female, CharacterGender.male];
  /// resolver.validateCharacterCount(genders, 2); // true
  /// resolver.validateCharacterCount(genders, 3); // false
  /// ```
  bool validateCharacterCount(
    List<CharacterGender> genders,
    int expectedCount,
  ) {
    return genders.length == expectedCount;
  }
}
