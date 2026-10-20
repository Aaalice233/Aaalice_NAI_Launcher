import 'prompt_edit_document.dart';

/// 官网把紧贴 `::` 的 `-?\d*\.?\d*` 读作新权重，内容以数字、`.`、`-` 结尾时
/// 闭合 `::` 前需要空格，否则 `1.05::year_2025::` 会让后续标签获得 2025 倍权重。
abstract final class NumericWeightClosing {
  static const plain = '::';
  static const separated = ' ::';
  static final _separatedEnding = RegExp(r'\s::$');

  /// 按发送时的有效内容判断；未闭合的禁用片段会吞掉随后的 `::`，无需补空格。
  static bool endsAmbiguously(String content) {
    if (_hasUnclosedDisabled(content)) return false;
    final sent = PromptEditDocument.effectiveText(content);
    return sent.isNotEmpty && _isNumeric(sent.codeUnitAt(sent.length - 1));
  }

  /// [original] 是被重写的原文，其闭合已带空格时沿用，选项关闭也不拆掉。
  static String closingFor(
    String content, {
    required bool separate,
    String? original,
  }) =>
      (original != null && _hasSeparatedClosing(original)) ||
          (separate && endsAmbiguously(content))
      ? separated
      : plain;

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

  static bool _hasSeparatedClosing(String source) => _separatedEnding.hasMatch(
    PromptEditDocument.decodeDisabled(source).trimRight(),
  );

  static bool _isNumeric(int code) =>
      (code >= 0x30 && code <= 0x39) || code == 0x2E || code == 0x2D;

  static bool _hasUnclosedDisabled(String content) {
    final fragments = PromptEditDocument.disabledRanges(
      content,
      allowIncomplete: true,
    );
    return fragments.isNotEmpty &&
        PromptEditDocument.disabledEnd(content, fragments.last.$1) < 0;
  }
}
