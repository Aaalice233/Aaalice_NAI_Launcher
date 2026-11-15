import 'package:flutter/material.dart';

/// 在提示词文本中查找大小写不敏感的搜索命中区间（升序且互不重叠）。
List<TextRange> findPromptSearchMatches(String source, String query) {
  final needle = query.trim();
  if (source.isEmpty || needle.isEmpty) {
    return const [];
  }

  final lowerSource = source.toLowerCase();
  final lowerNeedle = needle.toLowerCase();
  final matches = <TextRange>[];
  var start = 0;

  while (start < lowerSource.length) {
    final index = lowerSource.indexOf(lowerNeedle, start);
    if (index < 0) {
      break;
    }
    matches.add(TextRange(start: index, end: index + needle.length));
    start = index + needle.length;
  }

  return matches;
}

/// 根据当前激活索引或选区位置计算下一个激活的搜索命中索引。
int resolveActivePromptSearchIndex(
  List<TextRange> matches, {
  required int currentActiveIndex,
  required TextSelection selection,
  required bool preserveActive,
}) {
  if (matches.isEmpty) {
    return -1;
  }
  if (preserveActive &&
      currentActiveIndex >= 0 &&
      currentActiveIndex < matches.length) {
    return currentActiveIndex;
  }
  if (selection.isValid) {
    final index = matches.indexWhere((match) => match.start >= selection.end);
    if (index >= 0) {
      return index;
    }
  }
  return 0;
}

/// 全部替换。
///
/// 命中区间由 [findPromptSearchMatches] 保证互不重叠且按升序排列，
/// 因此可以一次线性拼接，不必反向逐个 replaceRange。
({String text, int caretOffset, int replacedCount}) buildReplaceAllPromptText({
  required String source,
  required List<TextRange> matches,
  required String replacement,
}) {
  final buffer = StringBuffer();
  var cursor = 0;
  var replacedCount = 0;
  var caretOffset = 0;

  for (final match in matches) {
    if (match.start < cursor || match.end > source.length) {
      continue;
    }
    buffer.write(source.substring(cursor, match.start));
    buffer.write(replacement);
    cursor = match.end;
    caretOffset = buffer.length;
    replacedCount++;
  }
  if (replacedCount == 0) {
    return (text: source, caretOffset: 0, replacedCount: 0);
  }
  buffer.write(source.substring(cursor));

  return (
    text: postProcessReplacedPromptText(buffer.toString()),
    caretOffset: caretOffset,
    replacedCount: replacedCount,
  );
}

/// 全部替换后的文本清理。
///
/// 提示词是逗号分隔的标签串，把某个标签整体替换为空串后会残留
/// `alpha, , beta` 这样的空位。这里决定要不要以及如何收拾残局。
///
/// TODO(用户实现)：见下方说明，可选择保持原样、收敛空标签，或整体格式化。
String postProcessReplacedPromptText(String text) {
  return text;
}
