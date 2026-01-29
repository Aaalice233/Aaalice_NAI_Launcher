import '../../../data/models/character/character_prompt.dart';
import 'models/comfyui_parse_result.dart';
import 'position_converter.dart';

/// AND+MASK 语法解析器
///
/// 解析 ComfyUI Prompt Control 的 AND+MASK/AREA 语法
///
/// 支持格式:
/// - `cat MASK(0 0.5, 0 1) AND dog MASK(0.5 1, 0 1)`
/// - `prompt1 AREA(0 0.5, 0 1) AND prompt2 AREA(0.5 1, 0 1)`
class AndMaskParser {
  // AND 分割模式
  static final _andPattern = RegExp(
    r'\s+AND\s+',
    caseSensitive: true,
  );

  // MASK 参数模式
  static final _maskPattern = RegExp(
    r'\bMASK\s*\(([^)]+)\)',
    caseSensitive: true,
  );

  // AREA 参数模式
  static final _areaPattern = RegExp(
    r'\bAREA\s*\(([^)]+)\)',
    caseSensitive: true,
  );

  // IMASK 模式（索引引用）
  static final _imaskPattern = RegExp(
    r'\bIMASK\s*\([^)]*\)',
    caseSensitive: true,
  );

  // 权重模式（:weight 结尾）
  static final _weightPattern = RegExp(
    r'\s*:\s*[\d.]+\s*$',
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

  /// 解析 AND+MASK 语法
  static ComfyuiParseResult parse(String input) {
    // 按 AND 分割
    final parts = input.split(_andPattern);

    if (parts.length < 2) {
      // 没有找到有效的 AND 分割
      return ComfyuiParseResult(
        globalPrompt: input.trim(),
        characters: const [],
        syntaxType: ComfyuiSyntaxType.andMask,
      );
    }

    // 每个部分都是一个角色
    final characters = <ParsedCharacter>[];

    for (final part in parts) {
      final character = _parseCharacterPart(part.trim());
      if (character != null) {
        characters.add(character);
      }
    }

    // AND+MASK 语法通常没有全局提示词
    // 但可以尝试提取公共部分（暂不实现）
    return ComfyuiParseResult(
      globalPrompt: '',
      characters: characters,
      syntaxType: ComfyuiSyntaxType.andMask,
    );
  }

  /// 解析单个角色部分
  static ParsedCharacter? _parseCharacterPart(String part) {
    var remaining = part.trim();
    ParsedPosition? position;

    // 移除末尾的权重 :weight
    remaining = remaining.replaceAll(_weightPattern, '');

    // 尝试提取 MASK 参数
    final maskMatch = _maskPattern.firstMatch(remaining);
    if (maskMatch != null) {
      final params = maskMatch.group(1);
      if (params != null) {
        position = PositionConverter.parseRegionParams('($params)');
      }
      // 从提示词中移除 MASK(...)
      remaining = remaining.replaceFirst(_maskPattern, '').trim();
    }

    // 尝试提取 AREA 参数
    final areaMatch = _areaPattern.firstMatch(remaining);
    if (areaMatch != null) {
      final params = areaMatch.group(1);
      if (params != null && position == null) {
        position = PositionConverter.parseRegionParams('($params)');
      }
      // 从提示词中移除 AREA(...)
      remaining = remaining.replaceFirst(_areaPattern, '').trim();
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
