import '../constants/api_constants.dart';
import 'prompt_literal_scanner.dart';
import 'character_prompt_block_parser.dart';
import 'text_space_converter.dart';
import 'prompt_edit_document.dart';

/// NAI 提示词格式化工具
/// 统一标签分隔符与空格风格，保留文字渲染内容和别名。
class NaiPromptFormatter {
  static final RegExp _lineBreakPattern = RegExp(r'\r\n|\r|\n');
  static final RegExp _horizontalWhitespacePattern = RegExp(r'[ \t\f\u00a0]+');
  static final RegExp _leadingHorizontalWhitespacePattern = RegExp(r'^[ \t]*');
  static final RegExp _trailingHorizontalWhitespacePattern = RegExp(r'[ \t]*$');
  static final RegExp _leadingSeparatorPattern = RegExp(r'^[ \t]*[,，][ \t]*');

  /// 格式化单个标签为 NAI 格式
  /// 将空格转换为下划线
  static String formatTag(String tag) {
    return _normalizeHorizontalWhitespace(tag).trim().replaceAll(' ', '_');
  }

  /// 格式化整个提示词
  /// - 将中文逗号转换为英文逗号
  /// - 按 replaceUnderscores 选择标签使用空格或下划线
  /// - 保留引号、别名及 text: 文字渲染段的原始内容
  /// - 保留用户用于分组的换行、空行和行首缩进
  static String format(String prompt, {bool replaceUnderscores = false}) {
    return _preserveLiterals(
      prompt,
      (text) => _formatActiveFragments(text, replaceUnderscores),
    );
  }

  static String _formatActiveFragments(String prompt, bool replaceUnderscores) {
    var followsDisabled = false;
    return PromptEditDocument.mapActiveText(prompt, (fragment) {
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
  }

  // Mask literal payloads before splitting on commas or normalizing whitespace.
  // Choose a prefix absent from the input so user text cannot collide with it.
  static String _preserveLiterals(
    String prompt,
    String Function(String) transform,
  ) {
    var prefix = '\uE000';
    while (prompt.contains(prefix)) {
      prefix += '\uE000';
    }
    final literals = <String, String>{};
    final buffer = StringBuffer();
    final textStarts = {
      for (final match in QualityTags.textRenderMarker.allMatches(prompt))
        match.end - 5,
    };
    for (var i = 0; i < prompt.length;) {
      if (prompt.startsWith(PromptEditDocument.disabledPrefix, i)) {
        final disabledEnd = PromptEditDocument.disabledEnd(prompt, i);
        final end = disabledEnd < 0 ? prompt.length : disabledEnd;
        buffer.write(prompt.substring(i, end));
        i = end;
        continue;
      }
      if (prompt[i] == r'\' && i + 1 < prompt.length) {
        buffer.write(prompt.substring(i, i + 2));
        i += 2;
        continue;
      }
      final end = textStarts.contains(i)
          ? _textPayloadEnd(prompt, i)
          : _literalEnd(prompt, i);
      if (end == null) {
        buffer.write(prompt[i++]);
        continue;
      }
      final token = '$prefix${literals.length}\uE001';
      literals[token] = prompt.substring(i, end);
      buffer.write(token);
      i = end;
    }
    var formatted = transform(buffer.toString());
    for (final entry in literals.entries) {
      formatted = formatted.replaceAll(entry.key, entry.value);
    }
    return formatted;
  }

  // A text payload ends at the next prompt-mix boundary, not an escaped
  // pipe or a pipe inside a ||randomizer||.
  static int _textPayloadEnd(String prompt, int start) {
    var inRandomizer = false;
    for (var i = start; i < prompt.length; i++) {
      if (prompt[i] == r'\') {
        i++;
      } else if (prompt.startsWith('||', i)) {
        inRandomizer = !inRandomizer;
        i++;
      } else if (prompt[i] == '|' && !inRandomizer) {
        return i;
      }
    }
    return prompt.length;
  }

  static int? _literalEnd(String prompt, int start) {
    final end = PromptLiteralScanner.endAt(prompt, start, prompt.length);
    if (end != null) return end;
    const quotePairs = {'“': '”', '‘': '’', '「': '」'};
    final closing = quotePairs[prompt[start]];
    if (closing == null) return null;
    for (var i = start + 1; i < prompt.length; i++) {
      if (prompt[i] == r'\') {
        i++;
      } else if (prompt[i] == closing) {
        return i + 1;
      }
    }
    return null;
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
          if (replaceUnderscores) return trimmed.replaceAll('_', ' ');
          return TextSpaceConverter.convert(
            trimmed,
            protectChars: {...TextSpaceConverter.naiFormat, '\uE000', '\uE001'},
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

  /// 统一行内空白字符，不跨越或删除换行。
  static String _normalizeHorizontalWhitespace(String text) {
    var result = text.replaceAll('　', ' ');
    result = result.replaceAll(_horizontalWhitespacePattern, ' ');
    return result;
  }
}
