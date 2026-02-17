import 'models/comfyui_parse_result.dart';
import 'pipe_parser.dart';

/// ComfyUI 语法检测器
///
/// 检测输入文本是否包含 ComfyUI Prompt Control 的多角色语法
/// 或竖线格式的多角色语法
class ComfyuiSyntaxDetector {
  // COUPLE 关键字匹配（不在引号内）
  // 匹配: COUPLE 或 COUPLE(...)
  static final _couplePattern = RegExp(
    r'\bCOUPLE\b',
    caseSensitive: true,
  );

  // AND + MASK/AREA 组合匹配
  // 匹配: ... AND ... 且包含 MASK(...) 或 AREA(...)
  static final _andPattern = RegExp(
    r'\s+AND\s+',
    caseSensitive: true,
  );

  static final _maskOrAreaPattern = RegExp(
    r'\b(MASK|AREA)\s*\(',
    caseSensitive: true,
  );

  /// 检测输入是否为 ComfyUI 多角色语法
  ///
  /// 返回检测到的语法类型
  static ComfyuiSyntaxType detect(String input) {
    if (input.isEmpty) return ComfyuiSyntaxType.unknown;

    // 移除引号内的内容后再检测
    final cleanedInput = _removeQuotedContent(input);

    // 优先检测 COUPLE 语法（更明确）
    if (_couplePattern.hasMatch(cleanedInput)) {
      return ComfyuiSyntaxType.couple;
    }

    // 检测 AND + MASK/AREA 组合
    if (_andPattern.hasMatch(cleanedInput) &&
        _maskOrAreaPattern.hasMatch(cleanedInput)) {
      return ComfyuiSyntaxType.andMask;
    }

    // 检测竖线格式（换行+管道符）
    if (PipeParser.isPipeFormat(input)) {
      return ComfyuiSyntaxType.pipe;
    }

    return ComfyuiSyntaxType.unknown;
  }

  /// 快速检测是否为 ComfyUI 多角色语法
  ///
  /// 仅判断是否需要解析，不区分具体类型
  static bool isComfyuiMultiCharacter(String input) {
    return detect(input) != ComfyuiSyntaxType.unknown;
  }

  /// 移除引号内的内容
  ///
  /// 防止引号内的关键字被误判
  /// 例如: "COUPLE" 或 'AND MASK' 不应被识别
  static String _removeQuotedContent(String input) {
    // 移除双引号内容
    var result = input.replaceAll(RegExp(r'"[^"]*"'), '""');
    // 移除单引号内容
    result = result.replaceAll(RegExp(r"'[^']*'"), "''");
    return result;
  }
}
