/// Danbooru 颜文字标签的下划线是字形本身，转成空格风格时必须原样保留。
abstract final class KaomojiTags {
  static const Set<String> values = {
    '0_0',
    '(o)_(o)',
    '+_+',
    '+_-',
    '._.',
    '<o>_<o>',
    '<|>_<|>',
    '=_=',
    '>_<',
    '3_3',
    '6_9',
    '>_o',
    '@_@',
    '^_^',
    'o_o',
    'u_u',
    'x_x',
    '|_|',
    '||_||',
  };

  /// 前后紧邻字母、数字或下划线时属于普通标签的一部分，例如 `foo_ood`。
  static final RegExp pattern = RegExp(
    r'(?<![\p{L}\p{N}_])(?:'
    '${_longestFirst.map(RegExp.escape).join('|')}'
    r')(?![\p{L}\p{N}_])',
    unicode: true,
  );

  // 同一起点能匹配多项时取最长的
  static List<String> get _longestFirst =>
      values.toList()..sort((a, b) => b.length.compareTo(a.length));

  static String underscoresToSpaces(String text) {
    if (!text.contains('_')) return text;
    return text.splitMapJoin(
      pattern,
      onMatch: (match) => match[0]!,
      onNonMatch: (segment) => segment.replaceAll('_', ' '),
    );
  }
}
