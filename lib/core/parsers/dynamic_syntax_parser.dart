import 'dart:math';

import '../../core/utils/app_logger.dart';

/// NAI 动态语法解析器
///
/// 解析 NovelAI 的随机语法格式：
/// - `||A|B||` - 在 A 和 B 之间随机选择一个
/// - `||n$$A|B|C||` - 随机选择 n 个不重复的选项
/// - 支持嵌套结构
/// - 最大递归深度: 10
class DynamicSyntaxParser {
  /// 最大递归深度
  static const int maxRecursionDepth = 10;

  /// 匹配 ||...|| 语法的正则
  static final RegExp _syntaxPattern = RegExp(r'\|\|([^|]+(?:\|[^|]+)*)\|\|');

  /// 匹配计数语法 n$$
  static final RegExp _countPattern = RegExp(r'^(\d+)\$\$(.+)$');

  final Random _random = Random();

  /// 解析单个语法块
  ///
  /// [input] 输入字符串，包含或不含语法
  /// 返回解析结果
  ParseResult parse(String input) {
    if (input.isEmpty) {
      return ParseResult(
        original: '',
        options: [],
        count: 1,
        beforeSyntax: '',
        afterSyntax: '',
        isValidSyntax: false,
      );
    }

    final match = _syntaxPattern.firstMatch(input);
    if (match == null) {
      return ParseResult(
        original: input,
        options: [],
        count: 1,
        beforeSyntax: input,
        afterSyntax: '',
        isValidSyntax: false,
      );
    }

    final fullMatch = match.group(0)!;
    final content = match.group(1)!;
    final before = input.substring(0, match.start);
    final after = input.substring(match.end);

    // 解析计数语法
    int count = 1;
    List<String> options;
    final countMatch = _countPattern.firstMatch(content);
    if (countMatch != null) {
      count = int.parse(countMatch.group(1)!);
      final optionsStr = countMatch.group(2)!;
      options = _splitOptions(optionsStr);
    } else {
      options = _splitOptions(content);
    }

    return ParseResult(
      original: fullMatch,
      options: options,
      count: count,
      beforeSyntax: before,
      afterSyntax: after,
      isValidSyntax: options.isNotEmpty,
    );
  }

  /// 解析多个语法块
  ///
  /// [input] 输入字符串，可能包含多个 ||...|| 块
  /// 返回所有解析结果的列表
  List<ParseResult> parseMultiple(String input) {
    final results = <ParseResult>[];
    var remaining = input;

    while (remaining.isNotEmpty) {
      final match = _syntaxPattern.firstMatch(remaining);
      if (match == null) break;

      // 添加语法块之前的文本作为单独的纯文本结果
      final before = remaining.substring(0, match.start);
      if (before.isNotEmpty) {
        results.add(
          ParseResult(
            original: before,
            options: [],
            count: 1,
            beforeSyntax: before,
            afterSyntax: '',
            isValidSyntax: false,
          ),
        );
      }

      // 解析语法块
      final syntaxResult = parse(match.group(0)!);
      results.add(syntaxResult);

      remaining = remaining.substring(match.end);
    }

    // 添加剩余的纯文本
    if (remaining.isNotEmpty) {
      results.add(
        ParseResult(
          original: remaining,
          options: [],
          count: 1,
          beforeSyntax: remaining,
          afterSyntax: '',
          isValidSyntax: false,
        ),
      );
    }

    return results;
  }

  /// 分割选项列表
  ///
  /// 处理嵌套的 ||...|| 结构
  List<String> _splitOptions(String content) {
    final options = <String>[];
    final buffer = StringBuffer();
    const depth = 0;
    var i = 0;

    while (i < content.length) {
      final char = content[i];

      if (char == '|' && depth == 0) {
        // 遇到分隔符，保存当前选项
        final option = buffer.toString().trim();
        if (option.isNotEmpty) {
          options.add(option);
        }
        buffer.clear();
        i++;
        continue;
      }

      if (char == '|') {
        if (i + 1 < content.length && content[i + 1] == '|') {
          // 检测到嵌套语法 ||...||
          buffer.write('||');
          i += 2;
          continue;
        }
      }

      buffer.write(char);
      i++;
    }

    // 保存最后一个选项
    final lastOption = buffer.toString().trim();
    if (lastOption.isNotEmpty) {
      options.add(lastOption);
    }

    return options;
  }

  /// 递归解析嵌套语法
  ///
  /// [input] 输入字符串
  /// [depth] 当前递归深度
  /// 返回展开后的字符串
  String resolveNested(String input, [int depth = 0]) {
    if (depth > maxRecursionDepth) {
      AppLogger.w(
        'Max recursion depth exceeded in DynamicSyntaxParser',
        'Parser',
      );
      return input;
    }

    final result = parse(input);
    if (!result.isValidSyntax) {
      // 尝试解析嵌套内容
      final nested = _resolveNestedInContent(input, depth);
      return nested;
    }

    // 随机选择一个选项
    final selected = result.getRandomSelection();
    return resolveNested(selected, depth + 1);
  }

  /// 递归解析内容中的嵌套语法
  String _resolveNestedInContent(String input, int depth) {
    var result = input;
    final matches = _syntaxPattern.allMatches(input).toList();

    for (final match in matches.reversed) {
      final nestedResult = parse(match.group(0)!);
      final selected = nestedResult.getRandomSelection();
      result = result.replaceRange(match.start, match.end, selected);
    }

    return result;
  }

  /// 生成随机选择（用于测试）
  String getRandomSelection(List<String> options, [int count = 1]) {
    if (options.isEmpty) return '';
    if (count >= options.length) {
      final shuffled = [...options]..shuffle(_random);
      return shuffled.join(', ');
    }

    final selected = <String>[];
    final remaining = [...options];

    for (var i = 0; i < count && remaining.isNotEmpty; i++) {
      final index = _random.nextInt(remaining.length);
      selected.add(remaining.removeAt(index));
    }

    return selected.join(', ');
  }
}

/// 解析结果
class ParseResult {
  /// 原始匹配的语法块
  final String original;

  /// 解析出的选项列表
  final List<String> options;

  /// 要选择的数量
  final int count;

  /// 语法块之前的文本
  final String beforeSyntax;

  /// 语法块之后的文本
  final String afterSyntax;

  /// 是否为有效的语法
  final bool isValidSyntax;

  ParseResult({
    required this.original,
    required this.options,
    required this.count,
    required this.beforeSyntax,
    required this.afterSyntax,
    required this.isValidSyntax,
  });

  /// 获取单个随机选择
  String getRandomSelection([Random? random]) {
    if (options.isEmpty) return '';
    random ??= Random();
    return options[random.nextInt(options.length)];
  }

  /// 获取多个不重复的随机选择
  List<String> getRandomSelectionMultiple(int count, [Random? random]) {
    if (options.isEmpty) return [];
    random ??= Random();

    if (count >= options.length) {
      return [...options]..shuffle(random);
    }

    final selected = <String>[];
    final remaining = [...options];

    for (var i = 0; i < count && remaining.isNotEmpty; i++) {
      final index = random.nextInt(remaining.length);
      selected.add(remaining.removeAt(index));
    }

    return selected;
  }

  @override
  String toString() {
    return 'ParseResult(options: $options, count: $count, isValid: $isValidSyntax)';
  }
}
