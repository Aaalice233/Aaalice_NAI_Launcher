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
    return _splitPipeSegments(input).length > 1;
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
    final parts = _splitPipeSegments(input);

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

  static List<String> _splitPipeSegments(String input) {
    final parts = <String>[];
    var start = 0;
    var curlyDepth = 0;
    var squareDepth = 0;
    var parenDepth = 0;
    var inDoubleQuote = false;
    var inRandomBlock = false;
    var escaped = false;

    for (var i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);

      if (escaped) {
        escaped = false;
        continue;
      }

      if (code == 0x5C) {
        escaped = true;
        continue;
      }

      if (code == 0x22) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }

      if (inDoubleQuote) continue;

      switch (code) {
        case 0x7B: // {
          curlyDepth++;
          continue;
        case 0x7D: // }
          if (curlyDepth > 0) curlyDepth--;
          continue;
        case 0x5B: // [
          squareDepth++;
          continue;
        case 0x5D: // ]
          if (squareDepth > 0) squareDepth--;
          continue;
        case 0x28: // (
          parenDepth++;
          continue;
        case 0x29: // )
          if (parenDepth > 0) parenDepth--;
          continue;
        case 0x7C: // |
          // NAI 随机选择 `||a|b||` 可嵌在括号里，块内竖线是候选项
          if (i + 1 < input.length && input.codeUnitAt(i + 1) == 0x7C) {
            inRandomBlock = !inRandomBlock;
            i++;
            continue;
          }
          if (!inRandomBlock &&
              curlyDepth == 0 &&
              squareDepth == 0 &&
              parenDepth == 0 &&
              _isPromptPipeDelimiter(input, i)) {
            final part = input.substring(start, i).trim();
            if (part.isNotEmpty) parts.add(part);
            start = i + 1;
          }
          continue;
      }
    }

    final tail = input.substring(start).trim();
    if (tail.isNotEmpty) parts.add(tail);
    return parts;
  }

  static bool _isPromptPipeDelimiter(String input, int index) {
    if (_isPipeAtLineStart(input, index)) return true;
    if (index == 0 || index == input.length - 1) return false;
    return _isWhitespace(input.codeUnitAt(index - 1)) &&
        _isWhitespace(input.codeUnitAt(index + 1));
  }

  static bool _isPipeAtLineStart(String input, int index) {
    for (var i = index - 1; i >= 0; i--) {
      final code = input.codeUnitAt(i);
      if (code == 0x0A || code == 0x0D) return true;
      if (!_isHorizontalWhitespace(code)) return false;
    }
    return false;
  }

  static bool _isWhitespace(int code) =>
      code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;

  static bool _isHorizontalWhitespace(int code) => code == 0x20 || code == 0x09;
}
