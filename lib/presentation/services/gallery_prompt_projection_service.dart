import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/online_gallery/gallery_item.dart';
import '../../data/models/online_gallery/gallery_prompt_projection.dart';
import '../../data/models/online_gallery/gallery_source.dart';
import '../providers/online_gallery_output_filter_provider.dart';
import '../providers/online_gallery_prompt_tag_settings_provider.dart';

/// Projects each gallery source's real prompt shape into action-specific data.
///
/// Generation uses [OnlineGalleryPromptTagSettings]. Copy exposes a separate
/// selection model, so changing a copy dialog never mutates generation policy.
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
    return switch (item.sourceId) {
      GallerySourceId.danbooru ||
      GallerySourceId.safebooru => _projectCategorizedBooru(
        item: item,
        promptTagSettings: promptTagSettings,
        outputFilter: outputFilter,
      ),
      GallerySourceId.gelbooru => _projectFlatTags(
        item: item,
        promptTagSettings: promptTagSettings,
        outputFilter: outputFilter,
      ),
      GallerySourceId.aiTag => _projectStructured(
        item: item,
        detail: detail,
        media: media,
        promptTagSettings: promptTagSettings,
        outputFilter: outputFilter,
        characters: _aiTagCharacters(media, detail),
      ),
      GallerySourceId.quickTagCloud => _projectStructured(
        item: item,
        detail: detail,
        media: media,
        promptTagSettings: promptTagSettings,
        outputFilter: outputFilter,
        characters: _detailOrMetadataCharacters(item, detail),
      ),
    };
  }

  String projectPositivePrompt(
    String prompt, {
    required OnlineGalleryOutputFilterSettings outputFilter,
  }) => outputFilter.filterPrompt(prompt);

  GalleryPromptProjection _projectCategorizedBooru({
    required GalleryItem item,
    required OnlineGalleryPromptTagSettings promptTagSettings,
    required OnlineGalleryOutputFilterSettings outputFilter,
  }) {
    final categorizedPrompts = <GalleryPromptCopyCategory, String>{
      for (final category in GalleryPromptCopyCategory.values)
        category: _categoryPrompt(item, category, outputFilter),
    }..removeWhere((_, value) => value.isEmpty);
    final positivePrompt = promptTagSettings.promptFor(
      item,
      outputFilter: outputFilter,
    );
    return GalleryPromptProjection(
      positivePrompt: positivePrompt,
      negativePrompt: '',
      characterPrompts: const [],
      copy: GalleryPromptCopyProjection(
        mainPositive: categorizedPrompts.isEmpty ? positivePrompt : '',
        categorizedPrompts: Map.unmodifiable(categorizedPrompts),
      ),
    );
  }

  GalleryPromptProjection _projectFlatTags({
    required GalleryItem item,
    required OnlineGalleryPromptTagSettings promptTagSettings,
    required OnlineGalleryOutputFilterSettings outputFilter,
  }) {
    final prompt = promptTagSettings.promptFor(
      item,
      outputFilter: outputFilter,
    );
    return GalleryPromptProjection(
      positivePrompt: prompt,
      negativePrompt: '',
      characterPrompts: const [],
      copy: GalleryPromptCopyProjection(mainPositive: prompt),
    );
  }

  GalleryPromptProjection _projectStructured({
    required GalleryItem item,
    required GalleryDetail? detail,
    required GalleryMedia? media,
    required OnlineGalleryPromptTagSettings promptTagSettings,
    required OnlineGalleryOutputFilterSettings outputFilter,
    required List<GalleryCharacterPrompt> characters,
  }) {
    final generatedTagPrompt = promptTagSettings.promptFor(
      item,
      outputFilter: outputFilter,
    );
    final rawPositive = _firstNonBlank([
      media?.prompt,
      detail?.prompt,
      item.cover.prompt,
      _metadataString(item.rawSourceMetadata, 'prompt'),
      generatedTagPrompt,
    ]);
    final positive = outputFilter.filterPrompt(rawPositive ?? '');
    final negative =
        _firstNonBlank([
          media?.negativePrompt,
          detail?.negativePrompt,
          item.cover.negativePrompt,
          _metadataString(item.rawSourceMetadata, 'negativePrompt'),
        ]) ??
        '';
    final projectedCharacters = List<GalleryCharacterPrompt>.unmodifiable(
      characters.map(
        (character) => GalleryCharacterPrompt(
          label: character.label,
          prompt: outputFilter.filterPrompt(character.prompt),
          negativePrompt: character.negativePrompt,
          positionX: character.positionX,
          positionY: character.positionY,
        ),
      ),
    );
    return GalleryPromptProjection(
      positivePrompt: positive,
      negativePrompt: negative,
      characterPrompts: projectedCharacters,
      copy: GalleryPromptCopyProjection(
        mainPositive: positive,
        mainNegative: negative,
        characterPrompts: projectedCharacters,
      ),
    );
  }

  String _categoryPrompt(
    GalleryItem item,
    GalleryPromptCopyCategory category,
    OnlineGalleryOutputFilterSettings outputFilter,
  ) {
    final tags = switch (category) {
      GalleryPromptCopyCategory.general => item.generalTags,
      GalleryPromptCopyCategory.character => item.characterTags,
      GalleryPromptCopyCategory.copyright => item.copyrightTags,
      GalleryPromptCopyCategory.artist => item.artistTags,
      GalleryPromptCopyCategory.meta => item.metaTags,
    };
    final values = <String>[];
    final seen = <String>{};
    for (final tag in tags) {
      final rendered = category == GalleryPromptCopyCategory.artist
          ? _formatArtistTag(tag)
          : tag;
      if (outputFilter.contains(tag) || outputFilter.contains(rendered)) {
        continue;
      }
      if (seen.add(rendered)) values.add(rendered);
    }
    return values.join(', ');
  }

  String _formatArtistTag(String tag) {
    const prefix = 'artist:';
    if (tag.toLowerCase().startsWith(prefix)) return tag;
    return '$prefix$tag';
  }

  List<GalleryCharacterPrompt> _aiTagCharacters(
    GalleryMedia? media,
    GalleryDetail? detail,
  ) {
    final metadata = media?.promptMetadata;
    if (metadata != null) {
      final count = _metadataCharacterCount(metadata);
      if (count > 0) {
        return List.generate(count, (index) {
          final info = index < metadata.characterInfos.length
              ? metadata.characterInfos[index]
              : null;
          return GalleryCharacterPrompt(
            label: '',
            prompt: info?.prompt ?? _at(metadata.characterPrompts, index),
            negativePrompt:
                info?.negativePrompt ??
                _at(metadata.characterNegativePrompts, index),
            positionX: info?.centerX,
            positionY: info?.centerY,
          );
        });
      }
    }
    return detail?.characterPrompts ?? const [];
  }

  int _metadataCharacterCount(NaiImageMetadata metadata) => [
    metadata.characterPrompts.length,
    metadata.characterNegativePrompts.length,
    metadata.characterInfos.length,
  ].reduce((left, right) => left > right ? left : right);

  String _at(List<String> values, int index) =>
      index < values.length ? values[index] : '';

  List<GalleryCharacterPrompt> _detailOrMetadataCharacters(
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
            positionX: _double(raw['positionX'] ?? raw['centerX']),
            positionY: _double(raw['positionY'] ?? raw['centerY']),
          ),
    ];
  }

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

  double? _double(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
}
