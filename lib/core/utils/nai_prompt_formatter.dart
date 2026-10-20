import 'character_prompt_block_parser.dart';
import 'prompt_literal_mask.dart';
import 'text_space_converter.dart';
import 'prompt_edit_document.dart';

/// NAI 提示词格式化工具
/// 统一逗号与标签空格风格；引号文字、text: 段、别名与颜文字原样保留。
class NaiPromptFormatter {
  static final RegExp _lineBreakPattern = RegExp(r'\r\n|\r|\n');
  static final RegExp _horizontalWhitespacePattern = RegExp(r'[ \t\f\u00a0]+');
  static final RegExp _leadingHorizontalWhitespacePattern = RegExp(r'^[ \t]*');
  static final RegExp _trailingHorizontalWhitespacePattern = RegExp(r'[ \t]*$');
  static final RegExp _leadingSeparatorPattern = RegExp(r'^[ \t]*[,，][ \t]*');

  static const Set<String> _protectChars = {
    ...TextSpaceConverter.naiFormat,
    PromptLiteralMask.tokenStart,
    PromptLiteralMask.tokenEnd,
  };

  /// 格式化整个提示词
  /// - 将中文逗号转换为英文逗号
  /// - 按 [replaceUnderscores] 统一标签使用空格或下划线
  /// - 官网会渲染的引号文字、手写 text: 段、别名与颜文字保持原样
  /// - 保留用户用于分组的换行、空行和行首缩进
  static String format(String prompt, {bool replaceUnderscores = false}) {
    final mask = PromptLiteralMask.of(prompt);
    var followsDisabled = false;
    final formatted = PromptEditDocument.mapActiveText(mask.text, (fragment) {
      // A leading comma after an opaque disabled fragment separates tags;
      // formatting that fragment alone would treat it as an empty first tag.
      final separator = followsDisabled
          ? _leadingSeparatorPattern.firstMatch(fragment)
          : null;
      followsDisabled = true;
      if (separator == null) return _formatActive(fragment, replaceUnderscores);
      return '${separator.group(0)!.replaceAll('，', ',')}'
          '${_formatActive(fragment.substring(separator.end), replaceUnderscores)}';
    });
    return mask.restore(formatted);
  }

  static String _formatActive(String prompt, bool replaceUnderscores) {
    if (prompt.isEmpty) return prompt;

    // Format block contents through the same path as positive tags while the
    // shared parser protects the reserved keyword and matching boundaries.
    var prepared = prompt;
    final parsed = CharacterPromptBlockParser.parse(prompt);
    for (final block in parsed.blocks.reversed) {
      final content = prepared.substring(
        block.contentRange.start,
        block.contentRange.end,
      );
      prepared = prepared.replaceRange(
        block.contentRange.start,
        block.contentRange.end,
        _formatPromptText(content, replaceUnderscores),
      );
    }

    return _formatPromptText(prepared, replaceUnderscores);
  }

  static String _formatPromptText(String prompt, bool replaceUnderscores) {
    return prompt.splitMapJoin(
      _lineBreakPattern,
      onMatch: (match) => match.group(0)!,
      onNonMatch: (line) => _formatLine(line, replaceUnderscores),
    );
  }

  static String _formatLine(String line, bool replaceUnderscores) {
    if (line.isEmpty) return line;

    final leadingWhitespace =
        _leadingHorizontalWhitespacePattern.firstMatch(line)?.group(0) ?? '';
    final trailingWhitespace =
        _trailingHorizontalWhitespacePattern.firstMatch(line)?.group(0) ?? '';
    final contentEnd = line.length - trailingWhitespace.length;
    if (leadingWhitespace.length >= contentEnd) {
      return line;
    }

    var content = line.substring(leadingWhitespace.length, contentEnd);
    content = _normalizeHorizontalWhitespace(content).replaceAll('，', ',');
    final keepsTrailingComma = content.endsWith(',');

    final tags = content
        .split(',')
        .map((tag) {
          final trimmed = tag.trim();
          if (trimmed.isEmpty) return '';
          if (replaceUnderscores) return _toSpaceStyle(trimmed);
          return TextSpaceConverter.convert(
            trimmed,
            protectChars: _protectChars,
          );
        })
        .where((tag) => tag.isNotEmpty)
        .toList();

    var formatted = tags.join(', ');
    if (keepsTrailingComma && formatted.isNotEmpty) {
      formatted = '$formatted,';
    }

    return '$leadingWhitespace$formatted$trailingWhitespace';
  }

  // 颜文字已被遮罩，这里可以整段替换；合并空白保证再次格式化结果不变
  static String _toSpaceStyle(String tag) =>
      _normalizeHorizontalWhitespace(tag.replaceAll('_', ' ')).trim();

  /// 统一行内空白字符，不跨越或删除换行。
  static String _normalizeHorizontalWhitespace(String text) {
    var result = text.replaceAll('　', ' ');
    result = result.replaceAll(_horizontalWhitespacePattern, ' ');
    return result;
  }
}
