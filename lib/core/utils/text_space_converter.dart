/// 空格转换工具类
/// 将标签内部的空格转换为下划线，同时保护特定位置的空格
class TextSpaceConverter {
  TextSpaceConverter._();

  /// 保护字符集预设：仅逗号
  static const Set<String> commaOnly = {',', '，'};

  /// 保护字符集预设：逗号 + 括号 + 竖线 + 尖括号 + 数值权重边界（用于 NAI 格式化）
  static const Set<String> naiFormat = {
    ',',
    '，', // 中文逗号
    '{',
    '}',
    '[',
    ']',
    '(',
    ')',
    '|',
    '<', // 别名语法
    '>', // 别名语法
    '::', // `1.5:: rain`、`year_2025 ::` 的空格是权重边界
  };

  /// 将空格转换为下划线
  ///
  /// [text] 要转换的文本
  /// [protectChars] 在这些字符或记号附近的空格会被保留
  ///
  /// 规则：
  /// - 如果空格前的非空格内容以 protectChars 中的项结尾，保留空格
  /// - 如果空格后的非空格内容以 protectChars 中的项开头，保留空格
  /// - 如果空格在尖括号 <> 内部，保留空格
  /// - 其他情况，将空格转换为下划线
  static String convert(String text, {Set<String> protectChars = commaOnly}) {
    if (text.isEmpty) return text;

    final chars = text.split('');
    final length = chars.length;

    // 预计算：每个位置前后最近的非空格字符索引
    // 使用两次遍历代替每个空格都双向查找，将 O(n²) 优化为 O(n)
    final prevNonSpaceIdx = List<int>.filled(length, -1);
    final nextNonSpaceIdx = List<int>.filled(length, -1);

    // 从左到右，记录每个位置前面最近的非空格字符索引
    int lastNonSpaceIdx = -1;
    for (var i = 0; i < length; i++) {
      prevNonSpaceIdx[i] = lastNonSpaceIdx;
      if (chars[i] != ' ') {
        lastNonSpaceIdx = i;
      }
    }

    // 从右到左，记录每个位置后面最近的非空格字符索引
    lastNonSpaceIdx = -1;
    for (var i = length - 1; i >= 0; i--) {
      nextNonSpaceIdx[i] = lastNonSpaceIdx;
      if (chars[i] != ' ') {
        lastNonSpaceIdx = i;
      }
    }

    // 预计算：每个位置是否在尖括号内部
    final inAngleBracket = List<bool>.filled(length, false);
    var angleBracketDepth = 0;
    for (var i = 0; i < length; i++) {
      if (chars[i] == '<') {
        angleBracketDepth++;
      }
      inAngleBracket[i] = angleBracketDepth > 0;
      if (chars[i] == '>') {
        angleBracketDepth = (angleBracketDepth - 1).clamp(0, 100);
      }
    }

    // 构建结果
    final result = StringBuffer();
    for (var i = 0; i < length; i++) {
      final char = chars[i];

      if (char != ' ') {
        result.write(char);
        continue;
      }

      // 处理空格：检查是否需要保护
      final prevIdx = prevNonSpaceIdx[i];
      final nextIdx = nextNonSpaceIdx[i];

      // 如果在尖括号内部，保留空格
      if (inAngleBracket[i]) {
        result.write(' ');
        continue;
      }

      // 如果前后非空格内容紧邻保护项，保留空格
      final shouldPreserve =
          (prevIdx >= 0 && _endsWithAny(text, prevIdx + 1, protectChars)) ||
          (nextIdx >= 0 && _startsWithAny(text, nextIdx, protectChars));

      result.write(shouldPreserve ? ' ' : '_');
    }

    return result.toString();
  }

  static bool _endsWithAny(String text, int end, Set<String> tokens) =>
      tokens.any(
        (token) =>
            end >= token.length && text.startsWith(token, end - token.length),
      );

  static bool _startsWithAny(String text, int start, Set<String> tokens) =>
      tokens.any((token) => text.startsWith(token, start));
}
