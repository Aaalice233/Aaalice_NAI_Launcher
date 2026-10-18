import '../../core/constants/api_constants.dart';
import '../../core/utils/nai_prompt_parser.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../data/models/gallery/fixed_tag_usage_projection.dart';
import '../../data/models/gallery/nai_image_metadata.dart';

NaiImageMetadata matchMetadataFixedTags({
  required NaiImageMetadata metadata,
  required Iterable<FixedTagEntry> positiveEntries,
  required Iterable<FixedTagEntry> negativeEntries,
}) {
  var base = metadata;
  if (base.hasExplicitFixedTagMetadata ||
      base.fixedPrefixTags.isNotEmpty ||
      base.fixedSuffixTags.isNotEmpty ||
      base.fixedNegativePrefixTags.isNotEmpty ||
      base.fixedNegativeSuffixTags.isNotEmpty) {
    base = projectFixedTagUsageSnapshot(base);
  }

  // 严格只匹配用户当前本地词库中实际存在的固定词，绝不从图片元数据中凭空捏造任何临时条目
  final posCandidates = [...positiveEntries];
  final negCandidates = [...negativeEntries];

  // 对于 Combo（正负组合）类型的条目，必须满足正向和反向同时 100% 严格匹配。
  // 只要任意一端有缺失（如负面缺少某些标签），该条目就判定为完全未命中，
  // 既不从正向剥离，也不从反向剥离，确保不激活该组合词并将全量信息展示在输入框中。
  final validCombos = <FixedTagEntry>{};
  final allCandidates = [...posCandidates, ...negCandidates];
  for (final entry in allCandidates) {
    if (entry.promptType == FixedTagPromptType.combo) {
      final posOk = _isTagsFullyContained(base.prompt, entry.content);
      final negOk = _isTagsFullyContained(
        base.negativePrompt,
        entry.negativeContent ?? '',
      );
      if (posOk && negOk) {
        validCombos.add(entry);
      }
    }
  }

  posCandidates.removeWhere(
    (e) => e.promptType == FixedTagPromptType.combo && !validCombos.contains(e),
  );
  negCandidates.removeWhere(
    (e) => e.promptType == FixedTagPromptType.combo && !validCombos.contains(e),
  );

  final posMatch = _matchAndStripTags(
    prompt: base.prompt,
    candidates: posCandidates,
    isNegative: false,
    trailingBlockers: [
      base.qualityTags.expand(_extractTags).map(_normalizeTag).toList(),
      if (base.hasRecordedTransparentBackgroundTag)
        [_normalizeTag(QualityTags.transparentBackgroundTag)],
    ],
  );

  final negMatch = _matchAndStripTags(
    prompt: base.negativePrompt,
    candidates: negCandidates,
    isNegative: true,
    trailingBlockers: const [],
  );

  return base.copyWith(
    fixedPrefixTags: _mergeMatches(
      base.fixedPrefixTags,
      posMatch.prefix,
    ),
    fixedSuffixTags: _mergeMatches(
      base.fixedSuffixTags,
      posMatch.suffix,
    ),
    fixedNegativePrefixTags: _mergeMatches(
      base.fixedNegativePrefixTags,
      negMatch.prefix,
    ),
    fixedNegativeSuffixTags: _mergeMatches(
      base.fixedNegativeSuffixTags,
      negMatch.suffix,
    ),
    prompt: posMatch.cleanedPrompt,
    negativePrompt: negMatch.cleanedPrompt,
  );
}

class _MatchResult {
  final List<String> prefix;
  final List<String> suffix;
  final String cleanedPrompt;

  const _MatchResult({
    required this.prefix,
    required this.suffix,
    required this.cleanedPrompt,
  });
}

