import '../../core/utils/nai_prompt_parser.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/gallery/nai_image_metadata.dart';

NaiImageMetadata matchMetadataFixedTags({
  required NaiImageMetadata metadata,
  required Iterable<FixedTagEntry> positiveEntries,
  required Iterable<FixedTagEntry> negativeEntries,
}) {
  final positiveMatches = _inferMatches(
    metadata.prompt,
    positiveEntries,
    recordedPrefix: metadata.fixedPrefixTags,
    recordedSuffix: metadata.fixedSuffixTags,
  );
  final negativeMatches = _inferMatches(
    metadata.negativePrompt,
    negativeEntries,
    recordedPrefix: metadata.fixedNegativePrefixTags,
    recordedSuffix: metadata.fixedNegativeSuffixTags,
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
  final normalized = recorded.map(_normalizeEntry).toSet();
  for (final match in inferred) {
    if (normalized.add(_normalizeEntry(match))) result.add(match);
  }
  return result;
}

String _normalizeEntry(String entry) =>
    _extractTags(entry).map(_normalizeTag).join(',');

({List<String> prefix, List<String> suffix}) _inferMatches(
  String prompt,
  Iterable<FixedTagEntry> entries, {
  required List<String> recordedPrefix,
  required List<String> recordedSuffix,
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
  final suffixBoundary = _matchedBoundaryLength(
    normalizedPrompt,
    recordedSuffix,
    fromStart: false,
  );
  var prefixCursor = prefixBoundary;
  var suffixCursor = normalizedPrompt.length - suffixBoundary;
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
