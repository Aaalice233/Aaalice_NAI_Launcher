import '../../data/models/character/character_prompt.dart';
import 'comfyui_prompt_parser/and_mask_parser.dart';
import 'comfyui_prompt_parser/couple_parser.dart';
import 'comfyui_prompt_parser/models/comfyui_parse_result.dart';
import 'comfyui_prompt_parser/pipe_parser.dart';
import 'comfyui_prompt_parser/position_converter.dart';
import 'comfyui_prompt_parser/syntax_detector.dart';

// 导出子模块
export 'comfyui_prompt_parser/models/comfyui_parse_result.dart';
export 'comfyui_prompt_parser/syntax_detector.dart';

/// ComfyUI Prompt Control 语法解析器
///
/// 统一入口，自动检测语法类型并解析
///
/// 支持三种语法:
/// 1. COUPLE 语法: `base_prompt COUPLE(x1 x2) char1 COUPLE(x1 x2) char2`
/// 2. AND+MASK 语法: `cat MASK(0 0.5, 0 1) AND dog MASK(0.5 1, 0 1)`
/// 3. 竖线格式: `全局提示词\n| 角色1\n| 角色2`
class ComfyuiPromptParser {
  /// 检测并解析 ComfyUI 多角色提示词
  ///
  /// 返回 null 表示不是 ComfyUI 格式或解析失败
  static ComfyuiParseResult? tryParse(String input) {
    if (input.isEmpty) return null;

    final type = ComfyuiSyntaxDetector.detect(input);

    switch (type) {
      case ComfyuiSyntaxType.couple:
        final result = CoupleParser.parse(input);
        // 如果没有解析出角色，返回 null
        if (!result.hasCharacters) return null;
        return result;

      case ComfyuiSyntaxType.andMask:
        final result = AndMaskParser.parse(input);
        // 如果没有解析出角色，返回 null
        if (!result.hasCharacters) return null;
        return result;

      case ComfyuiSyntaxType.pipe:
        final result = PipeParser.parse(input);
        // 如果没有解析出角色，返回 null
        if (!result.hasCharacters) return null;
        return result;

      case ComfyuiSyntaxType.unknown:
        return null;
    }
  }

  /// 快速检测是否为 ComfyUI 多角色语法
  static bool isComfyuiMultiCharacter(String input) {
    return ComfyuiSyntaxDetector.isComfyuiMultiCharacter(input);
  }

  /// 将解析结果转换为 NAI 角色列表
  ///
  /// [result] 解析结果
  /// [usePosition] 是否使用位置信息
  static List<CharacterPrompt> toNaiCharacters(
    ComfyuiParseResult result, {
    required bool usePosition,
  }) {
    final characters = <CharacterPrompt>[];

    for (var i = 0; i < result.characters.length; i++) {
      final parsed = result.characters[i];

      // 确定位置
      CharacterPosition? position;
      CharacterPositionMode positionMode = CharacterPositionMode.aiChoice;

      if (usePosition && parsed.position != null) {
        position = PositionConverter.toNaiPosition(parsed.position!);
        positionMode = CharacterPositionMode.custom;
      }

      characters.add(
        CharacterPrompt.create(
          name: 'Character ${i + 1}',
          gender: parsed.inferredGender ?? CharacterGender.female,
          prompt: parsed.prompt,
          positionMode: positionMode,
          customPosition: position,
        ),
      );
    }

    return characters;
  }
}
