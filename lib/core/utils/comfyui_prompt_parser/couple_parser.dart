import '../../../data/models/character/character_prompt.dart';
import 'models/comfyui_parse_result.dart';
import 'position_converter.dart';

/// COUPLE 语法解析器
///
/// 解析 ComfyUI Prompt Control 的 COUPLE 语法
///
/// 支持格式:
/// - `base_prompt COUPLE(x1 x2) char1 COUPLE(x1 x2) char2`
/// - `base_prompt COUPLE MASK(x1 x2, y1 y2) char1`
/// - `base_prompt FILL() COUPLE(0 0.5) char1 COUPLE(0.5 1) char2`
class CoupleParser {
  // COUPLE 分割模式（捕获 COUPLE 及其参数）
  static final _couplePattern = RegExp(
    r'\s+COUPLE\b',
    caseSensitive: true,
  );

  // COUPLE 后的参数模式: COUPLE(x1 x2) 或 COUPLE(x1 x2, y1 y2)
  static final _coupleParamsPattern = RegExp(
    r'^\s*\(([^)]+)\)',
  );

  // MASK 参数模式
  static final _maskPattern = RegExp(
    r'\bMASK\s*\(([^)]+)\)',
    caseSensitive: true,
  );

  // FILL() 模式
  static final _fillPattern = RegExp(
    r'\bFILL\s*\(\s*\)',
    caseSensitive: true,
  );

  // IMASK 模式（索引引用）
  static final _imaskPattern = RegExp(
    r'\bIMASK\s*\([^)]*\)',
    caseSensitive: true,
  );

  // 性别推断模式
  static final _malePattern = RegExp(
    r'\b(1boy|2boys|3boys|boy|male)\b',
    caseSensitive: false,
  );
  static final _femalePattern = RegExp(
    r'\b(1girl|2girls|3girls|girl|female)\b',
    caseSensitive: false,
  );

  /// 解析 COUPLE 语法
  static ComfyuiParseResult parse(String input) {
    // 按 COUPLE 分割
    final parts = input.split(_couplePattern);

    if (parts.length < 2) {
      // 没有找到有效的 COUPLE 分割
      return ComfyuiParseResult(
        globalPrompt: input.trim(),
        characters: const [],
        syntaxType: ComfyuiSyntaxType.couple,
      );
    }

    // 第一部分是全局提示词
    final globalPrompt = _cleanGlobalPrompt(parts[0]);

    // 后续部分是角色
    final characters = <ParsedCharacter>[];

    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      final character = _parseCharacterPart(part);
      if (character != null) {
        characters.add(character);
      }
    }

    return ComfyuiParseResult(
      globalPrompt: globalPrompt,
      characters: characters,
      syntaxType: ComfyuiSyntaxType.couple,
    );
  }

  /// 清理全局提示词
  ///
  /// 移除 FILL() 等函数调用
  static String _cleanGlobalPrompt(String prompt) {
    var result = prompt;

    // 移除 FILL()
    result = result.replaceAll(_fillPattern, '');

    // 移除多余的逗号和空格
    result = result.replaceAll(RegExp(r',\s*,'), ',');
    result = result.replaceAll(RegExp(r'^\s*,\s*'), '');
    result = result.replaceAll(RegExp(r'\s*,\s*$'), '');

    return result.trim();
  }

  /// 解析单个角色部分
  ///
  /// 格式: `(x1 x2) char_prompt` 或 `MASK(x1 x2, y1 y2) char_prompt`
  static ParsedCharacter? _parseCharacterPart(String part) {
    var remaining = part.trim();
    ParsedPosition? position;

    // 尝试提取 COUPLE 参数 (x1 x2) 或 (x1 x2, y1 y2)
    final coupleMatch = _coupleParamsPattern.firstMatch(remaining);
    if (coupleMatch != null) {
      final params = coupleMatch.group(1);
      if (params != null) {
        position = PositionConverter.parseRegionParams('($params)');
      }
      remaining = remaining.substring(coupleMatch.end).trim();
    }

    // 尝试提取 MASK 参数
    final maskMatch = _maskPattern.firstMatch(remaining);
    if (maskMatch != null) {
      final params = maskMatch.group(1);
      if (params != null && position == null) {
        position = PositionConverter.parseRegionParams('($params)');
      }
      // 从提示词中移除 MASK(...)
      remaining = remaining.replaceFirst(_maskPattern, '').trim();
    }

    // 移除 IMASK（索引引用，暂不支持）
    remaining = remaining.replaceAll(_imaskPattern, '').trim();

    // 清理提示词
    remaining = _cleanPrompt(remaining);

    if (remaining.isEmpty) return null;

    return ParsedCharacter(
      prompt: remaining,
      inferredGender: _inferGender(remaining),
      position: position,
    );
  }

  /// 清理提示词
  static String _cleanPrompt(String prompt) {
    var result = prompt;

    // 移除开头的逗号
    result = result.replaceAll(RegExp(r'^\s*,\s*'), '');
    // 移除结尾的逗号
    result = result.replaceAll(RegExp(r'\s*,\s*$'), '');
    // 规范化空格
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    return result.trim();
  }

  /// 推断角色性别
  static CharacterGender _inferGender(String prompt) {
    final maleMatch = _malePattern.firstMatch(prompt);
    final femaleMatch = _femalePattern.firstMatch(prompt);

    if (maleMatch != null && femaleMatch != null) {
      // 两者都有，取位置靠前的
      return maleMatch.start < femaleMatch.start
          ? CharacterGender.male
          : CharacterGender.female;
    }

    if (maleMatch != null) return CharacterGender.male;

    // 默认女性
    return CharacterGender.female;
  }
}
