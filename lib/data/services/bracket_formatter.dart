import 'dart:math';

/// 括号格式化器
///
/// 负责标签的括号权重调整和强调应用
/// 复刻 NovelAI 官网的括号权重系统
/// 参考: docs/NAI随机提示词功能分析.md
///
/// 主要功能：
/// - 应用权重括号到单个标签（{}增强，[]降低）
/// - 批量应用强调到标签列表（基于概率）
///
/// 括号说明：
/// - {tag}: 增强标签权重
/// - {{tag}}: 更强增强
/// - [tag]: 降低标签权重
/// - [[tag]]: 更强降低
class BracketFormatter {
  /// 应用权重括号到单个标签
  ///
  /// 在指定范围内随机选择括号层数并应用到标签。
  /// 正数使用 {} 增强权重，负数使用 [] 降低权重。
  ///
  /// [tag] 要处理的标签文本
  /// [bracketMin] 最小括号层数（可为负数）
  /// [bracketMax] 最大括号层数（可为负数）
  /// [random] 随机数生成器，可选（默认创建新实例）
  ///
  /// 返回带括号的标签，如果不需要括号则返回原标签
  ///
  /// 示例：
  /// ```dart
  /// final formatter = BracketFormatter();
  ///
  /// // 增强权重：1-3层 {}
  /// final enhanced = formatter.applyBrackets('blonde hair', 1, 3);
  /// // 可能返回：'{blonde hair}', '{{blonde hair}}', 或 '{{{blonde hair}}}'
  ///
  /// // 降低权重：1-2层 []
  /// final decreased = formatter.applyBrackets('background', -2, -1);
  /// // 可能返回：'[background]' 或 '[[background]]'
  ///
  /// // 范围包含0：可能不添加括号
  /// final maybe = formatter.applyBrackets('smile', 0, 2);
  /// // 可能返回：'smile', '{smile}', '{{smile}}'
  /// ```
  String applyBrackets(
    String tag,
    int bracketMin,
    int bracketMax, {
    Random? random,
  }) {
    // 如果范围都是0，不添加括号
    if (bracketMin == 0 && bracketMax == 0) return tag;

    // 确保 min <= max
    final min = bracketMin <= bracketMax ? bracketMin : bracketMax;
    final max = bracketMin <= bracketMax ? bracketMax : bracketMin;

    random ??= Random();

    // 随机选择层数
    final n = min + random.nextInt(max - min + 1);

    // 如果选中的是0，不添加括号
    if (n == 0) return tag;

    // 负数用 []（降权），正数用 {}（增强）
    if (n < 0) {
      final count = -n;
      final open = '[' * count;
      final close = ']' * count;
      return '$open$tag$close';
    } else {
      final open = '{' * n;
      final close = '}' * n;
      return '$open$tag$close';
    }
  }

  /// 批量应用强调括号到标签列表
  ///
  /// 对每个标签基于指定概率决定是否应用强调括号。
  /// 强调使用 {} 括号增强标签在生成中的重要性。
  ///
  /// [tags] 标签列表
  /// [probability] 每个标签被强调的概率（0.0-1.0）
  /// [bracketCount] 强调括号层数，必须为正数
  /// [random] 随机数生成器，可选（默认创建新实例）
  ///
  /// 返回处理后的标签列表（某些标签可能被强调）
  ///
  /// 抛出 [ArgumentError] 当 bracketCount 不为正数时
  ///
  /// 示例：
  /// ```dart
  /// final formatter = BracketFormatter();
  /// final tags = ['smile', 'blonde hair', 'blue eyes'];
  ///
  /// // 50%概率强调，2层括号
  /// final emphasized = formatter.applyEmphasis(
  ///   tags,
  ///   probability: 0.5,
  ///   bracketCount: 2,
  /// );
  /// // 可能返回：['smile', '{{blonde hair}}', 'blue eyes']
  /// // blonde hair 被强调，其他未强调
  ///
  /// // 100%强调，1层括号
  /// final allEmphasized = formatter.applyEmphasis(
  ///   tags,
  ///   probability: 1.0,
  ///   bracketCount: 1,
  /// );
  /// // 返回：['{smile}', '{blonde hair}', '{blue eyes}']
  /// ```
  List<String> applyEmphasis(
    List<String> tags, {
    required double probability,
    required int bracketCount,
    Random? random,
  }) {
    if (probability <= 0 || bracketCount <= 0) {
      return tags;
    }

    random ??= Random();
    final rng = random; // Promote to non-null

    return tags.map((tag) {
      // 基于概率决定是否强调此标签
      if (rng.nextDouble() < probability) {
        final openBrackets = '{' * bracketCount;
        final closeBrackets = '}' * bracketCount;
        return '$openBrackets$tag$closeBrackets';
      }
      return tag;
    }).toList();
  }

