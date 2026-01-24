/// NAI 提示词格式化工具
/// 支持所有 NAI 特殊语法的格式化和验证
class PromptFormatter {
  /// 格式化 NAI 提示词
  /// - 统一逗号后的空格
  /// - 保护 NAI 特殊语法
  /// - 移除多余空白
  static String format(String prompt) {
    if (prompt.isEmpty) return prompt;

    // 1. 保护特殊语法区域
    final protectedRegions = <_ProtectedRegion>[];
    var processedPrompt = prompt;

    // 保护数值权重语法: 1.5::content::
    processedPrompt = _protectPattern(
      processedPrompt,
      RegExp(r'-?\d+\.?\d*::.*?::'),
      protectedRegions,
    );

    // 保护 NAI 随机化语法: ||option1|option2||
    processedPrompt = _protectPattern(
      processedPrompt,
      RegExp(r'\|\|.*?\|\|'),
      protectedRegions,
    );

    // 保护本地随机化语法: {随机...随机}
    processedPrompt = _protectPattern(
      processedPrompt,
      RegExp(r'\{随机.*?随机\}'),
      protectedRegions,
    );

    // 保护多层括号: {{...}}, [[...]]
    processedPrompt = _protectPattern(
      processedPrompt,
      RegExp(r'\{\{.*?\}\}'),
      protectedRegions,
    );
    processedPrompt = _protectPattern(
      processedPrompt,
      RegExp(r'\[\[.*?\]\]'),
      protectedRegions,
    );

    // 保护单层括号: {...}, [...]
    processedPrompt = _protectPattern(
      processedPrompt,
      RegExp(r'\{[^{].*?[^}]\}'),
      protectedRegions,
    );
    processedPrompt = _protectPattern(
      processedPrompt,
      RegExp(r'\[[^\[].*?[^\]]\]'),
      protectedRegions,
    );

    // 2. 格式化普通部分
    // 移除多余空格
    processedPrompt = processedPrompt.replaceAll(RegExp(r'[ \t]+'), ' ');

    // 统一逗号格式: ", " (逗号后有一个空格)
    processedPrompt = processedPrompt.replaceAll(RegExp(r'\s*,\s*'), ', ');

    // 移除首尾空白
    processedPrompt = processedPrompt.trim();

    // 移除末尾多余的逗号
    processedPrompt = processedPrompt.replaceAll(RegExp(r',\s*$'), '');

    // 3. 恢复保护的区域
    processedPrompt =
        _restoreProtectedRegions(processedPrompt, protectedRegions);

    return processedPrompt;
  }

  /// 验证 NAI 语法
  static ValidationResult validate(String prompt) {
    final errors = <String>[];
    final warnings = <String>[];

    // 检查括号匹配
    _checkBracketBalance(prompt, '{', '}', '花括号', errors);
    _checkBracketBalance(prompt, '[', ']', '方括号', errors);

    // 检查数值权重语法
    final weightPattern = RegExp(r'-?\d+\.?\d*::');
    final weightMatches = weightPattern.allMatches(prompt);
    for (final match in weightMatches) {
      final afterMatch = prompt.substring(match.end);
      if (!afterMatch.contains('::')) {
        errors.add('数值权重语法不完整: "${match.group(0)}" 缺少结束的 "::"');
      }
    }

    // 检查 NAI 随机化语法
    final randomPattern = RegExp(r'\|\|');
    final randomMatches = randomPattern.allMatches(prompt).toList();
    if (randomMatches.length % 2 != 0) {
      errors.add('NAI 随机化语法不完整: "||" 数量不匹配');
    }

    // 检查本地随机化语法
    final localRandomStart = '{随机'.allMatches(prompt).length;
    final localRandomEnd = '随机}'.allMatches(prompt).length;
    if (localRandomStart != localRandomEnd) {
      errors.add('本地随机化语法不完整: "{随机" 和 "随机}" 数量不匹配');
    }

    // 检查常见问题
    if (prompt.contains(',,')) {
      warnings.add('发现连续的逗号');
    }

    if (prompt.contains('  ')) {
      warnings.add('发现多余的空格');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// 保护匹配的模式
  static String _protectPattern(
    String text,
    RegExp pattern,
    List<_ProtectedRegion> regions,
  ) {
    var result = text;
    final matches = pattern.allMatches(text).toList();

    // 从后向前替换，避免索引偏移
    for (var i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      final placeholder = '\x00${regions.length}\x00';
      regions.add(_ProtectedRegion(placeholder, match.group(0)!));
      result = result.replaceRange(match.start, match.end, placeholder);
    }

    return result;
  }

  /// 恢复保护的区域
  static String _restoreProtectedRegions(
    String text,
    List<_ProtectedRegion> regions,
  ) {
    var result = text;
    for (final region in regions) {
      result = result.replaceFirst(region.placeholder, region.content);
    }
    return result;
  }

  /// 检查括号平衡
  static void _checkBracketBalance(
    String text,
    String open,
    String close,
    String name,
    List<String> errors,
  ) {
    var count = 0;
    for (final char in text.split('')) {
      if (char == open) count++;
      if (char == close) count--;
      if (count < 0) {
        errors.add('$name不匹配: 多余的 "$close"');
        return;
      }
    }
    if (count > 0) {
      errors.add('$name不匹配: 缺少 "$close"');
    }
  }
}

/// 保护的区域
class _ProtectedRegion {
  final String placeholder;
  final String content;

  _ProtectedRegion(this.placeholder, this.content);
}

/// 验证结果
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}
