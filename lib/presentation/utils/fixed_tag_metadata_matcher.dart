import '../../core/constants/api_constants.dart';
import '../../core/utils/nai_prompt_parser.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/gallery/fixed_tag_usage_projection.dart';
import '../../data/models/gallery/nai_image_metadata.dart';

NaiImageMetadata matchMetadataFixedTags({
  required NaiImageMetadata metadata,
  required Iterable<FixedTagEntry> positiveEntries,
  required Iterable<FixedTagEntry> negativeEntries,
}) {
  if (metadata.hasExplicitFixedTagMetadata ||
      metadata.fixedPrefixTags.isNotEmpty ||
      metadata.fixedSuffixTags.isNotEmpty ||
      metadata.fixedNegativePrefixTags.isNotEmpty ||
      metadata.fixedNegativeSuffixTags.isNotEmpty) {
    return projectFixedTagUsageSnapshot(metadata);
  }
  final positiveMatches = _inferMatches(
    metadata.prompt,
    positiveEntries,
    recordedPrefix: metadata.fixedPrefixTags,
    recordedSuffix: metadata.fixedSuffixTags,
    trailingBlockers: [
      metadata.qualityTags.expand(_extractTags).map(_normalizeTag).toList(),
      if (metadata.hasRecordedTransparentBackgroundTag)
        [_normalizeTag(QualityTags.transparentBackgroundTag)],
    ],
  );
  final negativeMatches = _inferMatches(
    metadata.negativePrompt,
    negativeEntries,
    recordedPrefix: metadata.fixedNegativePrefixTags,
    recordedSuffix: metadata.fixedNegativeSuffixTags,
    trailingBlockers: const [],
  );

  return metadata.copyWith(
    fixedPrefixTags: _mergeMatches(
      metadata.fixedPrefixTags,
      positiveMatches.prefix,
    ),
    fixedSuffixTags: _mergeMatches(
      metadata.fixedSuffixTags,
      positiveMatches.suffix,
    ),
    fixedNegativePrefixTags: _mergeMatches(
      metadata.fixedNegativePrefixTags,
      negativeMatches.prefix,
    ),
    fixedNegativeSuffixTags: _mergeMatches(
      metadata.fixedNegativeSuffixTags,
      negativeMatches.suffix,
    ),
  );
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
    _extractTags(entry).map(_normalizeTag).join(',');

/// 后缀匹配的起点：让开 prompt 尾部那些不属于固定词的区块。
///
/// [blockers] 按"从尾往前"的顺序给出（质量词在外、透明背景标记在内）。
///
/// 某项对不上就跳过继续试下一项：自定义质量词模式下质量词列表为空，
/// 停在第一项会让透明背景标记也让不开。
int _initialSuffixCursor(
  List<String> normalizedPrompt,
  List<List<String>> blockers,
) {
  var cursor = normalizedPrompt.length;
  for (final blocker in blockers) {
    if (blocker.isEmpty) continue;
    final start = cursor - blocker.length;
    if (_matchesAt(normalizedPrompt, blocker, start)) cursor = start;
  }
  return cursor;
}

({List<String> prefix, List<String> suffix}) _inferMatches(
  String prompt,
  Iterable<FixedTagEntry> entries, {
  required List<String> recordedPrefix,
  required List<String> recordedSuffix,
  required List<List<String>> trailingBlockers,
}) {
  final promptTags = _extractTags(prompt);
  final normalizedPrompt = promptTags.map(_normalizeTag).toList();
  final candidates = entries
      .map(
        (entry) => (
          entry: entry,
          tags: _extractTags(entry.content).map(_normalizeTag).toList(),
        ),
      )
      .where((candidate) => candidate.tags.isNotEmpty)
      .toList();
  final prefixBoundary = _matchedBoundaryLength(
    normalizedPrompt,
    recordedPrefix,
    fromStart: true,
  );
  final tailStart = _initialSuffixCursor(normalizedPrompt, trailingBlockers);
  final suffixBoundary = _matchedBoundaryLength(
    normalizedPrompt.sublist(0, tailStart),
    recordedSuffix,
    fromStart: false,
  );
  var prefixCursor = prefixBoundary;
  var suffixCursor = tailStart - suffixBoundary;
  final usedEntryIds = <String>{};
  final prefix = <String>[];
  final suffix = <String>[];

  while (prefixCursor < suffixCursor) {
    final match = _bestBoundaryMatch(
      normalizedPrompt,
      candidates,
      cursor: prefixCursor,
      limit: suffixCursor,
      prefix: true,
      usedEntryIds: usedEntryIds,
    );
    if (match == null) break;
    final end = prefixCursor + match.tags.length;
    prefix.add(promptTags.sublist(prefixCursor, end).join(', '));
    prefixCursor = end;
    usedEntryIds.add(match.entry.id);
  }

  while (suffixCursor > prefixCursor) {
    final match = _bestBoundaryMatch(
      normalizedPrompt,
      candidates,
      cursor: suffixCursor,
      limit: prefixCursor,
      prefix: false,
      usedEntryIds: usedEntryIds,
    );
    if (match == null) break;
    final start = suffixCursor - match.tags.length;
    suffix.insert(0, promptTags.sublist(start, suffixCursor).join(', '));
    suffixCursor = start;
    usedEntryIds.add(match.entry.id);
  }

  return (prefix: prefix, suffix: suffix);
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

({FixedTagEntry entry, List<String> tags})? _bestBoundaryMatch(
  List<String> promptTags,
  List<({FixedTagEntry entry, List<String> tags})> candidates, {
  required int cursor,
  required int limit,
  required bool prefix,
  required Set<String> usedEntryIds,
}) {
  final matches = candidates.where((candidate) {
    if (candidate.entry.isPrefix != prefix ||
        usedEntryIds.contains(candidate.entry.id)) {
      return false;
    }
    final start = prefix ? cursor : cursor - candidate.tags.length;
    final end = start + candidate.tags.length;
    if (start < (prefix ? 0 : limit) ||
        end > (prefix ? limit : promptTags.length)) {
      return false;
    }
    return _matchesAt(promptTags, candidate.tags, start);
  }).toList();
  if (matches.isEmpty) return null;
  matches.sort((a, b) {
    final lengthOrder = b.tags.length.compareTo(a.tags.length);
    if (lengthOrder != 0) return lengthOrder;
    return prefix
        ? a.entry.sortOrder.compareTo(b.entry.sortOrder)
        : b.entry.sortOrder.compareTo(a.entry.sortOrder);
  });
  return matches.first;
}

bool _matchesAt(List<String> source, List<String> expected, int start) {
  if (start < 0 || start + expected.length > source.length) return false;
  for (var offset = 0; offset < expected.length; offset++) {
    if (source[start + offset] != expected[offset]) return false;
  }
  return true;
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

List<String> _extractTags(String prompt) =>
    NaiPromptParser.splitSegments(prompt);

String _normalizeTag(String tag) {
  var result = tag.trim().toLowerCase();
  final numericWeight = RegExp(
    r'^-?\d+(?:\.\d+)?::(.+?)(?:::)?$',
  ).firstMatch(result);
  if (numericWeight != null) result = numericWeight.group(1)!.trim();
  result = result.replaceFirst(RegExp(r'^[\{\[]+'), '');
  result = result.replaceFirst(RegExp(r'[\}\]]+$'), '');
  return result.trim();
}
