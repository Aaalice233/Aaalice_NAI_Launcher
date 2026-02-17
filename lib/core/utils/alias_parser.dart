// 别名解析器
//
// 负责从文本中识别别名语法并提取引用信息
// 支持 `<词库名称>` 格式，预留随机词库扩展点

/// 别名引用类型
enum AliasReferenceType {
  /// 普通词库引用: <词库名称>
  simple,

  /// 随机词库引用 (预留): <random:词库A,词库B>
  random,

  /// 带权重随机 (预留): <weighted:词库A:2,词库B:1>
  weighted,
}

/// 别名引用信息
class AliasReference {
  /// 引用类型
  final AliasReferenceType type;

  /// 在原文中的起始位置
  final int start;

  /// 在原文中的结束位置
  final int end;

  /// 引用的完整文本 (包括 < >)
  final String rawText;

  /// 引用的词库名称列表
  final List<String> entryNames;

  /// 权重信息 (可选,用于随机词库)
  final Map<String, double>? weights;

  const AliasReference({
    required this.type,
    required this.start,
    required this.end,
    required this.rawText,
    required this.entryNames,
    this.weights,
  });

  /// 获取主要引用名称（第一个）
  String get primaryName => entryNames.isNotEmpty ? entryNames.first : '';

  /// 引用文本长度
  int get length => end - start;

  @override
  String toString() =>
      'AliasReference(type: $type, start: $start, end: $end, names: $entryNames)';
}

/// 别名解析器
///
/// 负责从文本中识别别名语法并提取引用信息
/// 支持嵌套的NAI语法，不会误识别括号内的 < > 符号
class AliasParser {
  /// 正则表达式: 匹配别名语法 <xxx>
  /// 不匹配空内容或只有空格的情况
  static final RegExp _aliasPattern = RegExp(
    r'<([^<>]+?)>',
    multiLine: true,
  );

  /// 解析文本中的所有别名引用
  ///
  /// [text] 待解析的文本
  /// 返回所有找到的别名引用列表
  static List<AliasReference> parse(String text) {
    if (text.isEmpty) return [];

    final references = <AliasReference>[];

    for (final match in _aliasPattern.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      final rawText = match.group(0)!;
      final innerText = match.group(1)!.trim();

      // 跳过空内容
      if (innerText.isEmpty) continue;

      // 检查是否为特殊语法 (预留扩展点)
      if (innerText.startsWith('random:')) {
        final ref = _parseRandomReference(start, end, rawText, innerText);
        if (ref != null) references.add(ref);
      } else if (innerText.startsWith('weighted:')) {
        final ref = _parseWeightedReference(start, end, rawText, innerText);
        if (ref != null) references.add(ref);
      } else {
        // 普通引用
        references.add(
          AliasReference(
            type: AliasReferenceType.simple,
            start: start,
            end: end,
            rawText: rawText,
            entryNames: [innerText],
          ),
        );
      }
    }

    return references;
  }

  /// 获取光标位置处的别名引用
  ///
  /// [text] 文本
  /// [cursorPosition] 光标位置
  /// 返回光标所在的别名引用，若不存在则返回 null
  static AliasReference? getReferenceAtCursor(String text, int cursorPosition) {
    if (text.isEmpty || cursorPosition < 0) return null;

    final references = parse(text);
    for (final ref in references) {
      if (ref.start <= cursorPosition && cursorPosition <= ref.end) {
        return ref;
      }
    }
    return null;
  }

  /// 检查是否正在输入别名 (输入了 < 但未输入 >)
  ///
  /// 返回 (isTyping, partialText, startPosition)
  /// - isTyping: 是否正在输入别名
  /// - partialText: 已输入的部分文本（不包括 <）
  /// - startPosition: < 的位置
  static (bool, String, int) detectPartialAlias(
    String text,
    int cursorPosition,
  ) {
    if (cursorPosition <= 0 || text.isEmpty) {
      return (false, '', -1);
    }

    // 确保光标位置有效
    final effectiveCursor = cursorPosition.clamp(0, text.length);

    // 向前查找最近的 <
    int openBracketPos = -1;
    for (int i = effectiveCursor - 1; i >= 0; i--) {
      final char = text[i];
      if (char == '<') {
        openBracketPos = i;
        break;
      } else if (char == '>' || char == '\n') {
        // 遇到 > 或换行符，停止查找
        break;
      }
    }

    if (openBracketPos == -1) return (false, '', -1);

    // 检查 < 和光标之间是否有 >
    final textBetween = text.substring(openBracketPos, effectiveCursor);
    if (textBetween.contains('>')) {
      return (false, '', -1);
    }

    // 提取部分文本 (去掉 <)
    final partialText = textBetween.substring(1);
    return (true, partialText, openBracketPos);
  }

  /// 验证别名名称是否有效（不包含非法字符）
  static bool isValidAliasName(String name) {
    if (name.isEmpty) return false;
    // 不能包含 < > 和换行符
    return !name.contains('<') &&
        !name.contains('>') &&
        !name.contains('\n') &&
        !name.contains('\r');
  }

  /// 解析随机词库引用 (预留)
  /// 格式: <random:词库A,词库B,词库C>
  static AliasReference? _parseRandomReference(
    int start,
    int end,
    String rawText,
    String innerText,
  ) {
    // 移除 "random:" 前缀
    final content = innerText.substring(7).trim();
    if (content.isEmpty) return null;

    // 按逗号分割词库名称
    final names = content
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (names.isEmpty) return null;

    return AliasReference(
      type: AliasReferenceType.random,
      start: start,
      end: end,
      rawText: rawText,
      entryNames: names,
    );
  }

  /// 解析带权重的随机引用 (预留)
  /// 格式: <weighted:词库A:2,词库B:1>
  static AliasReference? _parseWeightedReference(
    int start,
    int end,
    String rawText,
    String innerText,
  ) {
    // 移除 "weighted:" 前缀
    final content = innerText.substring(9).trim();
    if (content.isEmpty) return null;

    final names = <String>[];
    final weights = <String, double>{};

    // 按逗号分割
    final parts = content.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      // 检查是否有权重
      final colonIndex = trimmed.lastIndexOf(':');
      if (colonIndex > 0) {
        final name = trimmed.substring(0, colonIndex).trim();
        final weightStr = trimmed.substring(colonIndex + 1).trim();
        final weight = double.tryParse(weightStr);

        if (name.isNotEmpty && weight != null && weight > 0) {
          names.add(name);
          weights[name] = weight;
        }
      } else {
        // 没有权重，默认为1
        names.add(trimmed);
        weights[trimmed] = 1.0;
      }
    }

    if (names.isEmpty) return null;

    return AliasReference(
      type: AliasReferenceType.weighted,
      start: start,
      end: end,
      rawText: rawText,
      entryNames: names,
      weights: weights,
    );
  }
}
