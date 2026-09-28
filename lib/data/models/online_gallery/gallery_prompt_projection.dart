import '../../../core/utils/nai_multi_character_prompt_codec.dart';
import '../../../core/utils/prompt_tag_utils.dart';
import 'gallery_item.dart';

enum GalleryPromptCopyCategory { general, character, copyright, artist, meta }

class GalleryPromptCopySelection {
  const GalleryPromptCopySelection({
    this.mainPositive = false,
    this.mainNegative = false,
    this.tagCategories = const {},
    this.characterPositiveIndices = const {},
    this.characterNegativeIndices = const {},
  });

  final bool mainPositive;
  final bool mainNegative;
  final Set<GalleryPromptCopyCategory> tagCategories;
  final Set<int> characterPositiveIndices;
  final Set<int> characterNegativeIndices;

  bool get hasSelection =>
      mainPositive ||
      mainNegative ||
      tagCategories.isNotEmpty ||
      characterPositiveIndices.isNotEmpty ||
      characterNegativeIndices.isNotEmpty;

  GalleryPromptCopySelection copyWith({
    bool? mainPositive,
    bool? mainNegative,
    Set<GalleryPromptCopyCategory>? tagCategories,
    Set<int>? characterPositiveIndices,
    Set<int>? characterNegativeIndices,
  }) {
    return GalleryPromptCopySelection(
      mainPositive: mainPositive ?? this.mainPositive,
      mainNegative: mainNegative ?? this.mainNegative,
      tagCategories: Set.unmodifiable(tagCategories ?? this.tagCategories),
      characterPositiveIndices: Set.unmodifiable(
        characterPositiveIndices ?? this.characterPositiveIndices,
      ),
      characterNegativeIndices: Set.unmodifiable(
        characterNegativeIndices ?? this.characterNegativeIndices,
      ),
    );
  }
}

/// Copy-specific prompt choices exposed by one gallery source.
///
/// Categorized booru tags stay separate from structured source prompts so
/// Gelbooru is never presented as categorized and AI TAG/codex characters keep
/// their real positive/negative shape.
class GalleryPromptCopyProjection {
  const GalleryPromptCopyProjection({
    this.mainPositive = '',
    this.mainNegative = '',
    this.categorizedPrompts = const {},
    this.characterPrompts = const [],
  });

  static const categoryOrder = <GalleryPromptCopyCategory>[
    GalleryPromptCopyCategory.artist,
    GalleryPromptCopyCategory.character,
    GalleryPromptCopyCategory.copyright,
    GalleryPromptCopyCategory.general,
    GalleryPromptCopyCategory.meta,
  ];

  final String mainPositive;
  final String mainNegative;
  final Map<GalleryPromptCopyCategory, String> categorizedPrompts;
  final List<GalleryCharacterPrompt> characterPrompts;

  Set<GalleryPromptCopyCategory> get availableCategories => {
    for (final entry in categorizedPrompts.entries)
      if (entry.value.trim().isNotEmpty) entry.key,
  };

  Set<int> get availableCharacterPositiveIndices => {
    for (var index = 0; index < characterPrompts.length; index++)
      if (characterPrompts[index].prompt.trim().isNotEmpty) index,
  };

  Set<int> get availableCharacterNegativeIndices => {
    for (var index = 0; index < characterPrompts.length; index++)
      if (characterPrompts[index].negativePrompt.trim().isNotEmpty) index,
  };

  bool get hasMainPositive => mainPositive.trim().isNotEmpty;
  bool get hasMainNegative => mainNegative.trim().isNotEmpty;
  bool get hasOptions =>
      hasMainPositive ||
      hasMainNegative ||
      availableCategories.isNotEmpty ||
      availableCharacterPositiveIndices.isNotEmpty ||
      availableCharacterNegativeIndices.isNotEmpty;

