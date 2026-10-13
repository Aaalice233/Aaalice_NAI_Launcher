import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 输入框里 `[imageN]` 附件引用的词法与编辑。

final RegExp agentChatImageTokenPattern = RegExp(r'\[image(\d+)\]');

/// 删除第 [removedNumber] 张附件的引用并把后续编号前移，选区随每处改写映射。
///
/// 只吃掉标记一侧的一个空格（与插入时补的空格对称），不动用户自己写的连续空格或缩进。
TextEditingValue removeAgentChatImageToken(
  TextEditingValue value,
  int removedNumber,
) {
  final text = value.text;
  final edits = <_TextEdit>[];
  var consumedEnd = 0;
  for (final match in agentChatImageTokenPattern.allMatches(text)) {
    final number = int.tryParse(match.group(1) ?? '');
    if (number == null || number < removedNumber) continue;
    if (number > removedNumber) {
      edits.add(_TextEdit(match.start, match.end, '[image${number - 1}]'));
      consumedEnd = match.end;
      continue;
    }
    final range = _removalRange(text, match.start, match.end, consumedEnd);
    edits.add(_TextEdit(range.$1, range.$2, ''));
    consumedEnd = range.$2;
  }
  if (edits.isEmpty) return value.copyWith(composing: TextRange.empty);
  final buffer = StringBuffer();
  var cursor = 0;
  for (final edit in edits) {
    buffer
      ..write(text.substring(cursor, edit.start))
      ..write(edit.replacement);
    cursor = edit.end;
  }
  buffer.write(text.substring(cursor));
  final selection = value.selection;
  return TextEditingValue(
    text: buffer.toString(),
    selection: selection.isValid
        ? selection.copyWith(
            baseOffset: _mapOffset(selection.baseOffset, edits),
            extentOffset: _mapOffset(selection.extentOffset, edits),
          )
        : selection,
  );
}

(int, int) _removalRange(String text, int start, int end, int consumedEnd) {
  bool isSpace(int index) => text.codeUnitAt(index) == 0x20;
  bool isBoundary(int index) =>
      index < 0 || index >= text.length || text.codeUnitAt(index) == 0x0A;
  final spaceBefore = start - 1 >= consumedEnd && isSpace(start - 1);
  final spaceAfter = end < text.length && isSpace(end);
  if (spaceAfter && (spaceBefore || isBoundary(start - 1))) {
    return (start, end + 1);
  }
  if (spaceBefore && isBoundary(end)) return (start - 1, end);
  return (start, end);
}

int _mapOffset(int offset, List<_TextEdit> edits) {
  var shift = 0;
  for (final edit in edits) {
    if (offset <= edit.start) break;
    if (offset < edit.end) {
      final inside = offset - edit.start;
      return edit.start +
          shift +
          (inside < edit.replacement.length ? inside : edit.replacement.length);
    }
    shift += edit.replacement.length - (edit.end - edit.start);
  }
  return offset + shift;
}

@immutable
class _TextEdit {
  const _TextEdit(this.start, this.end, this.replacement);

  final int start;
  final int end;
  final String replacement;
}