_MatchResult _matchAndStripTags({
  required String prompt,
  required List<FixedTagEntry> candidates,
  required bool isNegative,
  required List<List<String>> trailingBlockers,
}) {
  final rawTags = _extractTagsForAnalysis(prompt);
  if (rawTags.isEmpty || candidates.isEmpty) {
    return _MatchResult(
      prefix: const [],
      suffix: const [],
      cleanedPrompt: prompt,
    );
  }

  final normTags = rawTags.map(_normalizeTag).toList();
  final consumedIndices = <int>{};
  final matchedPrefix = <String>[];
  final matchedSuffix = <String>[];
  final matchedEntryIds = <String>{};

  // 候选按有效 tag 数量由多到少排序，避免长组合词被单个词碎片化抢占
  final sortedCandidates = [...candidates]..sort((a, b) {
      final aContent = (isNegative && a.promptType == FixedTagPromptType.combo)
          ? (a.negativeContent ?? '')
          : a.content;
      final bContent = (isNegative && b.promptType == FixedTagPromptType.combo)
          ? (b.negativeContent ?? '')
          : b.content;
      return _extractTagsForAnalysis(bContent).length.compareTo(_extractTagsForAnalysis(aContent).length);
    });

  for (final entry in sortedCandidates) {
    if (matchedEntryIds.contains(entry.id)) continue;

    final content = (isNegative && entry.promptType == FixedTagPromptType.combo)
        ? (entry.negativeContent ?? '')
        : entry.content;
    final entryTags = _extractTagsForAnalysis(content).map(_normalizeTag).where((t) => t.isNotEmpty).toList();
    if (entryTags.isEmpty) continue;

    // 在未被消费的 normTags 中查找所有匹配上的 tag 下标
    final currentMatched = <int>[];
    for (final eTag in entryTags) {
      for (var i = 0; i < normTags.length; i++) {
        if (!consumedIndices.contains(i) && !currentMatched.contains(i)) {
          if (normTags[i] == eTag) {
            currentMatched.add(i);
            break;
          }
        }
      }
    }

    // 严格完全重合判定：固定标签中的所有有效 tag 必须 100% 全部存在于提示词中
    // 只要缺少任何一个 tag（或者词条不完全重合），就绝不激活选中该固定标签
    final isMatch = currentMatched.length == entryTags.length;

    if (isMatch) {
      // 只要固定词被激活接管，该词条在原图中的所有出现（包括重复词，如 boy, boy）全部标记消费剥离
      for (var i = 0; i < normTags.length; i++) {
        if (entryTags.contains(normTags[i])) {
          consumedIndices.add(i);
        }
      }
      final sortedMatched = [...currentMatched]..sort();
      final rendered = sortedMatched.map((idx) => rawTags[idx]).join(', ');
      matchedEntryIds.add(entry.id);

      if (entry.position == FixedTagPosition.suffix) {
        matchedSuffix.add(rendered.trim());
      } else {
        matchedPrefix.add(rendered.trim());
      }
    }
  }

  // 同时将质量词、透明背景等系统项全量消费剔除
  for (final blocker in trailingBlockers) {
    for (var i = 0; i < normTags.length; i++) {
      if (blocker.contains(normTags[i])) {
        consumedIndices.add(i);
      }
    }
  }

  if (consumedIndices.isEmpty) {
    return _MatchResult(
      prefix: matchedPrefix,
      suffix: matchedSuffix,
      cleanedPrompt: prompt,
    );
  }

  // 构建从原提示词中扣除固定词后的极简净文本（严格保留换行、空行与缩进）
  final lineBreakPattern = RegExp(r'\r\n|\r|\n');
  final leadingWhitespacePattern = RegExp(r'^[ \t]*');
  final trailingWhitespacePattern = RegExp(r'[ \t]*$');

  final consumedNormTags = <String>{
    for (final idx in consumedIndices) normTags[idx],
  };

  final cleanedPrompt = prompt.splitMapJoin(
    lineBreakPattern,
    onMatch: (match) => match.group(0)!,
    onNonMatch: (line) {
      if (line.isEmpty) return line;

      final leadingWhitespace =
          leadingWhitespacePattern.firstMatch(line)?.group(0) ?? '';
      final trailingWhitespace =
          trailingWhitespacePattern.firstMatch(line)?.group(0) ?? '';
      final contentEnd = line.length - trailingWhitespace.length;
      if (leadingWhitespace.length >= contentEnd) {
        return line;
      }

      final content = line.substring(leadingWhitespace.length, contentEnd);
      final keepsTrailingComma = content.trim().endsWith(',');

      final lineTags = _extractTags(content);
      if (lineTags.isEmpty) return line;

      final remainingLineTags = <String>[];
      for (final rawTag in lineTags) {
        final norm = _normalizeTag(rawTag);
        if (norm.isNotEmpty && !consumedNormTags.contains(norm)) {
          remainingLineTags.add(rawTag);
        }
      }

      if (remainingLineTags.isEmpty) {
        return '';
      }

      var formatted = remainingLineTags.join(', ');
      if (keepsTrailingComma && formatted.isNotEmpty) {
        formatted = '$formatted,';
      }
      return '$leadingWhitespace$formatted$trailingWhitespace';
    },
  );

  var finalCleanedPrompt = cleanedPrompt;
  // 若整段提示词剥离后已无任何有效单词标签（仅剩换行、空白或逗号等符号残渣），
  // 则彻底净化为空字符串，避免残留无意义的空行或孤立回车符。
  if (finalCleanedPrompt.replaceAll(RegExp(r'[\r\n\s,]+'), '').isEmpty) {
    finalCleanedPrompt = '';
  } else {
    // 裁剪首尾因整行词条被剥离而留下的孤立空换行
    finalCleanedPrompt = finalCleanedPrompt
        .replaceAll(RegExp(r'^\s*[\r\n]+'), '')
        .replaceAll(RegExp(r'[\r\n]+\s*$'), '');
  }

  return _MatchResult(
    prefix: matchedPrefix,
    suffix: matchedSuffix,
    cleanedPrompt: finalCleanedPrompt,
  );
}

bool _isTagsFullyContained(String prompt, String content) {
  final rawTags = _extractTagsForAnalysis(prompt);
  final normTags = rawTags.map(_normalizeTag).toList();
  final entryTags = _extractTagsForAnalysis(content).map(_normalizeTag).where((t) => t.isNotEmpty).toList();
  if (entryTags.isEmpty) return false;
  final matched = <int>[];
  for (final eTag in entryTags) {
    for (var i = 0; i < normTags.length; i++) {
      if (!matched.contains(i) && normTags[i] == eTag) {
        matched.add(i);
        break;
      }
    }
  }
  return matched.length == entryTags.length;
}

