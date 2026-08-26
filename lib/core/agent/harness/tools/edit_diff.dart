// 编辑工具的共享 diff 计算工具集。
//
// 包含：行尾检测与归一化、模糊匹配归一化、精确/模糊文本替换、
// 未变更行保留的覆盖策略、统一补丁与带行号展示 diff 生成。
// 行级 diff 采用 LCS 算法实现。

enum LineEnding { crlf, lf }

/// 检测内容的主导行尾风格（CRLF 优先于首次出现的 LF）。
LineEnding detectLineEnding(String content) {
  final crlfIdx = content.indexOf('\r\n');
  final lfIdx = content.indexOf('\n');
  if (lfIdx == -1) {
    return LineEnding.lf;
  }
  if (crlfIdx == -1) {
    return LineEnding.lf;
  }
  return crlfIdx < lfIdx ? LineEnding.crlf : LineEnding.lf;
}

/// 把 CRLF / 孤立 CR 统一归一化为 LF。
String normalizeToLF(String text) {
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

/// 按检测出的行尾风格还原换行。
String restoreLineEndings(String text, LineEnding ending) {
  return ending == LineEnding.crlf ? text.replaceAll('\n', '\r\n') : text;
}

/// 模糊匹配归一化（逐级变换）：
/// - 去每行行尾空白；
/// - 智能引号 → ASCII 引号；
/// - Unicode 连字符/破折号 → ASCII 连字符；
/// - 特殊 Unicode 空格 → 普通空格。
String normalizeForFuzzyMatch(String text) {
  var result = text;
  result = result
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'\s+$'), ''))
      .join('\n');
  result = result.replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B]'), "'");
  result = result.replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F]'), '"');
  result =
      result.replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-');
  result =
      result.replaceAll(RegExp(r'[\u00A0\u2002-\u200A\u202F\u205F\u3000]'), ' ');
  return result;
}

