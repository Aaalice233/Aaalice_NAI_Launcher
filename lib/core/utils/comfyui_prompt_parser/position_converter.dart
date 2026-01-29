import '../../../data/models/character/character_prompt.dart';
import 'models/comfyui_parse_result.dart';

/// 位置坐标转换器
///
/// 负责将 ComfyUI 的区域坐标转换为 NAI 的位置格式
class PositionConverter {
  /// 将区域范围 (x1 x2, y1 y2) 转换为中心点坐标
  ///
  /// ComfyUI 使用 (x1 x2, y1 y2) 格式表示区域范围
  /// 例如: MASK(0 0.5, 0 1) 表示左半边区域
  static ParsedPosition regionToCenter(
    double x1,
    double x2,
    double y1,
    double y2,
  ) {
    return ParsedPosition(
      x: ((x1 + x2) / 2).clamp(0.0, 1.0),
      y: ((y1 + y2) / 2).clamp(0.0, 1.0),
    );
  }

  /// 将 ParsedPosition 转换为 NAI CharacterPosition
  ///
  /// NAI 使用 5x5 网格系统 (A1-E5)
  /// 这里将 0.0-1.0 的坐标转换为 CharacterPosition
  static CharacterPosition toNaiPosition(ParsedPosition pos) {
    return CharacterPosition(
      mode: CharacterPositionMode.custom,
      // NAI 的 column 对应 x 轴（横向）
      column: pos.x.clamp(0.0, 1.0),
      // NAI 的 row 对应 y 轴（纵向）
      row: pos.y.clamp(0.0, 1.0),
    );
  }

  /// 解析 MASK/AREA/COUPLE 参数字符串
  ///
  /// 支持以下格式:
  /// - `(x1 x2)` - 仅 x 范围，y 默认 0-1
  /// - `(x1 x2, y1 y2)` - 完整范围
  /// - `(x1 x2, y1 y2, weight)` - 带权重（权重被忽略）
  ///
  /// 返回 null 表示解析失败
  static ParsedPosition? parseRegionParams(String params) {
    // 移除括号
    var content = params.trim();
    if (content.startsWith('(')) content = content.substring(1);
    if (content.endsWith(')')) {
      content = content.substring(0, content.length - 1);
    }

    // 按逗号分割
    final parts = content.split(',').map((s) => s.trim()).toList();

    if (parts.isEmpty) return null;

    try {
      // 解析 x 范围
      final xParts =
          parts[0].split(RegExp(r'\s+')).map((s) => s.trim()).toList();
      if (xParts.length < 2) return null;

      final x1 = double.parse(xParts[0]);
      final x2 = double.parse(xParts[1]);

      // 解析 y 范围（可选，默认 0-1）
      double y1 = 0.0;
      double y2 = 1.0;

      if (parts.length >= 2) {
        final yParts =
            parts[1].split(RegExp(r'\s+')).map((s) => s.trim()).toList();
        if (yParts.length >= 2) {
          y1 = double.parse(yParts[0]);
          y2 = double.parse(yParts[1]);
        }
      }

      return regionToCenter(x1, x2, y1, y2);
    } catch (_) {
      return null;
    }
  }
}
