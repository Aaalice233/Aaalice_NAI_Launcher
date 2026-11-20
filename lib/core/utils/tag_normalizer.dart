/// 标签标准化工具函数
///
/// 统一处理标签的存储格式和显示格式转换
/// 解决项目中 "显示格式"（空格）和 "存储格式"（下划线）的不一致问题
class TagNormalizer {
  TagNormalizer._();

  static final RegExp weightPrefixPattern = RegExp(r'^-?(?:\d+\.?\d*|\.\d+)::');
  static final RegExp weightPattern = RegExp(r'-?(?:\d+\.?\d*|\.\d+)::');
  static final RegExp _leadingBracketPattern = RegExp(r'^[\{\[\(]+');
  static final RegExp _commaSeparatorPattern = RegExp(r'[,，]+');
  static final RegExp _searchSeparatorPattern = RegExp(r'[_/\\|,，;；\n\r\t]+');
  static final RegExp _delimitedSearchSeparatorPattern =
      RegExp(r'[/\\|,，;；\n\r\t]+');
  static final RegExp _bracketPattern = RegExp(r'[\{\}\[\]\(\)]');
  static final RegExp _colonPattern = RegExp(r'[:]+');
  static final RegExp _whitespacePattern = RegExp(r'\s+');

  static RegExp get commaSeparatorPattern => _commaSeparatorPattern;

  /// 统一标准化标签（用于存储和查询）
  ///
  /// 转换规则：
  /// 1. 转为小写
  /// 2. 去除首尾空格
  /// 3. 空格替换为下划线
  ///
  /// 示例：
  /// ```dart
  /// TagNormalizer.normalize('Simple Background') // 'simple_background'
  /// TagNormalizer.normalize('simple background')  // 'simple_background'
  /// TagNormalizer.normalize('  SOLO  ')           // 'solo'
  /// ```
  static String normalize(String tag) {
    return tag.toLowerCase().trim().replaceAll(' ', '_');
  }

  /// 批量标准化标签
  static List<String> normalizeList(List<String> tags) {
    return tags.map(normalize).toList();
  }

  /// 转换为显示格式（下划线转空格）
  ///
  /// 示例：
  /// ```dart
  /// TagNormalizer.toDisplay('simple_background') // 'simple background'
  /// TagNormalizer.toDisplay('solo')              // 'solo'
  /// ```
  static String toDisplay(String tag) {
    return tag.replaceAll('_', ' ');
  }

  static String foldSearchText(String text) => toDisplay(text.toLowerCase());

  /// 批量转换为显示格式
  static List<String> toDisplayList(List<String> tags) {
    return tags.map(toDisplay).toList();
  }

  /// 检查标签是否已标准化
  ///
  /// 已标准化：全小写、无首尾空格、无空格字符
  static bool isNormalized(String tag) {
    return tag == tag.toLowerCase().trim() && !tag.contains(' ');
  }

  /// 标准化并去重
  static Set<String> normalizeToSet(List<String> tags) {
    return tags.map(normalize).toSet();
  }

  /// 去掉 NAI 权重前缀，如 `1.2::tag`。
  static String stripWeightPrefix(String tag) {
    final weightMatch = weightPrefixPattern.firstMatch(tag);
    if (weightMatch == null) return tag;
    return tag.substring(weightMatch.end);
  }

  /// 去掉自动补全输入开头的括号前缀，不改变大小写。
  static String normalizeAutocompleteTag(String tag) {
    return stripWeightPrefix(tag.trim())
        .replaceAll(_leadingBracketPattern, '')
        .trim();
  }

  /// 标准化画廊搜索文本；下划线按空格处理以便包含匹配。
  static String normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(weightPattern, ' ')
        .replaceAll(_searchSeparatorPattern, ' ')
        .replaceAll(_bracketPattern, ' ')
        .replaceAll(_whitespacePattern, ' ')
        .trim();
  }

  /// 标准化标签匹配文本。
  static String normalizeTagForMatch(String value) {
    return normalizeSearchText(value)
        .replaceAll(_colonPattern, ' ')
        .replaceAll(_whitespacePattern, ' ')
        .trim();
  }

  /// 标准化数据库逗号分段搜索；保留下划线以便生成空格/下划线两种变体。
  static String normalizeDelimitedSearchSegment(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(weightPattern, ' ')
        .replaceAll(_delimitedSearchSeparatorPattern, ' ')
        .replaceAll(_bracketPattern, ' ')
        .replaceAll(_whitespacePattern, ' ')
        .trim();
  }

  static List<String> parseDelimitedSearchSegments(String value) {
    return value
        .split(_commaSeparatorPattern)
        .map(normalizeSearchText)
        .where((segment) => segment.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