  /// 移除标签的所有括号（工具方法）
  ///
  /// 移除标签外层的所有 {} 和 [] 括号，返回纯标签文本。
  /// 用于需要获取不带权重的标签文本的场景。
  ///
  /// [tag] 可能带括号的标签
  ///
  /// 返回不带括号的纯标签文本
  ///
  /// 示例：
  /// ```dart
  /// final formatter = BracketFormatter();
  ///
  /// formatter.removeBrackets('{{{blonde hair}}}'); // 'blonde hair'
  /// formatter.removeBrackets('[[background]]');     // 'background'
  /// formatter.removeBrackets('{smile}');            // 'smile'
  /// formatter.removeBrackets('simple tag');         // 'simple tag'
  /// ```
  String removeBrackets(String tag) {
    // 移除所有前导的 { 和 [
    var result = tag.replaceAll(RegExp(r'^[\{\[]+'), '');

    // 移除所有尾随的 } 和 ]
    result = result.replaceAll(RegExp(r'[\}\]]+$'), '');

    return result;
  }

  /// 计算标签的有效括号层数
  ///
  /// 计算标签外层的括号层数。
  /// 正数表示 {} 层数（增强），负数表示 [] 层数（降低），0表示无括号或混合类型。
  ///
  /// [tag] 可能带括号的标签
  ///
  /// 返回有效括号层数
  ///
  /// 示例：
  /// ```dart
  /// final formatter = BracketFormatter();
  ///
  /// formatter.getBracketLevel('{{{tag}}}'); // 3
  /// formatter.getBracketLevel('[[tag]]');   // -2
  /// formatter.getBracketLevel('{tag}');     // 1
  /// formatter.getBracketLevel('tag');       // 0
  /// formatter.getBracketLevel('{[tag]}');   // 0 (mixed types)
  /// ```
  int getBracketLevel(String tag) {
    if (tag.isEmpty) return 0;

    // 检查是否同时包含两种括号类型（混合）
    final hasBraces = tag.contains('{') || tag.contains('}');
    final hasBrackets = tag.contains('[') || tag.contains(']');
    if (hasBraces && hasBrackets) {
      return 0; // 混合类型，返回0
    }

    // 检查 {} 括号
    final openBraces = RegExp(r'^\{+');
    final closeBraces = RegExp(r'\}+$');
    final openMatch = openBraces.firstMatch(tag);
    final closeMatch = closeBraces.firstMatch(tag);

    if (openMatch != null && closeMatch != null) {
      final openCount = openMatch.group(0)!.length;
      final closeCount = closeMatch.group(0)!.length;
      if (openCount == closeCount) {
        return openCount;
      }
    }

    // 检查 [] 括号
    final openBrackets = RegExp(r'^\[+');
    final closeBrackets = RegExp(r'\]+$');
    final openBracketMatch = openBrackets.firstMatch(tag);
    final closeBracketMatch = closeBrackets.firstMatch(tag);

    if (openBracketMatch != null && closeBracketMatch != null) {
      final openCount = openBracketMatch.group(0)!.length;
      final closeCount = closeBracketMatch.group(0)!.length;
      if (openCount == closeCount) {
        return -openCount;
      }
    }

    return 0;
  }
}
