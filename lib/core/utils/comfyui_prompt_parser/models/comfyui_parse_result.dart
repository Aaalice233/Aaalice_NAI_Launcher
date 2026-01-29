import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../data/models/character/character_prompt.dart';

part 'comfyui_parse_result.freezed.dart';

/// ComfyUI 语法类型
enum ComfyuiSyntaxType {
  /// COUPLE 语法（基于注意力的区域划分）
  couple,

  /// AND+MASK 语法（基于 latent 遮罩的区域划分）
  andMask,

  /// 竖线格式（NAI Launcher 自定义格式）
  pipe,

  /// 未知/不支持的语法
  unknown,
}

/// 解析出的位置坐标
@freezed
class ParsedPosition with _$ParsedPosition {
  const ParsedPosition._();

  const factory ParsedPosition({
    /// 横向位置 (0.0-1.0)
    required double x,

    /// 纵向位置 (0.0-1.0)
    required double y,
  }) = _ParsedPosition;

  /// 从区域范围计算中心点
  factory ParsedPosition.fromRegion({
    required double x1,
    required double x2,
    required double y1,
    required double y2,
  }) {
    return ParsedPosition(
      x: (x1 + x2) / 2,
      y: (y1 + y2) / 2,
    );
  }
}

/// 解析出的单个角色
@freezed
class ParsedCharacter with _$ParsedCharacter {
  const ParsedCharacter._();

  const factory ParsedCharacter({
    /// 角色提示词
    required String prompt,

    /// 推断的性别
    CharacterGender? inferredGender,

    /// 解析出的位置（可选）
    ParsedPosition? position,
  }) = _ParsedCharacter;
}

/// ComfyUI 提示词解析结果
@freezed
class ComfyuiParseResult with _$ComfyuiParseResult {
  const ComfyuiParseResult._();

  const factory ComfyuiParseResult({
    /// 全局提示词
    required String globalPrompt,

    /// 解析出的角色列表
    required List<ParsedCharacter> characters,

    /// 检测到的语法类型
    required ComfyuiSyntaxType syntaxType,
  }) = _ComfyuiParseResult;

  /// 是否有有效的角色
  bool get hasCharacters => characters.isNotEmpty;

  /// 是否有位置信息
  bool get hasPositionInfo => characters.any((c) => c.position != null);
}
