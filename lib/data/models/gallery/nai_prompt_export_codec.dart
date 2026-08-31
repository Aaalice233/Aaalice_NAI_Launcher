import 'dart:convert';

import '../../../core/utils/nai_multi_character_prompt_codec.dart';
import 'nai_image_metadata.dart';
import 'nai_metadata_prompt_projection.dart';

/// Selects prompt categories without creating a second prompt classification.
///
/// Every category maps directly to a persisted [NaiImageMetadata] field.
class NaiPromptCopySelection {
  const NaiPromptCopySelection({
    this.mainPositive = false,
    this.qualityTags = false,
    this.fixedPositive = false,
    this.mainNegative = false,
    this.fixedNegative = false,
    this.characterPositiveIndices = const {},
    this.characterNegativeIndices = const {},
  });

  factory NaiPromptCopySelection.all(NaiImageMetadata metadata) {
    final characters = NaiPromptExportCodec.characterCount(metadata);
    return NaiPromptCopySelection(
      mainPositive: NaiPromptExportCodec.mainPositive(metadata).isNotEmpty,
      qualityTags: NaiPromptExportCodec.hasQualityTags(metadata),
      fixedPositive: NaiPromptExportCodec.hasFixedPositive(metadata),
      mainNegative: NaiPromptExportCodec.mainNegative(metadata).isNotEmpty,
      fixedNegative: NaiPromptExportCodec.hasFixedNegative(metadata),
      characterPositiveIndices: {
        for (var index = 0; index < characters; index++)
          if (NaiPromptExportCodec.characterPositive(
            metadata,
            index,
          ).isNotEmpty)
            index,
      },
      characterNegativeIndices: {
        for (var index = 0; index < characters; index++)
          if (NaiPromptExportCodec.characterNegative(
            metadata,
            index,
          ).isNotEmpty)
            index,
      },
    );
  }

  final bool mainPositive;
  final bool qualityTags;
  final bool fixedPositive;
  final bool mainNegative;
  final bool fixedNegative;
  final Set<int> characterPositiveIndices;
  final Set<int> characterNegativeIndices;

  bool get hasSelection =>
      mainPositive ||
      qualityTags ||
      fixedPositive ||
      mainNegative ||
      fixedNegative ||
      characterPositiveIndices.isNotEmpty ||
      characterNegativeIndices.isNotEmpty;

  NaiPromptCopySelection copyWith({
    bool? mainPositive,
    bool? qualityTags,
    bool? fixedPositive,
    bool? mainNegative,
    bool? fixedNegative,
    Set<int>? characterPositiveIndices,
    Set<int>? characterNegativeIndices,
  }) => NaiPromptCopySelection(
    mainPositive: mainPositive ?? this.mainPositive,
    qualityTags: qualityTags ?? this.qualityTags,
    fixedPositive: fixedPositive ?? this.fixedPositive,
    mainNegative: mainNegative ?? this.mainNegative,
    fixedNegative: fixedNegative ?? this.fixedNegative,
    characterPositiveIndices:
        characterPositiveIndices ?? this.characterPositiveIndices,
    characterNegativeIndices:
        characterNegativeIndices ?? this.characterNegativeIndices,
  );
}

/// Deterministic, round-trippable export for reusable NovelAI prompt text.
///
/// The first two lines remain human-readable. When selected categories carry
/// semantics that plain prompt text cannot represent (fixed categories,
/// character negatives, or coordinates), `metadata:` contains the existing
/// [NaiImageMetadata] JSON contract instead of inventing another schema.
class NaiPromptExportCodec {
  const NaiPromptExportCodec._();

  static String encode(
    NaiImageMetadata metadata, {
    NaiPromptCopySelection? selection,
  }) {
    final selected = selection ?? NaiPromptCopySelection.all(metadata);
    if (!selected.hasSelection) return '';

    final projected = _project(metadata, selected);
    final positive = NaiMultiCharacterPromptCodec.encodeInline(
      basePrompt: projected.prompt,
      characterPrompts: projected.characterPrompts,
    );
    final negative = NaiMultiCharacterPromptCodec.encodeInline(
      basePrompt: projected.negativePrompt,
      characterPrompts: projected.characterNegativePrompts,
    );
    final lines = <String>['positive: $positive', 'negative: $negative'];
    if (_requiresMetadataExtension(projected)) {
      lines.add('metadata: ${jsonEncode(projected.toJson())}');
    }
    return lines.join('\n');
  }

