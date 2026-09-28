import '../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import 'fixed_tag_metadata_matcher.dart';

enum FixedTagImportSource { structured, legacyFields, currentLibrary, unknown }

class FixedTagImportResolution {
  const FixedTagImportResolution({
    required this.metadata,
    required this.source,
    this.snapshot,
  });

  final NaiImageMetadata metadata;
  final FixedTagImportSource source;
  final FixedTagUsageSnapshot? snapshot;

  bool get isUnknown => source == FixedTagImportSource.unknown;
}

FixedTagImportResolution resolveFixedTagImport({
  required NaiImageMetadata metadata,
  required Iterable<FixedTagEntry> entries,
}) {
  final structured = metadata.fixedTagUsageSnapshot;
  if (structured != null) {
    return FixedTagImportResolution(
      metadata: metadata,
      source: FixedTagImportSource.structured,
      snapshot: structured,
    );
  }

  if (metadata.hasRecordedFixedTagFields || _hasRecordedTags(metadata)) {
    return FixedTagImportResolution(
      metadata: metadata,
      source: FixedTagImportSource.legacyFields,
      snapshot: _legacySnapshot(metadata),
    );
  }

  final positive = entries
      .where((entry) => entry.promptType == FixedTagPromptType.positive)
      .toList(growable: false);
  final negative = entries
      .where((entry) => entry.promptType == FixedTagPromptType.negative)
      .toList(growable: false);
  final inferred = matchMetadataFixedTags(
    metadata: metadata,
    positiveEntries: positive,
    negativeEntries: negative,
  );
  if (_hasRecordedTags(inferred)) {
    return FixedTagImportResolution(
      metadata: inferred,
      source: FixedTagImportSource.currentLibrary,
      snapshot: _snapshotFromMatches(inferred, entries),
    );
  }
  return FixedTagImportResolution(
    metadata: metadata,
    source: FixedTagImportSource.unknown,
  );
}

bool _hasRecordedTags(NaiImageMetadata metadata) =>
    metadata.fixedPrefixTags.isNotEmpty ||
    metadata.fixedSuffixTags.isNotEmpty ||
    metadata.fixedNegativePrefixTags.isNotEmpty ||
    metadata.fixedNegativeSuffixTags.isNotEmpty;

FixedTagUsageSnapshot _legacySnapshot(NaiImageMetadata metadata) {
  final result = <FixedTagUsageEntry>[];
  void add(
    Iterable<String> values,
    FixedTagPromptType promptType,
    FixedTagPosition position,
  ) {
    for (final value in values) {
      final content = value.trim();
      if (content.isEmpty) continue;
      result.add(
        FixedTagUsageEntry.legacy(
          renderedContent: content,
          position: position,
          promptType: promptType,
          order: result.length,
        ),
      );
    }
  }

  add(
    metadata.fixedPrefixTags,
    FixedTagPromptType.positive,
    FixedTagPosition.prefix,
  );
  add(
    metadata.fixedSuffixTags,
    FixedTagPromptType.positive,
    FixedTagPosition.suffix,
  );
  add(
    metadata.fixedNegativePrefixTags,
    FixedTagPromptType.negative,
    FixedTagPosition.prefix,
  );
  add(
    metadata.fixedNegativeSuffixTags,
    FixedTagPromptType.negative,
    FixedTagPosition.suffix,
  );
  return FixedTagUsageSnapshot(entries: result);
}

FixedTagUsageSnapshot _snapshotFromMatches(
  NaiImageMetadata metadata,
  Iterable<FixedTagEntry> entries,
) {
  final matched = <FixedTagUsageEntry>[];
  void add(
    List<String> values,
    FixedTagPromptType promptType,
    FixedTagPosition position,
  ) {
    for (final value in values) {
      final normalized = normalizeFixedTagMetadataEntry(value);
      final entry = entries.cast<FixedTagEntry?>().firstWhere(
        (candidate) =>
            candidate!.promptType == promptType &&
            candidate.position == position &&
            normalizeFixedTagMetadataEntry(candidate.weightedContent) ==
                normalized,
        orElse: () => null,
      );
      matched.add(
        entry == null
            ? FixedTagUsageEntry.legacy(
                renderedContent: value,
                position: position,
                promptType: promptType,
                order: matched.length,
              )
            : FixedTagUsageEntry.fromFixedTag(entry, order: matched.length),
      );
    }
  }

  add(
    metadata.fixedPrefixTags,
    FixedTagPromptType.positive,
    FixedTagPosition.prefix,
  );
  add(
    metadata.fixedSuffixTags,
    FixedTagPromptType.positive,
    FixedTagPosition.suffix,
  );
  add(
    metadata.fixedNegativePrefixTags,
    FixedTagPromptType.negative,
    FixedTagPosition.prefix,
  );
  add(
    metadata.fixedNegativeSuffixTags,
    FixedTagPromptType.negative,
    FixedTagPosition.suffix,
  );
  return FixedTagUsageSnapshot(entries: matched);
}
