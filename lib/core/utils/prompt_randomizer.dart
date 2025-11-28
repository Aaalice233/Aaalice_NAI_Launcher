import 'dart:math';

/// 提示词随机化处理器
/// 处理本地随机化语法 {随机...随机}
class PromptRandomizer {
  static final Random _random = Random();

  /// 处理本地随机化语法
  /// 将 {随机option1|option2|option3随机} 替换为随机选择的选项
  /// 支持嵌套
  static String process(String prompt) {
    if (!prompt.contains('{随机')) {
      return prompt;
    }

    var result = prompt;
    var maxIterations = 100; // 防止无限循环

    // 循环处理嵌套的随机化语法（从内到外）
    while (result.contains('{随机') && maxIterations > 0) {
      result = _processInnermost(result);
      maxIterations--;
    }

    return result;
  }

  /// 处理最内层的随机化语法
  static String _processInnermost(String text) {
    // 查找最内层的 {随机...随机}（不包含嵌套）
    final pattern = RegExp(r'\{随机([^{]*?)随机\}');
    final match = pattern.firstMatch(text);

    if (match == null) {
      return text;
    }

    final content = match.group(1)!;
    final options = _parseOptions(content);

    if (options.isEmpty) {
      // 如果没有有效选项，移除整个语法
      return text.replaceFirst(match.group(0)!, '');
    }

    // 随机选择一个选项
    final selectedOption = options[_random.nextInt(options.length)].trim();

    return text.replaceFirst(match.group(0)!, selectedOption);
  }

  /// 解析选项，处理嵌套的竖线
  static List<String> _parseOptions(String content) {
    final options = <String>[];
    final buffer = StringBuffer();
    var depth = 0; // 追踪嵌套深度

    for (var i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == '{') {
        depth++;
        buffer.write(char);
      } else if (char == '}') {
        depth--;
        buffer.write(char);
      } else if (char == '|' && depth == 0) {
        // 只有在顶层时才分割
        final option = buffer.toString().trim();
        if (option.isNotEmpty) {
          options.add(option);
        }
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // 添加最后一个选项
    final lastOption = buffer.toString().trim();
    if (lastOption.isNotEmpty) {
      options.add(lastOption);
    }

    return options;
  }

  /// 处理多个提示词（批量生成）
  /// 返回指定数量的随机化后的提示词
  static List<String> processMultiple(String prompt, int count) {
    final results = <String>[];
    for (var i = 0; i < count; i++) {
      results.add(process(prompt));
    }
    return results;
  }

  /// 检查提示词是否包含本地随机化语法
  static bool containsLocalRandom(String prompt) {
    return prompt.contains('{随机') && prompt.contains('随机}');
  }

  /// 获取所有可能的组合数量（估算）
  /// 注意：嵌套语法可能导致数量不准确
  static int estimateCombinations(String prompt) {
    if (!containsLocalRandom(prompt)) {
      return 1;
    }

    var combinations = 1;
    final pattern = RegExp(r'\{随机([^{]*?)随机\}');
    final matches = pattern.allMatches(prompt);

    for (final match in matches) {
      final content = match.group(1)!;
      final options = _parseOptions(content);
      if (options.isNotEmpty) {
        combinations *= options.length;
      }
    }

    return combinations;
  }

  /// 预览所有随机化位置
  /// 返回 Map<位置描述, 选项列表>
  static Map<String, List<String>> previewRandomPositions(String prompt) {
    final result = <String, List<String>>{};
    final pattern = RegExp(r'\{随机([^{]*?)随机\}');
    final matches = pattern.allMatches(prompt);

    var index = 1;
    for (final match in matches) {
      final content = match.group(1)!;
      final options = _parseOptions(content);
      result['位置 $index'] = options;
      index++;
    }

    return result;
  }
}