/// 按"保留行尾换行"的方式切分行：每段以 \n 结尾（末段除外）。
List<String> _splitLinesWithEndings(String content) {
  if (content.isEmpty) {
    return const [];
  }
  final result = <String>[];
  var start = 0;
  for (var i = 0; i < content.length; i++) {
    if (content.codeUnitAt(i) == 0x0a) {
      result.add(content.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < content.length) {
    result.add(content.substring(start));
  }
  return result;
}

class _LineSpan {
  const _LineSpan(this.start, this.end);

  final int start;
  final int end;
}

class _TextReplacement {
  const _TextReplacement({
    required this.matchIndex,
    required this.matchLength,
    required this.newText,
  });

  final int matchIndex;
  final int matchLength;
  final String newText;
}

class _MatchedEdit implements _TextReplacement {
  const _MatchedEdit({
    required this.editIndex,
    required this.matchIndex,
    required this.matchLength,
    required this.newText,
  });

  final int editIndex;

  @override
  final int matchIndex;

  @override
  final int matchLength;

  @override
  final String newText;
}

List<_LineSpan> _getLineSpans(String content) {
  var offset = 0;
  return _splitLinesWithEndings(content).map((line) {
    final span = _LineSpan(offset, offset + line.length);
    offset = span.end;
    return span;
  }).toList();
}

({int startLine, int endLine}) _getReplacementLineRange(
  List<_LineSpan> lines,
  _TextReplacement replacement,
) {
  final replacementStart = replacement.matchIndex;
  final replacementEnd = replacement.matchIndex + replacement.matchLength;

  var startLine = -1;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (replacementStart >= line.start && replacementStart < line.end) {
      startLine = i;
      break;
    }
  }
  if (startLine == -1) {
    throw StateError('Replacement range is outside the base content.');
  }

  var endLine = startLine;
  while (endLine < lines.length && lines[endLine].end < replacementEnd) {
    endLine++;
  }
  if (endLine >= lines.length) {
    throw StateError('Replacement range is outside the base content.');
  }

  return (startLine: startLine, endLine: endLine + 1);
}

String _applyReplacements(
  String content,
  List<_TextReplacement> replacements, [
  int offset = 0,
]) {
  var result = content;
  // 逆序应用使前面的偏移量保持稳定。
  for (var i = replacements.length - 1; i >= 0; i--) {
    final replacement = replacements[i];
    final matchIndex = replacement.matchIndex - offset;
    result = result.substring(0, matchIndex) +
        replacement.newText +
        result.substring(matchIndex + replacement.matchLength);
  }
  return result;
}

/// 把对 [baseContent] 匹配的替换应用到 [originalContent]，同时保留未变更
/// 行块的原始字节。
///
/// 适用场景：baseContent 是 original 的归一化视图。每个替换会扩展到其
/// 实际触碰的行；被触碰的行用归一化后的 base 重写，其余行原样复制回
/// original。以实际替换范围驱动保留策略，避免重复的归一化行错位对齐。
String _applyReplacementsPreservingUnchangedLines(
  String originalContent,
  String baseContent,
  List<_TextReplacement> replacements,
) {
  final originalLines = _splitLinesWithEndings(originalContent);
  final baseLines = _getLineSpans(baseContent);
  if (originalLines.length != baseLines.length) {
    throw StateError(
      'Cannot preserve unchanged lines because the base content has a '
      'different line count.',
    );
  }

  // 按源顺序分组相邻/重叠的替换，组间行块从 original 复制。
  final groups =
      <({int startLine, int endLine, List<_TextReplacement> replacements})>[];
  final sortedReplacements = List.of(replacements)
    ..sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
  for (final replacement in sortedReplacements) {
    final range = _getReplacementLineRange(baseLines, replacement);
    if (groups.isNotEmpty && range.startLine < groups.last.endLine) {
      final last = groups.removeLast();
      groups.add((
        startLine: last.startLine,
        endLine:
            last.endLine > range.endLine ? last.endLine : range.endLine,
        replacements: [...last.replacements, replacement],
      ));
      continue;
    }
    groups.add((
      startLine: range.startLine,
      endLine: range.endLine,
      replacements: [replacement],
    ));
  }

  var originalLineIndex = 0;
  var result = '';
  for (final group in groups) {
    result +=
        originalLines.sublist(originalLineIndex, group.startLine).join('');

    final groupStartOffset = baseLines[group.startLine].start;
    final groupEndOffset = baseLines[group.endLine - 1].end;
    result += _applyReplacements(
      baseContent.substring(groupStartOffset, groupEndOffset),
      group.replacements,
      groupStartOffset,
    );
    originalLineIndex = group.endLine;
  }
  result += originalLines.sublist(originalLineIndex).join('');

  return result;
}

/// 单次文本查找的结果。
class FuzzyMatchResult {
  const FuzzyMatchResult({
    required this.found,
    required this.index,
    required this.matchLength,
    required this.usedFuzzyMatch,
    required this.contentForReplacement,
  });

  /// 是否找到匹配。
  final bool found;

  /// 匹配起始下标（相对于 [contentForReplacement]）。
  final int index;
  final int matchLength;

  /// 是否使用了模糊匹配（false 表示精确匹配）。
  final bool usedFuzzyMatch;

  /// 用于替换操作的内容：精确匹配时为原文；模糊匹配时为归一化文本。
  final String contentForReplacement;
}

/// 一次目标编辑：oldText → newText。
class Edit {
  const Edit({required this.oldText, required this.newText});

  final String oldText;
  final String newText;
}

/// 归一化内容应用编辑后的产物。
class AppliedEditsResult {
  const AppliedEditsResult({
    required this.baseContent,
    required this.newContent,
  });

  final String baseContent;
  final String newContent;
}

/// 先精确匹配、后模糊匹配查找 oldText。
///
/// 使用模糊匹配时返回归一化空间中的偏移，[contentForReplacement] 为
/// 归一化后的全文，调用方据此计算替换再决定写回范围。
FuzzyMatchResult fuzzyFindText(String content, String oldText) {
  final exactIndex = content.indexOf(oldText);
  if (exactIndex != -1) {
    return FuzzyMatchResult(
      found: true,
      index: exactIndex,
      matchLength: oldText.length,
      usedFuzzyMatch: false,
      contentForReplacement: content,
    );
  }

  final fuzzyContent = normalizeForFuzzyMatch(content);
  final fuzzyOldText = normalizeForFuzzyMatch(oldText);
  final fuzzyIndex = fuzzyContent.indexOf(fuzzyOldText);

  if (fuzzyIndex == -1) {
    return FuzzyMatchResult(
      found: false,
      index: -1,
      matchLength: 0,
      usedFuzzyMatch: false,
      contentForReplacement: content,
    );
  }

  return FuzzyMatchResult(
    found: true,
    index: fuzzyIndex,
    matchLength: fuzzyOldText.length,
    usedFuzzyMatch: true,
    contentForReplacement: fuzzyContent,
  );
}

/// 剥离 UTF-8 BOM，返回 (bom, 无 BOM 文本)。
(String, String) stripBom(String content) {
  return content.startsWith('\uFEFF')
      ? ('\uFEFF', content.substring(1))
      : ('', content);
}

int _countOccurrences(String content, String oldText) {
  final fuzzyContent = normalizeForFuzzyMatch(content);
  final fuzzyOldText = normalizeForFuzzyMatch(oldText);
  if (fuzzyOldText.isEmpty) {
    return 0;
  }
  return fuzzyContent.split(fuzzyOldText).length - 1;
}

StateError _getNotFoundError(String path, int editIndex, int totalEdits) {
  if (totalEdits == 1) {
    return StateError(
      'Could not find the exact text in $path. The old text must match '
      'exactly including all whitespace and newlines.',
    );
  }
  return StateError(
    'Could not find edits[$editIndex] in $path. The oldText must match '
    'exactly including all whitespace and newlines.',
  );
}

StateError _getDuplicateError(
  String path,
  int editIndex,
  int totalEdits,
  int occurrences,
) {
  if (totalEdits == 1) {
    return StateError(
      'Found $occurrences occurrences of the text in $path. The text must be '
      'unique. Please provide more context to make it unique.',
    );
  }
  return StateError(
    'Found $occurrences occurrences of edits[$editIndex] in $path. Each '
    'oldText must be unique. Please provide more context to make it unique.',
  );
}

StateError _getEmptyOldTextError(String path, int editIndex, int totalEdits) {
  if (totalEdits == 1) {
    return StateError('oldText must not be empty in $path.');
  }
  return StateError('edits[$editIndex].oldText must not be empty in $path.');
}

StateError _getNoChangeError(String path, int totalEdits) {
  if (totalEdits == 1) {
    return StateError(
      'No changes made to $path. The replacement produced identical content. '
      'This might indicate an issue with special characters or the text not '
      'existing as expected.',
    );
  }
  return StateError(
    'No changes made to $path. The replacements produced identical content.',
  );
}

/// 对 LF 归一化内容应用一个或多个精确文本替换。
///
/// 全部编辑都对同一份原始内容匹配（非增量）；替换按逆序应用以保持
/// 偏移稳定。任一编辑需要模糊匹配时，整个操作切换到模糊归一化内容
/// 空间执行，随后通过行级覆盖把变更叠加回原文——未变更行块保留原始
/// 字节。
AppliedEditsResult applyEditsToNormalizedContent(
  String normalizedContent,
  List<Edit> edits,
  String path,
) {
  final normalizedEdits = edits
      .map(
        (edit) => Edit(
          oldText: normalizeToLF(edit.oldText),
          newText: normalizeToLF(edit.newText),
        ),
      )
      .toList();

  for (var i = 0; i < normalizedEdits.length; i++) {
    if (normalizedEdits[i].oldText.isEmpty) {
      throw _getEmptyOldTextError(path, i, normalizedEdits.length);
    }
  }

  final initialMatches = normalizedEdits
      .map((edit) => fuzzyFindText(normalizedContent, edit.oldText))
      .toList();
  final usedFuzzyMatch = initialMatches.any((match) => match.usedFuzzyMatch);
  final replacementBaseContent = usedFuzzyMatch
      ? normalizeForFuzzyMatch(normalizedContent)
      : normalizedContent;

  final matchedEdits = <_MatchedEdit>[];
  for (var i = 0; i < normalizedEdits.length; i++) {
    final edit = normalizedEdits[i];
    final matchResult = fuzzyFindText(replacementBaseContent, edit.oldText);
    if (!matchResult.found) {
      throw _getNotFoundError(path, i, normalizedEdits.length);
    }

    final occurrences =
        _countOccurrences(replacementBaseContent, edit.oldText);
    if (occurrences > 1) {
      throw _getDuplicateError(path, i, normalizedEdits.length, occurrences);
    }

    matchedEdits.add(
      _MatchedEdit(
        editIndex: i,
        matchIndex: matchResult.index,
        matchLength: matchResult.matchLength,
        newText: edit.newText,
      ),
    );
  }

  matchedEdits.sort((a, b) => a.matchIndex.compareTo(b.matchIndex));
  for (var i = 1; i < matchedEdits.length; i++) {
    final previous = matchedEdits[i - 1];
    final current = matchedEdits[i];
    if (previous.matchIndex + previous.matchLength > current.matchIndex) {
      throw StateError(
        'edits[${previous.editIndex}] and edits[${current.editIndex}] overlap '
        'in $path. Merge them into one edit or target disjoint regions.',
      );
    }
  }

  final baseContent = normalizedContent;
  final newContent = usedFuzzyMatch
      ? _applyReplacementsPreservingUnchangedLines(
          normalizedContent,
          replacementBaseContent,
          matchedEdits,
        )
      : _applyReplacements(replacementBaseContent, matchedEdits);

  if (baseContent == newContent) {
    throw _getNoChangeError(path, normalizedEdits.length);
  }

  return AppliedEditsResult(baseContent: baseContent, newContent: newContent);
}

// ---------------------------------------------------------------------------
// 行 diff（LCS 实现）
// ---------------------------------------------------------------------------

class _LineDiffPart {
  const _LineDiffPart({
    required this.value,
    required this.added,
    required this.removed,
  });

  final String value;
  final bool added;
  final bool removed;
}

List<String> _splitLinesForDiff(String content) {
  // diffLines 语义：值带换行、按行分组。
  if (content.isEmpty) {
    return const [];
  }
  final lines = <String>[];
  var start = 0;
  for (var i = 0; i < content.length; i++) {
    if (content.codeUnitAt(i) == 0x0a) {
      lines.add(content.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < content.length) {
    lines.add(content.substring(start));
  }
  return lines;
}

List<_LineDiffPart> _diffLines(String oldContent, String newContent) {
  final oldLines = _splitLinesForDiff(oldContent);
  final newLines = _splitLinesForDiff(newContent);
  final n = oldLines.length;
  final m = newLines.length;

  final lcs = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = oldLines[i] == newLines[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }

  final parts = <_LineDiffPart>[];
  void append(String line, bool added, bool removed) {
    if (parts.isNotEmpty &&
        parts.last.added == added &&
        parts.last.removed == removed) {
      final last = parts.removeLast();
      parts.add(
        _LineDiffPart(value: last.value + line, added: added, removed: removed),
      );
    } else {
      parts.add(_LineDiffPart(value: line, added: added, removed: removed));
    }
  }

  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (oldLines[i] == newLines[j]) {
      append(oldLines[i], false, false);
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      append(oldLines[i], false, true);
      i++;
    } else {
      append(newLines[j], true, false);
      j++;
    }
  }
  while (i < n) {
    append(oldLines[i], false, true);
    i++;
  }
  while (j < m) {
    append(newLines[j], true, false);
    j++;
  }
  return parts;
}

/// 生成标准 unified patch（默认上下文 4 行）。
String generateUnifiedPatch(
  String path,
  String oldContent,
  String newContent, [
  int contextLines = 4,
]) {
  final parts = _diffLines(oldContent, newContent);
  final output = <String>['--- $path', '+++ $path'];

  var line = 1;
  final hunks = <List<String>>[];
  List<String>? current;
  var contextRun = 0;
  for (final part in parts) {
    final raw = part.value.split('\n');
    if (raw.isNotEmpty && raw.last == '') {
      raw.removeLast();
    }
    final isChange = part.added || part.removed;
    if (isChange) {
      current ??= ['@@ -$line +$line @@'];
      contextRun = 0;
      for (final l in raw) {
        current.add(part.added ? '+$l' : '-$l');
      }
    } else {
      if (current != null) {
        contextRun += raw.length;
        for (final l in raw) {
          current.add(' $l');
        }
        if (contextRun >= contextLines * 2) {
          hunks.add(current);
          current = null;
          contextRun = 0;
        }
      }
      line += raw.length;
    }
  }
  if (current != null) {
    hunks.add(current);
  }
  if (hunks.isEmpty) {
    return '';
  }
  for (final hunk in hunks) {
    output.addAll(hunk);
  }
  return output.join('\n');
}

/// 生成带行号与上下文的展示型 diff，同时返回新文件中的首个变更行号。
({String diff, int? firstChangedLine}) generateDiffString(
  String oldContent,
  String newContent, [
  int contextLines = 4,
]) {
  final parts = _diffLines(oldContent, newContent);
  final output = <String>[];

  final oldLines = oldContent.split('\n');
  final newLines = newContent.split('\n');
  final maxLineNum =
      oldLines.length > newLines.length ? oldLines.length : newLines.length;
  final lineNumWidth = maxLineNum.toString().length;

  var oldLineNum = 1;
  var newLineNum = 1;
  var lastWasChange = false;
  int? firstChangedLine;

  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    final raw = part.value.split('\n');
    if (raw.isNotEmpty && raw.last == '') {
      raw.removeLast();
    }

    if (part.added || part.removed) {
      firstChangedLine ??= newLineNum;

      for (final line in raw) {
        if (part.added) {
          final lineNum = newLineNum.toString().padLeft(lineNumWidth);
          output.add('+$lineNum $line');
          newLineNum++;
        } else {
          final lineNum = oldLineNum.toString().padLeft(lineNumWidth);
          output.add('-$lineNum $line');
          oldLineNum++;
        }
      }
      lastWasChange = true;
    } else {
      final nextPartIsChange = i < parts.length - 1 &&
          (parts[i + 1].added || parts[i + 1].removed);
      final hasLeadingChange = lastWasChange;
      final hasTrailingChange = nextPartIsChange;

      if (hasLeadingChange && hasTrailingChange) {
        if (raw.length <= contextLines * 2) {
          for (final line in raw) {
            final lineNum = oldLineNum.toString().padLeft(lineNumWidth);
            output.add(' $lineNum $line');
            oldLineNum++;
            newLineNum++;
          }
        } else {
          final leadingLines = raw.sublist(0, contextLines);
          final trailingLines = raw.sublist(raw.length - contextLines);
          final skippedLines =
              raw.length - leadingLines.length - trailingLines.length;

          for (final line in leadingLines) {
            final lineNum = oldLineNum.toString().padLeft(lineNumWidth);
            output.add(' $lineNum $line');
            oldLineNum++;
            newLineNum++;
          }

          output.add(' ${''.padLeft(lineNumWidth)} ...');
          oldLineNum += skippedLines;
          newLineNum += skippedLines;

          for (final line in trailingLines) {
            final lineNum = oldLineNum.toString().padLeft(lineNumWidth);
            output.add(' $lineNum $line');
            oldLineNum++;
            newLineNum++;
          }
        }
      } else if (hasLeadingChange) {
        final shownLines = raw.sublist(
          0,
          contextLines > raw.length ? raw.length : contextLines,
        );
        final skippedLines = raw.length - shownLines.length;

        for (final line in shownLines) {
          final lineNum = oldLineNum.toString().padLeft(lineNumWidth);
          output.add(' $lineNum $line');
          oldLineNum++;
          newLineNum++;
        }

        if (skippedLines > 0) {
          output.add(' ${''.padLeft(lineNumWidth)} ...');
          oldLineNum += skippedLines;
          newLineNum += skippedLines;
        }
      } else if (hasTrailingChange) {
        final skippedLines =
            (raw.length - contextLines) > 0 ? raw.length - contextLines : 0;
        if (skippedLines > 0) {
          output.add(' ${''.padLeft(lineNumWidth)} ...');
          oldLineNum += skippedLines;
          newLineNum += skippedLines;
        }

        for (final line in raw.sublist(skippedLines)) {
          final lineNum = oldLineNum.toString().padLeft(lineNumWidth);
          output.add(' $lineNum $line');
          oldLineNum++;
          newLineNum++;
        }
      } else {
        // 与变更不相邻的上下文整体跳过。
        oldLineNum += raw.length;
        newLineNum += raw.length;
      }

      lastWasChange = false;
    }
  }

  return (diff: output.join('\n'), firstChangedLine: firstChangedLine);
}
