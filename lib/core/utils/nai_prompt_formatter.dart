/// 括号位置信息
class _BracketPos {
  final String char;
  final int position;
  
  _BracketPos(this.char, this.position);
}

/// NAI 提示词格式化工具
/// 将提示词转换为 NAI 标准格式（使用下划线，补齐括号等）
class NaiPromptFormatter {
  /// 格式化单个标签为 NAI 格式
  /// 将空格转换为下划线
  static String formatTag(String tag) {
    return tag.trim().replaceAll(' ', '_');
  }

  /// 格式化整个提示词
  /// - 将标签中的空格转换为下划线
  /// - 补齐未闭合的括号
  /// - 补齐未完成的权重冒号
  static String format(String prompt) {
    if (prompt.isEmpty) return prompt;

    var result = prompt;

    // 1. 处理每个逗号分隔的标签
    result = _formatTags(result);

    // 2. 补齐未闭合的括号
    result = _balanceBrackets(result);

    // 3. 补齐未完成的权重冒号
    result = _balanceWeightColons(result);

    // 4. 清理格式
    result = _cleanupFormat(result);

    return result;
  }

  /// 格式化标签（将空格转为下划线，但保护特殊语法）
  static String _formatTags(String prompt) {
    final buffer = StringBuffer();
    var inSpecialSyntax = false;
    var braceDepth = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    var inWeight = false;

    for (var i = 0; i < prompt.length; i++) {
      final char = prompt[i];

      // 跟踪括号深度
      if (char == '{') {
        braceDepth++;
        inSpecialSyntax = braceDepth > 0 || bracketDepth > 0;
      } else if (char == '}') {
        braceDepth--;
        inSpecialSyntax = braceDepth > 0 || bracketDepth > 0;
      } else if (char == '[') {
        bracketDepth++;
        inSpecialSyntax = braceDepth > 0 || bracketDepth > 0;
      } else if (char == ']') {
        bracketDepth--;
        inSpecialSyntax = braceDepth > 0 || bracketDepth > 0;
      } else if (char == '(') {
        parenDepth++;
      } else if (char == ')') {
        parenDepth--;
      }

      // 检查是否在权重语法中
      if (char == ':' && i + 1 < prompt.length && prompt[i + 1] == ':') {
        inWeight = !inWeight;
      }

      // 将空格转换为下划线（在标签内部，非分隔位置）
      if (char == ' ') {
        // 检查前后字符来判断是否是标签内部的空格
        final prevChar = i > 0 ? prompt[i - 1] : '';
        final nextChar = i + 1 < prompt.length ? prompt[i + 1] : '';

        // 如果是逗号后的空格，保留
        if (prevChar == ',') {
          buffer.write(char);
        }
        // 如果后面是逗号，保留
        else if (nextChar == ',') {
          buffer.write(char);
        }
        // 如果在括号边界，保留
        else if (prevChar == '{' ||
            prevChar == '[' ||
            prevChar == '(' ||
            nextChar == '}' ||
            nextChar == ']' ||
            nextChar == ')') {
          buffer.write(char);
        }
        // 如果是双竖线语法中的空格，保留
        else if (prevChar == '|' || nextChar == '|') {
          buffer.write(char);
        }
        // 如果在权重语法中，保留
        else if (inWeight) {
          buffer.write(char);
        }
        // 其他情况，将空格转为下划线
        else {
          buffer.write('_');
        }
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// 补齐未闭合的括号
  /// 智能补齐：在逗号前闭合所有未闭合的括号，只处理真正未闭合的括号
  static String _balanceBrackets(String prompt) {
    // 第一遍：标记所有已配对的括号位置
    final pairedPositions = <int>{};
    final stack = <_BracketPos>[];
    
    for (var i = 0; i < prompt.length; i++) {
      final char = prompt[i];
      
      if (char == '{' || char == '[' || char == '(') {
        stack.add(_BracketPos(char, i));
      } else if (char == '}' || char == ']' || char == ')') {
        final expectedOpen = _getMatchingOpen(char);
        
        // 从栈顶找匹配的开括号
        for (var j = stack.length - 1; j >= 0; j--) {
          if (stack[j].char == expectedOpen) {
            // 标记这对括号为已配对
            pairedPositions.add(stack[j].position);
            pairedPositions.add(i);
            stack.removeAt(j);
            break;
          }
        }
      }
    }
    
    // 第二遍：遍历字符串，遇到逗号时闭合未配对的开括号
    final result = StringBuffer();
    final unclosedStack = <String>[]; // 未闭合的开括号
    final prependOpens = <String>[]; // 需要在开头添加的开括号
    
    for (var i = 0; i < prompt.length; i++) {
      final char = prompt[i];
      
      if (char == '{' || char == '[' || char == '(') {
        if (!pairedPositions.contains(i)) {
          // 这是一个未配对的开括号
          unclosedStack.add(char);
        }
        result.write(char);
      } else if (char == '}' || char == ']' || char == ')') {
        if (!pairedPositions.contains(i)) {
          // 这是一个多余的闭括号，在开头添加对应的开括号
          prependOpens.add(_getMatchingOpen(char));
        }
        result.write(char);
      } else if (char == ',') {
        // 遇到逗号，先闭合所有未配对的开括号（从内到外）
        for (var j = unclosedStack.length - 1; j >= 0; j--) {
          result.write(_getMatchingClose(unclosedStack[j]));
        }
        unclosedStack.clear();
        result.write(char);
      } else {
        result.write(char);
      }
    }
    
    // 在末尾闭合剩余的未配对开括号
    for (var j = unclosedStack.length - 1; j >= 0; j--) {
      result.write(_getMatchingClose(unclosedStack[j]));
    }
    
    // 在开头添加多余闭括号对应的开括号
    var finalResult = result.toString();
    for (final open in prependOpens.reversed) {
      finalResult = open + finalResult;
    }
    
    return finalResult;
  }
  
  /// 获取匹配的开括号
  static String _getMatchingOpen(String close) {
    switch (close) {
      case '}': return '{';
      case ']': return '[';
      case ')': return '(';
      default: return '';
    }
  }
  
  /// 获取匹配的闭括号
  static String _getMatchingClose(String open) {
    switch (open) {
      case '{': return '}';
      case '[': return ']';
      case '(': return ')';
      default: return '';
    }
  }

  /// 补齐未完成的权重冒号
  static String _balanceWeightColons(String prompt) {
    var result = prompt;

    // 查找未闭合的 :: 权重语法
    final weightStartPattern = RegExp(r'-?\d+\.?\d*::');
    final matches = weightStartPattern.allMatches(result).toList();

    for (final match in matches) {
      final afterMatch = result.substring(match.end);
      // 查找是否有闭合的 ::
      if (!afterMatch.contains('::')) {
        // 在末尾添加 ::
        result += '::';
        break; // 一次只修复一个
      }
    }

    // 检查 NAI 随机化语法 ||...||
    final pipeCount = '||'.allMatches(result).length;
    if (pipeCount % 2 != 0) {
      result += '||';
    }

    return result;
  }

  /// 清理格式
  static String _cleanupFormat(String prompt) {
    var result = prompt;

    // 将中文逗号转换为英文逗号
    result = result.replaceAll('，', ',');

    // 移除连续的下划线
    result = result.replaceAll(RegExp(r'_+'), '_');

    // 移除标签开头和结尾的下划线
    result = result.replaceAllMapped(
      RegExp(r'(^|,\s*)_+'),
      (m) => m.group(1) ?? '',
    );
    result = result.replaceAllMapped(
      RegExp(r'_+(\s*,|$)'),
      (m) => m.group(1) ?? '',
    );

    // 统一逗号格式
    result = result.replaceAll(RegExp(r'\s*,\s*'), ', ');

    // 移除首尾空白
    result = result.trim();

    // 移除末尾的逗号
    result = result.replaceAll(RegExp(r',\s*$'), '');

    return result;
  }
}

