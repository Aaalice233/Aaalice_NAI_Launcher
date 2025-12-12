/// SD权重语法到NAI V4数值语法的转换工具
///
/// 转换规则：
/// - SD格式: (text:1.5) 或 (text) 或 [text]
/// - NAI V4格式: 1.5::text::
///
/// 参考: https://github.com/Metachs/sdwebui-nai-api
class SdToNaiConverter {
  SdToNaiConverter._();

  /// SD圆括号默认权重倍数
  static const double _roundBracketMultiplier = 1.1;

  /// SD方括号默认权重倍数
  static const double _squareBracketMultiplier = 1 / 1.1; // ≈ 0.909

  /// 正则表达式匹配SD注意力语法
  /// 匹配: \( \) \[ \] \\ \ ( [ :weight) ) ] 或普通文本
  static final RegExp _reAttention = RegExp(
    r'\\\(|'      // 转义的 (
    r'\\\)|'      // 转义的 )
    r'\\\[|'      // 转义的 [
    r'\\]|'       // 转义的 ]
    r'\\\\|'      // 转义的 \
    r'\\|'        // 单独的 \
    r'\(|'        // 开括号
    r'\[|'        // 开方括号
    r':\s*([+-]?[.\d]+)\s*\)|'  // :weight) 格式
    r'\)|'        // 闭括号
    r']|'         // 闭方括号
    r'[^\\()\[\]:]+|'  // 普通文本
    r':',         // 冒号
  );

