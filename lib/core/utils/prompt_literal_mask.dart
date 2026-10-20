import '../constants/api_constants.dart';
import 'kaomoji_tags.dart';
import 'novelai_auto_text.dart';
import 'prompt_edit_document.dart';
import 'prompt_literal_scanner.dart';

typedef _Range = ({int start, int end});

/// 把格式化不得改写的文字段换成占位符：官网会渲染的引号文字、手写 text: 段、
/// 别名与颜文字。格式化后用 [restore] 原样还原。
final class PromptLiteralMask {
  const PromptLiteralMask._(this.text, this._literals, this._token);

  factory PromptLiteralMask.of(String prompt) {
    final ranges = _literalRanges(prompt);
    if (ranges.isEmpty) return PromptLiteralMask._(prompt, const [], null);

    // 前缀取输入里不存在的长度，用户文本无法拼出合法占位符
    var lead = tokenStart;
    while (prompt.contains(lead)) {
      lead += tokenStart;
    }
    final literals = <String>[];
    final buffer = StringBuffer();
    var cursor = 0;
    for (final range in ranges) {
      buffer
        ..write(prompt.substring(cursor, range.start))
        ..write('$lead${literals.length}$tokenEnd');
      literals.add(prompt.substring(range.start, range.end));
      cursor = range.end;
    }
    buffer.write(prompt.substring(cursor));
    return PromptLiteralMask._(
      buffer.toString(),
      literals,
      RegExp('${RegExp.escape(lead)}(\\d+)$tokenEnd'),
    );
  }

  /// 占位符首尾字符；格式化时紧邻它们的空格必须保留，否则引号会失去边界。
  static const tokenStart = '\uE000';
  static const tokenEnd = '\uE001';

  static const _textMarker = 'text:';

  final String text;
  final List<String> _literals;
  final RegExp? _token;

  String restore(String formatted) {
    final token = _token;
    if (token == null) return formatted;
    return formatted.replaceAllMapped(
      token,
      (match) => _literals[int.parse(match[1]!)],
    );
  }

  static List<_Range> _literalRanges(String prompt) {
    final view = _blankDisabled(prompt);
    final ranges = <_Range>[
      ...NovelAiAutoText.quotedRanges(view),
      ..._textPayloadRanges(view),
      ..._angleRanges(view),
      for (final match in KaomojiTags.pattern.allMatches(view))
        (start: match.start, end: match.end),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final merged = <_Range>[];
    for (final range in ranges) {
      final last = merged.isEmpty ? null : merged.last;
      if (last == null || range.start >= last.end) {
        merged.add(range);
      } else if (range.end > last.end) {
        merged.last = (start: last.start, end: range.end);
      }
    }
    return merged;
  }

  // 禁用片段不会发送，既不能开启也不能闭合字面量；等长留白保持下标对齐
  static String _blankDisabled(String prompt) {
    final disabled = PromptEditDocument.disabledRanges(
      prompt,
      allowIncomplete: true,
    );
    if (disabled.isEmpty) return prompt;
    final buffer = StringBuffer();
    var cursor = 0;
    for (final (start, end) in disabled) {
      buffer
        ..write(prompt.substring(cursor, start))
        ..write(' ' * (end - start));
      cursor = end;
    }
    buffer.write(prompt.substring(cursor));
    return buffer.toString();
  }

  // 手写 text: 段一直渲染到所在混合段结尾
  static Iterable<_Range> _textPayloadRanges(String view) sync* {
    var chunkStart = 0;
    for (final chunk in QualityTags.splitPromptMixChunks(view)) {
      final marker = QualityTags.textRenderMarker.firstMatch(chunk);
      if (marker != null) {
        yield (
          start: chunkStart + marker.end - _textMarker.length,
          end: chunkStart + chunk.length,
        );
      }
      // 各段由单个分隔符拼回原文
      chunkStart += chunk.length + QualityTags.promptMixSeparator.length;
    }
  }

  static Iterable<_Range> _angleRanges(String view) sync* {
    for (var i = 0; i < view.length; i++) {
      if (view[i] == r'\') {
        i++;
        continue;
      }
      if (view[i] != '<') continue;
      final end = PromptLiteralScanner.endAt(view, i, view.length);
      if (end == null) continue;
      yield (start: i, end: end);
      i = end - 1;
    }
  }
}
