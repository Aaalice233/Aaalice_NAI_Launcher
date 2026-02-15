import '../../../data/models/character/character_prompt.dart';
import 'models/comfyui_parse_result.dart';

/// 竖线格式解析器
///
/// 解析竖线分隔的多角色提示词格式
///
/// 支持格式:
/// ```
/// 全局提示词
/// | 角色1提示词
/// | 角色2提示词
/// ```
///
/// 示例：
/// ```
/// 2girls, masterpiece
/// | girl, black hair, red eyes
/// | girl, white hair, blue eyes
/// ```
class PipeParser {
  /// 分隔符正则：必须有换行 + 管道符
  static final _separatorPattern = RegExp(r'\s*\|\s*');
  static final _hasNewlinePattern = RegExp(r'\n\s*\|\s*');

  // 性别推断模式
  static final _malePattern = RegExp(
    r'\b(1boy|2boys|3boys|boy|male)\b',
    caseSensitive: false,
  );
  static final _femalePattern = RegExp(
    r'\b(1girl|2girls|3girls|girl|female)\b',
    caseSensitive: false,
  );

  /// 检测是否为竖线格式
  static bool isPipeFormat(String input) {
    // 必须包含 换行+管道符，防止误触发 NAI 动态标签 {a|b}
    return _hasNewlinePattern.hasMatch(input);
  }

  /// 解析竖线格式
  static ComfyuiParseResult parse(String input) {
    // 空输入处理
    if (input.trim().isEmpty) {
      return const ComfyuiParseResult(
        globalPrompt: '',
        characters: [],
        syntaxType: ComfyuiSyntaxType.pipe,
      );
    }

    // 拆分段落
    final parts = input
        .split(_separatorPattern)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return const ComfyuiParseResult(
        globalPrompt: '',
        characters: [],
        syntaxType: ComfyuiSyntaxType.pipe,
      );
    }

    // 第一部分 = 全局提示词
    final globalPrompt = parts[0];

    // 后续部分 = 角色提示词
    final characters = <ParsedCharacter>[];
    for (var i = 1; i < parts.length; i++) {
      final prompt = parts[i];
      characters.add(
        ParsedCharacter(
          prompt: prompt,
          inferredGender: _inferGender(prompt),
          position: null, // 竖线格式不包含位置信息
        ),
      );
    }

    return ComfyuiParseResult(
      globalPrompt: globalPrompt,
      characters: characters,
      syntaxType: ComfyuiSyntaxType.pipe,
    );
  }

  /// 推断角色性别
  static CharacterGender _inferGender(String prompt) {
    final maleMatch = _malePattern.firstMatch(prompt);
    final femaleMatch = _femalePattern.firstMatch(prompt);

    if (maleMatch != null && femaleMatch != null) {
      return maleMatch.start < femaleMatch.start
          ? CharacterGender.male
          : CharacterGender.female;
    }

    if (maleMatch != null) return CharacterGender.male;

    return CharacterGender.female;
  }
}