  GalleryPromptCopySelection defaultSelection({
    Set<GalleryPromptCopyCategory>? preferredCategories,
  }) {
    final selectedCategories = preferredCategories == null
        ? availableCategories
        : availableCategories.intersection(preferredCategories);
    return GalleryPromptCopySelection(
      mainPositive: hasMainPositive,
      mainNegative: hasMainNegative,
      tagCategories: Set.unmodifiable(
        selectedCategories.isEmpty && availableCategories.isNotEmpty
            ? availableCategories
            : selectedCategories,
      ),
      characterPositiveIndices: Set.unmodifiable(
        availableCharacterPositiveIndices,
      ),
      characterNegativeIndices: Set.unmodifiable(
        availableCharacterNegativeIndices,
      ),
    );
  }

  String buildText(GalleryPromptCopySelection selection) {
    final positiveParts = <String>[];
    if (selection.mainPositive && hasMainPositive) {
      positiveParts.add(mainPositive.trim());
    }
    for (final category in categoryOrder) {
      if (!selection.tagCategories.contains(category)) continue;
      final value = categorizedPrompts[category]?.trim() ?? '';
      if (value.isNotEmpty) positiveParts.add(value);
    }
    final positiveCharacters = <String>[
      for (final index in selection.characterPositiveIndices.toList()..sort())
        if (index >= 0 &&
            index < characterPrompts.length &&
            characterPrompts[index].prompt.trim().isNotEmpty)
          characterPrompts[index].prompt.trim(),
    ];

    final negativeParts = <String>[];
    if (selection.mainNegative && hasMainNegative) {
      negativeParts.add(mainNegative.trim());
    }
    final negativeCharacters = <String>[
      for (final index in selection.characterNegativeIndices.toList()..sort())
        if (index >= 0 &&
            index < characterPrompts.length &&
            characterPrompts[index].negativePrompt.trim().isNotEmpty)
          characterPrompts[index].negativePrompt.trim(),
    ];

    final blocks = <String>[];
    final positive = NaiMultiCharacterPromptCodec.encodeInline(
      basePrompt: _stablePromptJoin(positiveParts),
      characterPrompts: positiveCharacters,
    );
    final negative = NaiMultiCharacterPromptCodec.encodeInline(
      basePrompt: _stablePromptJoin(negativeParts),
      characterPrompts: negativeCharacters,
    );
    if (positive.isNotEmpty) blocks.add(positive);
    if (negative.isNotEmpty) blocks.add(negative);
    return blocks.join('\n\n');
  }

  String _stablePromptJoin(List<String> prompts) {
    final values = <String>[];
    final seen = <String>{};
    for (final prompt in prompts) {
      for (final token in PromptTagUtils.splitTopLevel(prompt)) {
        final value = token.trim();
        if (value.isEmpty || !seen.add(value)) continue;
        values.add(value);
      }
    }
    return values.join(', ');
  }
}

/// Action-ready prompt output derived from an online gallery item.
class GalleryPromptProjection {
  const GalleryPromptProjection({
    required this.positivePrompt,
    required this.negativePrompt,
    required this.characterPrompts,
    required this.copy,
  });

  final String positivePrompt;
  final String negativePrompt;
  final List<GalleryCharacterPrompt> characterPrompts;
  final GalleryPromptCopyProjection copy;

  /// Legacy card-copy policy follows the generation projection.
  /// Detail copy uses [copy] with its own user selection instead.
  String get copyText {
    final projected = GalleryPromptCopyProjection(
      mainPositive: positivePrompt,
      mainNegative: negativePrompt,
      characterPrompts: characterPrompts,
    );
    return projected.buildText(projected.defaultSelection());
  }

  bool get hasUsableOutput =>
      positivePrompt.trim().isNotEmpty ||
      negativePrompt.trim().isNotEmpty ||
      characterPrompts.any(
        (character) =>
            character.prompt.trim().isNotEmpty ||
            character.negativePrompt.trim().isNotEmpty,
      );
}
