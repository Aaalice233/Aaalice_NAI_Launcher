import '../../data/models/character/character_prompt.dart';

/// 多角色提示词解析器
/// 
/// 将格式为 "全局提示词\n| 角色1\n| 角色2" 的输入拆分为：
/// - 全局提示词（保留在主输入框）
/// - 多个角色提示词（自动创建角色）
class MultiCharacterParser {
  /// 分隔符正则：必须有换行 + 管道符
  /// 
  /// 使用 `\s*\|\s*` 而非 `\n\s*\|\s*` 来支持多个空行
  /// 
  /// 示例：
  /// - ✅ "Global\n| Char1" → 触发拆分
  /// - ✅ "Global\n|\n\n| Char1" → 跳过空段落
  /// - ❌ "Global | Char1" → 不触发（需要在 hasMatch 中检查换行）
  /// - ❌ "{a|b}" → 不触发（NAI 动态标签）
  static final _separatorPattern = RegExp(r'\s*\|\s*');
  static final _hasNewlinePattern = RegExp(r'\n\s*\|\s*');

  /// 性别推断正则
  static final _malePattern = RegExp(
    r'\b(1boy|2boys|3boys|male)\b',
    caseSensitive: false,
  );

  static final _femalePattern = RegExp(
    r'\b(1girl|2girls|3girls|female)\b',
    caseSensitive: false,
  );

  /// 解析多角色提示词
  /// 
  /// 返回 [ParseResult] 包含：
  /// - `globalPrompt`: 全局提示词
  /// - `characters`: 角色列表
  /// - `hasMultipleCharacters`: 是否包含多个角色
  /// 
  /// 示例：
  /// ```dart
  /// final result = MultiCharacterParser.parse(
  ///   '2girls, masterpiece\n| girl, black hair\n| girl, white hair'
  /// );
  /// print(result.globalPrompt); // "2girls, masterpiece"
  /// print(result.characters.length); // 2
  /// ```
  static ParseResult parse(String input) {
    // 空输入处理
    if (input.trim().isEmpty) {
      return const ParseResult(
        globalPrompt: '',
        characters: [],
      );
    }

    // 检查是否包含换行+分隔符（防止误触发 {a|b}）
    if (!_hasNewlinePattern.hasMatch(input)) {
      // 无换行分隔符 → 作为单一全局提示词
      return ParseResult(
        globalPrompt: input.trim(),
        characters: const [],
      );
    }

    // 拆分段落（使用更宽松的模式以处理多个空行）
    final parts = input
        .split(_separatorPattern)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty) // 跳过空段落
        .toList();

    if (parts.isEmpty) {
      return const ParseResult(
        globalPrompt: '',
        characters: [],
      );
    }

    // 第一部分 = 全局提示词
    final globalPrompt = parts[0];

    // 后续部分 = 角色提示词
    final characters = <CharacterPrompt>[];
    for (var i = 1; i < parts.length; i++) {
      final prompt = parts[i];
      characters.add(
        CharacterPrompt.create(
          name: 'Character $i', // 从 1 开始编号
          prompt: prompt,
          gender: _inferGender(prompt),
        ),
      );
    }

    return ParseResult(
      globalPrompt: globalPrompt,
      characters: characters,
    );
  }

  /// 推断角色性别
  /// 
  /// 规则：
  /// 1. 查找 male 标签（1boy, 2boys, 3boys, male）
  /// 2. 查找 female 标签（1girl, 2girls, 3girls, female）
  /// 3. 如果两者都有，按首次出现位置决定
  /// 4. 默认为 female
  static CharacterGender _inferGender(String prompt) {
    final maleMatch = _malePattern.firstMatch(prompt);
    final femaleMatch = _femalePattern.firstMatch(prompt);

    // 两者都有 → 按位置优先
    if (maleMatch != null && femaleMatch != null) {
      return maleMatch.start < femaleMatch.start
          ? CharacterGender.male
          : CharacterGender.female;
    }

    // 只有 male
    if (maleMatch != null) {
      return CharacterGender.male;
    }

    // 只有 female 或都没有 → 默认 female
    return CharacterGender.female;
  }
}

/// 解析结果
class ParseResult {
  /// 全局提示词
  final String globalPrompt;

  /// 角色列表
  final List<CharacterPrompt> characters;

  const ParseResult({
    required this.globalPrompt,
    required this.characters,
  });

  /// 是否包含多个角色
  bool get hasMultipleCharacters => characters.isNotEmpty;
}
