import 'text_space_converter.dart';

/// NAI 提示词格式化工具
/// 简化版：只做中文逗号转英文和空格转下划线
class NaiPromptFormatter {
  static final RegExp _lineBreakPattern = RegExp(r'\r\n|\r|\n');
  static final RegExp _horizontalWhitespacePattern = RegExp(r'[ \t\f\u00a0]+');
  static final RegExp _leadingHorizontalWhitespacePattern = RegExp(r'^[ \t]*');
  static final RegExp _trailingHorizontalWhitespacePattern = RegExp(r'[ \t]*$');

  /// 格式化单个标签为 NAI 格式
  /// 将空格转换为下划线
  static String formatTag(String tag) {
    return _normalizeHorizontalWhitespace(tag).trim().replaceAll(' ', '_');
  }

  /// 格式化整个提示词
  /// - 将中文逗号转换为英文逗号
  /// - 将标签中的空格转换为下划线（保留逗号后的空格和尖括号内的空格）
  /// - 保留用户用于分组的换行、空行和行首缩进
  static String format(String prompt) {
    if (prompt.isEmpty) return prompt;

    return prompt.splitMapJoin(
      _lineBreakPattern,
      onMatch: (match) => match.group(0)!,
      onNonMatch: _formatLine,
    );
  }

  static String _formatLine(String line) {
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
          return TextSpaceConverter.convert(
            trimmed,
            protectChars: TextSpaceConverter.naiFormat,
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
