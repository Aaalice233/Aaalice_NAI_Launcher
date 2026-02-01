import 'text_space_converter.dart';

/// 括号条目，记录开括号时的位置和对应的闭括号位置
class _BracketEntry {
  final int startPosition;
  final int closeIndex;
  
  _BracketEntry(
    this.startPosition,
    this.closeIndex,
  );
}

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

  /// 检测文本是否包含SD权重语法
  /// 
  /// 使用启发式规则区分真正的 SD 权重括号和 Danbooru 标签中的括号：
  /// - 标签名中的括号：前面是下划线，内部是标签名（无空格），如 `character_(series)`
  /// - SD 权重括号：前后有空格/逗号，或内部有空格，或有明确的权重值，或多层嵌套
  static bool hasSDWeightSyntax(String text) {
    // 首先检查明确的 SD 权重语法：(text:weight)
    if (_hasExplicitWeightSyntax(text)) {
      return true;
    }

    // 然后检查可能的权重括号（排除标签名中的括号）
    return _hasProbableWeightBrackets(text);
  }

  /// 检测明确的权重语法：(text:weight) 或 [text:weight]
  static bool _hasExplicitWeightSyntax(String text) {
    // 匹配 (text:1.5) 或 [text:0.8] 这种明确指定权重的格式
    final explicitWeightPattern = RegExp(
      r'[\(\[]\s*[^\(\)\[\]:]+\s*:\s*[+-]?\d+\.?\d*\s*[\)\]]',
    );
    return explicitWeightPattern.hasMatch(text);
  }

  /// 检测可能的权重括号（排除标签名中的括号）
  static bool _hasProbableWeightBrackets(String text) {
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      
      // 只处理开括号
      if (char != '(' && char != '[') continue;
      
      // 检查是否是转义字符（前面有奇数个反斜杠）
      if (_isEscaped(text, i)) continue;

      final isRound = char == '(';
      final closeChar = isRound ? ')' : ']';
      
      // 找到对应的闭括号
      final closeIndex = _findMatchingCloseBracket(text, i, char, closeChar);
      if (closeIndex == -1) continue; // 未闭合，跳过

      final content = text.substring(i + 1, closeIndex);
      
      // 判断这是否是标签名中的括号
      if (_isTagNameBracket(text, i, closeIndex, content)) {
        continue; // 是标签名括号，跳过
      }

      // 是 SD 权重括号
      return true;
    }
    return false;
  }

  /// 检查字符是否被转义
  static bool _isEscaped(String text, int index) {
    if (index == 0) return false;
    var backslashCount = 0;
    for (var j = index - 1; j >= 0 && text[j] == r'\'; j--) {
      backslashCount++;
    }
    return backslashCount % 2 == 1;
  }

  /// 找到匹配的闭括号位置
  static int _findMatchingCloseBracket(
    String text,
    int openIndex,
    String openChar,
    String closeChar,
  ) {
    var depth = 1;
    for (var i = openIndex + 1; i < text.length; i++) {
      if (text[i] == openChar && !_isEscaped(text, i)) {
        depth++;
      } else if (text[i] == closeChar && !_isEscaped(text, i)) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1; // 未找到
  }

  /// 判断括号是否是标签名的一部分（Danbooru 标签命名规范）
  /// 
  /// 标签名括号的特征：
  /// 1. 前面是下划线 `character_(`
  /// 2. 内部内容符合标签名规范（字母、数字、下划线、连字符，无空格）
  /// 3. 内部不包含逗号（单个标签）
  /// 4. 不是多层嵌套
  static bool _isTagNameBracket(String text, int openIndex, int closeIndex, String content) {
    // 检查前面是否是下划线
    final hasUnderscoreBefore = openIndex > 0 && text[openIndex - 1] == '_';
    
    // 检查内部是否包含空格或逗号（标签名中通常不会有）
    final hasSpaceOrComma = content.contains(RegExp(r'[\s,]'));
    
    // 检查内部是否是合法的标签名格式
    // 标签名通常由字母、数字、下划线、连字符组成
    final isValidTagContent = RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(content.trim());
    
    // 检查内部是否包含嵌套括号（标签名中不会有）
    final hasNestedBrackets = content.contains('(') || 
                              content.contains(')') || 
                              content.contains('[') || 
                              content.contains(']');
    
    // 标签名括号的判断：前面有下划线 + 内部是合法标签内容 + 无空格/逗号 + 无嵌套
    if (hasUnderscoreBefore && isValidTagContent && !hasSpaceOrComma && !hasNestedBrackets) {
      return true;
    }
    
    // 额外检查：即使前面没有下划线，如果内部明显是标签名格式（如 series_name）
    // 且前后都是下划线或边界，也认为是标签名括号
    final beforeChar = openIndex > 0 ? text[openIndex - 1] : '';
    final afterChar = closeIndex < text.length - 1 ? text[closeIndex + 1] : '';
    
    if ((beforeChar == '_' || beforeChar == '' || beforeChar == ' ' || beforeChar == ',') &&
        (afterChar == '_' || afterChar == '' || afterChar == ' ' || afterChar == ',') &&
        isValidTagContent && 
        !hasSpaceOrComma && 
        !hasNestedBrackets &&
        content.contains('_')) {
      // 内部包含下划线，说明可能是 series_name 或 copyright_name
      return true;
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
  ///
  /// 注意：只负责 SD 语法转换，不做通用空格转换
  /// 通用空格转下划线由 NaiPromptFormatter 统一负责
  static String convert(String text) {
    // 只有当有SD语法且没有NAI语法时，才执行转换
    if (hasSDWeightSyntax(text) && !hasNAISyntax(text)) {
      final parsed = _parsePromptAttention(text);
      return _buildNaiV4(parsed);
    }

    // 其他情况直接返回原文，不做任何处理
    return text;
  }

  /// 解析SD权重语法
  /// 返回 List<[text, weight]>
  /// 
  /// 注意：此方法会正确处理标签名中的括号（如 character_(series)）
  static List<List<dynamic>> _parsePromptAttention(String text) {
    final res = <List<dynamic>>[];
    final roundBracketStack = <_BracketEntry>[];
    final squareBracketStack = <_BracketEntry>[];

    void multiplyRange(int startPosition, double multiplier) {
      for (var p = startPosition; p < res.length; p++) {
        res[p][1] = (res[p][1] as double) * multiplier;
      }
    }

    var i = 0;
    while (i < text.length) {
      final char = text[i];

      // 检查是否是转义序列
      if (char == r'\' && i + 1 < text.length) {
        final nextChar = text[i + 1];
        if (nextChar == '(' || nextChar == ')' || nextChar == '[' || nextChar == ']') {
          // 转义括号：保留原字符，移除反斜杠
          res.add([nextChar, 1.0]);
          i += 2;
          continue;
        } else if (nextChar == r'\') {
          // 转义的反斜杠：保留一个反斜杠
          res.add([r'\', 1.0]);
          i += 2;
          continue;
        }
      }

      // 处理开括号
      if (char == '(' || char == '[') {
        final isRound = char == '(';
        final closeChar = isRound ? ')' : ']';
        
        // 找到对应的闭括号
        final closeIndex = _findMatchingCloseBracket(text, i, char, closeChar);
        if (closeIndex == -1) {
          // 未闭合，作为普通文本
          res.add([char, 1.0]);
          i++;
          continue;
        }

        final content = text.substring(i + 1, closeIndex);
        
        // 检查是否是标签名中的括号
        if (_isTagNameBracket(text, i, closeIndex, content)) {
          // 标签名括号：作为普通文本处理，内容会在后续循环中处理
          res.add([char, 1.0]);
          i++;
          continue;
        }

        // 检查是否是 (text:weight) 明确权重格式
        final explicitWeight = _extractExplicitWeight(content);
        if (explicitWeight != null) {
          // 明确权重格式：直接添加带权重的文本
          var actualContent = content.substring(0, content.lastIndexOf(':'));
          // 处理内容中的转义字符
          actualContent = _processEscapes(actualContent.trim());
          res.add([actualContent, explicitWeight]);
          // 跳过整个括号
          i = closeIndex + 1;
          continue;
        }

        // SD 权重括号：记录位置，内容正常处理（权重在闭括号时应用）
        final bracketList = isRound ? roundBracketStack : squareBracketStack;
        bracketList.add(_BracketEntry(res.length, closeIndex));
        i++;
        continue;
      }

      // 处理闭括号
      if (char == ')') {
        // 检查是否是SD权重括号的闭括号
        final matchingEntryIndex = roundBracketStack.indexWhere((e) => e.closeIndex == i);
        if (matchingEntryIndex != -1) {
          // 移除该括号条目（以及可能嵌套在其内部的所有条目）
          final entry = roundBracketStack.removeAt(matchingEntryIndex);
          // 对从开括号位置到当前的所有内容应用权重
          multiplyRange(entry.startPosition, _roundBracketMultiplier);
        } else {
          // 没有匹配的开括号，作为普通文本
          res.add([char, 1.0]);
        }
        i++;
        continue;
      }

      if (char == ']') {
        // 检查是否是SD权重括号的闭括号
        final matchingEntryIndex = squareBracketStack.indexWhere((e) => e.closeIndex == i);
        if (matchingEntryIndex != -1) {
          // 移除该括号条目（以及可能嵌套在其内部的所有条目）
          final entry = squareBracketStack.removeAt(matchingEntryIndex);
          // 对从开括号位置到当前的所有内容应用权重
          multiplyRange(entry.startPosition, _squareBracketMultiplier);
        } else {
          // 没有匹配的开括号，作为普通文本
          res.add([char, 1.0]);
        }
        i++;
        continue;
      }

      // 普通文本字符
      res.add([char, 1.0]);
      i++;
    }

    // 处理未闭合的括号（对res中从记录位置开始的所有内容应用权重）
    for (final entry in roundBracketStack) {
      multiplyRange(entry.startPosition, _roundBracketMultiplier);
    }
    for (final entry in squareBracketStack) {
      multiplyRange(entry.startPosition, _squareBracketMultiplier);
    }

    if (res.isEmpty) {
      res.add(['', 1.0]);
    }

    // 合并连续文本
    return _mergeConsecutiveChars(res);
  }

  /// 处理文本中的转义字符
  /// 将 \( \) \[ \] \\ 转换为 ( ) [ ] \
  static String _processEscapes(String text) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (text[i] == r'\' && i + 1 < text.length) {
        final nextChar = text[i + 1];
        if (nextChar == '(' || nextChar == ')' || nextChar == '[' || nextChar == ']' || nextChar == r'\') {
          buffer.write(nextChar);
          i += 2;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }
    return buffer.toString();
  }

  /// 从括号内容中提取明确的权重值
  /// 匹配格式: "text:weight" 返回 weight
  /// 如果不是明确权重格式，返回 null
  static double? _extractExplicitWeight(String content) {
    // 查找最后一个冒号
    final colonIndex = content.lastIndexOf(':');
    if (colonIndex == -1 || colonIndex == 0 || colonIndex == content.length - 1) {
      return null;
    }

    final beforeColon = content.substring(0, colonIndex).trim();
    final afterColon = content.substring(colonIndex + 1).trim();

    // 检查冒号后面是否是有效的数字
    final weight = double.tryParse(afterColon);
    if (weight == null) {
      return null;
    }

    // 检查冒号前面是否有内容
    if (beforeColon.isEmpty) {
      return null;
    }

    // 确保冒号前面没有嵌套的权重语法（避免误解析）
    // 如果前面还有冒号，可能是嵌套或其他格式，不处理
    if (beforeColon.contains(':')) {
      return null;
    }

    return weight;
  }

  /// 合并连续的字符为字符串
  static List<List<dynamic>> _mergeConsecutiveChars(List<List<dynamic>> chars) {
    if (chars.isEmpty) return chars;

    final res = <List<dynamic>>[];
    final buffer = StringBuffer();
    double currentWeight = 1.0;

    for (final item in chars) {
      final char = item[0] as String;
      final weight = item[1] as double;

      if ((weight - currentWeight).abs() < 0.00001) {
        // 权重相同，追加到缓冲区
        buffer.write(char);
      } else {
        // 权重不同，保存之前的缓冲区
        if (buffer.isNotEmpty) {
          res.add([buffer.toString(), currentWeight]);
          buffer.clear();
        }
        buffer.write(char);
        currentWeight = weight;
      }
    }

    // 保存最后的内容
    if (buffer.isNotEmpty) {
      res.add([buffer.toString(), currentWeight]);
    }

    // 合并相同权重的连续项（二次确认）
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

      // 处理转义字符
      s = _processEscapes(s);

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
    return TextSpaceConverter.convert(
      text,
      protectChars: TextSpaceConverter.naiFormat,
    );
  }
}
