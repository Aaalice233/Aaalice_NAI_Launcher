import '../../../core/constants/api_constants.dart';
import '../../../core/utils/nai_prompt_parser.dart';
import '../fixed_tag/fixed_tag_entry.dart';
import '../fixed_tag/fixed_tag_prompt_type.dart';
import '../fixed_tag/fixed_tag_usage_snapshot.dart';
import 'nai_image_metadata.dart';
import 'nai_metadata_prompt_projection.dart';

/// 把固定词使用快照投影成四个固定词列表，供剥离、高亮与导入选项消费。
///
/// 快照只记录条目身份，PNG 里没有 fixed_* 字段；不投影就等于对所有消费端隐身。
NaiImageMetadata projectFixedTagUsageSnapshot(NaiImageMetadata metadata) {
  final data = metadata.fixedTagUsageData;
  if (data == null) return metadata;
  // PNG 里的 fixed_* 是解析事实，优先于快照派生结果。
  if (metadata.fixedPrefixTags.isNotEmpty ||
      metadata.fixedSuffixTags.isNotEmpty ||
      metadata.fixedNegativePrefixTags.isNotEmpty ||
      metadata.fixedNegativeSuffixTags.isNotEmpty) {
    return metadata;
  }

  final snapshot = FixedTagUsageSnapshot.fromJson(data);
  if (snapshot.entries.isEmpty) return metadata;

  final positive = _projectSide(
    prompt: metadata.prompt,
    snapshot: snapshot,
    promptType: FixedTagPromptType.positive,
    // 正向尾部按 mainPrompt 的剥离顺序让开质量词与透明背景标记。
    trailingBlockers: [
      _splitEntries(metadata.qualityTags),
      if (metadata.hasRecordedTransparentBackgroundTag)
        const [QualityTags.transparentBackgroundTag],
    ],
  );
  final negative = _projectSide(
    prompt: metadata.negativePrompt,
    snapshot: snapshot,
    promptType: FixedTagPromptType.negative,
    trailingBlockers: const [],
  );

  if (positive.prefix.isEmpty &&
      positive.suffix.isEmpty &&
      negative.prefix.isEmpty &&
      negative.suffix.isEmpty) {
    return metadata;
  }
  return metadata.copyWith(
    fixedPrefixTags: positive.prefix,
    fixedSuffixTags: positive.suffix,
    fixedNegativePrefixTags: negative.prefix,
    fixedNegativeSuffixTags: negative.suffix,
  );
}

({List<String> prefix, List<String> suffix}) _projectSide({
  required String prompt,
  required FixedTagUsageSnapshot snapshot,
  required FixedTagPromptType promptType,
  required List<List<String>> trailingBlockers,
}) {
  final prefixEntries = _renderedContents(
    snapshot,
    promptType,
    FixedTagPosition.prefix,
  );
  final suffixEntries = _renderedContents(
    snapshot,
    promptType,
    FixedTagPosition.suffix,
  );
  if (prefixEntries.isEmpty && suffixEntries.isEmpty) {
    return (prefix: const [], suffix: const []);
  }

  final tags = NaiPromptParser.splitSegments(prompt);
  final prefixExpected = _splitEntries(prefixEntries);
  final suffixExpected = _splitEntries(suffixEntries);

  final prefixMatched = promptSegmentsMatchAt(tags, prefixExpected, 0);
  var end = tags.length;
  for (final blocker in trailingBlockers) {
    final start = end - blocker.length;
    if (promptSegmentsMatchAt(tags, blocker, start)) end = start;
  }
  final suffixStart = end - suffixExpected.length;
  final suffixMatched =
      suffixStart >= (prefixMatched ? prefixExpected.length : 0) &&
      promptSegmentsMatchAt(tags, suffixExpected, suffixStart);

  return (
    prefix: prefixMatched ? prefixEntries : const <String>[],
    suffix: suffixMatched ? suffixEntries : const <String>[],
  );
}

List<String> _renderedContents(
  FixedTagUsageSnapshot snapshot,
  FixedTagPromptType promptType,
  FixedTagPosition position,
) {
  final entries =
      snapshot.entriesFor(promptType: promptType, position: position).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
  return [
    for (final entry in entries)
      if (entry.renderedContent.trim().isNotEmpty) entry.renderedContent.trim(),
  ];
}

List<String> _splitEntries(List<String> entries) =>
    entries.expand(NaiPromptParser.splitSegments).toList(growable: false);
