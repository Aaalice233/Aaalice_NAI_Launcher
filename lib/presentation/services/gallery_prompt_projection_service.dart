import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_prompt_projection.dart';
import '../providers/online_gallery_output_filter_provider.dart';
import '../providers/online_gallery_prompt_tag_settings_provider.dart';

/// Resolves the source-specific prompt shapes used by the online gallery into
/// one action-ready projection.
class GalleryPromptProjectionService {
  const GalleryPromptProjectionService();

  GalleryPromptProjection project({
    required GalleryItem item,
    GalleryDetail? detail,
    GalleryMedia? currentMedia,
    required OnlineGalleryPromptTagSettings promptTagSettings,
    required OnlineGalleryOutputFilterSettings outputFilter,
  }) {
    final media = currentMedia ?? _resolveMedia(item, detail);
    final generatedTagPrompt = promptTagSettings.promptFor(
      item,
      outputFilter: outputFilter,
    );
    final rawPositivePrompt = _firstNonBlank([
      media?.prompt,
      detail?.prompt,
      item.cover.prompt,
      _metadataString(item.rawSourceMetadata, 'prompt'),
      generatedTagPrompt,
    ]);
    final positivePrompt = projectPositivePrompt(
      rawPositivePrompt ?? '',
      outputFilter: outputFilter,
    );

    // Negative prompts describe generation intent rather than source tags and
    // must not be rewritten by output filtering.
    final negativePrompt =
        _firstNonBlank([
          media?.negativePrompt,
          detail?.negativePrompt,
          item.cover.negativePrompt,
          _metadataString(item.rawSourceMetadata, 'negativePrompt'),
        ]) ??
        '';

    final characterPrompts = List<GalleryCharacterPrompt>.unmodifiable(
      _characterPrompts(item, detail).map(
        (character) => GalleryCharacterPrompt(
          label: character.label,
          prompt: outputFilter.filterPrompt(character.prompt),
          negativePrompt: character.negativePrompt,
        ),
      ),
    );

    return GalleryPromptProjection(
      positivePrompt: positivePrompt,
      negativePrompt: negativePrompt,
      characterPrompts: characterPrompts,
      copyText: _buildCopyText(
        positivePrompt,
        negativePrompt,
        characterPrompts,
      ),
    );
  }

  /// Applies the shared positive-prompt projection to a specialized action
  /// such as an artist chain without changing that action's semantic scope.
  String projectPositivePrompt(
    String prompt, {
    required OnlineGalleryOutputFilterSettings outputFilter,
  }) => outputFilter.filterPrompt(prompt);

  GalleryMedia? _resolveMedia(GalleryItem item, GalleryDetail? detail) {
    if (detail == null || detail.media.isEmpty) return null;

    final focusedId = item.focusedMediaId;
    if (focusedId != null) {
      for (final media in detail.media) {
        if (media.id == focusedId) return media;
      }
    }

    final focusedIndex = item.focusedMediaIndex;
    if (focusedIndex != null &&
        focusedIndex >= 0 &&
        focusedIndex < detail.media.length) {
      return detail.media[focusedIndex];
    }
    return detail.media.first;
  }

  List<GalleryCharacterPrompt> _characterPrompts(
    GalleryItem item,
    GalleryDetail? detail,
  ) {
    if (detail != null && detail.characterPrompts.isNotEmpty) {
      return detail.characterPrompts;
    }

    final rawCharacters = item.rawSourceMetadata['characterPrompts'];
    if (rawCharacters is! List) return const [];
    return [
      for (final raw in rawCharacters.whereType<Map>())
        if (_hasCharacterPrompt(raw))
          GalleryCharacterPrompt(
            label: raw['label']?.toString() ?? '',
            prompt: raw['prompt']?.toString() ?? '',
            negativePrompt:
                raw['negativePrompt']?.toString() ??
                raw['negative']?.toString() ??
                '',
          ),
    ];
  }

  bool _hasCharacterPrompt(Map<dynamic, dynamic> raw) =>
      (raw['prompt']?.toString().trim().isNotEmpty ?? false) ||
      (raw['negativePrompt']?.toString().trim().isNotEmpty ?? false) ||
      (raw['negative']?.toString().trim().isNotEmpty ?? false);

  String? _metadataString(Map<String, dynamic> metadata, String key) {
    final value = metadata[key]?.toString();
    return value == null || value.trim().isEmpty ? null : value;
  }

  String? _firstNonBlank(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  String _buildCopyText(
    String positivePrompt,
    String negativePrompt,
    List<GalleryCharacterPrompt> characterPrompts,
  ) {
    final blocks = <String>[];
    if (positivePrompt.trim().isNotEmpty) blocks.add(positivePrompt.trim());
    if (negativePrompt.trim().isNotEmpty) {
      blocks.add('Negative Prompt:\n${negativePrompt.trim()}');
    }
    for (var index = 0; index < characterPrompts.length; index++) {
      final character = characterPrompts[index];
      final lines = <String>[
        if (character.prompt.trim().isNotEmpty) character.prompt.trim(),
        if (character.negativePrompt.trim().isNotEmpty)
          'Negative Prompt: ${character.negativePrompt.trim()}',
      ];
      if (lines.isEmpty) continue;
      final label = character.label.trim().isEmpty
          ? 'Character Prompt ${index + 1}'
          : character.label.trim();
      blocks.add('$label:\n${lines.join('\n')}');
    }
    return blocks.join('\n\n');
  }
}