  static NaiImageMetadata? tryDecode(String source) {
    final lines = source.split('\n');
    if (lines.length < 2 || !lines.first.startsWith('positive: ')) return null;
    final negativeIndex = lines.indexWhere(
      (line) => line.startsWith('negative: '),
    );
    if (negativeIndex < 1) return null;
    final metadataIndex = lines.indexWhere(
      (line) => line.startsWith('metadata: '),
    );
    if (metadataIndex >= 0) {
      try {
        final decoded = jsonDecode(
          lines[metadataIndex].substring('metadata: '.length),
        );
        if (decoded is Map) {
          return NaiImageMetadata.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        return null;
      }
    }

    final positive = <String>[
      lines.first.substring('positive: '.length),
      ...lines.sublist(1, negativeIndex),
    ].join('\n');
    final negativeEnd = metadataIndex < 0 ? lines.length : metadataIndex;
    final negative = <String>[
      lines[negativeIndex].substring('negative: '.length),
      ...lines.sublist(negativeIndex + 1, negativeEnd),
    ].join('\n');
    final decodedPositive = NaiMultiCharacterPromptCodec.tryDecode(positive);
    final decodedNegative = NaiMultiCharacterPromptCodec.tryDecode(negative);
    final characterCount = [
      decodedPositive?.characterPrompts.length ?? 0,
      decodedNegative?.characterPrompts.length ?? 0,
    ].reduce((left, right) => left > right ? left : right);
    final characterPrompts = [
      for (var index = 0; index < characterCount; index++)
        index < (decodedPositive?.characterPrompts.length ?? 0)
            ? decodedPositive!.characterPrompts[index]
            : '',
    ];
    final characterNegativePrompts = [
      for (var index = 0; index < characterCount; index++)
        index < (decodedNegative?.characterPrompts.length ?? 0)
            ? decodedNegative!.characterPrompts[index]
            : '',
    ];
    return NaiImageMetadata(
      prompt: decodedPositive?.basePrompt ?? positive,
      negativePrompt: decodedNegative?.basePrompt ?? negative,
      characterPrompts: characterPrompts,
      characterNegativePrompts: characterNegativePrompts,
      characterInfos: [
        for (var index = 0; index < characterCount; index++)
          CharacterPromptInfo(
            prompt: characterPrompts[index],
            negativePrompt: characterNegativePrompts[index],
          ),
      ],
    );
  }

  static int characterCount(NaiImageMetadata metadata) => [
    metadata.characterPrompts.length,
    metadata.characterNegativePrompts.length,
    metadata.characterInfos.length,
  ].reduce((left, right) => left > right ? left : right);

  static String mainPositive(NaiImageMetadata metadata) =>
      NaiMetadataPromptProjection(metadata).mainPrompt.trim();

  static String mainNegative(NaiImageMetadata metadata) =>
      NaiMetadataPromptProjection(
        metadata,
      ).negativePromptWithoutFixedTags.trim();

  static bool hasQualityTags(NaiImageMetadata metadata) =>
      metadata.qualityTags.any((tag) => tag.trim().isNotEmpty) ||
      metadata.hasRecordedTransparentBackgroundTag;

  static bool hasFixedPositive(NaiImageMetadata metadata) =>
      metadata.fixedPrefixTags.any((tag) => tag.trim().isNotEmpty) ||
      metadata.fixedSuffixTags.any((tag) => tag.trim().isNotEmpty);

  static bool hasFixedNegative(NaiImageMetadata metadata) =>
      metadata.fixedNegativePrefixTags.any((tag) => tag.trim().isNotEmpty) ||
      metadata.fixedNegativeSuffixTags.any((tag) => tag.trim().isNotEmpty);

  static String characterPositive(NaiImageMetadata metadata, int index) {
    if (index < metadata.characterPrompts.length) {
      final value = metadata.characterPrompts[index].trim();
      if (value.isNotEmpty) return value;
    }
    return index < metadata.characterInfos.length
        ? metadata.characterInfos[index].prompt.trim()
        : '';
  }

  static String characterNegative(NaiImageMetadata metadata, int index) {
    if (index < metadata.characterNegativePrompts.length) {
      final value = metadata.characterNegativePrompts[index].trim();
      if (value.isNotEmpty) return value;
    }
    return index < metadata.characterInfos.length
        ? metadata.characterInfos[index].negativePrompt?.trim() ?? ''
        : '';
  }

  static NaiImageMetadata _project(
    NaiImageMetadata metadata,
    NaiPromptCopySelection selection,
  ) {
    final positiveParts = <String>[
      if (selection.fixedPositive) ...metadata.fixedPrefixTags,
      if (selection.mainPositive) mainPositive(metadata),
      if (selection.fixedPositive) ...metadata.fixedSuffixTags,
      if (selection.qualityTags && metadata.hasRecordedTransparentBackgroundTag)
        'transparent background',
      if (selection.qualityTags) ...metadata.qualityTags,
    ].map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
    final negativeParts = <String>[
      if (selection.fixedNegative) ...metadata.fixedNegativePrefixTags,
      if (selection.mainNegative) mainNegative(metadata),
      if (selection.fixedNegative) ...metadata.fixedNegativeSuffixTags,
    ].map((value) => value.trim()).where((value) => value.isNotEmpty).toList();

    final selectedIndices = <int>{
      ...selection.characterPositiveIndices,
      ...selection.characterNegativeIndices,
    }.toList()..sort();
    final characterInfos = <CharacterPromptInfo>[];
    for (final index in selectedIndices) {
      final sourceInfo = index < metadata.characterInfos.length
          ? metadata.characterInfos[index]
          : null;
      characterInfos.add(
        CharacterPromptInfo(
          prompt: selection.characterPositiveIndices.contains(index)
              ? characterPositive(metadata, index)
              : '',
          negativePrompt: selection.characterNegativeIndices.contains(index)
              ? characterNegative(metadata, index)
              : '',
          position: sourceInfo?.position,
          centerX: sourceInfo?.centerX,
          centerY: sourceInfo?.centerY,
        ),
      );
    }

    return NaiImageMetadata(
      prompt: positiveParts.join(', '),
      negativePrompt: negativeParts.join(', '),
      characterPrompts: [for (final info in characterInfos) info.prompt],
      characterNegativePrompts: [
        for (final info in characterInfos) info.negativePrompt ?? '',
      ],
      fixedPrefixTags: selection.fixedPositive
          ? metadata.fixedPrefixTags
          : const [],
      fixedSuffixTags: selection.fixedPositive
          ? metadata.fixedSuffixTags
          : const [],
      qualityTags: selection.qualityTags ? metadata.qualityTags : const [],
      fixedNegativePrefixTags: selection.fixedNegative
          ? metadata.fixedNegativePrefixTags
          : const [],
      fixedNegativeSuffixTags: selection.fixedNegative
          ? metadata.fixedNegativeSuffixTags
          : const [],
      transparentBackground: selection.qualityTags
          ? metadata.transparentBackground
          : null,
      characterInfos: characterInfos,
      characterUseCoords: characterInfos.isEmpty
          ? null
          : metadata.characterUseCoords,
      originalPrompt: positiveParts.join(', '),
    );
  }

  static bool _requiresMetadataExtension(NaiImageMetadata metadata) =>
      metadata.hasSeparatedFields ||
      metadata.characterNegativePrompts.any((value) => value.isNotEmpty) ||
      metadata.characterInfos.any(
        (info) =>
            (info.negativePrompt?.isNotEmpty ?? false) ||
            info.position != null ||
            info.centerX != null ||
            info.centerY != null,
      ) ||
      metadata.characterUseCoords != null;
}