  /// 检测文本是否包含SD权重语法
  static bool hasSDWeightSyntax(String text) {
    // 使用简单遍历检测未转义的SD权重括号
    // 避免使用负向后瞻（某些平台不支持）
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      // 检查是否是转义字符
      if (i > 0 && text[i - 1] == r'\') {
        // 但需要确认前面的 \ 不是被转义的 \\
        var backslashCount = 0;
        for (var j = i - 1; j >= 0 && text[j] == r'\'; j--) {
          backslashCount++;
        }
        // 奇数个反斜杠说明当前字符被转义
        if (backslashCount % 2 == 1) continue;
      }
      // 找到未转义的 ( 或 [
      if (char == '(' || char == '[') {
        return true;
      }
    }
    return false;
  }

  /// 检测文本是否已经包含NAI语法
  static bool hasNAISyntax(String text) {
    // NAI V4数值语法: weight::text:: (数字后跟双冒号，支持 1.5:: 或 .5:: 格式)
    if (RegExp(r'-?(?:\d+\.?\d*|\.\d+)::').hasMatch(text)) return true;

    // NAI花括号语法: 检测成对的花括号 {...}
    // 简单检查：有 { 后面跟着 }（允许嵌套）
    var braceDepth = 0;
    var foundClosedBrace = false;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '{') {
        braceDepth++;
      } else if (text[i] == '}') {
        if (braceDepth > 0) {
          braceDepth--;
          foundClosedBrace = true;
        }
      }
    }
    if (foundClosedBrace) return true;

    return false;
  }

  /// SD语法转NAI V4数值语法
  ///
  /// 示例:
  /// - `(text:1.5)` → `1.5::text::`
  /// - `(long hair)` → `1.1::long_hair::`
  /// - `[ugly]` → `0.91::ugly::`
  /// - `\(text\)` → `(text)` (转义符保留)
  static String convert(String text) {
    // 如果有SD语法且没有NAI语法，执行完整的SD→NAI转换（内部包含空格转换）
    if (hasSDWeightSyntax(text) && !hasNAISyntax(text)) {
      final parsed = _parsePromptAttention(text);
      return _buildNaiV4(parsed);
    }

    // 其他情况（无SD语法、已有NAI语法、或混合语法），只转换空格为下划线
    return _convertSpacesToUnderscores(text);
  }

  /// 解析SD权重语法
  /// 返回 List<[text, weight]>
  static List<List<dynamic>> _parsePromptAttention(String text) {
    final res = <List<dynamic>>[];
    final roundBrackets = <int>[];
    final squareBrackets = <int>[];

    void multiplyRange(int startPosition, double multiplier) {
      for (var p = startPosition; p < res.length; p++) {
        res[p][1] = (res[p][1] as double) * multiplier;
      }
    }

    for (final m in _reAttention.allMatches(text)) {
      final matchText = m.group(0)!;
      final weight = m.group(1);

      if (matchText.startsWith(r'\')) {
        // 转义字符：移除反斜杠
        res.add([matchText.substring(1), 1.0]);
      } else if (matchText == '(') {
        roundBrackets.add(res.length);
      } else if (matchText == '[') {
        squareBrackets.add(res.length);
      } else if (weight != null) {
        // :weight) 格式
        if (roundBrackets.isNotEmpty) {
          final w = double.tryParse(weight);
          if (w != null) {
            multiplyRange(roundBrackets.removeLast(), w);
          }
        } else {
          // 没有匹配的开括号，作为普通文本处理
          res.add([matchText, 1.0]);
        }
      } else if (matchText == ')' && roundBrackets.isNotEmpty) {
        multiplyRange(roundBrackets.removeLast(), _roundBracketMultiplier);
      } else if (matchText == ']' && squareBrackets.isNotEmpty) {
        multiplyRange(squareBrackets.removeLast(), _squareBracketMultiplier);
      } else {
        res.add([matchText, 1.0]);
      }
    }

    // 处理未闭合的括号
    for (final pos in roundBrackets) {
      multiplyRange(pos, _roundBracketMultiplier);
    }
    for (final pos in squareBrackets) {
      multiplyRange(pos, _squareBracketMultiplier);
    }

    if (res.isEmpty) {
      res.add(['', 1.0]);
    }

    // 合并相同权重的连续文本（使用容差比较浮点数）
    var i = 0;
    while (i + 1 < res.length) {
      final w1 = res[i][1] as double;
      final w2 = res[i + 1][1] as double;
      if ((w1 - w2).abs() < 0.00001) {
        res[i][0] = '${res[i][0]}${res[i + 1][0]}';
        res.removeAt(i + 1);
      } else {
        i++;
      }
    }

    return res;
  }

  /// 构建NAI V4数值语法
  static String _buildNaiV4(List<List<dynamic>> parsed) {
    final buffer = StringBuffer();
    var isOpen = false;

    for (final item in parsed) {
      var s = item[0] as String;
      final w = item[1] as double;

      // 格式化权重值
      var weightStr = w.toStringAsFixed(5);
      // 移除末尾的0和小数点
      weightStr = weightStr.replaceAll(RegExp(r'0+$'), '');
      weightStr = weightStr.replaceAll(RegExp(r'\.$'), '');

      final hasWeight = weightStr != '1';

      if (hasWeight) {
        // 有权重：使用 weight::text 格式
        s = _convertSpacesToUnderscores(s);

        // 如果前面有打开的权重区域，先关闭它
        if (isOpen) {
          buffer.write('::');
        }

        // 检查是否需要添加分隔符（避免数字混淆）
        var sep = '';
        final combined = '$buffer$weightStr';
        final match = RegExp(r'-?\d*\.?\d*$').firstMatch(combined);
        if (match != null && match.group(0) != weightStr) {
          sep = ' ';
        }

        buffer.write('$sep$weightStr::$s');
        isOpen = true;
      } else {
        // 无权重：直接写入文本
        // 如果前面有打开的权重区域，先关闭它
        if (isOpen) {
          buffer.write('::');
          isOpen = false;
        }
        // 无权重的文本也需要转换空格为下划线
        buffer.write(_convertSpacesToUnderscores(s));
      }
    }

    // 关闭最后的权重区域
    if (isOpen) {
      buffer.write('::');
    }

    return buffer.toString();
  }

  /// 将文本中的空格转换为下划线
  /// 保护特殊位置的空格（逗号旁边等）
  static String _convertSpacesToUnderscores(String text) {
    // 不转换逗号前后的空格
    // 转换标签内部的空格
    final result = StringBuffer();
    final chars = text.split('');

    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];

      if (char == ' ') {
        // 检查是否在逗号附近（需要向前/向后跳过其他空格）
        final prevChar = i > 0 ? chars[i - 1] : '';
        final nextChar = i < chars.length - 1 ? chars[i + 1] : '';

        // 查找前面第一个非空格字符
        String? prevNonSpace;
        for (var j = i - 1; j >= 0; j--) {
          if (chars[j] != ' ') {
            prevNonSpace = chars[j];
            break;
          }
        }

        // 查找后面第一个非空格字符
        String? nextNonSpace;
        for (var j = i + 1; j < chars.length; j++) {
          if (chars[j] != ' ') {
            nextNonSpace = chars[j];
            break;
          }
        }

        // 如果前面的非空格字符是逗号，或后面的非空格字符是逗号，保留空格
        if (prevNonSpace == ',' || nextNonSpace == ',') {
          result.write(char);
        }
        // 如果相邻字符是逗号（向后兼容）
        else if (prevChar == ',' || nextChar == ',') {
          result.write(char);
        } else {
          // 转换为下划线
          result.write('_');
        }
      } else {
        result.write(char);
      }
    }

    return result.toString();
  }
}
