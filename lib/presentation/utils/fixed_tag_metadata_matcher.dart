import '../../core/utils/nai_prompt_parser.dart';
import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/gallery/nai_image_metadata.dart';

NaiImageMetadata matchMetadataFixedTags({
  required NaiImageMetadata metadata,
  required Iterable<FixedTagEntry> positiveEntries,
  required Iterable<FixedTagEntry> negativeEntries,
}) {
  final positiveMatches = _inferMatches(metadata.prompt, positiveEntries);
  final negativeMatches = _inferMatches(
    metadata.negativePrompt,
    negativeEntries,
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
  Iterable<FixedTagEntry> entries,
) {
  final promptTags = _extractTags(prompt);
  final normalizedPrompt = promptTags.map(_normalizeTag).toList();
  final matches = <({int start, int end, FixedTagEntry entry})>[];

  for (final entry in entries) {
    final entryTags = _extractTags(entry.content).map(_normalizeTag).toList();
    if (entryTags.isEmpty || entryTags.length > normalizedPrompt.length) {
      continue;
    }

    for (
      var start = 0;
      start <= normalizedPrompt.length - entryTags.length;
      start++
    ) {
      var isMatch = true;
      for (var offset = 0; offset < entryTags.length; offset++) {
        if (normalizedPrompt[start + offset] != entryTags[offset]) {
          isMatch = false;
          break;
        }
      }
      if (isMatch) {
        matches.add((
          start: start,
          end: start + entryTags.length,
          entry: entry,
        ));
        break;
      }
    }
  }

  matches.sort((a, b) => a.start.compareTo(b.start));
  final prefix = <String>[];
  final suffix = <String>[];
  for (final match in matches) {
    final actualContent = promptTags.sublist(match.start, match.end).join(', ');
    if (match.entry.isPrefix) {
      prefix.add(actualContent);
    } else {
      suffix.add(actualContent);
    }
  }

  return (prefix: prefix, suffix: suffix);
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