Set<int> fixedPromptTagIndexes({
  required List<String> promptTags,
  required List<String> prefixEntries,
  required List<String> suffixEntries,
}) {
  final normalizedPrompt = promptTags.map(_normalizeTag).toList();
  final prefixLength = _matchedBoundaryLength(
    normalizedPrompt,
    prefixEntries,
    fromStart: true,
  );
  final suffixLength = _matchedBoundaryLength(
    normalizedPrompt,
    suffixEntries,
    fromStart: false,
  );
  return {
    for (var index = 0; index < prefixLength; index++) index,
    for (
      var index = normalizedPrompt.length - suffixLength;
      index < normalizedPrompt.length;
      index++
    )
      if (index >= prefixLength) index,
  };
}

int _matchedBoundaryLength(
  List<String> promptTags,
  List<String> entries, {
  required bool fromStart,
}) {
  final expected = entries
      .expand(_extractTags)
      .map(_normalizeTag)
      .where((tag) => tag.isNotEmpty)
      .toList();
  if (expected.isEmpty || expected.length > promptTags.length) return 0;
  final start = fromStart ? 0 : promptTags.length - expected.length;
  return _matchesAt(promptTags, expected, start) ? expected.length : 0;
}

bool _matchesAt(List<String> source, List<String> expected, int start) {
  if (start < 0 || start + expected.length > source.length) return false;
  for (var offset = 0; offset < expected.length; offset++) {
    if (source[start + offset] != expected[offset]) return false;
  }
  return true;
}

List<String> _mergeMatches(List<String> recorded, List<String> inferred) {
  final result = <String>[...recorded];
  final normalized = recorded.map(normalizeFixedTagMetadataEntry).toSet();
  for (final match in inferred) {
    if (normalized.add(normalizeFixedTagMetadataEntry(match))) {
      result.add(match);
    }
  }
  return result;
}

String normalizeFixedTagMetadataEntry(String entry) =>
    _extractTagsForAnalysis(entry).map(_normalizeTag).join(',');

List<String> _extractTags(String prompt) =>
    NaiPromptParser.splitSegments(prompt);

/// 专用于固定词语义数据分析与比对的切分器：
/// 在数据分析层将换行与逗号等同看待，与呈现层排版彻底解耦。
List<String> _extractTagsForAnalysis(String prompt) {
  final segments = <String>[];
  final buffer = StringBuffer();
  var braceDepth = 0;
  var bracketDepth = 0;
  var parenDepth = 0;
  var inPipe = false;

  for (var i = 0; i < prompt.length; i++) {
    final char = prompt[i];

    if (char == '\\' && i + 1 < prompt.length) {
      buffer
        ..write(char)
        ..write(prompt[i + 1]);
      i++;
      continue;
    }

    if (char == '{') {
      braceDepth++;
    } else if (char == '}' && braceDepth > 0) {
      braceDepth--;
    } else if (char == '[') {
      bracketDepth++;
    } else if (char == ']' && bracketDepth > 0) {
      bracketDepth--;
    } else if (char == '(') {
      parenDepth++;
    } else if (char == ')' && parenDepth > 0) {
      parenDepth--;
    }

    if (char == '|' && i + 1 < prompt.length && prompt[i + 1] == '|') {
      inPipe = !inPipe;
      buffer.write('||');
      i++;
      continue;
    }

    // 在数据分析层，顶层的逗号或换行均为语义标签分隔符
    final isDelimiter = (char == ',' || char == '\n' || char == '\r');
    if (isDelimiter &&
        braceDepth == 0 &&
        bracketDepth == 0 &&
        parenDepth == 0 &&
        !inPipe) {
      final segment = buffer.toString().trim();
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  final lastSegment = buffer.toString().trim();
  if (lastSegment.isNotEmpty) {
    segments.add(lastSegment);
  }

  return segments;
}

String _normalizeTag(String tag) {
  var result = tag.trim().toLowerCase();
  result = result
      .replaceAll('，', ',')
      .replaceAll('。', '.')
      .replaceAll('：', ':')
      .replaceAll('；', ';')
      .replaceAll('！', '!')
      .replaceAll('？', '?')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('【', '[')
      .replaceAll('】', ']')
      .replaceAll('｛', '{')
      .replaceAll('｝', '}')
      .replaceAll('、', ',');
  result = result.replaceAll('_', ' ');
  final numericWeight = RegExp(
    r'^-?\d+(?:\.\d+)?::(.+?)(?:::)?$',
  ).firstMatch(result);
  if (numericWeight != null) result = numericWeight.group(1)!.trim();
  result = result.replaceAll('::', '').trim();
  result = result.replaceAll(RegExp(r'^[\{\[]+'), '');
  result = result.replaceAll(RegExp(r'[\}\]]+$'), '');
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  return result;
}
