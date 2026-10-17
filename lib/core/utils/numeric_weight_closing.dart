import 'prompt_edit_document.dart';

/// 官网把紧贴 `::` 的 `-?\d*\.?\d*` 读作新权重，内容以数字、`.`、`-` 结尾时
/// 闭合 `::` 前需要空格，否则 `1.05::year_2025::` 会让后续标签获得 2025 倍权重。
abstract final class NumericWeightClosing {
  static const plain = '::';
  static const separated = ' ::';
  static final _separatedEnding = RegExp(r'\s::$');

  /// 发送前被移除的结尾禁用片段不算内容，按剩余部分判断。
  static bool endsAmbiguously(String content) {
    var end = content.length;
    final fragments = PromptEditDocument.disabledRanges(
      content,
      allowIncomplete: true,
    );
    for (var i = fragments.length - 1; i >= 0 && fragments[i].$2 == end; i--) {
      end = fragments[i].$1;
      while (end > 0 && _isSeparator(content[end - 1])) {
        end--;
      }
    }
    return end > 0 && _isNumeric(content.codeUnitAt(end - 1));
  }

  static String closingFor(String content, {required bool separate}) =>
      separate && endsAmbiguously(content) ? separated : plain;

  /// 重写权重时用于沿用原文已有的闭合空格，选项关闭也不拆掉。
  static bool hasSeparatedClosing(String source) => _separatedEnding.hasMatch(
    PromptEditDocument.decodeDisabled(source).trimRight(),
  );

  /// 只在闭合 `::` 前插入空格，不改动其他字符。
  static String separate(String source) {
    final offsets = [
      for (final (contentStart, closing) in PromptEditDocument.numericClosings(
        source,
      ))
        if (endsAmbiguously(source.substring(contentStart, closing))) closing,
    ];
    if (offsets.isEmpty) return source;
    final result = StringBuffer();
    var cursor = 0;
    for (final offset in offsets) {
      result
        ..write(source.substring(cursor, offset))
        ..write(' ');
      cursor = offset;
    }
    result.write(source.substring(cursor));
    return result.toString();
  }

  static bool _isNumeric(int code) =>
      (code >= 0x30 && code <= 0x39) || code == 0x2E || code == 0x2D;

  static bool _isSeparator(String char) => char == ',' || char.trim().isEmpty;
}
